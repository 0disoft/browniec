/* Only OS singleton allocation/locking and private transport marshalling.
   ALL registry/admission/generation/kind/Engine decisions are compiled Fairy.
   tools/abi-registry/transport.json and the builder freeze the full transport. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <string.h>
#include "abi_registry.h"
#include "abi_thread_identity.h"

#define main bc_registry_unused_retention_main
#include "abi_registry_generated.c"
#undef main

_Static_assert(sizeof(uintptr_t) == 8, "x64 transport only");
_Static_assert(sizeof(fy_struct_3) == 3608, "reviewed kernel table");
_Static_assert(sizeof(fy_struct_2) == 56, "reviewed slot");
_Static_assert(sizeof(bc_abi_registry_admission) == 40, "internal admission");
_Static_assert(offsetof(bc_abi_registry_admission, object) == 32, "object offset");
_Static_assert(sizeof(fy_struct_3) <= 4096, "bounded one-page metadata");

/* Accessed only while the single helper's guard is owned. Allocation and every
   generation tombstone persist for module lifetime, even with zero live handles.
   No production/test reset, generation injection or table accessor exists. */
static fy_struct_3 *registry;
// This bounded trap context is also guard-protected; no extra per-thread TLS.
static bc_abi_thread_identity held_identity;
static int guard_held;

/* Impossible kernel traps terminate rather than inventing successful recovery.
   Release our OS guard first when healthy enough to do so. No pointer walking. */
static _Noreturn void registry_fail_fast(void) {
    if (guard_held) {
        bc_abi_thread_identity identity = held_identity;
        guard_held = 0; /* Last context write BEFORE releasing the guard. */
        (void)bc_abi_guard_leave(identity);
    }
    RaiseFailFastException(NULL, NULL, 0);
    ExitProcess(7);
}
_Noreturn void fy_runtime_trap(uint32_t category) {
    (void)category; registry_fail_fast();
}
_Noreturn void fy_runtime_trap_at_v0(uint32_t category, const char *source,
    uint32_t length, uint64_t start, uint64_t end) {
    (void)category; (void)source; (void)length; (void)start; (void)end;
    registry_fail_fast();
}
static uint32_t begin(bc_abi_thread_identity *identity) {
    uint32_t status = bc_abi_guard_enter(identity);
    if (status == 0) { held_identity = *identity; guard_held = 1; }
    return status;
}
/* The sole normal post-acquisition exit. Never leave an OS guard held simply
   because a Fairy result is an error. Engine busy is NOT released here. */
static uint32_t finish(bc_abi_thread_identity identity, uint32_t status) {
    /* Never touch shared context after release: another thread may enter. */
    guard_held = 0;
    if (bc_abi_guard_leave(identity) != 0) { ExitProcess(7); }
    return status;
}
static fy_struct_1 caller(bc_abi_thread_identity identity) {
    fy_struct_1 value = {0};
    value.f_0 = (uintptr_t)identity.thread;
    value.f_1 = (uintptr_t)identity.lifetime;
    return value;
}
static fy_struct_0 unpack(bc_abi_registry_admission a) {
    fy_struct_0 value = {0};
    value.f_0 = (uintptr_t)a.target; value.f_1 = (uintptr_t)a.engine;
    value.f_2 = (uintptr_t)a.epoch; value.f_3 = a.kind;
    value.f_4 = (uintptr_t)a.object;
    return value;
}
static bc_abi_registry_admission pack(fy_struct_0 value) {
    bc_abi_registry_admission a = {0};
    a.target = value.f_0; a.engine = value.f_1; a.epoch = value.f_2;
    a.kind = value.f_3; a.object = value.f_4;
    return a;
}
static uint32_t word_status(fy_tagged_1 result) {
    if (result.tag == FY_RESULT_OK) { return 0; }
    if (result.tag != FY_RESULT_ERR) { registry_fail_fast(); }
    return fy_fn_19(result.p_1);
}
static uint32_t admission_status(fy_tagged_0 result) {
    if (result.tag == FY_RESULT_OK) { return 0; }
    if (result.tag != FY_RESULT_ERR) { registry_fail_fast(); }
    return fy_fn_19(result.p_1);
}
uint32_t bc_abi_registry_create_engine(uint64_t object, uint64_t *out_handle) {
    bc_abi_thread_identity identity; fy_tagged_1 result;
    uint32_t status; uint64_t candidate;
    if (out_handle == NULL) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) {
        fy_struct_3 *allocated = VirtualAlloc(NULL, 4096, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
        if (allocated == NULL) { return finish(identity, 6); }
        *allocated = fy_fn_3(); /* one-time Fairy initialization */
        registry = allocated;
    }
    result = fy_fn_2(registry, caller(identity), (uintptr_t)object);
    status = word_status(result);
    candidate = status == 0 ? result.p_0 : 0;
    status = finish(identity, status);
    if (status == 0) { memcpy(out_handle, &candidate, sizeof(candidate)); }
    return status;
}
uint32_t bc_abi_registry_enter(uint64_t target, uint32_t kind, uint64_t engine,
    bc_abi_registry_admission *out_admission) {
    bc_abi_thread_identity identity; fy_tagged_0 result;
    bc_abi_registry_admission candidate = {0}; uint32_t status;
    if (out_admission == NULL) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) { return finish(identity, 2); }
    result = fy_fn_5(registry, (uintptr_t)target, kind, (uintptr_t)engine, caller(identity));
    status = admission_status(result);
    if (status == 0) { candidate = pack(result.p_0); }
    status = finish(identity, status);
    if (status == 0) { memcpy(out_admission, &candidate, sizeof(candidate)); }
    return status;
}
uint32_t bc_abi_registry_enter_instance(uint64_t instance, bc_abi_registry_admission *out_admission) {
    bc_abi_thread_identity identity; fy_tagged_0 result;
    bc_abi_registry_admission candidate = {0}; uint32_t status;
    if (out_admission == NULL) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) { return finish(identity, 2); }
    result = fy_fn_6(registry, (uintptr_t)instance, caller(identity));
    status = admission_status(result);
    if (status == 0) { candidate = pack(result.p_0); }
    status = finish(identity, status);
    if (status == 0) { memcpy(out_admission, &candidate, sizeof(candidate)); }
    return status;
}
uint32_t bc_abi_registry_insert(const bc_abi_registry_admission *admission,
    uint32_t kind, uint64_t object, uint64_t *out_handle) {
    bc_abi_thread_identity identity; bc_abi_registry_admission a;
    fy_tagged_1 result; uint32_t status; uint64_t candidate;
    if (admission == NULL || out_handle == NULL) { return 1; }
    memcpy(&a, admission, sizeof(a)); if (a.reserved != 0) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) { return finish(identity, 2); }
    result = fy_fn_10(registry, unpack(a), kind, (uintptr_t)object, caller(identity));
    status = word_status(result); candidate = status == 0 ? result.p_0 : 0;
    status = finish(identity, status);
    if (status == 0) { memcpy(out_handle, &candidate, sizeof(candidate)); }
    return status;
}
uint32_t bc_abi_registry_leave(const bc_abi_registry_admission *admission) {
    bc_abi_thread_identity identity; bc_abi_registry_admission a;
    fy_tagged_1 result; uint32_t status;
    if (admission == NULL) { return 1; }
    memcpy(&a, admission, sizeof(a)); if (a.reserved != 0) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) { return finish(identity, 2); }
    result = fy_fn_13(registry, unpack(a), caller(identity));
    return finish(identity, word_status(result));
}
uint32_t bc_abi_registry_remove(const bc_abi_registry_admission *admission, uint64_t *out_object) {
    bc_abi_thread_identity identity; bc_abi_registry_admission a;
    fy_tagged_1 result; uint32_t status; uint64_t candidate;
    if (admission == NULL || out_object == NULL) { return 1; }
    memcpy(&a, admission, sizeof(a)); if (a.reserved != 0) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    if (registry == NULL) { return finish(identity, 2); }
    result = fy_fn_17(registry, unpack(a), caller(identity));
    status = word_status(result); candidate = status == 0 ? result.p_0 : 0;
    status = finish(identity, status);
    if (status == 0) { memcpy(out_object, &candidate, sizeof(candidate)); }
    return status;
}
uint32_t bc_abi_registry_inspect(bc_abi_registry_info *out_info) {
    bc_abi_thread_identity identity; bc_abi_registry_info candidate = {0}; uint32_t status;
    if (out_info == NULL) { return 1; }
    status = begin(&identity); if (status != 0) { return status; }
    candidate.capacity = fy_fn_1(); candidate.table_bytes = sizeof(fy_struct_3);
    candidate.committed_bytes = registry == NULL ? 0 : 4096;
    candidate.allocation_count = registry == NULL ? 0 : 1;
    status = finish(identity, 0);
    if (status == 0) { memcpy(out_info, &candidate, sizeof(candidate)); }
    return status;
}
