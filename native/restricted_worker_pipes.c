#define WIN32_LEAN_AND_MEAN
#include "restricted_worker_pipes.h"
#include <bcrypt.h>
#include <stdlib.h>
#include <string.h>

static const DWORD client_write = (FILE_GENERIC_WRITE & ~FILE_CREATE_PIPE_INSTANCE) |
    FILE_READ_ATTRIBUTES;
static const DWORD client_read = FILE_GENERIC_READ;

static DWORD pipe_security(PSECURITY_DESCRIPTOR descriptor, PACL acl, DWORD acl_bytes) {
    HANDLE token = NULL;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return GetLastError();
    union {
        TOKEN_GROUPS groups;
        BYTE bytes[sizeof(TOKEN_GROUPS) + SECURITY_MAX_SID_SIZE];
    } logon;
    DWORD used = 0;
    const BOOL read = GetTokenInformation(token, TokenLogonSid, &logon, sizeof(logon), &used);
    const DWORD status = read ? ERROR_SUCCESS : GetLastError();
    CloseHandle(token);
    if (status) return status;
    if (logon.groups.GroupCount != 1 ||
        (logon.groups.Groups[0].Attributes & SE_GROUP_LOGON_ID) != SE_GROUP_LOGON_ID)
        return ERROR_ACCESS_DENIED;
    if (!InitializeAcl(acl, acl_bytes, ACL_REVISION) ||
        !AddAccessAllowedAce(acl, ACL_REVISION, client_read | client_write,
            logon.groups.Groups[0].Sid) ||
        !InitializeSecurityDescriptor(descriptor, SECURITY_DESCRIPTOR_REVISION) ||
        !SetSecurityDescriptorDacl(descriptor, TRUE, acl, FALSE) ||
        !SetSecurityDescriptorControl(descriptor, SE_DACL_PROTECTED, SE_DACL_PROTECTED))
        return GetLastError();
    return ERROR_SUCCESS;
}

static void close_endpoint(HANDLE *endpoint) {
    if (*endpoint) {
        CloseHandle(*endpoint);
        *endpoint = NULL;
    }
}

static DWORD open_pair(SECURITY_ATTRIBUTES *security, BOOL send, HANDLE *broker, HANDLE *child) {
    static const wchar_t prefix[] = L"\\\\.\\pipe\\browniec-worker-";
    static const wchar_t hex[] = L"0123456789abcdef";
    BYTE nonce[16];
    if (BCryptGenRandom(NULL, nonce, sizeof(nonce), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0)
        return ERROR_GEN_FAILURE;
    wchar_t name[_countof(prefix) + 2 * sizeof(nonce)];
    memcpy(name, prefix, sizeof(prefix));
    for (size_t i = 0; i < sizeof(nonce); ++i) {
        name[_countof(prefix) - 1 + 2*i] = hex[nonce[i] >> 4];
        name[_countof(prefix) + 2*i] = hex[nonce[i] & 15];
    }
    name[_countof(name) - 1] = 0;
    HANDLE server = CreateNamedPipeW(name, (send ? PIPE_ACCESS_OUTBOUND : PIPE_ACCESS_INBOUND) |
        FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
        1, BC_WORKER_PIPE_BUFFER_BYTES, BC_WORKER_PIPE_BUFFER_BYTES, 0, security);
    if (server == INVALID_HANDLE_VALUE) return GetLastError();
    *broker = server;
    HANDLE client = CreateFileW(name, send ? client_read : client_write, 0, NULL,
        OPEN_EXISTING, SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION, NULL);
    if (client == INVALID_HANDLE_VALUE) return GetLastError();
    *child = client;
    // CreateFile has already connected the instance. Authenticate both ends
    // without issuing a ConnectNamedPipe operation that could pend.
    ULONG client_pid = 0, server_pid = 0;
    const DWORD own_pid = GetCurrentProcessId();
    if (!GetNamedPipeClientProcessId(server, &client_pid) ||
        !GetNamedPipeServerProcessId(client, &server_pid))
        return GetLastError();
    if (client_pid != own_pid || server_pid != own_pid)
        return ERROR_ACCESS_DENIED;
    if (!SetHandleInformation(client, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT))
        return GetLastError();
    return ERROR_SUCCESS;
}

DWORD bc_worker_pipes_open(bc_worker_pipes *pipes) {
    if (!pipes) return ERROR_INVALID_PARAMETER;
    for (size_t i = 0; i < BC_WORKER_PIPE_COUNT; ++i)
        if (pipes->broker[i] || pipes->child[i]) return ERROR_INVALID_PARAMETER;
    SECURITY_DESCRIPTOR descriptor;
    union {
        ACL align;
        BYTE bytes[sizeof(ACL) + sizeof(ACCESS_ALLOWED_ACE) + SECURITY_MAX_SID_SIZE];
    } acl;
    DWORD status = pipe_security(&descriptor, &acl.align, sizeof(acl));
    if (status) return status;
    SECURITY_ATTRIBUTES security = {sizeof(security), &descriptor, FALSE};
    bc_worker_pipes pending = {0};
    const uint8_t empty_nonce[BC_WORKER_NONCE_BYTES] = {0};
    if (BCryptGenRandom(NULL, pending.nonce, sizeof(pending.nonce), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0 ||
        !memcmp(pending.nonce, empty_nonce, sizeof(empty_nonce))) return ERROR_GEN_FAILURE;
    for (size_t i = 0; i < BC_WORKER_PIPE_COUNT; ++i) {
        status = open_pair(&security, i == BC_WORKER_STDIN, &pending.broker[i], &pending.child[i]);
        if (status) {
            bc_worker_pipes_close(&pending);
            return status;
        }
    }
    *pipes = pending;
    return ERROR_SUCCESS;
}

void bc_worker_pipes_close_child(bc_worker_pipes *pipes) {
    for (size_t i = 0; i < BC_WORKER_PIPE_COUNT; ++i) close_endpoint(&pipes->child[i]);
}

void bc_worker_pipes_close(bc_worker_pipes *pipes) {
    bc_worker_pipes_close_child(pipes);
    for (size_t i = 0; i < BC_WORKER_PIPE_COUNT; ++i) close_endpoint(&pipes->broker[i]);
    memset(pipes->nonce, 0, sizeof(pipes->nonce));
}
