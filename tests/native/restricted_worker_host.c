#define WIN32_LEAN_AND_MEAN
#include <aclapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <userenv.h>
#include <wchar.h>
#include "../../native/restricted_worker.h"

enum { commit_limit = 128 * 1024 * 1024, cpu_limit = 500 };
static const DWORD status_quota_exceeded = 0xc0000044;
static wchar_t profile_name[64];
static PSID profile;
static HANDLE pipe_ends[6];
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
    for (size_t i = 0; i < _countof(pipe_ends); ++i) {
        if (pipe_ends[i]) CloseHandle(pipe_ends[i]);
        pipe_ends[i] = NULL;
    }
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
    unsigned char byte = 0;
    DWORD count = 0;
    if (!ReadFile(input, &byte, 1, &count, NULL) || count != 1 || byte != 41) return 6;
    ++byte;
    if (!WriteFile(output, &byte, 1, &count, NULL) || count != 1) return 7;
    if (!WriteFile(error, &byte, 1, &count, NULL) || count != 1) return 8;
    // The Job's user CPU limit must stop this process without parent intervention.
    for (;;) YieldProcessor();
}

static void open_pipes(HANDLE endpoints[3]) {
    SECURITY_ATTRIBUTES inheritable = {sizeof(inheritable), NULL, TRUE};
    for (size_t i = 0; i < 3; ++i) {
        HANDLE *pair = &pipe_ends[2*i];
        check(CreatePipe(&pair[0], &pair[1], &inheritable, 0), "pipe pair");
        endpoints[i] = pair[i != 0];
        check(SetHandleInformation(pair[i == 0], HANDLE_FLAG_INHERIT, 0),
            "disable parent endpoint inheritance");
    }
    decoy = CreateEventW(&inheritable, TRUE, FALSE, NULL);
    check(decoy != NULL, "inheritable decoy");
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
    HANDLE endpoints[3];
    open_pipes(endpoints);
    unsigned char ordinary_sid[SECURITY_MAX_SID_SIZE];
    DWORD sid_size = sizeof(ordinary_sid);
    check(CreateWellKnownSid(WinWorldSid, NULL, ordinary_sid, &sid_size), "ordinary SID fixture");
    check(prepare(argv[1], directory, endpoints, ordinary_sid) != ERROR_SUCCESS &&
        !worker.job && !worker.process && !worker.thread, "reject an ordinary SID without publication");
    HANDLE invalid[3] = {endpoints[0], pipe_ends[2], endpoints[2]};
    check(prepare(argv[1], directory, invalid, profile) == ERROR_INVALID_PARAMETER &&
        !worker.process, "reject a noninheritable endpoint");
    DWORD status = prepare(argv[1], directory, endpoints, profile);
    SetLastError(status);
    check(status == ERROR_SUCCESS, "prepare suspended AppContainer");
    verify_job();
    DWORD available = 1;
    check(PeekNamedPipe(pipe_ends[2], NULL, 0, NULL, &available, NULL) && !available,
        "no child output before resume");
    check(bc_restricted_worker_close(&worker) ||
        (WaitForSingleObject(worker.process, 5000) == WAIT_OBJECT_0 && bc_restricted_worker_close(&worker)),
        "close a suspended worker and reap");
    // A first AppContainer launch can initialize process-wide Windows state.
    // Measure the repeat launch with the six pipe handles and decoy still open.
    check(GetProcessHandleCount(GetCurrentProcess(), &baseline), "warm launcher handles");

    status = prepare(argv[1], directory, endpoints, profile);
    SetLastError(status);
    check(status == ERROR_SUCCESS, "prepare AppContainer for execution");
    check(bc_restricted_worker_resume(&worker) == ERROR_SUCCESS &&
        bc_restricted_worker_resume(&worker) == ERROR_INVALID_PARAMETER, "resume exactly once");
    // Close the parent's copies of the worker endpoints so a failed child
    // yields EOF instead of leaving a read blocked.
    for (size_t i = 0; i < 3; ++i) {
        const size_t index = 2*i + (i != 0);
        check(CloseHandle(pipe_ends[index]), "close child endpoint in parent");
        pipe_ends[index] = NULL;
    }
    unsigned char byte = 41;
    DWORD count = 0;
    check(WriteFile(pipe_ends[1], &byte, 1, &count, NULL) && count == 1, "send a fixture byte");
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
    for (size_t i = 2; i < 6; i += 2)
        check(ReadFile(pipe_ends[i], &byte, 1, &count, NULL) && count == 1 && byte == 42,
            "worker returned the fixture byte on the approved endpoints");
    check(WaitForSingleObject(decoy, 0) == WAIT_TIMEOUT, "decoy was not inherited");
    check(bc_restricted_worker_close(&worker), "reap completed worker");
    for (size_t i = 0; i < _countof(pipe_ends); ++i) {
        if (pipe_ends[i]) check(CloseHandle(pipe_ends[i]), "close parent endpoint");
        pipe_ends[i] = NULL;
    }
    check(CloseHandle(decoy), "close decoy");
    decoy = NULL;
    check(GetProcessHandleCount(GetCurrentProcess(), &final), "final launcher handles");
    if (final + 7 != baseline)
        fprintf(stderr, "handles cold %lu, warm %lu, final %lu\n", cold, baseline, final);
    check(final + 7 == baseline, "balanced launcher handles after warmup");
    printf("{\"appContainer\":true,\"capabilities\":0,\"inheritedPipes\":3,"
           "\"commitDenied\":true,\"cpuTermination\":true,\"handleDelta\":0,"
           "\"coldHandleDelta\":%ld}\n", (long)final - (long)cold);
    return 0;
}
