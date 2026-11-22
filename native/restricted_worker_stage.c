#define WIN32_LEAN_AND_MEAN
#include "restricted_worker_stage.h"
#include <aclapi.h>
#include <bcrypt.h>
#include <userenv.h>
#include <wchar.h>

static DWORD create_profile(bc_worker_stage *stage) {
    static const wchar_t prefix[] = L"Rodisoft.BrownieC.Run.";
    static const wchar_t hex[] = L"0123456789abcdef";
    BYTE random[16];
    if (BCryptGenRandom(NULL, random, sizeof(random), BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0)
        return ERROR_GEN_FAILURE;
    wmemcpy(stage->name, prefix, _countof(prefix) - 1);
    size_t next = _countof(prefix) - 1;
    for (size_t i = 0; i < sizeof(random); ++i) {
        stage->name[next++] = hex[random[i] >> 4];
        stage->name[next++] = hex[random[i] & 15];
    }
    stage->name[next] = 0;
    PSID profile = NULL;
    const HRESULT status = CreateAppContainerProfile(stage->name, L"Brownie C worker",
        L"Brownie C restricted execution", NULL, 0, &profile);
    if (FAILED(status)) return (DWORD)status;
    stage->profile = profile;
    return ERROR_SUCCESS;
}

static DWORD stopped(bc_worker_stage_stop stop, void *context) {
    return stop ? stop(context) : ERROR_SUCCESS;
}

static DWORD copy_worker_image(HANDLE input, HANDLE output, bc_worker_stage_stop stop, void *context) {
    enum { image_limit = 64 * 1024 * 1024, copy_window = 16 * 1024 };
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(input, &info)) return GetLastError();
    if (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))
        return ERROR_INVALID_DATA;
    if (info.nFileSizeHigh || !info.nFileSizeLow || info.nFileSizeLow > image_limit)
        return ERROR_FILE_TOO_LARGE;

    BYTE window[copy_window];
    DWORD remaining = info.nFileSizeLow;
    while (remaining) {
        DWORD status = stopped(stop, context);
        if (status) return status;
        DWORD read = 0, written = 0;
        const DWORD request = remaining < copy_window ? remaining : copy_window;
        if (!ReadFile(input, window, request, &read, NULL)) return GetLastError();
        if (!read) return ERROR_HANDLE_EOF;
        status = stopped(stop, context);
        if (status) return status;
        if (!WriteFile(output, window, read, &written, NULL)) return GetLastError();
        if (written != read) return ERROR_WRITE_FAULT;
        remaining -= read;
    }
    return ERROR_SUCCESS;
}

static DWORD stage_image(bc_worker_stage *stage, HANDLE input, PSID user,
    bc_worker_stage_stop stop, void *context) {
    union {
        ACL acl;
        BYTE bytes[sizeof(ACL) + 3 * (sizeof(ACCESS_ALLOWED_ACE) + SECURITY_MAX_SID_SIZE)];
    } access;
    BYTE system[SECURITY_MAX_SID_SIZE];
    DWORD system_size = sizeof(system);
    SECURITY_DESCRIPTOR descriptor;
    if (!CreateWellKnownSid(WinLocalSystemSid, NULL, system, &system_size) ||
        !InitializeAcl(&access.acl, sizeof(access), ACL_REVISION) ||
        !AddAccessAllowedAce(&access.acl, ACL_REVISION, FILE_ALL_ACCESS, user) ||
        !AddAccessAllowedAce(&access.acl, ACL_REVISION, FILE_ALL_ACCESS, system) ||
        !AddAccessAllowedAce(&access.acl, ACL_REVISION,
            FILE_GENERIC_READ | FILE_GENERIC_EXECUTE, stage->profile) ||
        !InitializeSecurityDescriptor(&descriptor, SECURITY_DESCRIPTOR_REVISION) ||
        !SetSecurityDescriptorDacl(&descriptor, TRUE, &access.acl, FALSE) ||
        !SetSecurityDescriptorControl(&descriptor, SE_DACL_PROTECTED, SE_DACL_PROTECTED))
        return GetLastError();
    DWORD status = stopped(stop, context);
    if (status) return status;
    SECURITY_ATTRIBUTES security = {sizeof(security), &descriptor, FALSE};
    if (!CreateDirectoryW(stage->directory, &security)) return GetLastError();
    stage->owns_directory = TRUE;
    HANDLE output = CreateFileW(stage->image, GENERIC_WRITE, 0, &security,
        CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (output == INVALID_HANDLE_VALUE) return GetLastError();
    stage->owns_image = TRUE;
    status = copy_worker_image(input, output, stop, context);
    if (!CloseHandle(output) && !status) status = GetLastError();
    if (!status) status = stopped(stop, context);
    if (status) return status;
    HANDLE pin = CreateFileW(stage->image, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (pin == INVALID_HANDLE_VALUE) return GetLastError();
    stage->pinned_image = pin;
    return stopped(stop, context);
}

DWORD bc_worker_stage_open(bc_worker_stage *stage, const wchar_t *application,
    bc_worker_stage_stop stop, void *context) {
    if (!stage || stage->profile || stage->owns_directory || !application)
        return ERROR_INVALID_PARAMETER;
    DWORD status = stopped(stop, context);
    if (status) return status;
    const DWORD capacity = _countof(stage->directory);
    const DWORD root = GetTempPathW(capacity, stage->directory);
    if (!root || root >= capacity) return ERROR_BAD_PATHNAME;
    if (root < 3 || stage->directory[1] != L':' || stage->directory[2] != L'\\' ||
        stage->directory[root - 1] != L'\\') return ERROR_BAD_PATHNAME;

    HANDLE input = CreateFileW(application, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (input == INVALID_HANDLE_VALUE) return GetLastError();
    HANDLE token = NULL;
    union {
        TOKEN_USER info;
        BYTE bytes[sizeof(TOKEN_USER) + SECURITY_MAX_SID_SIZE];
    } user = {0};
    DWORD used = 0;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token) ||
        !GetTokenInformation(token, TokenUser, &user, sizeof(user), &used))
        status = GetLastError();
    if (token) CloseHandle(token);
    if (!status) status = stopped(stop, context);
    if (!status) status = create_profile(stage);
    static const wchar_t leaf[] = L"\\browniec.exe";
    if (!status) {
        const size_t name_length = wcslen(stage->name);
        if (root + name_length + _countof(leaf) > capacity) status = ERROR_BAD_PATHNAME;
        else {
            wmemcpy(stage->directory + root, stage->name, name_length + 1);
            wmemcpy(stage->image, stage->directory, root + name_length);
            wmemcpy(stage->image + root + name_length, leaf, _countof(leaf));
        }
    }
    if (!status) status = stage_image(stage, input, user.info.User.Sid, stop, context);
    CloseHandle(input);
    return status;
}

BOOL bc_worker_stage_close(bc_worker_stage *stage) {
    if (stage->pinned_image && CloseHandle(stage->pinned_image)) stage->pinned_image = NULL;
    if (stage->owns_image && !stage->pinned_image && DeleteFileW(stage->image))
        stage->owns_image = FALSE;
    if (stage->owns_directory && !stage->owns_image && RemoveDirectoryW(stage->directory))
        stage->owns_directory = FALSE;
    if (stage->profile && SUCCEEDED(DeleteAppContainerProfile(stage->name))) {
        FreeSid(stage->profile);
        stage->profile = NULL;
    }
    return !stage->owns_directory && !stage->profile;
}
