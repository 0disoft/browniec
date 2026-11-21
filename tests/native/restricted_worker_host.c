#define WIN32_LEAN_AND_MEAN
#include <aclapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <userenv.h>
#include <wchar.h>
#include "../../native/restricted_worker.h"
#include "../../native/restricted_worker_broker.h"
#include "../../native/restricted_worker_gate.h"
#include "../../native/restricted_worker_io.h"
#include "../../native/restricted_worker_pipes.h"
#include "../../native/restricted_worker_stream.h"

enum { commit_limit = 128 * 1024 * 1024, cpu_limit = 500 };
static const DWORD status_quota_exceeded = 0xc0000044;
static wchar_t profile_name[64];
static PSID profile;
static bc_worker_pipes pipes;
static HANDLE decoy;
static bc_restricted_worker worker;

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

enum fixture_mode { cpu, clean, early, trailing, stalled, stalled_result };

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
    expected.length = 1;
    uint8_t byte = 0;
    if (!child_read(input, header, sizeof(header)) ||
        !bc_worker_frame_preflight(header, sizeof(header), &expected, &received) ||
        !bc_worker_frame_complete(&received, 1) ||
        !child_read(input, &byte, 1) || byte != 41) return 8;
    if (mode == stalled_result) return child_read(input, header, 1) ? 13 : 0;
    ++byte;
    received.kind = BC_WORKER_RESULT;
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

static bool fixture_result(const uint8_t *bytes, size_t length) {
    return length == 1 && bytes[0] == 42;
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
    bc_worker_gate_stage(&gate, rx, fixture_result, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "EOF before RESULT is terminal");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, 1);
    bc_worker_gate_stage(&gate, rx, fixture_result, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "duplicate RESULT drops candidate");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, 1);
    bc_worker_gate_stdout_end(&gate, false, 2);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "trailing stdout drops candidate");

    uint8_t invalid_byte = 41;
    bc_worker_rx invalid = *rx;
    invalid.body = &invalid_byte;
    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, &invalid, fixture_result, 1);
    check(gate.status == BC_WORKER_GATE_PROTOCOL && !gate.candidate, "invalid payload cannot stage");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_stage(&gate, rx, fixture_result, 1);
    bc_worker_gate_cancel(&gate, 99);
    bc_worker_gate_exit(&gate, 1, 101);
    check(!bc_worker_gate_take(&gate, &length, 102) && length == 123 &&
        gate.status == BC_WORKER_GATE_CANCELLED && !gate.candidate, "first cancellation survives expiry and exit");

    bc_worker_gate_begin(&gate, 100);
    bc_worker_gate_exit(&gate, 0, 1);
    bc_worker_gate_stage(&gate, rx, fixture_result, 2);
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
    bc_worker_gate_stage(&gate, &rx, fixture_result, clock_ticks());
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
        a.child_commit_bytes == b.child_commit_bytes && a.wire_bytes == b.wire_bytes;
}

static void verify_shared_budget(bc_worker_broker_budget *budget, const bc_worker_broker_run *run,
    bc_worker_broker_amounts one) {
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
        2, 2 * one.parent_bytes, 2 * one.child_commit_bytes, 2 * one.wire_bytes
    };
    const bc_worker_broker_amounts limits[] = {
        {1, both.parent_bytes, both.child_commit_bytes, both.wire_bytes},
        {2, both.parent_bytes - 1, both.child_commit_bytes, both.wire_bytes},
        {2, both.parent_bytes, both.child_commit_bytes - 1, both.wire_bytes},
        {2, both.parent_bytes, both.child_commit_bytes, both.wire_bytes - 1}
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
    while (!bc_worker_broker_close(&second)) {
        check(clock_ticks() < deadline && same_charge(budget->reserved, both),
            "second worker keeps its charge through reaping");
        Sleep(1);
    }
    check(same_charge(budget->reserved, one), "first worker's reservation survives second teardown");
}

static void verify_broker(const wchar_t *path, const wchar_t *directory,
    const wchar_t *mode, bc_worker_gate_status expected) {
    bc_worker_broker broker = {0};
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker %ls %llx", mode,
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format broker fixture command");
    const uint8_t request = 41;
    uint8_t result = 0;
    const size_t wire = 4 * BC_WORKER_FRAME_BYTES + 3;
    const bc_worker_broker_amounts charge = {1, sizeof(broker) + 2, commit_limit, wire};
    bc_worker_broker_budget budget = {.limit = charge};
    const bool idle_expiry = !wcscmp(mode, L"--child-stalled-result");
    const bc_worker_broker_phase wait_phase = idle_expiry ?
        BC_WORKER_BROKER_READ_RESULT : BC_WORKER_BROKER_READ_READY;
    bc_worker_broker_run run = {
        .budget = &budget,
        .application = path, .command_line = command, .directory = directory,
        .profile = profile, .commit_bytes = commit_limit, .cpu_ms = cpu_limit,
        .startup_ms = expected == BC_WORKER_GATE_EXPIRED && !idle_expiry ? 1200 : 4000,
        .io_idle_ms = idle_expiry ? 500 : 4000,
        .deadline = clock_ticks() + 100000000ULL, .wire_limit = wire - 1,
        .request = &request, .request_length = 1, .result = &result, .result_capacity = 1,
        .validate = fixture_result
    };
    check(bc_worker_broker_start(&broker, &run) == ERROR_NOT_ENOUGH_QUOTA &&
        !broker.worker.process && !broker.io.event, "wire capacity one byte short rejects before launch");
    run.wire_limit = wire;
    const DWORD status = bc_worker_broker_start(&broker, &run);
    SetLastError(status);
    check(status == ERROR_SUCCESS && same_charge(budget.reserved, charge),
        "start worker through the broker at exact wire and aggregate capacity");
    const uint64_t startup_deadline = broker.phase_deadline;

    while (broker.gate.status == BC_WORKER_GATE_PENDING && broker.phase != BC_WORKER_BROKER_FINISH) {
        size_t untouched = 123;
        check(!bc_worker_broker_take(&broker, &untouched) && untouched == 123,
            "broker never exposes output while a phase is pending");
        bc_worker_broker_step(&broker);
        if (broker.phase == BC_WORKER_BROKER_READ_READY && broker.io.pipe &&
            expected == BC_WORKER_GATE_CANCELLED) break;
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
        check(pending && broker.phase == wait_phase &&
            terminal == (expected == BC_WORKER_GATE_CANCELLED ? BC_WORKER_GATE_PENDING : expected),
            "stop begins with a live outstanding read");
        if (expected == BC_WORKER_GATE_CANCELLED) verify_shared_budget(&budget, &run, charge);
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
        check(clock_ticks() < reaping_limit && broker.phase == BC_WORKER_BROKER_REAPING &&
            broker.gate.status == expected && same_charge(budget.reserved, charge),
            "reaping retains the first cause and reservation");
        Sleep(1);
    }
    check(!broker.worker.process && !broker.io.event && !broker.pipes.broker[BC_WORKER_STDOUT] &&
        same_charge(budget.reserved, (bc_worker_broker_amounts){0}),
        "broker releases resources only after reaping");
}

int wmain(int argc, wchar_t **argv) {
    if (argc == 3 && !wcscmp(argv[1], L"--child")) return child(argv[2], cpu);
    if (argc == 3 && !wcscmp(argv[1], L"--child-ok")) return child(argv[2], clean);
    if (argc == 3 && !wcscmp(argv[1], L"--child-early")) return child(argv[2], early);
    if (argc == 3 && !wcscmp(argv[1], L"--child-trailing")) return child(argv[2], trailing);
    if (argc == 3 && !wcscmp(argv[1], L"--child-stalled")) return child(argv[2], stalled);
    if (argc == 3 && !wcscmp(argv[1], L"--child-stalled-result")) return child(argv[2], stalled_result);
    check(argc == 2 && atexit(cleanup) == 0, "parent fixture arguments");
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
    bc_worker_gate_stage(&gate, &rx, fixture_result, clock_ticks());
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
    check(CloseHandle(decoy), "close decoy");
    decoy = NULL;
    check(GetProcessHandleCount(GetCurrentProcess(), &final), "final launcher handles");
    if (final + 7 != baseline)
        fprintf(stderr, "handles cold %lu, warm %lu, final %lu\n", cold, baseline, final);
    check(final + 7 == baseline, "balanced launcher handles after warmup");
    printf("{\"appContainer\":true,\"capabilities\":0,\"inheritedPipes\":3,"
           "\"commitDenied\":true,\"cpuTermination\":true,\"privatePipeAcl\":true,"
           "\"framedExchange\":true,\"headerMutationsRejected\":48,"
           "\"boundedStream\":true,\"pipeEof\":true,\"publicationGate\":true,"
           "\"ioLease\":true,\"brokerSessions\":6,\"sharedBudget\":true,"
           "\"phaseDeadlines\":true,\"handleDelta\":0,"
           "\"coldHandleDelta\":%ld}\n", (long)final - (long)cold);
    return 0;
}
