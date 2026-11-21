#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "preview_owner.h"

#ifdef BC_INCOMPATIBLE_OWNER_FIXTURE
__declspec(dllexport) uint32_t BC_CALL bc_private_preview_process_owner(
    uint32_t protocol, const bc_preview_dispatch **out) {
    (void)protocol;
    *out = NULL;
    return BC_ABI_MISMATCH;
}
#else
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

typedef struct preview_module {
    HMODULE dll;
    bc_preview_owner_query query;
    bc_preview_dispatch call;
} preview_module;

static preview_module load(const wchar_t *name) {
    preview_module module = {0};
    module.dll = LoadLibraryW(name);
    assert(module.dll);
    FARPROC probe = GetProcAddress(module.dll, BC_OWNER_EXPORT);
    assert(probe);
    memcpy(&module.query, &probe, sizeof(probe));
#define BC_ROUTE(name, params, args, failure) do { \
    FARPROC symbol = GetProcAddress(module.dll, #name); \
    assert(symbol); \
    memcpy(&module.call.name, &symbol, sizeof(symbol)); \
} while (0);
#include "preview_api.inc"
#undef BC_ROUTE
    return module;
}

typedef struct first_call {
    HANDLE start;
    preview_module *module;
    preview_module *peer;
} first_call;

static DWORD WINAPI race_owner(void *state) {
    first_call *call = state;
    assert(WaitForSingleObject(call->start, 5000) == WAIT_OBJECT_0);
    bc_handle handle = 0;
    assert(call->module->call.bc_preview_engine_create(BC_PREVIEW_REVISION, &handle) == BC_OK);
    assert(call->peer->call.bc_preview_engine_destroy(handle) == BC_OK);
    return 0;
}

static void race_first_calls(preview_module modules[2]) {
    HANDLE start = CreateEventW(NULL, TRUE, FALSE, NULL);
    assert(start);
    first_call calls[] = {{start, &modules[0], &modules[1]}, {start, &modules[1], &modules[0]}};
    HANDLE threads[] = {CreateThread(NULL, 0, race_owner, &calls[0], 0, NULL),
                        CreateThread(NULL, 0, race_owner, &calls[1], 0, NULL)};
    assert(threads[0] && threads[1] && SetEvent(start));
    assert(WaitForMultipleObjects(2, threads, TRUE, 10000) == WAIT_OBJECT_0);
    assert(CloseHandle(threads[0]) && CloseHandle(threads[1]) && CloseHandle(start));
}

static void exercise_shared_registry(preview_module modules[2], const bc_preview_dispatch *owner) {
    bc_abi_registry_info info = {0};
    assert(owner->inspect_registry(&info) == BC_OK);
    assert(info.capacity == 65536 && info.table_bytes == 3670048);
    assert(info.committed_bytes == 4096 && info.allocation_count == 1);
    bc_handle engines[75];
    for (size_t i = 0; i < _countof(engines); ++i) {
        assert(modules[i % 2].call.bc_preview_engine_create(BC_PREVIEW_REVISION, &engines[i]) == BC_OK);
        for (size_t j = 0; j < i; ++j) { assert(engines[i] != engines[j]); }
    }
    assert(owner->inspect_registry(&info) == BC_OK);
    assert(info.committed_bytes == 8192 && info.allocation_count == 2);
    for (size_t i = 0; i < _countof(engines); ++i) {
        assert(modules[(i + 1) % 2].call.bc_preview_engine_destroy(engines[i]) == BC_OK);
    }
    assert(owner->inspect_registry(&info) == BC_OK);
    assert(info.committed_bytes == 8192 && info.allocation_count == 2);
}

static void exercise_live_program(preview_module *creator, preview_module *peer, bc_handle *stale) {
    const uint8_t source[] = "module main; pub fn i32 main(){return 77;}";
    bc_handle engine = 0, program = 0, instance = 0;
    assert(creator->call.bc_preview_engine_create(BC_PREVIEW_REVISION, &engine) == BC_OK);
    assert(peer->call.bc_preview_compile(engine, (bc_slice){source, sizeof(source) - 1}, &program) == BC_OK);
    assert(creator->call.bc_preview_instance_create(engine, program, 4000000, &instance) == BC_OK);
    assert(peer->call.bc_preview_program_release(engine, program) == BC_OK);
    bc_preview_event event = {.struct_size = sizeof(event)};
    do {
        assert(peer->call.bc_preview_step(instance, 64, &event) == BC_OK);
    } while (event.kind == BC_PREVIEW_YIELD);
    assert(event.kind == BC_PREVIEW_DONE && event.return_i32 == 77 && event.fuel_used > 0);
    assert(creator->call.bc_preview_instance_destroy(instance) == BC_OK);
    assert(peer->call.bc_preview_engine_destroy(engine) == BC_OK);
    *stale = engine;
}

int wmain(int argc, wchar_t **argv) {
    const wchar_t *paths[] = {L".\\brownie-preview.dll", L".\\brownie-preview-copy.dll"};
    if (argc == 2 && wcscmp(argv[1], L"incompatible") == 0) {
        HMODULE fixture = LoadLibraryW(L".\\incompatible-owner.dll");
        assert(fixture);
        preview_module candidate = load(paths[0]);
        bc_handle handle = UINT64_MAX;
        bc_diagnostic diagnostic = {.struct_size = sizeof(diagnostic)};
        assert(candidate.call.bc_engine_create(BC_ABI_REVISION, (bc_slice){0},
                                               &handle, &diagnostic) == BC_ABI_MISMATCH);
        assert(handle == 0);
        const bc_preview_dispatch *owner;
        assert(candidate.query(BC_OWNER_PROTOCOL, &owner) == BC_OK && !owner);
        assert(FreeLibrary(fixture));
        assert(candidate.call.bc_preview_engine_create(BC_PREVIEW_REVISION, &handle) == BC_OK);
        assert(candidate.call.bc_preview_engine_destroy(handle) == BC_OK);
        assert(FreeLibrary(candidate.dll));
        puts("PASS: incompatible owner refused and resolution retried without a second registry");
        return 0;
    }
    preview_module modules[] = {load(paths[0]), load(paths[1])};
    assert(modules[0].dll != modules[1].dll);
    race_first_calls(modules);
    const bc_preview_dispatch *dispatch[2];
    assert(modules[0].query(BC_OWNER_PROTOCOL, &dispatch[0]) == BC_OK);
    assert(modules[1].query(BC_OWNER_PROTOCOL, &dispatch[1]) == BC_OK);
    assert((dispatch[0] == NULL) != (dispatch[1] == NULL));
    size_t elected = dispatch[0] ? 0 : 1;
    size_t client = 1 - elected;
    exercise_shared_registry(modules, dispatch[elected]);

    bc_handle stale = 0;
    assert(FreeLibrary(modules[elected].dll));
    exercise_live_program(&modules[client], &modules[client], &stale);
    assert(FreeLibrary(modules[client].dll));
    modules[client] = load(paths[client]);
    modules[elected] = load(paths[elected]);
    bc_handle replaced = 0;
    assert(modules[client].call.bc_preview_engine_create(BC_PREVIEW_REVISION, &replaced) == BC_OK);
    assert(replaced != stale);
    assert(modules[elected].call.bc_preview_engine_destroy(stale) == BC_INVALID_HANDLE);
    assert(modules[elected].call.bc_preview_engine_destroy(replaced) == BC_OK);
    exercise_live_program(&modules[client], &modules[elected], &stale);
    exercise_live_program(&modules[elected], &modules[client], &stale);
    assert(FreeLibrary(modules[client].dll) && FreeLibrary(modules[elected].dll));
    puts("PASS: one pinned owner for simultaneous DLL copies, two shared registry pages, cross-DLL program lifecycle and stale handle rejection after reload");
    return 0;
}
#endif
