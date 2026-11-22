#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <stdlib.h>
#include <string.h>

#include "host_adapter_process.h"

#pragma comment(lib, "mincore.lib")

typedef enum phase { SEND, READ_HEADER, WAIT_HEADER, READ_BODY, READ_EOF, WAIT_EXIT } phase;

struct bc_adapter_process {
    HANDLE job, process, input, output, event;
    OVERLAPPED io;
    uint64_t deadline;
    size_t offset, target, reply_limit;
    phase phase;
    bc_adapter_state state;
    int pending;
    uint8_t frame[BC_ADAPTER_HEADER_BYTES + BC_ADAPTER_BODY_LIMIT + 1];
};

static uint64_t now_ticks(void) {
    ULONGLONG now;
    QueryInterruptTimePrecise(&now);
    return now;
}

static void close_handle(HANDLE *h) {
    if (*h && *h != INVALID_HANDLE_VALUE) CloseHandle(*h);
    *h = NULL;
}

static void release(bc_adapter_process *s) {
    close_handle(&s->input);
    close_handle(&s->output);
    close_handle(&s->event);
    close_handle(&s->job);
    close_handle(&s->process);
    HeapFree(GetProcessHeap(), 0, s);
}

static int pipe_pair(HANDLE *server, HANDLE *client, int send, HANDLE event) {
    static const wchar_t base[] = L"\\\\.\\pipe\\browniec-adapter-";
    static const wchar_t hex[] = L"0123456789abcdef";
    uint8_t nonce[16];
    wchar_t name[_countof(base)+2*sizeof(nonce)];
    if (BCryptGenRandom(NULL, nonce, sizeof(nonce), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) return 0;
    memcpy(name, base, sizeof(base));
    for (size_t i = 0; i < sizeof(nonce); ++i) {
        name[_countof(base)-1+2*i] = hex[nonce[i] >> 4];
        name[_countof(base)+2*i] = hex[nonce[i] & 15];
    }
    name[_countof(name)-1] = 0;
    *server = CreateNamedPipeW(name, (send ? PIPE_ACCESS_OUTBOUND : PIPE_ACCESS_INBOUND) |
        FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
        1, BC_ADAPTER_PIPE_BUFFER_BYTES, BC_ADAPTER_PIPE_BUFFER_BYTES, 0, NULL);
    if (*server == INVALID_HANDLE_VALUE) return 0;
    SECURITY_ATTRIBUTES inherit = {sizeof(inherit), NULL, TRUE};
    *client = CreateFileW(name, send ? GENERIC_READ : GENERIC_WRITE, 0, &inherit, OPEN_EXISTING,
        SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION, NULL);
    if (*client == INVALID_HANDLE_VALUE) return 0;
    ULONG pid = 0;
    if (!GetNamedPipeClientProcessId(*server, &pid) || pid != GetCurrentProcessId()) return 0;
    OVERLAPPED connect = {0};
    connect.hEvent = event;
    /* Our opened client stays alive, so this is already connected. If the
       kernel still returns a pending operation, reap it before leaving. */
    if (ConnectNamedPipe(*server, &connect)) return 1;
    DWORD error = GetLastError();
    if (error == ERROR_PIPE_CONNECTED) return 1;
    if (error == ERROR_IO_PENDING) {
        DWORD ignored;
        CancelIoEx(*server, &connect);
        GetOverlappedResult(*server, &connect, &ignored, TRUE);
    }
    return 0;
}

static HANDLE make_job(size_t commit_bytes) {
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (!job) return NULL;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE |
        JOB_OBJECT_LIMIT_ACTIVE_PROCESS;
    limits.BasicLimitInformation.ActiveProcessLimit = 1;
    if (commit_bytes) {
        limits.BasicLimitInformation.LimitFlags |= JOB_OBJECT_LIMIT_JOB_MEMORY;
        limits.JobMemoryLimit = commit_bytes;
    }
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits)))
        close_handle(&job);
    return job;
}

static SIZE_T attribute_list_bytes(void) {
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(NULL, 2, 0, &size);
    return size;
}

size_t bc_adapter_slot_heap_bytes(const uint8_t *path, size_t path_len) {
    if (!path || !path_len || path_len > 4096) return 0;
    const int units = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)path,
        (int)path_len, NULL, 0);
    if (!units) return 0;
    const SIZE_T attrs = attribute_list_bytes();
    const size_t fixed = sizeof(bc_adapter_process) + ((size_t)units + 1) * sizeof(wchar_t);
    return attrs && attrs <= SIZE_MAX - fixed ? fixed + attrs : 0;
}

static int launch(bc_adapter_process *s, const wchar_t *path, HANDLE child[3]) {
    SIZE_T size = attribute_list_bytes();
    if (!size) return 0;
    LPPROC_THREAD_ATTRIBUTE_LIST attrs = HeapAlloc(GetProcessHeap(), 0, size);
    if (!attrs) return 0;
    int initialized = InitializeProcThreadAttributeList(attrs, 2, 0, &size);
    PROCESS_INFORMATION pi = {0};
    if (initialized &&
        UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, child,
            3*sizeof(*child), NULL, NULL) &&
        UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST, &s->job,
            sizeof(s->job), NULL, NULL)) {
        STARTUPINFOEXW startup = {0};
        startup.StartupInfo.cb = sizeof(startup);
        startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
        startup.StartupInfo.hStdInput = child[0];
        startup.StartupInfo.hStdOutput = child[1];
        startup.StartupInfo.hStdError = child[2];
        startup.lpAttributeList = attrs;
        if (now_ticks() < s->deadline &&
            CreateProcessW(path, NULL, NULL, NULL, TRUE, EXTENDED_STARTUPINFO_PRESENT |
                CREATE_NO_WINDOW, NULL, NULL, &startup.StartupInfo, &pi)) {
            s->process = pi.hProcess;
            CloseHandle(pi.hThread);
        }
    }
    if (initialized) DeleteProcThreadAttributeList(attrs);
    HeapFree(GetProcessHeap(), 0, attrs);
    return s->process != NULL;
}

static int valid_path(const wchar_t *path, size_t n) {
    if (!path || n < 8 || n > 32766 || path[1] != L':' || path[2] != L'\\') return 0;
    wchar_t drive = path[0] | 32;
    if (drive < L'a' || drive > L'z') return 0;
    for (size_t i = 3; i < n; ++i) {
        if (path[i] < 32 || path[i] == L'"' || path[i] == L':' || path[i] == L'/') return 0;
    }
    return path[n-4] == L'.' && (path[n-3] | 32) == L'e' &&
        (path[n-2] | 32) == L'x' && (path[n-1] | 32) == L'e';
}

int bc_adapter_path_valid(const uint8_t *path, size_t path_len) {
    if (!path || !path_len || path_len > 4096) return 0;
    wchar_t wide[4096];
    const int units = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)path,
        (int)path_len, wide, _countof(wide));
    return units && valid_path(wide, (size_t)units);
}

bc_adapter_process *bc_adapter_process_start(const wchar_t *path, size_t path_len,
    const uint8_t *header, const uint8_t *body, size_t body_len, uint64_t deadline,
    size_t job_commit_bytes) {
    if (!valid_path(path, path_len) || !header || (body_len && !body) ||
        body_len > BC_ADAPTER_BODY_LIMIT || now_ticks() >= deadline) return NULL;
    bc_adapter_process *s = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*s));
    if (!s) return NULL;
    wchar_t *application = HeapAlloc(GetProcessHeap(), 0, (path_len+1)*sizeof(*path));
    if (!application) { release(s); return NULL; }
    memcpy(application, path, path_len*sizeof(*path));
    application[path_len] = 0;
    s->event = CreateEventW(NULL, TRUE, FALSE, NULL);
    s->job = make_job(job_commit_bytes);
    s->deadline = deadline;
    s->phase = SEND;
    s->target = BC_ADAPTER_HEADER_BYTES + body_len;
    s->reply_limit = BC_ADAPTER_BODY_LIMIT;
    memcpy(s->frame, header, BC_ADAPTER_HEADER_BYTES);
    if (body_len) memcpy(s->frame+BC_ADAPTER_HEADER_BYTES, body, body_len);
    SECURITY_ATTRIBUTES inherit = {sizeof(inherit), NULL, TRUE};
    HANDLE child[3] = {NULL, NULL, CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_WRITE,
        &inherit, OPEN_EXISTING, 0, NULL)};
    int started = s->event && s->job && child[2] != INVALID_HANDLE_VALUE &&
        pipe_pair(&s->input, &child[0], 1, s->event) &&
        pipe_pair(&s->output, &child[1], 0, s->event) && launch(s, application, child);
    close_handle(&child[0]);
    close_handle(&child[1]);
    close_handle(&child[2]);
    HeapFree(GetProcessHeap(), 0, application);
    if (!started) { release(s); return NULL; }
    return s;
}

static int terminal(const bc_adapter_process *s) { return s->state >= BC_ADAPTER_READY; }

static HANDLE active_pipe(const bc_adapter_process *s) {
    return s->phase == SEND ? s->input : s->output;
}

static bc_adapter_state stop(bc_adapter_process *s, bc_adapter_state reason) {
    if (!terminal(s)) {
        s->state = reason;
        if (s->pending) CancelIoEx(active_pipe(s), &s->io);
        close_handle(&s->job);
    }
    return s->state;
}

static bc_adapter_state eof(bc_adapter_process *s) {
    if (s->phase != READ_EOF) return stop(s, BC_ADAPTER_FAILED);
    s->phase = WAIT_EXIT;
    return s->state;
}

static bc_adapter_state advance_io(bc_adapter_process *s) {
    HANDLE pipe = active_pipe(s);
    if (!s->pending) {
        if (!ResetEvent(s->event)) return stop(s, BC_ADAPTER_FAILED);
        s->io = (OVERLAPPED){0};
        s->io.hEvent = s->event;
        DWORD count = (DWORD)(s->target-s->offset);
        BOOL complete = s->phase == SEND ?
            WriteFile(pipe, s->frame+s->offset, count, NULL, &s->io) :
            ReadFile(pipe, s->frame+s->offset, count, NULL, &s->io);
        if (!complete) {
            DWORD error = GetLastError();
            if (error == ERROR_BROKEN_PIPE) return eof(s);
            if (error != ERROR_IO_PENDING) return stop(s, BC_ADAPTER_FAILED);
            s->pending = 1;
            return s->state;
        }
    }
    DWORD done = 0;
    if (!GetOverlappedResult(pipe, &s->io, &done, FALSE)) {
        DWORD error = GetLastError();
        if (error == ERROR_IO_INCOMPLETE) { s->pending = 1; return s->state; }
        s->pending = 0;
        if (error == ERROR_BROKEN_PIPE) return eof(s);
        return stop(s, BC_ADAPTER_FAILED);
    }
    s->pending = 0;
    if (!done || done > s->target-s->offset || s->phase == READ_EOF)
        return stop(s, BC_ADAPTER_FAILED);
    s->offset += done;
    if (s->offset < s->target) return s->state;
    if (s->phase == SEND) {
        close_handle(&s->input);
        s->phase = READ_HEADER;
        s->offset = 0;
        s->target = BC_ADAPTER_HEADER_BYTES;
    } else if (s->phase == READ_HEADER) {
        s->phase = WAIT_HEADER;
        s->state = BC_ADAPTER_HEADER;
    } else {
        s->phase = READ_EOF;
        ++s->target;
    }
    return s->state;
}

bc_adapter_state bc_adapter_process_step(bc_adapter_process *s) {
    if (terminal(s)) return s->state;
    if (now_ticks() >= s->deadline) return stop(s, BC_ADAPTER_DEADLINE);
    if (s->phase == WAIT_HEADER) return s->state;
    if (s->phase != WAIT_EXIT) return advance_io(s);
    DWORD waited = WaitForSingleObject(s->process, 0);
    if (waited == WAIT_TIMEOUT) return s->state;
    DWORD exit_code;
    if (waited != WAIT_OBJECT_0 || !GetExitCodeProcess(s->process, &exit_code) || exit_code)
        return stop(s, BC_ADAPTER_FAILED);
    return stop(s, now_ticks() < s->deadline ? BC_ADAPTER_READY : BC_ADAPTER_DEADLINE);
}

const uint8_t *bc_adapter_process_frame(const bc_adapter_process *s, size_t *length) {
    *length = 0;
    if (s->state == BC_ADAPTER_HEADER || s->state == BC_ADAPTER_READY) {
        *length = s->offset;
        return s->frame;
    }
    return NULL;
}

int bc_adapter_process_accept_body(bc_adapter_process *s, size_t length) {
    if (s->state != BC_ADAPTER_HEADER || length > s->reply_limit) return 0;
    if (now_ticks() >= s->deadline) { stop(s, BC_ADAPTER_DEADLINE); return 0; }
    s->target = BC_ADAPTER_HEADER_BYTES + length;
    s->state = BC_ADAPTER_PENDING;
    s->phase = length ? READ_BODY : READ_EOF;
    if (!length) ++s->target;
    return 1;
}

void bc_adapter_process_cancel(bc_adapter_process *s) { stop(s, BC_ADAPTER_CANCELLED); }

int bc_adapter_process_close(bc_adapter_process *s) {
    if (!s) return 1;
    bc_adapter_process_cancel(s);
    if (s->pending) {
        DWORD done;
        if (!GetOverlappedResult(active_pipe(s), &s->io, &done, FALSE) &&
            GetLastError() == ERROR_IO_INCOMPLETE) return 0;
        s->pending = 0;
    }
    if (WaitForSingleObject(s->process, 0) != WAIT_OBJECT_0) return 0;
    release(s);
    return 1;
}

static size_t wire_reservation(size_t request_length, size_t reply_limit) {
    return 2 * BC_ADAPTER_HEADER_BYTES + request_length + reply_limit + 1;
}

uint32_t bc_adapter_slot_admits(const void *owner, size_t request_length, size_t reply_limit) {
    const bc_adapter_slot *slot = owner;
    if (!slot || !slot->budget || slot->process || slot->generation == UINTPTR_MAX ||
        request_length > BC_ADAPTER_BODY_LIMIT || reply_limit > BC_ADAPTER_BODY_LIMIT) return 0;
    const bc_adapter_budget *budget = slot->budget;
    return budget->live < budget->live_limit && budget->launches < budget->launch_limit &&
        budget->wire <= budget->wire_limit &&
        wire_reservation(request_length, reply_limit) <= budget->wire_limit - budget->wire;
}

void *bc_adapter_slot_process(const void *owner, const void *engine, uintptr_t generation) {
    const bc_adapter_slot *slot = owner;
    return slot && slot->engine == engine && slot->generation == generation ? slot->process : NULL;
}

uintptr_t bc_adapter_slot_start(void *owner, const void *engine, const uint8_t *path,
    size_t path_len, const uint8_t *header, const uint8_t *body, size_t body_len,
    size_t reply_limit, uintptr_t deadline) {
    bc_adapter_slot *slot = owner;
    if (!engine || !path || !path_len || path_len > 4096 ||
        !bc_adapter_slot_admits(slot, body_len, reply_limit))
        return 0;
    bc_adapter_budget *budget = slot->budget;
    ++budget->launches;
    budget->wire += wire_reservation(body_len, reply_limit);
    wchar_t wide[4096];
    int units = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)path,
        (int)path_len, wide, _countof(wide));
    if (!units) return 0;
    slot->process = bc_adapter_process_start(wide, (size_t)units, header, body, body_len, deadline,
        slot->job_commit_bytes);
    if (!slot->process) return 0;
    slot->process->reply_limit = reply_limit;
    ++budget->live;
    slot->engine = engine;
    return ++slot->generation;
}

uint32_t bc_adapter_slot_close(void *owner) {
    bc_adapter_slot *slot = owner;
    if (!slot) return 0;
    if (!slot->process) return 1;
    if (!bc_adapter_process_close(slot->process)) return 0;
    --slot->budget->live;
    slot->process = NULL;
    slot->engine = NULL;
    return 1;
}
