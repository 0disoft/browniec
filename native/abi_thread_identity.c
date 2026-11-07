/* OS synchronization and thread-lifetime identity only; registry logic is Fairy. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include "abi_thread_identity.h"

static SRWLOCK registry_guard = SRWLOCK_INIT;
static DWORD identity_tls = TLS_OUT_OF_INDEXES;
static uint64_t next_lifetime = 1;
static volatile LONG owner_thread;
static volatile LONG64 owner_lifetime;

uint32_t bc_abi_guard_enter(bc_abi_thread_identity *identity) {
    bc_abi_thread_identity candidate;
    ULONG_PTR stored;
    if (identity == NULL) { return 1; }
    if (!TryAcquireSRWLockExclusive(&registry_guard)) { return 3; }
    if (identity_tls == TLS_OUT_OF_INDEXES) {
        identity_tls = TlsAlloc();
        if (identity_tls == TLS_OUT_OF_INDEXES) {
            ReleaseSRWLockExclusive(&registry_guard); return 6;
        }
    }
    stored = (ULONG_PTR)TlsGetValue(identity_tls);
    if (stored == 0) {
        uint64_t ticket = next_lifetime;
        if (ticket == 0) { ReleaseSRWLockExclusive(&registry_guard); return 8; }
        /* Consume before the fallible TLS write: no ticket is ever reissued. */
        next_lifetime = ticket == UINT64_MAX ? 0 : ticket + 1;
        if (!TlsSetValue(identity_tls, (LPVOID)(ULONG_PTR)ticket)) {
            ReleaseSRWLockExclusive(&registry_guard); return 6;
        }
        stored = (ULONG_PTR)ticket;
    }
    candidate.thread = (uint64_t)GetCurrentThreadId();
    candidate.lifetime = (uint64_t)stored;
    InterlockedExchange64(&owner_lifetime, (LONG64)candidate.lifetime);
    InterlockedExchange(&owner_thread, (LONG)candidate.thread);
    *identity = candidate;
    return 0;
}

uint32_t bc_abi_guard_leave(bc_abi_thread_identity identity) {
    DWORD current = GetCurrentThreadId();
    if (identity.thread != (uint64_t)current) { return 10; }
    if (identity.lifetime == 0 ||
        (DWORD)InterlockedCompareExchange(&owner_thread, 0, 0) != current ||
        (uint64_t)InterlockedCompareExchange64(&owner_lifetime, 0, 0) != identity.lifetime) {
        return 7;
    }
    InterlockedExchange(&owner_thread, 0);
    InterlockedExchange64(&owner_lifetime, 0);
    ReleaseSRWLockExclusive(&registry_guard);
    return 0;
}

#ifdef BC_ABI_IDENTITY_TEST
uint32_t bc_abi_test_exhaust_next(bc_abi_thread_identity owner) {
    if (owner.thread != (uint64_t)GetCurrentThreadId() || owner.lifetime == 0 ||
        (DWORD)InterlockedCompareExchange(&owner_thread, 0, 0) != (DWORD)owner.thread ||
        (uint64_t)InterlockedCompareExchange64(&owner_lifetime, 0, 0) != owner.lifetime) {
        return 7;
    }
    next_lifetime = UINT64_MAX;
    return 0;
}
#endif
