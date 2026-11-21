#define WIN32_LEAN_AND_MEAN
#include <aclapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <userenv.h>
#include <wchar.h>
#include "../../native/restricted_worker.h"
#include "../../native/restricted_worker_pipes.h"

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

static int child(wchar_t *number) {
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
    received.kind = BC_WORKER_READY;
    DWORD count = 0;
    if (!bc_worker_frame_encode(header, &received) ||
        !WriteFile(output, header, sizeof(header), &count, NULL) || count != sizeof(header)) return 7;
    expected = received;
    expected.kind = BC_WORKER_START;
    expected.sequence = 2;
    expected.length = 1;
    uint8_t byte = 0;
    if (!child_read(input, header, sizeof(header)) ||
        !bc_worker_frame_preflight(header, sizeof(header), &expected, &received) ||
        !bc_worker_frame_complete(&received, 1) ||
        !child_read(input, &byte, 1) || byte != 41) return 8;
    ++byte;
    received.kind = BC_WORKER_RESULT;
    if (!bc_worker_frame_encode(header, &received) ||
        !WriteFile(output, header, sizeof(header), &count, NULL) || count != sizeof(header) ||
        !WriteFile(output, &byte, 1, &count, NULL) || count != 1) return 9;
    if (!WriteFile(error, &byte, 1, &count, NULL) || count != 1) return 10;
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

static void exchange_bytes(HANDLE pipe, uint8_t *bytes, DWORD length, BOOL write) {
    OVERLAPPED io = {0};
    io.hEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
    check(io.hEvent != NULL, "create test I/O event");
    while (length) {
        DWORD count = 0;
        BOOL complete = write ? WriteFile(pipe, bytes, length, &count, &io) :
            ReadFile(pipe, bytes, length, &count, &io);
        if (!complete && GetLastError() == ERROR_IO_PENDING) {
            if (WaitForSingleObject(io.hEvent, 5000) == WAIT_OBJECT_0) {
                complete = GetOverlappedResult(pipe, &io, &count, FALSE);
            } else {
                CancelIoEx(pipe, &io);
                GetOverlappedResult(pipe, &io, &count, TRUE);
            }
        }
        check(complete && count && count <= length, "exchange bytes over the broker endpoint");
        bytes += count;
        length -= count;
    }
    check(CloseHandle(io.hEvent), "close test I/O event");
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

static void start_exchange(bc_worker_frame *frame) {
    uint8_t header[BC_WORKER_FRAME_BYTES];
    HANDLE input = pipes.broker[BC_WORKER_STDIN];
    HANDLE output = pipes.broker[BC_WORKER_STDOUT];
    *frame = (bc_worker_frame){.kind = BC_WORKER_HELLO, .sequence = 1};
    memcpy(frame->nonce, pipes.nonce, sizeof(frame->nonce));
    check(bc_worker_frame_encode(header, frame), "encode broker HELLO");
    exchange_bytes(input, header, 7, TRUE);
    exchange_bytes(input, header + 7, sizeof(header) - 7, TRUE);
    frame->kind = BC_WORKER_READY;
    exchange_bytes(output, header, sizeof(header), FALSE);
    bc_worker_frame ready;
    check(bc_worker_frame_preflight(header, sizeof(header), frame, &ready), "verify worker READY");
    frame->kind = BC_WORKER_START;
    frame->sequence = 2;
    frame->length = 1;
    check(bc_worker_frame_encode(header, frame), "encode broker START");
    exchange_bytes(input, header, sizeof(header), TRUE);
    uint8_t byte = 41;
    exchange_bytes(input, &byte, 1, TRUE);
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

static DWORD prepare(const wchar_t *path, const wchar_t *directory, HANDLE endpoints[3], PSID sid) {
    wchar_t command[256];
    check(swprintf_s(command, _countof(command), L"worker --child %llx",
        (unsigned long long)(ULONG_PTR)decoy) > 0, "format the fixture argument");
    return bc_restricted_worker_prepare(&worker, path, command, directory, sid, endpoints,
        commit_limit, cpu_limit);
}

int wmain(int argc, wchar_t **argv) {
    if (argc == 3 && !wcscmp(argv[1], L"--child")) return child(argv[2]);
    check(argc == 2 && atexit(cleanup) == 0, "parent fixture arguments");
    verify_frames();
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
    SECURITY_ATTRIBUTES inheritable = {sizeof(inheritable), NULL, TRUE};
    decoy = CreateEventW(&inheritable, TRUE, FALSE, NULL);
    check(decoy != NULL, "inheritable decoy");
    unsigned char ordinary_sid[SECURITY_MAX_SID_SIZE];
    DWORD sid_size = sizeof(ordinary_sid);
    check(CreateWellKnownSid(WinWorldSid, NULL, ordinary_sid, &sid_size), "ordinary SID fixture");
    check(prepare(argv[1], directory, pipes.child, ordinary_sid) != ERROR_SUCCESS &&
        !worker.job && !worker.process && !worker.thread, "reject an ordinary SID without publication");
    HANDLE invalid[3] = {pipes.child[BC_WORKER_STDIN], pipes.broker[BC_WORKER_STDOUT], pipes.child[BC_WORKER_STDERR]};
    check(prepare(argv[1], directory, invalid, profile) == ERROR_INVALID_PARAMETER &&
        !worker.process, "reject a noninheritable endpoint");
    DWORD status = prepare(argv[1], directory, pipes.child, profile);
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

    status = prepare(argv[1], directory, pipes.child, profile);
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
    uint8_t header[BC_WORKER_FRAME_BYTES], byte = 0;
    bc_worker_frame result;
    expected.kind = BC_WORKER_RESULT;
    exchange_bytes(pipes.broker[BC_WORKER_STDOUT], header, sizeof(header), FALSE);
    check(bc_worker_frame_preflight(header, sizeof(header), &expected, &result) &&
        bc_worker_frame_complete(&result, 1), "verify worker RESULT before reading the only body byte");
    for (size_t i = BC_WORKER_STDOUT; i < BC_WORKER_PIPE_COUNT; ++i) {
        exchange_bytes(pipes.broker[i], &byte, 1, FALSE);
        check(byte == 42, "worker returned the fixture byte on the approved endpoints");
    }
    check(WaitForSingleObject(decoy, 0) == WAIT_TIMEOUT, "decoy was not inherited");
    check(bc_restricted_worker_close(&worker), "reap completed worker");
    bc_worker_pipes_close(&pipes);
    check(CloseHandle(decoy), "close decoy");
    decoy = NULL;
    check(GetProcessHandleCount(GetCurrentProcess(), &final), "final launcher handles");
    if (final + 7 != baseline)
        fprintf(stderr, "handles cold %lu, warm %lu, final %lu\n", cold, baseline, final);
    check(final + 7 == baseline, "balanced launcher handles after warmup");
    printf("{\"appContainer\":true,\"capabilities\":0,\"inheritedPipes\":3,"
           "\"commitDenied\":true,\"cpuTermination\":true,\"privatePipeAcl\":true,"
           "\"framedExchange\":true,\"headerMutationsRejected\":48,\"handleDelta\":0,"
           "\"coldHandleDelta\":%ld}\n", (long)final - (long)cold);
    return 0;
}
