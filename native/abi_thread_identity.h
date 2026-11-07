#ifndef BC_ABI_THREAD_IDENTITY_H
#define BC_ABI_THREAD_IDENTITY_H
#include <stdint.h>

/* Internal Windows coordinator primitive, not a DLL export or public C ABI.
   A successful enter owns the process-local guard until matching leave. Keep
   the protected interval bounded; no callbacks, guest execution or host I/O.
   Every failure leaves caller output unchanged. Never unload the module while
   calls or handles are live. Identity values are not native object pointers. */
typedef struct bc_abi_thread_identity {
    uint64_t thread;
    uint64_t lifetime;
} bc_abi_thread_identity;
uint32_t bc_abi_guard_enter(bc_abi_thread_identity *identity);
uint32_t bc_abi_guard_leave(bc_abi_thread_identity identity);

#ifdef BC_ABI_IDENTITY_TEST
/* Unit-test build only; cannot reset any existing identity or production state. */
uint32_t bc_abi_test_exhaust_next(bc_abi_thread_identity owner);
#endif
#endif
