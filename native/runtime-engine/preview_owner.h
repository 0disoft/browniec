#ifndef BC_PREVIEW_OWNER_H
#define BC_PREVIEW_OWNER_H

#include "brownie_preview.h"
#include "abi_registry.h"

#define BC_OWNER_PROTOCOL 1u
#define BC_OWNER_EXPORT "bc_private_preview_process_owner"

typedef struct bc_preview_dispatch {
#define BC_ROUTE(name, params, args, failure) uint32_t (BC_CALL *name) params;
#include "preview_api.inc"
#undef BC_ROUTE
    uint32_t (*inspect_registry)(bc_abi_registry_info *);
} bc_preview_dispatch;

/* Stable discovery ABI. An inactive module returns BC_OK with NULL. An
   active module returns BC_ABI_MISMATCH for an unsupported protocol. */
typedef uint32_t (BC_CALL *bc_preview_owner_query)(uint32_t, const bc_preview_dispatch **);
#endif
