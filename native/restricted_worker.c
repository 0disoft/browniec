#define WIN32_LEAN_AND_MEAN
#include "restricted_worker.h"
#include <stdlib.h>
#include <wchar.h>

static BOOL absolute_drive_path(const wchar_t *path) {
    if (!path || !path[0] || path[1] != L':' || path[2] != L'\\') return FALSE;
    wchar_t drive = path[0] | 32;
    return drive >= L'a' && drive <= L'z';
}

static BOOL valid_endpoints(const HANDLE child[3]) {
    if (!child || child[0] == child[1] || child[0] == child[2] || child[1] == child[2])
        return FALSE;
    for (size_t i = 0; i < 3; ++i) {
        DWORD flags = 0;
        if (GetFileType(child[i]) != FILE_TYPE_PIPE ||
            !GetHandleInformation(child[i], &flags) || !(flags & HANDLE_FLAG_INHERIT))
            return FALSE;
    }
    return TRUE;
}

static DWORD configure_job(HANDLE job, SIZE_T commit_bytes, DWORD user_cpu_ms) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS | JOB_OBJECT_LIMIT_JOB_MEMORY | JOB_OBJECT_LIMIT_JOB_TIME;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    limits.BasicLimitInformation.PerJobUserTimeLimit.QuadPart = (LONGLONG)user_cpu_ms * 10000;
    limits.JobMemoryLimit = commit_bytes;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits)))
        return GetLastError();
    return ERROR_SUCCESS;
}

// Win32 uses these entries to initialize and redirect the AppContainer's
// private directories. Keep the block independent of broker configuration.
static DWORD worker_environment(wchar_t *block, DWORD capacity) {
    static const wchar_t *const names[] = {L"LOCALAPPDATA", L"SystemRoot", L"TEMP", L"TMP", L"USERPROFILE"};
    for (size_t i = 0; i < _countof(names); ++i) {
        const wchar_t *name = names[i];
        const DWORD prefix = (DWORD)wcslen(name) + 1;
        if (capacity <= prefix + 1) return ERROR_INSUFFICIENT_BUFFER;
        wmemcpy(block, name, prefix - 1);
        block[prefix - 1] = L'=';
        const DWORD used = GetEnvironmentVariableW(name, block + prefix, capacity - prefix - 1);
        if (!used) return ERROR_ENVVAR_NOT_FOUND;
        if (used >= capacity - prefix - 1) return ERROR_INSUFFICIENT_BUFFER;
        const DWORD entry = prefix + used + 1;
        block += entry;
        capacity -= entry;
    }
    *block = 0;
    return ERROR_SUCCESS;
}

enum { worker_launch_attribute_count = 3 };

SIZE_T bc_restricted_worker_launch_heap_bytes(void) {
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(NULL, worker_launch_attribute_count, 0, &size);
    return size;
}

static DWORD create_suspended(HANDLE job, PSID sid, HANDLE child[3],
    const wchar_t *application, wchar_t *command_line, const wchar_t *directory,
    PROCESS_INFORMATION *process) {
    wchar_t environment[8192];
    DWORD error = worker_environment(environment, _countof(environment));
    if (error) return error;
    SIZE_T size = bc_restricted_worker_launch_heap_bytes();
    if (!size) return GetLastError();
    LPPROC_THREAD_ATTRIBUTE_LIST attrs = HeapAlloc(GetProcessHeap(), 0, size);
    if (!attrs) return ERROR_NOT_ENOUGH_MEMORY;
    const BOOL initialized = InitializeProcThreadAttributeList(attrs, worker_launch_attribute_count, 0, &size);
    SECURITY_CAPABILITIES capabilities = {.AppContainerSid = sid};
    STARTUPINFOEXW startup = {0};
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startup.StartupInfo.hStdInput = child[0];
    startup.StartupInfo.hStdOutput = child[1];
    startup.StartupInfo.hStdError = child[2];
    startup.lpAttributeList = attrs;
    if (!initialized ||
        !UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES,
            &capabilities, sizeof(capabilities), NULL, NULL) ||
        !UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
            child, 3 * sizeof(*child), NULL, NULL) ||
        !UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
            &job, sizeof(job), NULL, NULL) ||
        !CreateProcessW(application, command_line, NULL, NULL, TRUE,
            EXTENDED_STARTUPINFO_PRESENT | CREATE_SUSPENDED | CREATE_NO_WINDOW |
            CREATE_UNICODE_ENVIRONMENT, environment, directory, &startup.StartupInfo, process))
        error = GetLastError();
    if (initialized) DeleteProcThreadAttributeList(attrs);
    HeapFree(GetProcessHeap(), 0, attrs);
    return error;
}

static BOOL verify_token(HANDLE process, PSID expected) {
    HANDLE token = NULL;
    if (!OpenProcessToken(process, TOKEN_QUERY, &token)) return FALSE;
    DWORD size = 0, app_container = 0;
    TOKEN_GROUPS grants = {0};
    union {
        TOKEN_APPCONTAINER_INFORMATION info;
        BYTE bytes[sizeof(TOKEN_APPCONTAINER_INFORMATION) + SECURITY_MAX_SID_SIZE];
    } identity;
    const BOOL valid =
        GetTokenInformation(token, TokenIsAppContainer, &app_container, sizeof(app_container), &size) &&
        app_container &&
        GetTokenInformation(token, TokenAppContainerSid, &identity, sizeof(identity), &size) &&
        identity.info.TokenAppContainer && EqualSid(identity.info.TokenAppContainer, expected) &&
        GetTokenInformation(token, TokenCapabilities, &grants, sizeof(grants), &size) &&
        !grants.GroupCount;
    CloseHandle(token);
    return valid;
}

DWORD bc_restricted_worker_prepare(bc_restricted_worker *worker,
    const wchar_t *application, wchar_t *command_line, const wchar_t *directory,
    PSID profile, HANDLE child[3], SIZE_T commit_bytes, DWORD user_cpu_ms) {
    if (!worker || worker->job || worker->process || worker->thread ||
        !absolute_drive_path(application) || !absolute_drive_path(directory) ||
        !profile || !IsValidSid(profile) || !valid_endpoints(child) ||
        !commit_bytes || !user_cpu_ms)
        return ERROR_INVALID_PARAMETER;

    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!job) return GetLastError();
    DWORD error = configure_job(job, commit_bytes, user_cpu_ms);
    PROCESS_INFORMATION process = {0};
    if (!error) error = create_suspended(job, profile, child,
        application, command_line, directory, &process);
    if (!error) {
        BOOL assigned = FALSE;
        if (!IsProcessInJob(process.hProcess, job, &assigned) || !assigned ||
            !verify_token(process.hProcess, profile))
            error = ERROR_ACCESS_DENIED;
    }
    if (error) {
        // The thread has never run. Terminate explicitly even if membership
        // verification failed, then close the kill-on-close Job.
        if (process.hProcess) TerminateProcess(process.hProcess, error);
        CloseHandle(job);
        if (process.hThread) CloseHandle(process.hThread);
        if (process.hProcess) CloseHandle(process.hProcess);
        return error;
    }
    *worker = (bc_restricted_worker){job, process.hProcess, process.hThread};
    return ERROR_SUCCESS;
}

DWORD bc_restricted_worker_resume(bc_restricted_worker *worker) {
    if (!worker || !worker->job || !worker->process || !worker->thread)
        return ERROR_INVALID_PARAMETER;
    const DWORD previous = ResumeThread(worker->thread);
    if (previous != 1) {
        const DWORD error = previous == (DWORD)-1 ? GetLastError() : ERROR_INVALID_STATE;
        CloseHandle(worker->job);
        worker->job = NULL;
        return error;
    }
    CloseHandle(worker->thread);
    worker->thread = NULL;
    return ERROR_SUCCESS;
}

BOOL bc_restricted_worker_stop(bc_restricted_worker *worker) {
    if (worker->job) {
        if (!CloseHandle(worker->job)) return FALSE;
        worker->job = NULL;
    }
    return TRUE;
}

BOOL bc_restricted_worker_close(bc_restricted_worker *worker) {
    if (!bc_restricted_worker_stop(worker)) return FALSE;
    if (worker->process && WaitForSingleObject(worker->process, 0) != WAIT_OBJECT_0)
        return FALSE;
    if (worker->thread) CloseHandle(worker->thread);
    if (worker->process) CloseHandle(worker->process);
    *worker = (bc_restricted_worker){0};
    return TRUE;
}
