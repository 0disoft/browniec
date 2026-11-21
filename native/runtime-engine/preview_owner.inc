/* All public lifecycle calls enter the elected image before touching native
   objects. Only that image uses its Fairy runtime, registry, and TLS. */
#include <tlhelp32.h>
#include <stdlib.h>
#include <wchar.h>
#include "preview_owner.h"

static const bc_preview_dispatch local_dispatch = {
#define BC_ROUTE(name, params, args, failure) .name = owner_##name,
#include "preview_api.inc"
#undef BC_ROUTE
    .inspect_registry = bc_abi_registry_inspect,
};
static volatile LONG is_process_owner;
static INIT_ONCE owner_once = INIT_ONCE_STATIC_INIT;

__declspec(dllexport) uint32_t BC_CALL bc_private_preview_process_owner(
    uint32_t protocol, const bc_preview_dispatch **out) {
    *out = NULL;
    if (!InterlockedCompareExchange(&is_process_owner, 0, 0)) { return BC_OK; }
    if (protocol != BC_OWNER_PROTOCOL) { return BC_ABI_MISMATCH; }
    *out = &local_dispatch;
    return BC_OK;
}

static uint32_t find_process_owner(const bc_preview_dispatch **out) {
    HANDLE snapshot = INVALID_HANDLE_VALUE;
    for (unsigned attempt = 0; attempt < 4; ++attempt) {
        snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, 0);
        if (snapshot != INVALID_HANDLE_VALUE || GetLastError() != ERROR_BAD_LENGTH) { break; }
    }
    if (snapshot == INVALID_HANDLE_VALUE) { return BC_INTERNAL_ERROR; }

    MODULEENTRY32W entry = { .dwSize = sizeof(entry) };
    uint32_t status = BC_OK;
    BOOL found = Module32FirstW(snapshot, &entry);
    for (; found; found = Module32NextW(snapshot, &entry)) {
        HMODULE module;
        /* A snapshot entry may have been unloaded. Take a real reference
           before inspecting its exports. An elected module is pinned. */
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                                (LPCWSTR)entry.modBaseAddr, &module)) { continue; }
        bc_preview_owner_query query = (bc_preview_owner_query)GetProcAddress(module, BC_OWNER_EXPORT);
        if (query) { status = query(BC_OWNER_PROTOCOL, out); }
        FreeLibrary(module);
        if (status != BC_OK || *out) { break; }
    }
    if (!found && GetLastError() != ERROR_NO_MORE_FILES) { status = BC_INTERNAL_ERROR; }
    CloseHandle(snapshot);
    return status;
}

static uint32_t elect_process_owner(const bc_preview_dispatch **out) {
    /* Only the lock is named. Owner addresses are discovered inside this
       process and never read from named memory or inherited environment. */
    FILETIME creation, exit, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user)) {
        return BC_INTERNAL_ERROR;
    }
    wchar_t name[96];
    if (swprintf_s(name, _countof(name), L"Local\\BrownieC.PreviewOwner.%08lx.%08lx%08lx",
                   GetCurrentProcessId(), creation.dwHighDateTime, creation.dwLowDateTime) < 0) {
        return BC_INTERNAL_ERROR;
    }
    HANDLE election = CreateMutexW(NULL, FALSE, name);
    if (!election) { return BC_INTERNAL_ERROR; }
    DWORD wait = WaitForSingleObject(election, 5000);
    uint32_t status = wait == WAIT_TIMEOUT ? BC_BUSY : BC_INTERNAL_ERROR;
    if (wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED) {
        status = find_process_owner(out);
        if (status == BC_OK && !*out) {
            HMODULE pinned;
            if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                                   (LPCWSTR)&is_process_owner, &pinned)) {
                InterlockedExchange(&is_process_owner, 1);
                *out = &local_dispatch;
            } else { status = BC_INTERNAL_ERROR; }
        }
        ReleaseMutex(election);
    }
    CloseHandle(election);
    return status;
}

static BOOL CALLBACK resolve_owner(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    (void)once;
    uint32_t *status = parameter;
    const bc_preview_dispatch *owner = NULL;
    *status = elect_process_owner(&owner);
    if (*status != BC_OK) { return FALSE; }
    *context = (PVOID)owner;
    return TRUE;
}

static uint32_t get_process_owner(const bc_preview_dispatch **out) {
    PVOID context;
    uint32_t status = BC_INTERNAL_ERROR;
    if (!InitOnceExecuteOnce(&owner_once, resolve_owner, &status, &context)) { return status; }
    *out = context;
    return BC_OK;
}

static void clear_handle(bc_handle *out) {
    if (out) { *out = 0; }
}

#define BC_ROUTE(name, params, args, failure) \
    uint32_t BC_CALL name params { \
        const bc_preview_dispatch *owner; \
        uint32_t status = get_process_owner(&owner); \
        if (status != BC_OK) { failure; return status; } \
        return owner->name args; \
    }
#include "preview_api.inc"
#undef BC_ROUTE
