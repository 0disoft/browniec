#ifndef BC_HOST_ADAPTER_PROCESS_TYPES_H
#define BC_HOST_ADAPTER_PROCESS_TYPES_H

#include <stddef.h>
#include <stdint.h>

typedef struct bc_adapter_process bc_adapter_process;

enum {
    BC_ADAPTER_HEADER_BYTES = 64,
    BC_ADAPTER_BODY_LIMIT = 4096,
    BC_ADAPTER_PIPE_BUFFER_BYTES = 8192,
    BC_ADAPTER_PIPE_BUFFER_RESERVATION = 2 * 2 * BC_ADAPTER_PIPE_BUFFER_BYTES
};

/* Initialize the ceilings before use. All other fields start at zero.
   The host serializes all access, including across slots sharing a budget. */
typedef struct bc_adapter_budget {
    size_t live_limit, launch_limit, wire_limit;
    size_t live, launches, wire;
} bc_adapter_budget;

/* Bind the slot to its budget before use. Keep both and the associated
   Engine alive at stable addresses until close succeeds. */
typedef struct bc_adapter_slot {
    bc_adapter_process *process;
    const void *engine;
    uintptr_t generation;
    bc_adapter_budget *budget;
} bc_adapter_slot;

/* Peak requested heap bytes for a slot launch with this UTF-8 path.
   Includes the retained process owner and its temporary launch allocations.
   Zero means the path or Windows attribute list could not be sized. */
size_t bc_adapter_slot_heap_bytes(const uint8_t *path, size_t path_len);

#endif
