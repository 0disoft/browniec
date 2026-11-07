#ifndef BC_ABI_REGISTRY_H
#define BC_ABI_REGISTRY_H
#include <stdint.h>

/* Internal Windows x64 module singleton; no public E01 exports/lifecycle.
   Trusted native callers supply valid storage. Failed calls leave all output
   bytes untouched. object IDs are opaque integers, NEVER followed as pointers.
   No callbacks, VM work or I/O run inside the OS guard. Busy is nonblocking.
   Link exactly one coordinator + identity helper into the owning module.
   All handles/admissions must be gone before module unload; never reset state. */
typedef struct bc_abi_registry_admission {
    uint64_t target, engine, epoch;
    uint32_t kind, reserved; /* reserved must be zero; successful outputs zero it */
    uint64_t object;
} bc_abi_registry_admission;
typedef struct bc_abi_registry_info {
    uint64_t capacity, table_bytes, committed_bytes, allocation_count;
} bc_abi_registry_info;

/* OS thread ID/lifetime are obtained internally; never accepted from callers. */
uint32_t bc_abi_registry_create_engine(uint64_t object, uint64_t *out_handle);
uint32_t bc_abi_registry_enter(uint64_t target, uint32_t kind, uint64_t engine,
    bc_abi_registry_admission *out_admission);
uint32_t bc_abi_registry_enter_instance(uint64_t instance,
    bc_abi_registry_admission *out_admission);
/* Input receipt is trusted internal metadata; do not forge/copy into new calls.
   It remains active across insert (including failures) until leave/remove.
   Stale copies are rejected by the compiled kernel's live epoch checks. */
uint32_t bc_abi_registry_insert(const bc_abi_registry_admission *admission,
    uint32_t kind, uint64_t object, uint64_t *out_handle);
uint32_t bc_abi_registry_leave(const bc_abi_registry_admission *admission);
/* Registry invalidation only. The coordinator caller owns native cleanup/pins.
   Successful remove consumes admission and returns the removed opaque object ID. */
uint32_t bc_abi_registry_remove(const bc_abi_registry_admission *admission,
    uint64_t *out_object);
/* Read-only allocation facts, not slot contents or native addresses. */
uint32_t bc_abi_registry_inspect(bc_abi_registry_info *out_info);
#endif
