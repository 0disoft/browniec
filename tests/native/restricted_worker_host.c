#define WIN32_LEAN_AND_MEAN
#include <aclapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <userenv.h>
#include <wchar.h>
#include "../../native/restricted_worker.h"
#include "../../native/restricted_worker_broker.h"
#include "../../native/host_adapter_process.h"
#include "../../native/restricted_worker_process_route.h"
#include "../../native/restricted_worker_gate.h"
#include "../../native/restricted_worker_io.h"
#include "../../native/restricted_worker_pipes.h"
#include "../../native/restricted_worker_stage.h"
#include "../../native/restricted_worker_stream.h"
#include "../../native/windows-scalar-worker.h"
#include "../../native/runtime-engine/clock.inc"

enum { commit_limit = 128 * 1024 * 1024, cpu_limit = 500 };
enum { worker_pipe_buffers = 3 * 2 * 4096, process_pipe_buffers = worker_pipe_buffers + 2 * 2 * 8192 };
static const DWORD status_quota_exceeded = 0xc0000044;
static wchar_t profile_name[64];
static PSID profile;
static bc_worker_pipes pipes;
static HANDLE decoy;
static bc_restricted_worker worker;
static SIZE_T worker_launch_heap;

static void check(BOOL ok, const char *what) {
    if (!ok) {
        fprintf(stderr, "%s (Windows error %lu)\n", what, GetLastError());
        exit(1);
    }
}

static void clean_profile(void) {
    if (profile) {
        FreeSid(profile);
        profile = NULL;
        const HRESULT status = DeleteAppContainerProfile(profile_name);
        if (FAILED(status))
            fprintf(stderr, "DeleteAppContainerProfile: 0x%08lx\n", (unsigned long)status);
    }
}

static void cleanup(void) {
    if (worker.job) TerminateJobObject(worker.job, 1);
    if (worker.process) WaitForSingleObject(worker.process, 5000);
    bc_restricted_worker_close(&worker);
    bc_worker_pipes_close(&pipes);
    if (decoy) CloseHandle(decoy);
    decoy = NULL;
    clean_profile();
}

static void permit_execute(wchar_t *path) {
    PACL existing = NULL, updated = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    check(GetNamedSecurityInfoW(path, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION,
        NULL, NULL, &existing, NULL, &descriptor) == ERROR_SUCCESS, "read fixture DACL");
    EXPLICIT_ACCESSW grant = {0};
    grant.grfAccessPermissions = FILE_GENERIC_READ | FILE_GENERIC_EXECUTE;
    grant.grfAccessMode = GRANT_ACCESS;
    BuildTrusteeWithSidW(&grant.Trustee, profile);
    check(SetEntriesInAclW(1, &grant, existing, &updated) == ERROR_SUCCESS, "build fixture DACL");
    check(SetNamedSecurityInfoW(path, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION,
        NULL, NULL, updated, NULL) == ERROR_SUCCESS, "set executable-only fixture grant");
    LocalFree(updated);
    LocalFree(descriptor);
}

typedef struct stage_stop_fixture {
    const bc_worker_stage *stage;
    DWORD cause;
    unsigned copy_checkpoints;
} stage_stop_fixture;

static DWORD interrupt_staging(void *context) {
    const stage_stop_fixture *fixture = context;
    return *fixture->stage->name ? fixture->cause : ERROR_SUCCESS;
}

static DWORD interrupt_stage_copy(void *context) {
    stage_stop_fixture *fixture = context;
    if (!fixture->stage->owns_image) return ERROR_SUCCESS;
    return ++fixture->copy_checkpoints == 3 ? fixture->cause : ERROR_SUCCESS;
}

typedef struct stage_finish_fixture {
    const bc_worker_stage *stage;
    DWORD before_cleanup;
    DWORD after_cleanup;
    unsigned calls;
} stage_finish_fixture;

static DWORD observe_stage_finish(void *context) {
    stage_finish_fixture *fixture = context;
    const bc_worker_stage *stage = fixture->stage;
    if (++fixture->calls == 1) {
        check(stage->owns_directory && stage->pinned_image && stage->profile,
            "first stop sample precedes cleanup");
        return fixture->before_cleanup;
    }
    check(fixture->calls == 2 && !stage->owns_image && !stage->owns_directory &&
        !stage->pinned_image && !stage->profile &&
        GetFileAttributesW(stage->directory) == INVALID_FILE_ATTRIBUTES,
        "second stop sample follows stage reclamation");
    return fixture->after_cleanup;
}

static void verify_stage(const wchar_t *application) {
    bc_worker_stage stage = {0};
    check(bc_worker_stage_open(&stage, application, NULL, NULL) == ERROR_SUCCESS, "provision worker image and profile");
    PACL acl = NULL;
    PSECURITY_DESCRIPTOR descriptor = NULL;
    check(GetSecurityInfo(stage.pinned_image, SE_FILE_OBJECT, DACL_SECURITY_INFORMATION,
        NULL, NULL, &acl, NULL, &descriptor) == ERROR_SUCCESS && acl && acl->AceCount == 3,
        "read exactly three staged image ACEs");
    SECURITY_DESCRIPTOR_CONTROL control;
    DWORD revision = 0;
    void *entry = NULL;
    check(GetSecurityDescriptorControl(descriptor, &control, &revision) &&
        (control & SE_DACL_PROTECTED) && GetAce(acl, 2, &entry), "protect the staged image ACL");
    const ACCESS_ALLOWED_ACE *grant = entry;
    check(grant->Header.AceType == ACCESS_ALLOWED_ACE_TYPE && !grant->Header.AceFlags &&
        grant->Mask == (FILE_GENERIC_READ | FILE_GENERIC_EXECUTE) &&
        EqualSid(stage.profile, (PSID)&grant->SidStart), "grant only read and execute to the worker SID");
    LocalFree(descriptor);
    check(!DeleteFileW(stage.image) && GetLastError() == ERROR_SHARING_VIOLATION, "pin staged image until teardown");
    check(bc_worker_stage_close(&stage) && GetFileAttributesW(stage.directory) == INVALID_FILE_ATTRIBUTES,
        "remove worker image and stage");
    PSID reclaimed = NULL;
    check(SUCCEEDED(CreateAppContainerProfile(stage.name, stage.name, stage.name, NULL, 0, &reclaimed)),
        "release the profile name");
    FreeSid(reclaimed);
    check(SUCCEEDED(DeleteAppContainerProfile(stage.name)), "delete the profile reuse probe");

    check(bc_worker_stage_open(&stage, L"empty-image.exe", NULL, NULL) == ERROR_FILE_TOO_LARGE &&
        stage.owns_image && stage.profile, "reject an empty image after acquiring stage resources");
    check(bc_worker_stage_close(&stage) && GetFileAttributesW(stage.directory) == INVALID_FILE_ATTRIBUTES,
        "remove partially prepared image and stage");
    stage_stop_fixture fixture = {&stage, ERROR_TIMEOUT, 0};
    stage = (bc_worker_stage){0};
    check(bc_worker_stage_open(&stage, application, interrupt_staging, &fixture) == ERROR_TIMEOUT &&
        stage.profile && !stage.owns_directory, "expire the stage after provisioning the profile");
    check(bc_worker_stage_close(&stage), "reclaim the profile on expiry before copying");

    for (unsigned i = 0; i < 2; ++i) {
        stage = (bc_worker_stage){0};
        fixture.cause = i ? ERROR_TIMEOUT : ERROR_CANCELLED;
        fixture.copy_checkpoints = 0;
        check(bc_worker_stage_open(&stage, application, interrupt_stage_copy, &fixture) == fixture.cause &&
            stage.owns_image && !stage.pinned_image, "stop the stage before copying its second chunk");
        WIN32_FILE_ATTRIBUTE_DATA partial;
        check(GetFileAttributesExW(stage.image, GetFileExInfoStandard, &partial) &&
            !partial.nFileSizeHigh && partial.nFileSizeLow == 16 * 1024,
            "only one chunk was copied before the stop");
        check(bc_worker_stage_close(&stage) && GetFileAttributesW(stage.directory) == INVALID_FILE_ATTRIBUTES,
            "reclaim partial image, directory and profile after a staging stop");
    }

    const struct { DWORD before, after, result; unsigned calls; } finish_cases[] = {
        {ERROR_SUCCESS, ERROR_SUCCESS, ERROR_SUCCESS, 2},
        {ERROR_SUCCESS, ERROR_CANCELLED, ERROR_CANCELLED, 2},
        {ERROR_SUCCESS, ERROR_TIMEOUT, ERROR_TIMEOUT, 2},
        {ERROR_CANCELLED, ERROR_TIMEOUT, ERROR_CANCELLED, 1},
    };
    for (size_t i = 0; i < _countof(finish_cases); ++i) {
        stage = (bc_worker_stage){0};
        check(bc_worker_stage_open(&stage, application, NULL, NULL) == ERROR_SUCCESS,
            "stage a worker image for publication checks");
        stage_finish_fixture finish = {&stage, finish_cases[i].before, finish_cases[i].after, 0};
        check(bc_worker_stage_finish(&stage, observe_stage_finish, &finish) == finish_cases[i].result &&
            finish.calls == finish_cases[i].calls && !stage.profile &&
            GetFileAttributesW(stage.directory) == INVALID_FILE_ATTRIBUTES,
            "settle publication after cleanup without replacing an earlier stop");
    }
}

static BOOL decoy_is_absent(HANDLE handle) {
    // AppContainer strict handle checks can raise STATUS_INVALID_HANDLE.
    __try {
        DWORD flags = 0;
        return !GetHandleInformation(handle, &flags) && GetLastError() == ERROR_INVALID_HANDLE;
    } __except (GetExceptionCode() == (DWORD)0xc0000008 ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
        return TRUE;
    }
}

static BOOL child_read(HANDLE input, uint8_t *bytes, DWORD length) {
    while (length) {
        DWORD count = 0;
        if (!ReadFile(input, bytes, length, &count, NULL) || !count) return FALSE;
        bytes += count;
        length -= count;
    }
    return TRUE;
}

enum fixture_mode {
    cpu, clean, early, trailing, stalled, stalled_result, cancel_reply, cancel_ignore,
    host_ok, host_wrong_id, host_oversized, host_exhausted, host_invalid, host_cancel_rx, host_cancel_tx
};
enum { long_request_bytes = BC_WORKER_IO_WINDOW + 1 };

static bool child_send(HANDLE output, const bc_worker_frame *frame, const uint8_t *body) {
    uint8_t header[BC_WORKER_FRAME_BYTES];
    DWORD count;
    return bc_worker_frame_encode(header, frame) &&
        WriteFile(output, header, sizeof(header), &count, NULL) && count == sizeof(header) &&
        (!frame->length || (WriteFile(output, body, frame->length, &count, NULL) && count == frame->length));
}

static int child_host(HANDLE input, HANDLE output, bc_worker_frame frame, enum fixture_mode mode) {
    uint8_t header[BC_WORKER_FRAME_BYTES];
    uint8_t reply[long_request_bytes];
    const uint8_t body[] = {41, 0};
    uint64_t calls = mode == host_ok || mode == host_exhausted ? 2 : 1;
    for (uint64_t call = 1; call <= calls; ++call) {
        frame.kind = BC_WORKER_HOST_REQUEST;
        frame.sequence = 1 + call;
        frame.correlation = call + (mode == host_wrong_id);
        frame.length = mode == host_oversized ? 2 : 1;
        const uint8_t invalid = 0;
        if (!child_send(output, &frame, mode == host_invalid ? &invalid : body)) return 21;
        if (mode == host_wrong_id || mode == host_oversized || mode == host_invalid ||
            (mode == host_exhausted && call == calls)) return 0;
        bc_worker_frame expected = frame;
        expected.sequence = 2 + call;
        expected.kind = mode == host_cancel_rx ? BC_WORKER_CANCEL : BC_WORKER_HOST_REPLY;
        expected.correlation = mode == host_cancel_rx ? 0 : call;
        expected.length = mode == host_cancel_rx ? 0 : sizeof(reply);
        bc_worker_frame incoming;
        if (!child_read(input, header, sizeof(header)) ||
            !bc_worker_frame_preflight(header, sizeof(header), &expected, &incoming) ||
            incoming.length != expected.length) return 22;
        if (incoming.length && (!child_read(input, reply, incoming.length) ||
            reply[0] != (uint8_t)(41 + call) || reply[sizeof(reply) - 1] != 255)) return 23;
        if (mode == host_cancel_tx) {
            ++expected.sequence;
            expected.kind = BC_WORKER_CANCEL;
            expected.correlation = 0;
            expected.length = 0;
            if (!child_read(input, header, sizeof(header)) ||
                !bc_worker_frame_preflight(header, sizeof(header), &expected, &incoming)) return 24;
        }
    }
    frame.kind = BC_WORKER_RESULT;
    frame.sequence = 2 + calls;
    frame.correlation = 0;
    frame.length = 1;
    const uint8_t result = 42;
    return child_send(output, &frame, &result) ? 0 : 25;
}

static int child(wchar_t *number, enum fixture_mode mode) {
    const HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
    const HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    const HANDLE error = GetStdHandle(STD_ERROR_HANDLE);
    HANDLE inherited_decoy = (HANDLE)(ULONG_PTR)_wcstoui64(number, NULL, 16);
    if (!decoy_is_absent(inherited_decoy)) return 2;
    HANDLE forbidden = CreateFileW(L"parent-data.txt", GENERIC_READ, FILE_SHARE_READ,
        NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (forbidden != INVALID_HANDLE_VALUE || GetLastError() != ERROR_ACCESS_DENIED) return 3;
    wchar_t environment[16];
    if (GetEnvironmentVariableW(L"BC_WORKER_TEST_PARENT", environment, _countof(environment))) return 4;
    void *oversized = VirtualAlloc(NULL, commit_limit, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (oversized) return 5;
    uint8_t header[BC_WORKER_FRAME_BYTES];
    bc_worker_frame expected = {.kind = BC_WORKER_HELLO, .sequence = 1};
    bc_worker_frame received;
    if (!child_read(input, header, sizeof(header)) ||
        !bc_worker_frame_preflight(header, sizeof(header), &expected, &received)) return 6;
    if (mode == stalled) return child_read(input, header, 1) ? 11 : 0;
    if (mode == early) {
        received.kind = BC_WORKER_RESULT;
        received.sequence = 2;
    } else {
        received.kind = BC_WORKER_READY;
    }
    DWORD count = 0;
    if (!bc_worker_frame_encode(header, &received) ||
        !WriteFile(output, header, sizeof(header), &count, NULL) || count != sizeof(header)) return 7;
    if (mode == early) return 0;
    expected = received;
    expected.kind = BC_WORKER_START;
    expected.sequence = 2;
    uint8_t request[long_request_bytes];
    expected.length = mode == cancel_reply ? sizeof(request) : 1;
    uint8_t byte = 0;
    if (!child_read(input, header, sizeof(header)) ||
        !bc_worker_frame_preflight(header, sizeof(header), &expected, &received) ||
        !bc_worker_frame_complete(&received, expected.length) ||
        !child_read(input, request, expected.length) || request[0] != 41) return 8;
    if (mode == stalled_result) return child_read(input, header, 1) ? 13 : 0;
    if (mode >= host_ok) return child_host(input, output, received, mode);
    if (mode == cancel_reply || mode == cancel_ignore) {
        for (size_t i = 1; i < expected.length; ++i)
            if (request[i] != 0) return 14;
        expected.kind = BC_WORKER_CANCEL;
        expected.sequence = 3;
        expected.length = 0;
        bc_worker_frame cancellation;
        if (!child_read(input, header, sizeof(header)) ||
            !bc_worker_frame_preflight(header, sizeof(header), &expected, &cancellation)) return 15;
        if (mode == cancel_ignore) Sleep(INFINITE);
    }
    byte = (uint8_t)(request[0] + 1);
    received.kind = BC_WORKER_RESULT;
    received.length = 1;
    if (!bc_worker_frame_encode(header, &received) ||
        !WriteFile(output, header, sizeof(header), &count, NULL) || count != sizeof(header) ||
        !WriteFile(output, &byte, 1, &count, NULL) || count != 1) return 9;
    if (!WriteFile(error, &byte, 1, &count, NULL) || count != 1) return 10;
    if (mode == trailing &&
        (!WriteFile(output, &byte, 1, &count, NULL) || count != 1)) return 12;
    if (mode != cpu) return 0;
    // The Job's user CPU limit must stop this process without parent intervention.
    for (;;) YieldProcessor();
}

static int production_peer(bool cancel) {
    uint8_t start[9];
    if (bc_project_worker_begin() != sizeof(start) || !bc_project_worker_read(start, sizeof(start)) ||
        start[0] != 41 || bc_project_worker_read(start, sizeof(start))) return 26;
    const uint8_t request = start[0];
    uint8_t reply[long_request_bytes];
    size_t length = 123;
    if (cancel) {
        if (bc_project_worker_host(&request, 1, reply, sizeof(reply), &length) != 2 || length != 123 ||
            bc_project_worker_host(&request, 1, reply, sizeof(reply), &length) || length != 123) return 27;
    } else {
        for (uint8_t i = 1; i <= 2; ++i) {
            if (bc_project_worker_host(&request, 1, reply, sizeof(reply), &length) != 1 ||
                length != sizeof(reply) || reply[0] != 41 + i || reply[length - 1] != 255) return 28;
        }
    }
    const uint8_t result = 42;
    return bc_scalar_worker_finish(&result, 1) ? 0 : 29;
}

static void verify_pipes(void) {
    HANDLE token = NULL;
    check(OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token), "open broker token");
    union {
        TOKEN_GROUPS groups;
        BYTE bytes[sizeof(TOKEN_GROUPS) + SECURITY_MAX_SID_SIZE];
    } logon;
    DWORD used = 0;
    check(GetTokenInformation(token, TokenLogonSid, &logon, sizeof(logon), &used) &&
        logon.groups.GroupCount == 1, "resolve broker logon SID");
    check(CloseHandle(token), "close broker token");

    for (size_t i = 0; i < BC_WORKER_PIPE_COUNT; ++i) {
        HANDLE broker = pipes.broker[i], child = pipes.child[i];
        DWORD flags = 0, instances = 0;
        check(GetHandleInformation(broker, &flags) && !(flags & HANDLE_FLAG_INHERIT),
            "broker endpoint is noninheritable");
        check(GetHandleInformation(child, &flags) && (flags & HANDLE_FLAG_INHERIT),
            "child endpoint is inheritable");
        check(GetNamedPipeInfo(child, &flags, NULL, NULL, &instances) &&
            !(flags & PIPE_SERVER_END) && instances == 1, "single worker pipe instance");
        ULONG pid = 0;
        check(GetNamedPipeClientProcessId(broker, &pid) && pid == GetCurrentProcessId(),
            "pipe client belongs to broker before launch");

        PACL acl = NULL;
        PSECURITY_DESCRIPTOR descriptor = NULL;
        check(GetSecurityInfo(broker, SE_KERNEL_OBJECT, DACL_SECURITY_INFORMATION,
            NULL, NULL, &acl, NULL, &descriptor) == ERROR_SUCCESS, "query real pipe DACL");
        ACL_SIZE_INFORMATION info;
        void *entry = NULL;
        check(acl && GetAclInformation(acl, &info, sizeof(info), AclSizeInformation) &&
            info.AceCount == 1 && GetAce(acl, 0, &entry), "one pipe ACL entry");
        ACCESS_ALLOWED_ACE *ace = entry;
        check(ace->Header.AceType == ACCESS_ALLOWED_ACE_TYPE &&
            !(ace->Mask & FILE_CREATE_PIPE_INSTANCE) &&
            EqualSid(&ace->SidStart, logon.groups.Groups[0].Sid),
            "only the broker logon SID may open endpoints");
        LocalFree(descriptor);
    }
}

static DWORD transfer(HANDLE pipe, uint8_t *receive, const uint8_t *send, DWORD length, DWORD *count) {
    bc_worker_io io = {0};
    check(bc_worker_io_open(&io) == ERROR_SUCCESS, "open fixture I/O lease");
    DWORD status = bc_worker_io_start(&io, pipe, receive, send, length, count);
    if (status == ERROR_IO_PENDING) {
        const DWORD wait = WaitForSingleObject(io.event, 5000);
        if (wait == WAIT_OBJECT_0) {
            status = bc_worker_io_poll(&io, count);
        } else {
            status = wait == WAIT_TIMEOUT ? ERROR_TIMEOUT : GetLastError();
            bc_worker_io_cancel(&io);
            check(WaitForSingleObject(io.event, 5000) == WAIT_OBJECT_0, "wait for fixture I/O reap");
            bc_worker_io_poll(&io, count);
        }
    }
    check(bc_worker_io_close(&io) == ERROR_SUCCESS, "close fixture I/O lease");
    SetLastError(status);
    return status;
}

static void verify_io_lifetime(void) {
    bc_worker_io io = {0};
    check(bc_worker_io_open(&io) == ERROR_SUCCESS, "open native I/O lifetime fixture");
    HANDLE output = pipes.broker[BC_WORKER_STDOUT];
    HANDLE peer = pipes.child[BC_WORKER_STDOUT];
    DWORD flags = HANDLE_FLAG_INHERIT;
    check(GetHandleInformation(io.event, &flags) && !(flags & HANDLE_FLAG_INHERIT),
        "I/O event is noninheritable");
    uint8_t byte = 19;
    DWORD count = 123;
    check(bc_worker_io_start(&io, output, &byte, NULL, 1, &count) == ERROR_IO_PENDING &&
        bc_worker_io_poll(&io, &count) == ERROR_IO_PENDING && count == 123,
        "idle reader has a pending lease and no byte count");
    check(bc_worker_io_start(&io, output, &byte, NULL, 1, &count) == ERROR_BUSY &&
        bc_worker_io_cancel(&io) == ERROR_SUCCESS &&
        bc_worker_io_close(&io) == ERROR_IO_PENDING && io.pipe == output,
        "cancel neither reuses nor closes an uncollected lease");
    check(WaitForSingleObject(io.event, 5000) == WAIT_OBJECT_0 &&
        bc_worker_io_poll(&io, &count) == ERROR_OPERATION_ABORTED && count == 123 && byte == 19,
        "explicitly reap the cancelled operation");

    check(bc_worker_io_start(&io, output, &byte, NULL, 1, &count) == ERROR_IO_PENDING,
        "reuse a reaped event for another transfer");
    const uint8_t sent = 42;
    DWORD written = 0;
    check(WriteFile(peer, &sent, 1, &written, NULL) && written == 1 &&
        WaitForSingleObject(io.event, 5000) == WAIT_OBJECT_0, "complete before cancellation request");
    const DWORD cancelled = bc_worker_io_cancel(&io);
    check((cancelled == ERROR_NOT_FOUND || cancelled == ERROR_SUCCESS) &&
        bc_worker_io_close(&io) == ERROR_IO_PENDING &&
        bc_worker_io_poll(&io, &count) == ERROR_SUCCESS && count == 1 && byte == sent,
        "completion wins the cancellation race and still requires reap");
    check(bc_worker_io_close(&io) == ERROR_SUCCESS && !io.event && !io.pipe,
        "release the event after actual completion");
}

static void send_frame(HANDLE pipe, const bc_worker_frame *frame, const uint8_t *body) {
    bc_worker_tx tx;
    check(bc_worker_tx_begin(&tx, frame, body), "begin bounded fixture frame send");
    const uint8_t *bytes;
    size_t length;
    while ((length = bc_worker_tx_window(&tx, &bytes)) != 0) {
        if (!tx.sent && frame->kind == BC_WORKER_HELLO) length = 7;
        DWORD count = 0;
        check(transfer(pipe, NULL, bytes, (DWORD)length, &count) == ERROR_SUCCESS &&
            bc_worker_tx_advance(&tx, count), "send bounded fixture frame window");
    }
}

static bc_worker_rx_status receive_frame(HANDLE pipe, bc_worker_rx *rx) {
    uint8_t *bytes;
    size_t length;
    while ((length = bc_worker_rx_window(rx, &bytes)) != 0) {
        DWORD count = 0;
        const DWORD status = transfer(pipe, bytes, NULL, (DWORD)length, &count);
        if (status == ERROR_BROKEN_PIPE) return bc_worker_rx_eof(rx);
        check(status == ERROR_SUCCESS, "receive bounded fixture frame window");
        bc_worker_rx_advance(rx, count);
    }
    return rx->status;
}

static void verify_frames(void) {
    const bc_worker_frame ready = {
        .kind = BC_WORKER_READY, .sequence = 1,
        .nonce = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
    };
    const uint8_t ready_wire[BC_WORKER_FRAME_BYTES] = {
        'B','C','W','K',1,0,2,0, 0,0,0,0,0,0,0,0,
        1,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        1,2,3,4,5,6,7,8, 9,10,11,12,13,14,15,16
    };
    uint8_t header[BC_WORKER_FRAME_BYTES + 1] = {0};
    check(bc_worker_frame_encode(header, &ready) && !memcmp(header, ready_wire, sizeof(ready_wire)),
        "exact little-endian wire layout");
    bc_worker_frame decoded = {.sequence = 123};
    for (size_t i = 0; i < BC_WORKER_FRAME_BYTES; ++i) {
        check(!bc_worker_frame_preflight(header, i, &ready, &decoded), "reject truncated header");
        header[i] ^= 1;
        check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &ready, &decoded),
            "reject mutated READY field");
        header[i] ^= 1;
    }
    check(!bc_worker_frame_preflight(header, sizeof(header), &ready, &decoded) &&
        decoded.sequence == 123, "reject excess header and retain caller state on failure");
    check(bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &ready, &decoded) &&
        bc_worker_frame_complete(&decoded, 0), "accept exact READY frame");

    bc_worker_frame expected = ready;
    expected.kind = BC_WORKER_HOST_REPLY;
    expected.sequence = 0x0102030405060708ULL;
    expected.correlation = 0x0807060504030201ULL;
    expected.length = BC_WORKER_FRAME_PAYLOAD_MAX;
    check(bc_worker_frame_encode(header, &expected), "encode at wire maximum");
    check(bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded) &&
        bc_worker_frame_complete(&decoded, expected.length) &&
        !bc_worker_frame_complete(&decoded, expected.length - 1) &&
        !bc_worker_frame_complete(&decoded, expected.length + 1), "require exact bounded body size");
    ++expected.sequence;
    check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "reject duplicate frame when the receive sequence advances");
    --expected.sequence;
    ++expected.correlation;
    check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "reject crossed request");
    --expected.correlation;
    --expected.length;
    check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "reject wire length above session ceiling");
    header[11] = 1;
    expected.length = UINT32_MAX;
    check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded) &&
        !bc_worker_frame_encode(header, &expected), "enforce absolute wire limit");
    expected = ready;
    memset(expected.nonce, 0, sizeof(expected.nonce));
    check(bc_worker_frame_encode(header, &ready) &&
        !bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "READY requires the broker nonce");
    expected = ready;
    expected.kind = BC_WORKER_HELLO;
    check(bc_worker_frame_encode(header, &expected), "encode initial HELLO");
    memset(expected.nonce, 0, sizeof(expected.nonce));
    check(bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "only initial HELLO can establish a session");
    memset(header + 32, 0, BC_WORKER_NONCE_BYTES);
    check(!bc_worker_frame_preflight(header, BC_WORKER_FRAME_BYTES, &expected, &decoded),
        "reject zero session nonce");
}

static void verify_stream(void) {
    const bc_worker_frame frame = {
        .kind = BC_WORKER_RESULT, .sequence = 2, .nonce = {1},
        .length = BC_WORKER_IO_WINDOW + 1
    };
    uint8_t outgoing[BC_WORKER_IO_WINDOW + 1] = {17};
    uint8_t incoming[sizeof(outgoing)] = {0};
    bc_worker_tx tx;
    bc_worker_rx rx;
    const uint8_t *source;
    uint8_t *target;
    check(bc_worker_tx_begin(&tx, &frame, outgoing), "start stream fixture");
    check(bc_worker_tx_window(&tx, &source) == BC_WORKER_FRAME_BYTES &&
        !bc_worker_tx_advance(&tx, BC_WORKER_FRAME_BYTES + 1), "TX cannot cross the header boundary");
    bc_worker_rx_begin(&rx, &frame, incoming, sizeof(incoming));
    check(bc_worker_rx_window(&rx, &target) == BC_WORKER_FRAME_BYTES, "only the header is writable first");
    memcpy(target, source, 7);
    check(bc_worker_rx_advance(&rx, 7) == BC_WORKER_RX_HEADER &&
        !bc_worker_rx_frame(&rx) &&
        bc_worker_rx_eof(&rx) == BC_WORKER_RX_TRUNCATED, "EOF in header never delivers");

    bc_worker_rx_begin(&rx, &frame, incoming, sizeof(incoming) - 1);
    check(bc_worker_rx_window(&rx, &target) == BC_WORKER_FRAME_BYTES, "receive over-cap header only");
    memcpy(target, source, BC_WORKER_FRAME_BYTES);
    check(bc_worker_rx_advance(&rx, BC_WORKER_FRAME_BYTES) == BC_WORKER_RX_REJECTED &&
        !bc_worker_rx_window(&rx, &target) && !bc_worker_rx_frame(&rx) && !incoming[0],
        "reject before touching storage one byte too small");

    bc_worker_rx_begin(&rx, &frame, incoming, sizeof(incoming));
    for (size_t step = 0; step < 3; ++step) {
        const size_t expected[] = {BC_WORKER_FRAME_BYTES, BC_WORKER_IO_WINDOW, 1};
        const size_t length = bc_worker_tx_window(&tx, &source);
        check(length == expected[step] && length == bc_worker_rx_window(&rx, &target),
            "header and payload stay in separate bounded windows");
        memcpy(target, source, length);
        check(bc_worker_tx_advance(&tx, length), "advance bounded TX");
        bc_worker_rx_advance(&rx, length);
        check((bc_worker_rx_frame(&rx) != NULL) == (step == 2), "deliver only after all bytes");
        if (step == 1) {
            bc_worker_rx truncated = rx;
            check(bc_worker_rx_eof(&truncated) == BC_WORKER_RX_TRUNCATED &&
                !bc_worker_rx_frame(&truncated), "EOF one byte short never delivers");
            bc_worker_rx stalled = rx;
            check(bc_worker_rx_advance(&stalled, 0) == BC_WORKER_RX_REJECTED &&
                !bc_worker_rx_frame(&stalled), "zero-byte progress never delivers");
        }
    }
    check(!bc_worker_tx_window(&tx, &source) && !bc_worker_rx_window(&rx, &target) &&
        !memcmp(incoming, outgoing, sizeof(incoming)), "finished cursor exposes no I/O window");
}

static void start_exchange(bc_worker_frame *frame) {
    HANDLE input = pipes.broker[BC_WORKER_STDIN];
    HANDLE output = pipes.broker[BC_WORKER_STDOUT];
    *frame = (bc_worker_frame){.kind = BC_WORKER_HELLO, .sequence = 1};
    memcpy(frame->nonce, pipes.nonce, sizeof(frame->nonce));
    send_frame(input, frame, NULL);
    frame->kind = BC_WORKER_READY;
    bc_worker_rx rx;
    bc_worker_rx_begin(&rx, frame, NULL, 0);
    check(receive_frame(output, &rx) == BC_WORKER_RX_COMPLETE, "verify worker READY");
    frame->kind = BC_WORKER_START;
    frame->sequence = 2;
    frame->length = 1;
    uint8_t byte = 41;
    send_frame(input, frame, &byte);
}

static void verify_job(void) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    check(QueryInformationJobObject(worker.job, JobObjectExtendedLimitInformation,
        &limits, sizeof(limits), NULL), "query the live Job");
    check(limits.BasicLimitInformation.LimitFlags == (JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_JOB_MEMORY | JOB_OBJECT_LIMIT_JOB_TIME),
        "limit flags and no breakaway");
    check(limits.BasicLimitInformation.ActiveProcessLimit == 1 &&
        limits.BasicLimitInformation.PerJobUserTimeLimit.QuadPart == cpu_limit * 10000LL &&
        limits.JobMemoryLimit == commit_limit, "exact limits");
    JOBOBJECT_BASIC_ACCOUNTING_INFORMATION accounting = {0};
    check(QueryInformationJobObject(worker.job, JobObjectBasicAccountingInformation,
        &accounting, sizeof(accounting), NULL) && accounting.ActiveProcesses == 1,
        "the suspended worker is in the Job");
}

static DWORD prepare(const wchar_t *path, const wchar_t *directory, HANDLE endpoints[3], PSID sid,
    BOOL clean_exit) {
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx",
        clean_exit ? L"--child-ok" : L"--child",
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format the fixture argument");
    return bc_restricted_worker_prepare(&worker, path, command, directory, sid, endpoints,
        commit_limit, cpu_limit);
}

static uint64_t clock_ticks(void) {
    ULONGLONG now;
    QueryInterruptTimePrecise(&now);
    return now;
}

static bool fixture_result(const void *expectation, const uint8_t *bytes, size_t length) {
    const uint8_t expected = expectation ? *(const uint8_t *)expectation : 42;
    return length == 1 && bytes[0] == expected;
}

static bool stdout_eof(HANDLE output) {
    uint8_t trailing;
    DWORD count = 0;
    const DWORD status = transfer(output, &trailing, NULL, 1, &count);
    check(status == ERROR_BROKEN_PIPE || (status == ERROR_SUCCESS && count == 1),
        "observe EOF or a trailing byte");
    return status == ERROR_BROKEN_PIPE;
}

static void verify_gate_rejections(const bc_worker_rx *rx) {
    bc_worker_gate gate;
    size_t length = 123;
    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stdout_end(&gate, true, 1);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "EOF before RESULT is terminal");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 1);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "duplicate RESULT drops candidate");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 1);
    bc_worker_gate_stdout_end(&gate, false, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "trailing stdout drops candidate");

    uint8_t invalid_byte = 41;
    bc_worker_rx invalid = *rx;
    invalid.body = &invalid_byte;
    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, &invalid, fixture_result, NULL, 1);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "invalid payload cannot stage");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 1);
    bc_worker_gate_cancel(&gate, 99);
    bc_worker_gate_exit(&gate, 1, 101);
    check(!bc_worker_gate_take(&gate, &length, 102) && length == 123 &&
        gate.status == BC_WORKER_GATE_CANCELLED && !gate.candidate, "first cancellation survives expiry and exit");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_exit(&gate, 0, 1);
    bc_worker_gate_stage(&gate, rx, fixture_result, NULL, 2);
    bc_worker_gate_stdout_end(&gate, true, 99);
    check(!bc_worker_gate_take(&gate, &length, 100) && length == 123 &&
        gate.status == BC_WORKER_GATE_EXPIRED && !gate.candidate, "deadline tick blocks an otherwise ready RESULT");
}

static void verify_clean_publication(const wchar_t *path, const wchar_t *directory) {
    check(bc_worker_pipes_open(&pipes) == ERROR_SUCCESS, "prepare clean-exit pipes");
    DWORD status = prepare(path, directory, pipes.child, profile, TRUE);
    SetLastError(status);
    check(status == ERROR_SUCCESS && bc_restricted_worker_resume(&worker) == ERROR_SUCCESS,
        "resume clean-exit fixture");
    bc_worker_pipes_close_child(&pipes);

    bc_worker_gate gate;
    bc_worker_gate_begin(&gate, clock_ticks() + 100000000ULL);
    bc_worker_frame expected;
    start_exchange(&expected);
    expected.kind = BC_WORKER_RESULT;
    uint8_t candidate = 0;
    bc_worker_rx rx;
    bc_worker_rx_begin(&rx, &expected, &candidate, 1);
    HANDLE output = pipes.broker[BC_WORKER_STDOUT];
    check(receive_frame(output, &rx) == BC_WORKER_RX_COMPLETE, "receive clean-exit candidate");
    bc_worker_gate_stage(&gate, &rx, fixture_result, NULL, clock_ticks());
    size_t length = 123;
    check(!bc_worker_gate_take(&gate, &length, clock_ticks()) && length == 123, "RESULT alone cannot deliver");
    const bool clean_eof = stdout_eof(output);
    bc_worker_gate_stdout_end(&gate, clean_eof, clock_ticks());
    check(!bc_worker_gate_take(&gate, &length, clock_ticks()), "RESULT and EOF cannot deliver without observed exit");
    check(WaitForSingleObject(worker.process, 5000) == WAIT_OBJECT_0, "wait for clean exit");
    DWORD exit_code = 1;
    check(GetExitCodeProcess(worker.process, &exit_code) && exit_code == 0, "observe zero exit code");
    bc_worker_gate_exit(&gate, exit_code, clock_ticks());
    check(bc_worker_gate_take(&gate, &length, clock_ticks()) == &candidate && length == 1 &&
        candidate == 42 && !bc_worker_gate_take(&gate, &length, clock_ticks()), "deliver once after all evidence");
    check(bc_restricted_worker_close(&worker), "reap clean-exit worker");
    bc_worker_pipes_close(&pipes);
}

static bool same_charge(bc_worker_broker_amounts a, bc_worker_broker_amounts b) {
    return a.sessions == b.sessions && a.parent_bytes == b.parent_bytes &&
        a.child_commit_bytes == b.child_commit_bytes && a.wire_bytes == b.wire_bytes &&
        a.adapter_slots == b.adapter_slots && a.io_slots == b.io_slots &&
        a.pipe_buffer_bytes == b.pipe_buffer_bytes &&
        a.host_request_bytes == b.host_request_bytes && a.host_reply_bytes == b.host_reply_bytes &&
        a.handle_slots == b.handle_slots;
}

static void verify_shared_budget(bc_worker_broker *first, const bc_worker_broker_run *run,
    bc_worker_broker_amounts one) {
    bc_worker_broker_budget *budget = run->budget;
    bc_worker_broker second = {0};
    bc_worker_broker_run other = *run;
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker --child-stalled %llx",
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format concurrent broker fixture command");
    other.command_line = command;
    const uint8_t request = 41;
    uint8_t result = 0;
    other.request = &request;
    other.result = &result;
    const bc_worker_broker_amounts both = {
        2, 2 * one.parent_bytes, 2 * one.child_commit_bytes, 2 * one.wire_bytes, 0, 4,
        2 * one.pipe_buffer_bytes, 0, 0, 24
    };
    const bc_worker_broker_amounts limits[] = {
        {1, both.parent_bytes, both.child_commit_bytes, both.wire_bytes, 0, both.io_slots, both.pipe_buffer_bytes, 0, 0, both.handle_slots},
        {2, both.parent_bytes - 1, both.child_commit_bytes, both.wire_bytes, 0, both.io_slots, both.pipe_buffer_bytes, 0, 0, both.handle_slots},
        {2, both.parent_bytes, both.child_commit_bytes - 1, both.wire_bytes, 0, both.io_slots, both.pipe_buffer_bytes, 0, 0, both.handle_slots},
        {2, both.parent_bytes, both.child_commit_bytes, both.wire_bytes - 1, 0, both.io_slots, both.pipe_buffer_bytes, 0, 0, both.handle_slots},
        {2, both.parent_bytes, both.child_commit_bytes, both.wire_bytes, 0, both.io_slots - 1, both.pipe_buffer_bytes, 0, 0, both.handle_slots},
        {2, both.parent_bytes, both.child_commit_bytes, both.wire_bytes, 0, both.io_slots, both.pipe_buffer_bytes - 1, 0, 0, both.handle_slots},
        {2, both.parent_bytes, both.child_commit_bytes, both.wire_bytes, 0, both.io_slots, both.pipe_buffer_bytes, 0, 0, both.handle_slots - 1}
    };
    for (size_t i = 0; i < _countof(limits); ++i) {
        budget->limit = limits[i];
        check(bc_worker_broker_start(&second, &other) == ERROR_NOT_ENOUGH_QUOTA &&
            !second.worker.process && !second.io.event && same_charge(budget->reserved, one),
            "reject another session before opening handles for each short aggregate limit");
    }
    budget->limit = both;
    const wchar_t *application = other.application;
    other.application = L"relative.exe";
    check(bc_worker_broker_start(&second, &other) == ERROR_INVALID_PARAMETER &&
        second.phase == BC_WORKER_BROKER_IDLE && same_charge(budget->reserved, one),
        "failed startup releases only its reservation");
    other.application = application;
    check(bc_worker_broker_start(&second, &other) == ERROR_SUCCESS &&
        same_charge(budget->reserved, both), "admit a second worker at all exact aggregate limits");
    const uint64_t deadline = clock_ticks() + 50000000ULL;
    while (!second.io.pipe && second.gate.status == BC_WORKER_GATE_PENDING) {
        check(clock_ticks() < deadline, "wait for the second worker's pending read");
        bc_worker_broker_step(&second);
    }
    check(second.phase == BC_WORKER_BROKER_READ_READY && second.io.pipe,
        "both workers own a pending READY read");
    second.phase_deadline = clock_ticks();
    check(bc_worker_broker_step(&second) == BC_WORKER_GATE_EXPIRED &&
        bc_worker_broker_cancel(&second) == BC_WORKER_GATE_EXPIRED &&
        first->gate.status == BC_WORKER_GATE_CANCELLED,
        "keep independent stop causes for the two workers");

    check(bc_worker_io_cancel(&first->io) == ERROR_SUCCESS &&
        bc_worker_io_cancel(&second.io) == ERROR_SUCCESS &&
        WaitForSingleObject(first->io.event, 5000) == WAIT_OBJECT_0 &&
        WaitForSingleObject(second.io.event, 5000) == WAIT_OBJECT_0 &&
        first->io.pipe && second.io.pipe && same_charge(budget->reserved, both),
        "signaled completions still own both I/O leases until collected");
    bc_worker_broker third = {0};
    bc_worker_broker_run next = other;
    const uint8_t next_request = 41;
    uint8_t next_result = 0;
    next.request = &next_request;
    next.result = &next_result;
    next.deadline = clock_ticks() + 100000000ULL;
    budget->limit = (bc_worker_broker_amounts){
        3, 3 * one.parent_bytes, 3 * one.child_commit_bytes, 3 * one.wire_bytes, 0, both.io_slots,
        3 * one.pipe_buffer_bytes, 0, 0, 3 * one.handle_slots
    };
    check(bc_worker_broker_start(&third, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !third.worker.process && !third.io.event && same_charge(budget->reserved, both),
        "deny a third worker at the I/O limit while completions await collection");
    budget->limit.io_slots = 3 * one.io_slots;
    budget->limit.pipe_buffer_bytes = both.pipe_buffer_bytes;
    check(bc_worker_broker_start(&third, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !third.worker.process && !third.io.event && same_charge(budget->reserved, both),
        "deny a third worker at the pipe buffer limit while completions await collection");
    budget->limit.pipe_buffer_bytes = 3 * one.pipe_buffer_bytes;
    budget->limit.handle_slots = both.handle_slots;
    check(bc_worker_broker_start(&third, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !third.worker.process && !third.io.event && same_charge(budget->reserved, both),
        "deny a third worker at the handle limit while completions await collection");
    size_t length = 123;
    check(!bc_worker_broker_take(&second, &length) && length == 123,
        "the expired worker publishes no result");
    while (!bc_worker_broker_close(&second)) {
        check(clock_ticks() < deadline && same_charge(budget->reserved, both),
            "second worker keeps its charge through reaping");
        Sleep(1);
    }
    check(first->io.pipe && same_charge(budget->reserved, one),
        "first worker's uncollected lease survives second teardown");
    check(bc_worker_broker_start(&third, &next) == ERROR_SUCCESS && same_charge(budget->reserved, both),
        "reuse only the collected worker's admission slots");
    while (!bc_worker_broker_close(&third)) {
        check(clock_ticks() < deadline && same_charge(budget->reserved, both),
            "keep both charges through replacement worker close");
        Sleep(1);
    }
    check(same_charge(budget->reserved, one), "refund the replacement without touching the first worker");
}

static void verify_broker(const wchar_t *path, const wchar_t *directory,
    const wchar_t *mode, bc_worker_gate_status expected) {
    bc_worker_broker broker = {0};
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx", mode,
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format broker fixture command");
    const uint8_t request = 41;
    uint8_t result = 0;
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + 3;
    const bc_worker_broker_amounts charge = {1, sizeof(broker) + 2 + worker_launch_heap,
        commit_limit, wire, 0, 2, worker_pipe_buffers, 0, 0, 12};
    bc_worker_broker_budget budget = {.limit = charge};
    const bool idle_expiry = !wcscmp(mode, L"--child-stalled-result");
    const bool cancel_at_expiry = expected == BC_WORKER_GATE_EXPIRED && !idle_expiry;
    const bc_worker_broker_phase wait_phase = idle_expiry ?
        BC_WORKER_BROKER_READ_RESULT : BC_WORKER_BROKER_READ_READY;
    bc_worker_broker_run run = {
        .budget = &budget,
        .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = cpu_limit,
        .startup_ms = expected == BC_WORKER_GATE_EXPIRED && !idle_expiry ? 1200 : 4000,
        .io_idle_ms = idle_expiry ? 500 : 4000,
        .shutdown_grace_ms = 500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire - 1,
        .request = &request, .request_length = 1, .result = &result, .result_capacity = 1,
        .validate = fixture_result
    };
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event, "wire capacity one byte short rejects before launch");
    run.wire_limit = wire;
    --budget.limit.parent_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !broker.cancel_io.event &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "short worker launch heap quota denies admission before opening handles");
    ++budget.limit.parent_bytes;
    const DWORD status = bc_worker_broker_start(&broker, &run);
    SetLastError(status);
    check(status == ERROR_SUCCESS && same_charge(budget.reserved, charge),
        "start worker through the broker at exact wire and aggregate capacity");
    const uint64_t startup_deadline = broker.phase_deadline;

    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        size_t untouched = 123;
        check(!bc_worker_broker_take(&broker, &untouched) && untouched == 123,
            "broker never exposes output while a phase is pending");
        if (cancel_at_expiry && broker.io.pipe) {
            if (clock_ticks() >= startup_deadline) {
                check(bc_worker_broker_cancel(&broker) == BC_WORKER_GATE_EXPIRED,
                    "an explicit cancel observed after startup expiry records the deadline");
                break;
            }
            Sleep(1);
            continue;
        }
        bc_worker_broker_step(&broker);
        if (broker.phase == BC_WORKER_BROKER_READ_READY && broker.io.pipe &&
            expected == BC_WORKER_GATE_CANCELLED) {
            check(bc_worker_broker_cancel(&broker) == BC_WORKER_GATE_CANCELLED,
                "an explicit cancel before expiry records cancellation");
            break;
        }
        if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
    }
    size_t length = 123;
    if (expected == BC_WORKER_GATE_DELIVERED) {
        check(bc_worker_broker_take(&broker, &length) == &result && length == 1 && result == 42 &&
            !bc_worker_broker_take(&broker, &length), "broker exposes exactly one verified success");
    } else {
        check(!bc_worker_broker_take(&broker, &length) && length == 123,
            "broker withholds rejected output");
    }
    const bool pending = broker.io.pipe != NULL;
    const bc_worker_gate_status terminal = broker.gate.status;
    if (expected == BC_WORKER_GATE_CANCELLED || expected == BC_WORKER_GATE_EXPIRED) {
        check(pending && broker.phase == wait_phase && terminal == expected,
            "stop begins with a live outstanding read");
        if (expected == BC_WORKER_GATE_CANCELLED) {
            verify_shared_budget(&broker, &run, charge);
            broker.phase_deadline = clock_ticks();
            check(bc_worker_broker_cancel(&broker) == BC_WORKER_GATE_CANCELLED,
                "expiry during cleanup cannot overwrite the cancelled outcome");
        }
        else {
            const uint64_t now = clock_ticks();
            check(now >= broker.phase_deadline && now < run.deadline &&
                (idle_expiry ? broker.phase_deadline != startup_deadline :
                    broker.phase_deadline == startup_deadline),
                "actual phase expiry precedes the session deadline");
        }
    } else {
        check(terminal == expected, "broker recorded the expected outcome");
    }
    const uint64_t reaping_limit = clock_ticks() + 50000000ULL;
    while (!bc_worker_broker_close(&broker)) {
        check(clock_ticks() < reaping_limit && broker.phase >= BC_WORKER_BROKER_CANCEL_TX &&
            broker.gate.status == expected && same_charge(budget.reserved, charge),
            "reaping retains the first cause and reservation");
        Sleep(1);
    }
    check(!broker.worker.process && !broker.io.event && !broker.pipes.broker[BC_WORKER_STDOUT] &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "broker releases resources only after reaping");
}

static bool reject_callback(const void *expectation, const uint8_t *bytes, size_t length) {
    (void)expectation;
    (void)bytes;
    (void)length;
    check(FALSE, "cancelled broker must never invoke the payload callback");
    return false;
}

static size_t reply_fixture(void *raw, uint64_t correlation,
    const uint8_t *request, size_t length, uint8_t *reply, size_t capacity) {
    unsigned *calls = raw;
    ++*calls;
    if (length != 1 || request[0] != 41 || correlation != *calls ||
        capacity != long_request_bytes) return 0;
    memset(reply, 0, capacity);
    reply[0] = (uint8_t)(41 + correlation);
    reply[capacity - 1] = 255;
    return capacity;
}

static void verify_host_broker(const wchar_t *path, const wchar_t *directory,
    const wchar_t *mode, uint32_t max_calls, bc_worker_gate_status expected, unsigned expected_calls) {
    bc_worker_broker broker = {0};
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx", mode,
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format host broker fixture command");
    const bool peer_cancel = !wcscmp(mode, L"--child-peer-cancel");
    const bool peer = peer_cancel || !wcscmp(mode, L"--child-peer-ok");
    const bool cancel_rx = peer_cancel || !wcscmp(mode, L"--child-host-cancel-rx");
    const bool cancel_tx = !wcscmp(mode, L"--child-host-cancel-tx");
    const uint8_t start[9] = {41};
    const size_t start_length = peer ? sizeof(start) : 1;
    uint8_t request = 0, result = 0, reply[long_request_bytes];
    unsigned calls = 0;
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + start_length + 2 +
        max_calls * (2 * BC_WORKER_FRAME_BYTES + sizeof(request) + sizeof(reply));
    const bc_worker_broker_amounts charge = {1, sizeof(broker) + start_length + 1 +
        sizeof(request) + sizeof(reply) + sizeof(calls) + worker_launch_heap, commit_limit, wire, 0, 2, worker_pipe_buffers,
        max_calls * sizeof(request), max_calls * sizeof(reply), 12};
    bc_worker_broker_budget budget = {.limit = charge};
    bc_worker_broker_run run = {
        .budget = &budget, .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = cpu_limit,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 2500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire - 1,
        .request = start, .request_length = start_length, .result = &result, .result_capacity = 1,
        .validate = expected == BC_WORKER_GATE_DELIVERED ? fixture_result : reject_callback,
        .host_parent_bytes = sizeof(calls),
        .host = {reply_fixture, &calls, &request, reply, sizeof(request), sizeof(reply), max_calls}
    };
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process, "host wire quota checked before launch");
    run.wire_limit = wire;
    --budget.limit.host_request_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !calls &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "short host request quota denies admission without dispatch");
    ++budget.limit.host_request_bytes;
    --budget.limit.host_reply_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !calls &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "short host reply quota denies admission without dispatch");
    ++budget.limit.host_reply_bytes;
    --budget.limit.parent_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !calls &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "one byte short of synchronous context storage denies admission");
    ++budget.limit.parent_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_SUCCESS &&
        same_charge(budget.reserved, charge), "reserve host spans and wire at exact limits");
    HANDLE exit_witness = NULL;
    if (cancel_tx || cancel_rx)
        check(DuplicateHandle(GetCurrentProcess(), broker.worker.process, GetCurrentProcess(),
            &exit_witness, SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, 0),
            "retain host cancellation exit witness");
    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        bc_worker_broker_step(&broker);
        if ((cancel_rx && broker.phase == BC_WORKER_BROKER_READ_RESULT &&
             broker.rx.status == BC_WORKER_RX_BODY) ||
            (cancel_tx && broker.phase == BC_WORKER_BROKER_SEND_HOST_REPLY &&
             broker.tx.sent == BC_WORKER_FRAME_BYTES)) {
            if (expected == BC_WORKER_GATE_EXPIRED) {
                broker.phase_deadline = clock_ticks();
                check(bc_worker_broker_step(&broker) == BC_WORKER_GATE_EXPIRED,
                    "phase expiry settles an unfinished host transfer");
            } else {
                check(bc_worker_broker_cancel(&broker) == BC_WORKER_GATE_CANCELLED,
                    "cancel with host transfer unfinished");
                broker.phase_deadline = clock_ticks();
            }
            check(bc_worker_broker_cancel(&broker) == expected,
                "later stop preserves the first host transfer outcome");
            break;
        }
        if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
    }
    size_t length = 123;
    const uint8_t *published = bc_worker_broker_take(&broker, &length);
    check(broker.gate.status == expected && calls == expected_calls,
        "host broker outcome and exact dispatch count");
    check(expected == BC_WORKER_GATE_DELIVERED ? published == &result && length == 1 && result == 42 :
        !published && length == 123, "publish only clean RESULT after host exchange");
    const uint64_t reap_limit = clock_ticks() + 50000000ULL;
    while (!bc_worker_broker_close(&broker)) {
        check(clock_ticks() < reap_limit && broker.gate.status == expected &&
            same_charge(budget.reserved, charge), "hold host reservation and cause through reaping");
        Sleep(1);
    }
    if (exit_witness) {
        DWORD code = STILL_ACTIVE;
        check(WaitForSingleObject(exit_witness, 0) == WAIT_OBJECT_0 &&
            GetExitCodeProcess(exit_witness, &code) && code == 0 && result == 42 &&
            CloseHandle(exit_witness), "worker received ordered CANCEL and drained a late RESULT");
    }
    check(calls == expected_calls && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "no dispatch after settlement and refund host reservation exactly once");
}

typedef struct deferred_fixture {
    const uint8_t *request;
    unsigned begins, polls, closes;
    bool hold_close;
} deferred_fixture;

static bool deferred_begin(void *context, uint64_t correlation, const uint8_t *request,
    size_t size, uint64_t deadline) {
    deferred_fixture *f = context;
    check(!f->request && ++f->begins == correlation && size == 1 && request[0] == 41 &&
        deadline > clock_ticks(), "admit one complete request with the phase deadline");
    f->request = request;
    return true;
}

static bc_worker_host_progress deferred_poll(void *context, uint8_t *reply, size_t capacity, size_t *size) {
    deferred_fixture *f = context;
    check(f->request && f->request[0] == 41, "retain immutable request across adapter polls");
    if (++f->polls % 2) return BC_WORKER_HOST_PENDING;
    unsigned calls = f->begins - 1;
    *size = reply_fixture(&calls, f->begins, f->request, 1, reply, capacity);
    return *size ? BC_WORKER_HOST_READY : BC_WORKER_HOST_REJECTED;
}

static bool deferred_close(void *context) {
    deferred_fixture *f = context;
    check(f->request && f->request[0] == 41, "retain the borrowed request through adapter close");
    if (f->hold_close) return false;
    f->request = NULL;
    ++f->closes;
    return true;
}

static void verify_deferred_adapter(const wchar_t *path, const wchar_t *directory,
    bc_worker_gate_status expected) {
    const bool success = expected == BC_WORKER_GATE_DELIVERED;
    const bool expires = expected == BC_WORKER_GATE_EXPIRED;
    const uint8_t start = 41;
    uint8_t request = 0, result = 0, reply[long_request_bytes];
    const uint32_t calls = success ? 2 : 1;
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + 3 +
        calls * (2 * BC_WORKER_FRAME_BYTES + sizeof(request) + sizeof(reply));
    bc_worker_broker broker = {0};
    deferred_fixture fixture = {.hold_close = !success};
    const bc_worker_broker_amounts charge = {1, sizeof(broker) + 3 + sizeof(reply) + worker_launch_heap,
        commit_limit, wire, 1, 2, worker_pipe_buffers, calls * sizeof(request), calls * sizeof(reply), 12};
    bc_worker_broker_budget budget = {.limit = charge};
    const bc_worker_host_adapter adapter = {
        .begin = deferred_begin, .poll = deferred_poll, .close = deferred_close
    };
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx",
        success ? L"--child-host-ok" : L"--child-host-cancel-rx",
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format deferred adapter fixture command");
    const bc_worker_broker_run run = {
        .budget = &budget, .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = cpu_limit,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 2500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire,
        .request = &start, .request_length = 1, .result = &result, .result_capacity = 1,
        .validate = success ? fixture_result : reject_callback,
        .host = {NULL, &fixture, &request, reply, sizeof(request), sizeof(reply), calls},
        .adapter = &adapter
    };
    check(!bc_worker_broker_start(&broker, &run) && same_charge(budget.reserved, charge),
        "start deferred adapter session at exact reservation");
    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        bc_worker_broker_step(&broker);
        if ((!success && !expires && broker.phase == BC_WORKER_BROKER_WAIT_HOST && fixture.polls == 1) ||
            (expires && broker.phase == BC_WORKER_BROKER_REAP_HOST)) {
            if (!expires) check(bc_worker_broker_cancel(&broker) == expected, "cancel pending adapter");
            broker.phase_deadline = clock_ticks();
            check(bc_worker_broker_step(&broker) == expected &&
                bc_worker_broker_cancel(&broker) == expected, "preserve first deferred adapter outcome");
            break;
        }
        if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
    }
    size_t length = 123;
    const uint8_t *published = bc_worker_broker_take(&broker, &length);
    check(broker.gate.status == expected && fixture.begins == calls,
        "observe one dispatch per completed request");
    if (success) {
        check(published == &result && length == 1 && result == 42 &&
            fixture.polls == 4 && fixture.closes == 2, "publish after both deferred replies were reaped");
    } else {
        check(!published && length == 123, "stopped adapter cannot publish");
        const uint64_t limit = clock_ticks() + 50000000ULL;
        do {
            check(!bc_worker_broker_close(&broker) && clock_ticks() < limit &&
                same_charge(budget.reserved, charge) && broker.gate.status == expected,
                "adapter residual work retains the broker reservation");
            Sleep(1);
        } while (WaitForSingleObject(broker.worker.process, 0) == WAIT_TIMEOUT ||
            broker.phase != BC_WORKER_BROKER_REAPING);
        check(result == 42 && fixture.closes == 0 && fixture.polls == (expires ? 2u : 1u),
            "drain late RESULT without any more adapter polls");
        bc_worker_broker next = {0};
        bc_worker_broker_run next_run = run;
        deferred_fixture next_fixture = {0};
        uint8_t next_request = 0, next_result = 0, next_reply[long_request_bytes];
        next_run.result = &next_result;
        next_run.host.context = &next_fixture;
        next_run.host.request = &next_request;
        next_run.host.reply = next_reply;
        next_run.deadline = clock_ticks() + 100000000ULL;
        budget.limit = (bc_worker_broker_amounts){
            2, 2 * charge.parent_bytes, 2 * charge.child_commit_bytes, 2 * charge.wire_bytes, 1, 4,
            2 * charge.pipe_buffer_bytes, 2 * charge.host_request_bytes, 2 * charge.host_reply_bytes, 2 * charge.handle_slots
        };
        check(bc_worker_broker_start(&next, &next_run) == ERROR_NOT_ENOUGH_QUOTA &&
            !next.worker.process && !next.io.event && same_charge(budget.reserved, charge),
            "deny another deferred session while only the adapter is still reaping");
        fixture.hold_close = false;
        check(bc_worker_broker_close(&broker) && fixture.closes == calls &&
            same_charge(budget.reserved, (bc_worker_broker_amounts){0}), "refund after adapter cleanup");
        check(bc_worker_broker_start(&next, &next_run) == ERROR_SUCCESS &&
            same_charge(budget.reserved, charge), "reuse the adapter slot after cleanup");
        const uint64_t next_limit = clock_ticks() + 50000000ULL;
        while (!bc_worker_broker_close(&next)) {
            check(clock_ticks() < next_limit && same_charge(budget.reserved, charge),
                "keep the reused slot through worker close");
            Sleep(1);
        }
        check(same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
            "refund the reused adapter slot");
        return;
    }
    check(bc_worker_broker_close(&broker) && fixture.closes == calls &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}), "refund after adapter cleanup");
}

static void verify_graceful_cancel(const wchar_t *path, const wchar_t *directory, bool ignore) {
    bc_worker_broker broker = {0};
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx",
        ignore ? L"--child-ignore-cancel" : L"--child-late-result",
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format cancellation fixture command");
    const uint8_t request[long_request_bytes] = {41};
    uint8_t result = 0;
    const size_t request_length = ignore ? 1 : sizeof(request);
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + request_length + 2;
    const bc_worker_broker_amounts charge = {1, sizeof(broker) + request_length + 1 + worker_launch_heap,
        commit_limit, wire, 0, 2, worker_pipe_buffers, 0, 0, 12};
    bc_worker_broker_budget budget = {.limit = charge};
    const bc_worker_broker_run run = {
        .budget = &budget, .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = cpu_limit,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = ignore ? 300 : 2500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire,
        .request = request, .request_length = request_length, .result = &result,
        .result_capacity = 1, .validate = reject_callback
    };
    check(bc_worker_broker_start(&broker, &run) == ERROR_SUCCESS, "start cancellation fixture");
    HANDLE process = NULL;
    check(DuplicateHandle(GetCurrentProcess(), broker.worker.process, GetCurrentProcess(),
        &process, SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, 0),
        "retain a fixture-only exit witness");
    while (broker.gate.status == BC_WORKER_GATE_PENDING) {
        bc_worker_broker_step(&broker);
        if (ignore ? broker.phase == BC_WORKER_BROKER_READ_RESULT && broker.io.pipe :
            broker.phase == BC_WORKER_BROKER_SEND_START && broker.tx.sent == BC_WORKER_FRAME_BYTES) break;
        if (broker.io.pipe) Sleep(1);
    }
    check(broker.gate.status == BC_WORKER_GATE_PENDING, "pause after START header or on pending RESULT");
    const uint64_t reaping_limit = clock_ticks() + 50000000ULL;
    bool cancel_sent = false;
    uint64_t grace_deadline = 0;
    while (!bc_worker_broker_close(&broker)) {
        size_t length = 123;
        check(clock_ticks() < reaping_limit && broker.gate.status == BC_WORKER_GATE_CANCELLED &&
            same_charge(budget.reserved, charge) &&
            !bc_worker_broker_take(&broker, &length) && length == 123,
            "cancellation freezes publication while retaining its resources");
        if (broker.phase == BC_WORKER_BROKER_DRAIN_RESULT) cancel_sent = true;
        grace_deadline = broker.shutdown_deadline;
        if (broker.io.pipe || broker.cancel_io.pipe || broker.phase == BC_WORKER_BROKER_DRAIN_EXIT)
            Sleep(1);
    }
    DWORD code = STILL_ACTIVE;
    check(cancel_sent && WaitForSingleObject(process, 0) == WAIT_OBJECT_0 &&
        GetExitCodeProcess(process, &code), "CANCEL sent and worker reaped");
    const bool forced_on_time = clock_ticks() >= grace_deadline;
    const bool lifecycle_ok = ignore ? forced_on_time && code == ERROR_TIMEOUT && !result :
        code == 0 && result == 42;
    if (!lifecycle_ok)
        fprintf(stderr, "cancellation fixture ignore=%d, deadline reached=%d, exit=%lu, result=%u\n",
            ignore, forced_on_time, code, (unsigned)result);
    check(lifecycle_ok, "late RESULT drained or ignored CANCEL forced after grace");
    check(CloseHandle(process) && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "refund cancellation and fixture witness");
}

static bool scalar_payload(const void *expectation, const uint8_t *body, size_t size) {
    if (!expectation || size < 2 || body[0] != 0) return false;
    ++body;
    --size;
    const char *expected_scalar_payload = expectation;
    const size_t expected = strlen(expected_scalar_payload);
    if (size < expected || memcmp(body, expected_scalar_payload, expected) || body[size - 1] != '}')
        return false;
    if (expected_scalar_payload[expected - 1] == '}') return size == expected;
    for (size_t i = expected; i < size - 1; ++i)
        if (body[i] < '0' || body[i] > '9') return false;
    return size > expected + 1;
}

static void verify_guest_exchange(const wchar_t *path, const wchar_t *directory,
    const uint8_t *request, size_t request_length, const char *expected, bool accept) {
    bc_worker_broker broker = {0};
    uint8_t result[256];
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + request_length + sizeof(result) + 1;
    const bc_worker_broker_amounts charge = {
        1, sizeof(broker) + request_length + sizeof(result) + worker_launch_heap,
        commit_limit, wire, 0, 2, worker_pipe_buffers, 0, 0, 12
    };
    bc_worker_broker_budget budget = {.limit = charge};
    wchar_t scalar_command[] = L"browniec worker";
    wchar_t project_command[] = L"worker --internal-project-worker";
    const bc_worker_broker_run run = {
        .budget = &budget, .application = path, .directory = directory,
        .command_line = expected ? scalar_command : project_command,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = 2000,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire,
        .request = request, .request_length = request_length, .result = result,
        .result_capacity = sizeof(result), .validate = scalar_payload, .expectation = expected
    };
    DWORD status = bc_worker_broker_start(&broker, &run);
    SetLastError(status);
    check(status == ERROR_SUCCESS, "launch real Brownie worker");
    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        bc_worker_broker_step(&broker);
        if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
    }
    size_t length = 0;
    if (accept && broker.gate.status != BC_WORKER_GATE_PENDING)
        fprintf(stderr, "scalar gate status %d, phase %d, body %.*s\n", broker.gate.status,
            broker.phase, broker.rx.used > 1 ? (int)(broker.rx.used - 1) : 0, (const char *)result + 1);
    if (accept) {
        check(bc_worker_broker_take(&broker, &length) == result && scalar_payload(expected, result, length) &&
            !bc_worker_broker_take(&broker, &length), "publish validated Brownie scalar outcome once");
    } else {
        check(broker.gate.status == BC_WORKER_GATE_PROTOCOL && !bc_worker_broker_take(&broker, &length) &&
            !length, "a rejected exchange cannot publish");
        if (!expected) check(!broker.rx.used, "malformed project START produced no result body");
    }
    const uint64_t limit = clock_ticks() + 50000000ULL;
    while (!bc_worker_broker_close(&broker)) {
        check(clock_ticks() < limit, "reap actual Brownie scalar worker");
        Sleep(1);
    }
    check(same_charge(budget.reserved, (bc_worker_broker_amounts){0}), "refund scalar worker budget");
}

static void verify_scalar_programs(const wchar_t *path, const wchar_t *directory) {
    FILE *source = NULL;
    check(!fopen_s(&source, "answer.brc", "rb"), "open answer fixture in the parent");
    uint8_t request[4101] = {0};
    const size_t source_bytes = fread(request + 5, 1, sizeof(request) - 5, source);
    check(source_bytes && feof(source) && !ferror(source) && !fclose(source), "snapshot answer fixture");
    verify_guest_exchange(path, directory, request, source_bytes + 5,
        "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\"}", true);
    request[0] = 1;
    request[2] = 1;
    verify_guest_exchange(path, directory, request, source_bytes + 5,
        "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"completed\",\"return_i32\":77}", true);
    verify_guest_exchange(path, directory, request, source_bytes + 5,
        "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\"}", false);
    request[2] = 0;
    verify_guest_exchange(path, directory, request, source_bytes + 5,
        "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\",\"kind\":8,\"location\":0,\"offset\":", true);
    const uint8_t lexical_error[] = {0, 0, 0, 0, 0, 255};
    verify_guest_exchange(path, directory, lexical_error, sizeof(lexical_error),
        "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\",\"kind\":1,\"location\":0,\"offset\":0}", true);
}

static void verify_project_rejections(const wchar_t *path, const wchar_t *directory) {
    static const char project[] = "{\"schema\":\"brownie.project/0.3\",\"name\":\"app\","
        "\"entry\":{\"module\":\"app\",\"function\":\"start\"},"
        "\"sources\":[{\"module\":\"app\",\"path\":\"app.brc\"}],\"requires\":[]}";
    enum { size = sizeof(project) - 1, member = 9 + size };
    _Static_assert(size <= 255, "fixture manifest length fits one byte");
    uint8_t request[member + 3] = {2, 0, 0, 0, 0, size};
    memcpy(request + 9, project, size);
    request[member] = 2;
    verify_guest_exchange(path, directory, request, sizeof(request), NULL, false);
    request[member] = 0;
    verify_guest_exchange(path, directory, request, sizeof(request), NULL, false);
}

static void verify_project_compile_stop(const wchar_t *path, const wchar_t *directory,
    const char *fixture, bool valid_cancel) {
    uint8_t queued[4096];
    FILE *file = NULL;
    check(!fopen_s(&file, fixture, "rb"), "open configured START fixture");
    const size_t length = fread(queued + BC_WORKER_FRAME_BYTES, 1,
        sizeof(queued) - 2 * BC_WORKER_FRAME_BYTES, file);
    check(length && feof(file) && !ferror(file) && !fclose(file), "read complete START fixture");

    bc_worker_pipes transport = {0};
    bc_restricted_worker child = {0};
    wchar_t command[] = L"worker --internal-project-worker";
    check(bc_worker_pipes_open(&transport) == ERROR_SUCCESS &&
        bc_restricted_worker_prepare(&child, path, command, directory, profile,
            transport.child, commit_limit, 2000) == ERROR_SUCCESS, "prepare confined compile fixture");
    bc_worker_pipes_close_child(&transport);
    check(bc_restricted_worker_resume(&child) == ERROR_SUCCESS, "start confined compile fixture");
    const HANDLE input = transport.broker[BC_WORKER_STDIN];
    const HANDLE output = transport.broker[BC_WORKER_STDOUT];
    bc_worker_frame frame = {.kind = BC_WORKER_HELLO, .sequence = 1};
    memcpy(frame.nonce, transport.nonce, sizeof(frame.nonce));
    uint8_t header[BC_WORKER_FRAME_BYTES];
    DWORD count = 0;
    check(bc_worker_frame_encode(header, &frame) &&
        !transfer(input, NULL, header, sizeof(header), &count) && count == sizeof(header), "send HELLO");
    frame.kind = BC_WORKER_READY;
    bc_worker_frame ready;
    check(!transfer(output, header, NULL, sizeof(header), &count) &&
        bc_worker_frame_preflight(header, count, &frame, &ready), "receive READY");
    frame.kind = BC_WORKER_START;
    frame.sequence = 2;
    frame.length = (uint32_t)length;
    check(bc_worker_frame_encode(queued, &frame), "encode START");
    frame.kind = BC_WORKER_CANCEL;
    frame.sequence = 3;
    frame.length = 0;
    if (!valid_cancel) frame.nonce[0] ^= 1;
    check(bc_worker_frame_encode(queued + BC_WORKER_FRAME_BYTES + length, &frame), "encode CANCEL");
    const DWORD queued_length = (DWORD)length + 2 * BC_WORKER_FRAME_BYTES;
    check(!transfer(input, NULL, queued, queued_length, &count) && count == queued_length, "queue START and CANCEL together");
    check(transfer(output, header, NULL, sizeof(header), &count) == ERROR_BROKEN_PIPE,
        "a stopped compile sends neither RESULT nor a HOST_REQUEST");
    DWORD code = STILL_ACTIVE;
    check(WaitForSingleObject(child.process, 5000) == WAIT_OBJECT_0 &&
        GetExitCodeProcess(child.process, &code) && code == (valid_cancel ? 0u : 4u),
        "a valid CANCEL exits cleanly and an invalid CANCEL fails closed");
    check(bc_restricted_worker_stop(&child) && bc_restricted_worker_close(&child), "release compile fixture process");
    bc_worker_pipes_close(&transport);
}

static size_t catalog_reply(void *context, uint64_t correlation, const uint8_t *request,
    size_t length, uint8_t *reply, size_t capacity) {
    static const uint8_t first_call[] = {0,0,0,0, 1,0, 3,0,0,0, 4,0,0,0, 41,0,0,0};
    static const uint8_t first_reply[] = {0, 3,0,0,0, 4,0,0,0, 42,0,0,0};
    unsigned *calls = context;
    check(++*calls == 1 && correlation == 1 && length == sizeof(first_call) &&
        !memcmp(request, first_call, length) && capacity >= sizeof(first_reply),
        "dispatch only the first typed catalog request");
    memcpy(reply, first_reply, sizeof(first_reply));
    return sizeof(first_reply);
}

static void verify_catalog_host_stop(const wchar_t *path, const wchar_t *directory,
    bool after_reply_header, bc_worker_gate_status cause) {
    uint8_t start[4096], result[512] = {0}, request[18], reply[13];
    FILE *file = NULL;
    check(!fopen_s(&file, "catalog-compile.start", "rb"), "open catalog START fixture");
    const size_t size = fread(start, 1, sizeof(start), file);
    check(size && feof(file) && !ferror(file) && !fclose(file), "read catalog START fixture");

    bc_worker_broker broker = {0};
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + size + sizeof(result) + 1 +
        2 * (2 * BC_WORKER_FRAME_BYTES + sizeof(request) + sizeof(reply));
    const bc_worker_broker_amounts charge = {1,
        sizeof(broker) + size + sizeof(result) + sizeof(request) + sizeof(reply) + worker_launch_heap,
        commit_limit, wire, 0, 2, worker_pipe_buffers, 2 * sizeof(request), 2 * sizeof(reply), 12};
    bc_worker_broker_budget budget = {.limit = charge};
    unsigned calls = 0;
    wchar_t command[] = L"worker --internal-project-worker";
    const bc_worker_broker_run run = {
        .budget = &budget, .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = 2000,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 2500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire,
        .request = start, .request_length = size, .result = result, .result_capacity = sizeof(result),
        .validate = reject_callback,
        .host = {catalog_reply, &calls, request, reply, sizeof(request), sizeof(reply), 2}
    };
    check(bc_worker_broker_start(&broker, &run) == ERROR_SUCCESS &&
        same_charge(budget.reserved, charge), "launch catalog guest with exact broker reservation");
    HANDLE witness = NULL;
    check(DuplicateHandle(GetCurrentProcess(), broker.worker.process, GetCurrentProcess(),
        &witness, SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, 0),
        "retain the catalog worker exit witness");
    bool at_transfer = false;
    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        bc_worker_broker_step(&broker);
        at_transfer = after_reply_header ?
            broker.phase == BC_WORKER_BROKER_SEND_HOST_REPLY && broker.tx.sent == BC_WORKER_FRAME_BYTES :
            broker.phase == BC_WORKER_BROKER_READ_RESULT && broker.rx.status == BC_WORKER_RX_BODY &&
            broker.rx.received.kind == BC_WORKER_HOST_REQUEST;
        if (at_transfer) break;
        if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
    }
    check(at_transfer && calls == (after_reply_header ? 1u : 0u),
        "reach the requested transfer before settling the catalog guest");
    if (cause == BC_WORKER_GATE_CANCELLED)
        check(bc_worker_broker_cancel(&broker) == cause, "cancel the in-flight catalog transfer");
    broker.phase_deadline = clock_ticks();
    check(bc_worker_broker_step(&broker) == cause &&
        bc_worker_broker_cancel(&broker) == cause, "preserve the first catalog transfer outcome");
    const uint64_t reap_limit = clock_ticks() + 50000000ULL;
    size_t drained = 0;
    do {
        if (broker.phase == BC_WORKER_BROKER_DRAIN_EOF && bc_worker_rx_frame(&broker.rx))
            drained = broker.rx.received.length;
        size_t length = 123;
        check(!bc_worker_broker_take(&broker, &length) && length == 123 &&
            clock_ticks() < reap_limit && broker.gate.status == cause &&
            same_charge(budget.reserved, charge), "hold the cause and quota without publishing");
        Sleep(1);
    } while (!bc_worker_broker_close(&broker));

    DWORD code = STILL_ACTIVE;
    static const uint8_t prefix[] = {8, 16, 0, 0};
    static const char cancelled[] = "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\","
        "\"kind\":33,\"location\":2,\"offset\":0}";
    const bool exited = WaitForSingleObject(witness, 0) == WAIT_OBJECT_0 && GetExitCodeProcess(witness, &code);
    if (!exited || code != 0)
        fprintf(stderr, "catalog stop: after reply header=%d, cause=%d, exit=%lu, result=%.*s\n",
            after_reply_header, cause, code, (int)sizeof(result) - 4, (const char *)result + 4);
    check(exited && code == 0 && CloseHandle(witness), "catalog worker consumes CANCEL and exits cleanly");
    check(drained == sizeof(prefix) + sizeof(cancelled) - 1 &&
        !memcmp(result, prefix, sizeof(prefix)) &&
        !memcmp(result + sizeof(prefix), cancelled, sizeof(cancelled) - 1) &&
        calls == (after_reply_header ? 1u : 0u) &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "drain only the cancelled outcome and refund the catalog session");
}

typedef struct process_codec {
    unsigned requests, headers, replies;
    uint8_t expected[BC_ADAPTER_HEADER_BYTES];
} process_codec;

static bool process_fixture_encode(void *raw, uint64_t correlation, const uint8_t *request,
    size_t length, uint8_t header[BC_ADAPTER_HEADER_BYTES]) {
    process_codec *codec = raw;
    static const uint8_t prefix[] = {0,0,0,0, 1,0, 3,0,0,0, 4,0,0,0};
    if (length != 18 || correlation != codec->requests + 1u || correlation > 2 ||
        memcmp(request, prefix, sizeof(prefix)) || request[14] != 40 + correlation ||
        request[15] || request[16] || request[17]) return false;
    ++codec->requests;
    memcpy(header, "BCA1", 4);
    header[8] = 1;
    header[16] = (uint8_t)correlation;
    header[28] = 14;
    memcpy(codec->expected, header, BC_ADAPTER_HEADER_BYTES);
    codec->expected[4] = 1;
    codec->expected[28] = 12;
    return true;
}

static bool process_fixture_header(void *raw, const uint8_t *header, size_t length,
    size_t limit, size_t *body_length) {
    process_codec *codec = raw;
    ++codec->headers;
    if (limit < 12 || length != BC_ADAPTER_HEADER_BYTES || memcmp(header, codec->expected, length))
        return false;
    *body_length = 12;
    return true;
}

static size_t process_fixture_decode(void *raw, const uint8_t *frame, size_t length,
    uint8_t *reply, size_t capacity) {
    process_codec *codec = raw;
    uint8_t expected[] = {3,0,0,0, 4,0,0,0, codec->requests == 1 ? 42 : 35,0,0,0};
    if (length != BC_ADAPTER_HEADER_BYTES + sizeof(expected) || capacity < sizeof(expected) + 1 ||
        memcmp(frame, codec->expected, BC_ADAPTER_HEADER_BYTES) ||
        memcmp(frame + BC_ADAPTER_HEADER_BYTES, expected, sizeof(expected))) return 0;
    ++codec->replies;
    reply[0] = 0;
    memcpy(reply + 1, expected, sizeof(expected));
    return sizeof(expected) + 1;
}

static int process_fixture_child(wchar_t mode) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    if (!QueryInformationJobObject(NULL, JobObjectExtendedLimitInformation, &limits, sizeof(limits), NULL) ||
        !(limits.BasicLimitInformation.LimitFlags & JOB_OBJECT_LIMIT_JOB_MEMORY) ||
        limits.JobMemoryLimit != BC_WORKER_ADAPTER_JOB_COMMIT_BYTES) return 35;
    void *oversized = VirtualAlloc(NULL, BC_WORKER_ADAPTER_JOB_COMMIT_BYTES, MEM_COMMIT | MEM_RESERVE,
        PAGE_READWRITE);
    if (oversized) {
        VirtualFree(oversized, 0, MEM_RELEASE);
        return 36;
    }
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE), output = GetStdHandle(STD_OUTPUT_HANDLE);
    uint8_t header[BC_ADAPTER_HEADER_BYTES], request[14], extra;
    static const uint8_t prefix[] = {1,0, 3,0,0,0, 4,0,0,0};
    const uint8_t zero[8] = {0};
    DWORD count = 0;
    if (!child_read(input, header, sizeof(header)) || memcmp(header, "BCA1", 4) ||
        header[4] || !memcmp(header + 8, zero, sizeof(zero)) || (header[16] != 1 && header[16] != 2) || header[28] != 14 ||
        !child_read(input, request, sizeof(request)) || memcmp(request, prefix, sizeof(prefix)) ||
        request[10] != 40 + header[16] ||
        ReadFile(input, &extra, 1, &count, NULL) || GetLastError() != ERROR_BROKEN_PIPE) return 30;
    header[4] = 1;
    header[28] = 12;
    if (mode == L'm' || mode == L'x') {
        wchar_t image[MAX_PATH];
        const DWORD n = GetModuleFileNameW(NULL, image, _countof(image));
        if (!n || n >= _countof(image)) return 37;
        const wchar_t *name = wcsrchr(image, L'\\');
        const bool first = header[16] == 1;
        if (!name || header[24] != (first ? 0 : 1) ||
            wcscmp(name + 1, first ? L"route zero.exe" : L"route one.exe")) return 38;
        if (!first && mode == L'x') header[24] = 0;
    }
    if (mode == L'w') ++header[16];
    if (!WriteFile(output, header, sizeof(header), &count, NULL) || count != sizeof(header)) return 31;
    uint8_t body[] = {3,0,0,0, 4,0,0,0, header[16] == 1 ? 42 : 35,0,0,0};
    const bool partial = mode == L's' || mode == L'c';
    const DWORD size = partial ? 3 : sizeof(body);
    if (!WriteFile(output, body, size, &count, NULL) || count != size) return 32;
    if (mode == L'c') {
        HANDLE marker = CreateFileW(L"process-adapter.pid", GENERIC_WRITE, FILE_SHARE_READ,
            NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (marker == INVALID_HANDLE_VALUE) return 33;
        const DWORD pid = GetCurrentProcessId();
        const BOOL marked = WriteFile(marker, &pid, sizeof(pid), &count, NULL) && count == sizeof(pid);
        if (!CloseHandle(marker) || !marked) return 34;
    }
    if (partial) Sleep(INFINITE);
    return 0;
}

static bool catalog_process_result(const void *unused, const uint8_t *body, size_t length) {
    (void)unused;
    static const char metadata[] = "{\"schema\":\"browniec.worker-result/v1\",\"status\":\"completed\",\"return_i32\":77}";
    const size_t meta = 4 + sizeof(metadata) - 1;
    return length == 3 + meta + 6 && body[0] == 128 && body[1] == meta && body[2] == 0 &&
        !memcmp(body + 3, "\x08\x10\x00\x00", 4) &&
        !memcmp(body + 7, metadata, sizeof(metadata) - 1) && !memcmp(body + 3 + meta, "before", 6);
}

static void verify_shared_process_reaping(bc_worker_broker *first, const bc_worker_broker_run *run,
    bc_worker_broker_amounts one) {
    bc_worker_broker_budget *budget = run->budget;
    const bc_worker_process_adapter *first_adapter = run->host.context;
    bc_adapter_budget *processes = first_adapter->slot.budget;
    const bc_worker_broker_amounts both = {
        2, 2 * one.parent_bytes, 2 * one.child_commit_bytes, 2 * one.wire_bytes, 2, 6,
        2 * one.pipe_buffer_bytes, 2 * one.host_request_bytes, 2 * one.host_reply_bytes, 42
    };
    budget->limit = both;
    processes->live_limit = 2;
    bc_worker_broker second = {0};
    process_codec codec = {0};
    bc_worker_process_adapter adapter = *first_adapter;
    adapter.slot = (bc_adapter_slot){.budget = processes, .job_commit_bytes = adapter.slot.job_commit_bytes};
    adapter.codec = &codec;
    uint8_t result[512];
    bc_worker_broker_run next = *run;
    next.result = result;
    next.host.context = &adapter;
    next.deadline = clock_ticks() + 100000000ULL;
    --budget->limit.child_commit_bytes;
    check(bc_worker_broker_start(&second, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !second.worker.process && !second.io.event && processes->live == 1 &&
        same_charge(budget->reserved, one), "deny a second worker one byte below combined Job capacity");
    ++budget->limit.child_commit_bytes;
    --budget->limit.handle_slots;
    check(bc_worker_broker_start(&second, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !second.worker.process && !second.io.event && processes->live == 1 &&
        same_charge(budget->reserved, one), "deny a second process route one slot below aggregate handle capacity");
    ++budget->limit.handle_slots;
    --budget->limit.host_request_bytes;
    check(bc_worker_broker_start(&second, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !second.worker.process && !second.io.event && same_charge(budget->reserved, one),
        "deny a second worker at the aggregate host request byte ceiling");
    ++budget->limit.host_request_bytes;
    --budget->limit.host_reply_bytes;
    check(bc_worker_broker_start(&second, &next) == ERROR_NOT_ENOUGH_QUOTA &&
        !second.worker.process && !second.io.event && same_charge(budget->reserved, one),
        "deny a second worker at the aggregate host reply byte ceiling");
    ++budget->limit.host_reply_bytes;
    check(bc_worker_broker_start(&second, &next) == ERROR_SUCCESS &&
        first->host_staging && second.host_staging && first->host_staging != second.host_staging &&
        same_charge(budget->reserved, both), "admit separate staging for both process-backed workers at exact capacity");
    while (!codec.headers && second.gate.status == BC_WORKER_GATE_PENDING) {
        bc_worker_broker_step(&second);
        Sleep(1);
    }
    check(codec.headers == 1 && second.phase == BC_WORKER_BROKER_WAIT_HOST &&
        processes->live == 2 && first_adapter->slot.process && adapter.slot.process,
        "both real adapters hold their process slots while replying");
    second.phase_deadline = clock_ticks();
    check(bc_worker_broker_step(&second) == BC_WORKER_GATE_EXPIRED &&
        bc_worker_broker_cancel(&second) == BC_WORKER_GATE_EXPIRED &&
        first->gate.status == BC_WORKER_GATE_CANCELLED,
        "settle independent outcomes for the two process-backed workers");
    size_t length = 123;
    check(!bc_worker_broker_take(&second, &length) && length == 123,
        "the expired process-backed worker publishes nothing");

    const uint64_t deadline = clock_ticks() + 50000000ULL;
    while (!bc_worker_broker_close(&second)) {
        check(clock_ticks() < deadline && same_charge(budget->reserved, both) &&
            second.gate.status == BC_WORKER_GATE_EXPIRED,
            "retain both broker charges while one process adapter is being collected");
        Sleep(1);
    }
    check(same_charge(budget->reserved, one) && first_adapter->slot.process &&
        !adapter.slot.process && processes->live == 1 && processes->launches == 2 &&
        codec.requests == 1 && !codec.replies && first->gate.status == BC_WORKER_GATE_CANCELLED,
        "collect only the expired worker and its adapter");
}

static void verify_catalog_process(const wchar_t *path, const wchar_t *directory,
    const wchar_t *adapter_image, bc_worker_gate_status expected) {
    uint8_t start[4096], result[512] = {0}, request[18], reply[13], executable[4096];
    FILE *file = NULL;
    check(!fopen_s(&file, "catalog-compile.start", "rb"), "open process adapter START fixture");
    const size_t size = fread(start, 1, sizeof(start), file);
    check(size && feof(file) && !ferror(file) && !fclose(file), "read process adapter START fixture");
    const int path_size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, adapter_image, -1,
        (char *)executable, sizeof(executable), NULL, NULL);
    check(path_size > 1, "encode trusted adapter path");

    const bool success = expected == BC_WORKER_GATE_DELIVERED;
    const bool stop = expected == BC_WORKER_GATE_CANCELLED || expected == BC_WORKER_GATE_EXPIRED;
    const wchar_t mode[] = {success ? L'o' : stop ? L's' : L'w', 0};
    const size_t adapter_wire = 2 * BC_ADAPTER_HEADER_BYTES + 14 + 12 + 1;
    const size_t adapter_heap = bc_adapter_slot_heap_bytes(executable, (size_t)path_size - 1);
    check(adapter_heap > BC_ADAPTER_HEADER_BYTES + BC_ADAPTER_BODY_LIMIT &&
        bc_adapter_slot_heap_bytes((const uint8_t *)"\xc3\xa9", 2) ==
        bc_adapter_slot_heap_bytes((const uint8_t *)"e", 1) &&
        !bc_adapter_slot_heap_bytes((const uint8_t *)"\xff", 1),
        "size the retained frame and launch scratch using converted UTF-16 length");
    process_codec codec = {0};
    bc_worker_process_route route;
    check(bc_worker_process_route_init(&route, executable, (size_t)path_size - 1, 12,
        2, 2 * adapter_wire, &codec, process_fixture_encode, process_fixture_header,
        process_fixture_decode), "initialize caller-owned process route");
    const size_t adapter_parent = adapter_heap + sizeof(route) + sizeof(codec);
    bc_worker_broker broker = {0};
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + size + sizeof(result) + 1 +
        2 * (2 * BC_WORKER_FRAME_BYTES + sizeof(request) + sizeof(reply) + adapter_wire);
    const bc_worker_broker_amounts charge = {1,
        sizeof(broker) + size + sizeof(result) + sizeof(request) + sizeof(reply) + worker_launch_heap + adapter_parent,
        commit_limit + BC_WORKER_ADAPTER_JOB_COMMIT_BYTES, wire, 1, 3, process_pipe_buffers,
        2 * sizeof(request), 2 * sizeof(reply), 21};
    bc_worker_broker_budget budget = {.limit = charge};
    wchar_t command[] = L"worker --internal-project-worker";
    bc_worker_broker_run run = {
        .budget = &budget, .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = 2000,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 2500,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire,
        .request = start, .request_length = size, .result = result, .result_capacity = sizeof(result),
        .validate = success ? catalog_process_result : reject_callback,
        .host = {NULL, &route.adapter, NULL, NULL, sizeof(request), sizeof(reply), 2},
        .adapter = &bc_worker_process_callbacks, .adapter_wire_bytes = 2 * adapter_wire,
        .host_parent_bytes = adapter_parent
    };
    --run.wire_limit;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.io.event && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject a session wire limit one byte short of the combined envelope");
    ++run.wire_limit;
    --budget.limit.wire_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.io.event && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject an aggregate wire limit one byte short of the combined envelope");
    ++budget.limit.wire_bytes;
    --budget.limit.io_slots;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.io.event && !broker.cancel_io.event && !route.budget.live &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject a process-backed run without the third I/O slot");
    ++budget.limit.io_slots;
    --budget.limit.pipe_buffer_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !route.budget.launches &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject a process-backed run one byte below its combined pipe buffer reservation");
    ++budget.limit.pipe_buffer_bytes;
    --budget.limit.handle_slots;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event && !route.budget.launches &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject a process-backed run one slot below its combined handle reservation");
    ++budget.limit.handle_slots;
    --budget.limit.parent_bytes;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.host_staging && !broker.worker.process && !broker.io.event && !route.budget.launches &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject a parent limit one byte short of the route, staging and launch reservation");
    ++budget.limit.parent_bytes;
    run.host_parent_bytes = SIZE_MAX;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject an overflowing parent charge");
    run.host_parent_bytes = adapter_parent;
    run.commit_bytes = SIZE_MAX;
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.io.event && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "reject overflowing combined Job commit before opening handles");
    run.commit_bytes = commit_limit;
    run.application = L"relative.exe";
    check(bc_worker_broker_start(&broker, &run) == ERROR_INVALID_PARAMETER &&
        !broker.host_staging && broker.phase == BC_WORKER_BROKER_IDLE &&
        !route.budget.launches && same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "release broker-owned staging after a failed launch");
    run.application = path;
    check(SetEnvironmentVariableW(L"BC_TEST_RESTRICTED_PROCESS", mode) &&
        !bc_worker_broker_start(&broker, &run) && same_charge(budget.reserved, charge),
        "launch catalog guest at the exact combined wire limit");
    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        bc_worker_broker_step(&broker);
        if (stop && codec.headers == 1 && broker.phase == BC_WORKER_BROKER_WAIT_HOST) {
            check(route.budget.live == 1, "adapter process holds its slot during the reply");
            if (expected == BC_WORKER_GATE_CANCELLED)
                check(bc_worker_broker_cancel(&broker) == expected, "cancel live adapter");
            broker.phase_deadline = clock_ticks();
            check(bc_worker_broker_step(&broker) == expected &&
                bc_worker_broker_cancel(&broker) == expected, "keep the first process stop cause");
        }
        Sleep(1);
    }
    size_t length = 123;
    const uint8_t *published = bc_worker_broker_take(&broker, &length);
    check(broker.gate.status == expected &&
        (success ? published == result && catalog_process_result(NULL, result, length) :
            !published && length == 123), "publish only the completed process-backed guest");
    const bool shared = expected == BC_WORKER_GATE_CANCELLED;
    if (shared) verify_shared_process_reaping(&broker, &run, charge);
    const uint64_t reap_limit = clock_ticks() + 50000000ULL;
    while (!bc_worker_broker_close(&broker)) {
        check(clock_ticks() < reap_limit && broker.gate.status == expected &&
            same_charge(budget.reserved, charge), "keep the reservation during process adapter reaping");
        Sleep(1);
    }
    check(SetEnvironmentVariableW(L"BC_TEST_RESTRICTED_PROCESS", NULL), "clear process adapter mode");
    const unsigned launches = success ? 2 : 1;
    check(codec.requests == launches && codec.headers == launches && codec.replies == (success ? 2u : 0u) &&
        route.budget.launches == launches + (size_t)shared &&
        route.budget.wire == (launches + (size_t)shared) * adapter_wire &&
        !broker.host_staging && !route.budget.live && !route.adapter.slot.process &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}), "reap process and refund both live reservations");
}

static void verify_parent_broker(const wchar_t *image, const wchar_t *directory,
    const wchar_t *name, const wchar_t *operation, const wchar_t *source,
    DWORD expected_exit, const char *expected_output) {
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"browniec --internal-scalar-broker %ls %ls %ls",
        name, operation, source) > 0, "format parent broker fixture command");
    SECURITY_ATTRIBUTES inherit = {sizeof(inherit), NULL, TRUE};
    HANDLE input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ, &inherit, OPEN_EXISTING, 0, NULL);
    HANDLE read = NULL, write = NULL;
    check(input != INVALID_HANDLE_VALUE && CreatePipe(&read, &write, &inherit, 4096) &&
        SetHandleInformation(read, HANDLE_FLAG_INHERIT, 0), "prepare parent broker fixture streams");
    STARTUPINFOW setup = {0};
    setup.cb = sizeof(setup);
    setup.dwFlags = STARTF_USESTDHANDLES;
    setup.hStdInput = input;
    setup.hStdOutput = write;
    setup.hStdError = write;
    PROCESS_INFORMATION parent = {0};
    check(CreateProcessW(image, command, NULL, NULL, TRUE, CREATE_NO_WINDOW,
        NULL, directory, &setup, &parent), "launch actual parent broker command");
    CloseHandle(parent.hThread);
    CloseHandle(input);
    CloseHandle(write);
    if (WaitForSingleObject(parent.hProcess, 15000) != WAIT_OBJECT_0) {
        TerminateProcess(parent.hProcess, ERROR_TIMEOUT);
        check(FALSE, "parent broker command did not finish");
    }
    DWORD code = STILL_ACTIVE;
    check(GetExitCodeProcess(parent.hProcess, &code) && CloseHandle(parent.hProcess),
        "reap parent broker command");
    char data[256] = {0};
    DWORD used = 0, count = 0;
    while (used < sizeof(data) - 1 && ReadFile(read, data + used,
        (DWORD)sizeof(data) - 1 - used, &count, NULL) && count) used += count;
    check(CloseHandle(read), "close parent broker output");
    if (code != expected_exit || strcmp(data, expected_output))
        fprintf(stderr, "parent broker command: exit=%lu, output=%s\n", code, data);
    check(code == expected_exit && used == strlen(expected_output) &&
        !memcmp(data, expected_output, used), "verify exactly one parent result and the expected exit");
}

int wmain(int argc, wchar_t **argv) {
    wchar_t adapter_mode[2];
    if (argc == 1 && GetEnvironmentVariableW(L"BC_TEST_RESTRICTED_PROCESS", adapter_mode, 2) == 1)
        return process_fixture_child(adapter_mode[0]);
    if (argc == 3 && !wcscmp(argv[1], L"--child")) return child(argv[2], cpu);
    if (argc == 3 && !wcscmp(argv[1], L"--child-ok")) return child(argv[2], clean);
    if (argc == 3 && !wcscmp(argv[1], L"--child-early")) return child(argv[2], early);
    if (argc == 3 && !wcscmp(argv[1], L"--child-trailing")) return child(argv[2], trailing);
    if (argc == 3 && !wcscmp(argv[1], L"--child-stalled")) return child(argv[2], stalled);
    if (argc == 3 && !wcscmp(argv[1], L"--child-stalled-result")) return child(argv[2], stalled_result);
    if (argc == 3 && !wcscmp(argv[1], L"--child-late-result")) return child(argv[2], cancel_reply);
    if (argc == 3 && !wcscmp(argv[1], L"--child-ignore-cancel")) return child(argv[2], cancel_ignore);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-ok")) return child(argv[2], host_ok);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-wrong-id")) return child(argv[2], host_wrong_id);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-size")) return child(argv[2], host_oversized);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-exhausted")) return child(argv[2], host_exhausted);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-invalid")) return child(argv[2], host_invalid);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-cancel-rx")) return child(argv[2], host_cancel_rx);
    if (argc == 3 && !wcscmp(argv[1], L"--child-host-cancel-tx")) return child(argv[2], host_cancel_tx);
    if (argc == 3 && !wcscmp(argv[1], L"--child-peer-ok")) return production_peer(false);
    if (argc == 3 && !wcscmp(argv[1], L"--child-peer-cancel")) return production_peer(true);
    check((argc == 2 || argc == 3) && atexit(cleanup) == 0, "parent fixture arguments");
    InitializeProcThreadAttributeList(NULL, 3, 0, &worker_launch_heap);
    check(worker_launch_heap && worker_launch_heap == bc_restricted_worker_launch_heap_bytes(),
        "reserve the Windows size of the worker's three launch attributes");
    verify_frames();
    verify_stream();
    DWORD cold = 0, baseline = 0, final = 0;
    check(SetEnvironmentVariableW(L"BC_WORKER_TEST_PARENT", L"sentinel"), "parent environment marker");
    check(swprintf_s(profile_name, _countof(profile_name), L"Rodisoft.BrownieC.Test.%lu.%llu",
        GetCurrentProcessId(), GetTickCount64()) > 0, "fixture profile name");
    const HRESULT created = CreateAppContainerProfile(profile_name, profile_name, profile_name, NULL, 0, &profile);
    if (FAILED(created)) SetLastError((DWORD)created);
    check(SUCCEEDED(created), "create ephemeral fixture profile");
    permit_execute(argv[1]);
    if (argc == 3) permit_execute(argv[2]);
    wchar_t directory[MAX_PATH];
    const DWORD length = GetCurrentDirectoryW(_countof(directory), directory);
    check(length && length < _countof(directory), "get fixture directory");
    check(GetProcessHandleCount(GetCurrentProcess(), &cold), "cold launcher handles");
    DWORD pipe_status = bc_worker_pipes_open(&pipes);
    SetLastError(pipe_status);
    check(pipe_status == ERROR_SUCCESS, "prepare private worker pipes");
    check(bc_worker_pipes_open(&pipes) == ERROR_INVALID_PARAMETER, "reject reopening a live pipe owner");
    verify_pipes();
    verify_io_lifetime();
    SECURITY_ATTRIBUTES inheritable = {sizeof(inheritable), NULL, TRUE};
    decoy = CreateEventW(&inheritable, TRUE, FALSE, NULL);
    check(decoy != NULL, "inheritable decoy");
    unsigned char ordinary_sid[SECURITY_MAX_SID_SIZE];
    DWORD sid_size = sizeof(ordinary_sid);
    check(CreateWellKnownSid(WinWorldSid, NULL, ordinary_sid, &sid_size), "ordinary SID fixture");
    check(prepare(argv[1], directory, pipes.child, ordinary_sid, FALSE) != ERROR_SUCCESS &&
        !worker.job && !worker.process && !worker.thread, "reject an ordinary SID without publication");
    HANDLE invalid[3] = {pipes.child[BC_WORKER_STDIN], pipes.broker[BC_WORKER_STDOUT], pipes.child[BC_WORKER_STDERR]};
    check(prepare(argv[1], directory, invalid, profile, FALSE) == ERROR_INVALID_PARAMETER &&
        !worker.process, "reject a noninheritable endpoint");
    DWORD status = prepare(argv[1], directory, pipes.child, profile, FALSE);
    SetLastError(status);
    check(status == ERROR_SUCCESS, "prepare suspended AppContainer");
    verify_job();
    DWORD available = 1;
    check(PeekNamedPipe(pipes.broker[BC_WORKER_STDOUT], NULL, 0, NULL, &available, NULL) && !available,
        "no child output before resume");
    check(bc_restricted_worker_close(&worker) ||
        (WaitForSingleObject(worker.process, 5000) == WAIT_OBJECT_0 && bc_restricted_worker_close(&worker)),
        "close a suspended worker and reap");
    // A first AppContainer launch can initialize process-wide Windows state.
    // Measure the repeat launch with the six pipe handles and decoy still open.
    check(GetProcessHandleCount(GetCurrentProcess(), &baseline), "warm launcher handles");

    status = prepare(argv[1], directory, pipes.child, profile, FALSE);
    SetLastError(status);
    check(status == ERROR_SUCCESS, "prepare AppContainer for execution");
    check(bc_restricted_worker_resume(&worker) == ERROR_SUCCESS &&
        bc_restricted_worker_resume(&worker) == ERROR_INVALID_PARAMETER, "resume exactly once");
    // Close the parent's copies of the worker endpoints so a failed child
    // yields EOF instead of leaving a read blocked.
    bc_worker_pipes_close_child(&pipes);
    bc_worker_frame expected;
    start_exchange(&expected);
    check(WaitForSingleObject(worker.process, 10000) == WAIT_OBJECT_0, "Job CPU limit stopped the worker");
    DWORD exit_code = 0;
    check(GetExitCodeProcess(worker.process, &exit_code), "get worker exit code");
    SetLastError(exit_code);
    check(exit_code == status_quota_exceeded || exit_code == ERROR_NOT_ENOUGH_QUOTA,
        "worker terminated by Job CPU limit");
    FILETIME began, ended, kernel, user;
    check(GetProcessTimes(worker.process, &began, &ended, &kernel, &user), "query terminated worker CPU time");
    const ULONGLONG user_ticks = ((ULONGLONG)user.dwHighDateTime << 32) | user.dwLowDateTime;
    check(user_ticks >= cpu_limit * 10000ULL, "worker consumed its user CPU budget");
    uint8_t byte = 0;
    bc_worker_rx rx;
    HANDLE output = pipes.broker[BC_WORKER_STDOUT];
    expected.kind = BC_WORKER_RESULT;
    bc_worker_rx_begin(&rx, &expected, &byte, 1);
    check(receive_frame(output, &rx) == BC_WORKER_RX_COMPLETE &&
        bc_worker_rx_frame(&rx)->length == 1 && byte == 42, "receive only the entire worker RESULT");
    verify_gate_rejections(&rx);
    bc_worker_gate gate;
    bc_worker_gate_begin(&gate, clock_ticks() + 100000000ULL);
    bc_worker_gate_stage(&gate, &rx, fixture_result, NULL, clock_ticks());
    const bool clean_eof = stdout_eof(output);
    check(clean_eof, "observe EOF on CPU-terminated worker stdout");
    bc_worker_gate_stdout_end(&gate, clean_eof, clock_ticks());
    bc_worker_gate_exit(&gate, exit_code, clock_ticks());
    size_t published_length = 123;
    check(!bc_worker_gate_take(&gate, &published_length, clock_ticks()) && published_length == 123 &&
        gate.status == BC_WORKER_GATE_EXIT && !gate.candidate, "reject complete RESULT on Job termination");
    ++expected.sequence;
    bc_worker_rx_begin(&rx, &expected, &byte, 1);
    check(receive_frame(output, &rx) == BC_WORKER_RX_EOF, "confirm EOF from the real worker stdout");
    DWORD count = 0;
    check(transfer(pipes.broker[BC_WORKER_STDERR], &byte, NULL, 1, &count) == ERROR_SUCCESS &&
        count == 1 && byte == 42, "receive the approved stderr byte");
    check(WaitForSingleObject(decoy, 0) == WAIT_TIMEOUT, "decoy was not inherited");
    check(bc_restricted_worker_close(&worker), "reap completed worker");
    bc_worker_pipes_close(&pipes);
    verify_clean_publication(argv[1], directory);
    verify_broker(argv[1], directory, L"--child-ok", BC_WORKER_GATE_DELIVERED);
    verify_broker(argv[1], directory, L"--child-early", BC_WORKER_GATE_PROTOCOL);
    verify_broker(argv[1], directory, L"--child-trailing", BC_WORKER_GATE_PROTOCOL);
    verify_broker(argv[1], directory, L"--child-stalled", BC_WORKER_GATE_CANCELLED);
    verify_broker(argv[1], directory, L"--child-stalled", BC_WORKER_GATE_EXPIRED);
    verify_broker(argv[1], directory, L"--child-stalled-result", BC_WORKER_GATE_EXPIRED);
    verify_host_broker(argv[1], directory, L"--child-host-ok", 2, BC_WORKER_GATE_DELIVERED, 2);
    verify_host_broker(argv[1], directory, L"--child-host-wrong-id", 2, BC_WORKER_GATE_PROTOCOL, 0);
    verify_host_broker(argv[1], directory, L"--child-host-size", 2, BC_WORKER_GATE_PROTOCOL, 0);
    verify_host_broker(argv[1], directory, L"--child-host-exhausted", 1, BC_WORKER_GATE_PROTOCOL, 1);
    verify_host_broker(argv[1], directory, L"--child-host-invalid", 2, BC_WORKER_GATE_PROTOCOL, 1);
    verify_host_broker(argv[1], directory, L"--child-host-cancel-rx", 2, BC_WORKER_GATE_CANCELLED, 0);
    verify_host_broker(argv[1], directory, L"--child-host-cancel-tx", 2, BC_WORKER_GATE_CANCELLED, 1);
    verify_host_broker(argv[1], directory, L"--child-host-cancel-rx", 2, BC_WORKER_GATE_EXPIRED, 0);
    verify_host_broker(argv[1], directory, L"--child-host-cancel-tx", 2, BC_WORKER_GATE_EXPIRED, 1);
    verify_host_broker(argv[1], directory, L"--child-peer-ok", 2, BC_WORKER_GATE_DELIVERED, 2);
    verify_host_broker(argv[1], directory, L"--child-peer-cancel", 2, BC_WORKER_GATE_CANCELLED, 0);
    verify_deferred_adapter(argv[1], directory, BC_WORKER_GATE_DELIVERED);
    verify_deferred_adapter(argv[1], directory, BC_WORKER_GATE_CANCELLED);
    verify_deferred_adapter(argv[1], directory, BC_WORKER_GATE_EXPIRED);
    verify_graceful_cancel(argv[1], directory, false);
    verify_graceful_cancel(argv[1], directory, true);
    if (argc == 3) {
        verify_scalar_programs(argv[2], directory);
        verify_project_rejections(argv[2], directory);
        verify_project_compile_stop(argv[2], directory, "managed-compile.start", true);
        verify_project_compile_stop(argv[2], directory, "configured-compile.start", true);
        verify_project_compile_stop(argv[2], directory, "catalog-compile.start", true);
        verify_project_compile_stop(argv[2], directory, "configured-compile.start", false);
        verify_catalog_host_stop(argv[2], directory, false, BC_WORKER_GATE_CANCELLED);
        verify_catalog_host_stop(argv[2], directory, true, BC_WORKER_GATE_CANCELLED);
        verify_catalog_host_stop(argv[2], directory, false, BC_WORKER_GATE_EXPIRED);
        verify_catalog_host_stop(argv[2], directory, true, BC_WORKER_GATE_EXPIRED);
        verify_catalog_process(argv[2], directory, argv[1], BC_WORKER_GATE_DELIVERED);
        verify_catalog_process(argv[2], directory, argv[1], BC_WORKER_GATE_CANCELLED);
        verify_catalog_process(argv[2], directory, argv[1], BC_WORKER_GATE_EXPIRED);
        verify_catalog_process(argv[2], directory, argv[1], BC_WORKER_GATE_PROTOCOL);
    }
    check(CloseHandle(decoy), "close decoy");
    decoy = NULL;
    long parent_cold_delta = 0;
    if (argc == 3) {
        DWORD before_parent = 0, warm_parent = 0, after_parent = 0;
        check(GetProcessHandleCount(GetCurrentProcess(), &before_parent), "count handles before parent commands");
        verify_parent_broker(argv[2], directory, profile_name, L"check", L"answer.brc", 0,
            "{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m1-scalar/1\",\"command\":\"check\",\"status\":\"checked\",\"return_i32\":null,\"error\":null}\n");
        check(GetProcessHandleCount(GetCurrentProcess(), &warm_parent), "count handles after first parent command");
        parent_cold_delta = (long)warm_parent - (long)before_parent;
        check(parent_cold_delta >= 0 && parent_cold_delta <= 1, "bound first parent launch handle change");
        verify_parent_broker(argv[2], directory, profile_name, L"run", L"answer.brc", 0,
            "{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m1-scalar/1\",\"command\":\"run\",\"status\":\"completed\",\"return_i32\":77,\"error\":null}\n");
        verify_parent_broker(argv[2], directory, profile_name, L"check", L"bad-source.brc", 3,
            "{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m1-scalar/1\",\"command\":\"check\",\"status\":\"error\",\"return_i32\":null,\"error\":{\"kind\":\"lexical\",\"byte_offset\":0}}\n");
        verify_parent_broker(argv[2], directory, L"bad/profile", L"run", L"answer.brc", 4,
            "{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m1-scalar/1\",\"command\":\"run\",\"status\":\"error\",\"return_i32\":null,\"error\":{\"kind\":\"unavailable\",\"byte_offset\":0}}\n");
        check(GetProcessHandleCount(GetCurrentProcess(), &after_parent) && after_parent == warm_parent,
            "success and failure parent commands leave no repeat handle increase");
    }
    check(GetProcessHandleCount(GetCurrentProcess(), &final), "final launcher handles");
    if ((long)final + 7 != (long)baseline + parent_cold_delta)
        fprintf(stderr, "handles cold %lu, warm %lu, final %lu\n", cold, baseline, final);
    check((long)final + 7 == (long)baseline + parent_cold_delta, "balanced launcher handles after warmup");
    verify_stage(argv[0]);
    printf("{\"appContainer\":true,\"capabilities\":0,\"inheritedPipes\":3,"
           "\"commitDenied\":true,\"cpuTermination\":true,\"privatePipeAcl\":true,"
           "\"framedExchange\":true,\"headerMutationsRejected\":48,"
           "\"boundedStream\":true,\"pipeEof\":true,\"publicationGate\":true,"
           "\"ioLease\":true,\"brokerSessions\":6,\"hostBrokerCases\":11,\"deferredAdapterCases\":3,\"sharedBudget\":true,"
           "\"sharedReapCases\":1,"
           "\"phaseDeadlines\":true,\"gracefulCancelCases\":2,\"handleDelta\":0,\"staging\":true,"
           "\"scalarSessions\":%d,\"parentBrokerCases\":%d,\"projectWireRejections\":%d,"
           "\"projectCompileStopCases\":%d,\"catalogHostStopCases\":%d,\"catalogProcessCases\":%d,"
           "\"sharedProcessReapCases\":%d,"
           "\"parentColdHandleDelta\":%ld,\"coldHandleDelta\":%ld}\n",
           argc == 3 ? 5 : 0, argc == 3 ? 4 : 0, argc == 3 ? 2 : 0, argc == 3 ? 4 : 0,
           argc == 3 ? 4 : 0, argc == 3 ? 4 : 0, argc == 3 ? 1 : 0,
           parent_cold_delta, (long)final - (long)cold);
    return 0;
}
