#ifndef BC_HOST_ADAPTER_PROCESS_H
#define BC_HOST_ADAPTER_PROCESS_H

#include <stddef.h>
#include <stdint.h>

typedef struct bc_adapter_process bc_adapter_process;

enum {
    BC_ADAPTER_HEADER_BYTES = 64,
    BC_ADAPTER_BODY_LIMIT = 4096
};

typedef enum bc_adapter_state {
    BC_ADAPTER_PENDING = 0,
    BC_ADAPTER_HEADER,
    BC_ADAPTER_READY,
    BC_ADAPTER_CANCELLED,
    BC_ADAPTER_DEADLINE,
    BC_ADAPTER_FAILED
} bc_adapter_state;

/* A trusted host selects an absolute drive path. The Windows adapter runs
   with host authority. It inherits only the private pipes and a NUL stderr.
   Deadline is absolute QueryInterruptTimePrecise ticks (100 ns), as in the
   Engine. All calls are serialized.
   Start copies the request before returning and never retries a launch. */
bc_adapter_process *bc_adapter_process_start(const wchar_t *path, size_t path_len,
    const uint8_t *header, const uint8_t *body, size_t body_len, uint64_t deadline);
bc_adapter_state bc_adapter_process_step(bc_adapter_process *session);
/* In HEADER, only the 64-byte header is visible. In READY, frame() returns
   the entire response after exact EOF and child exit 0. The span is borrowed
   until the next mutating call. A valid frame still needs typed validation. */
const uint8_t *bc_adapter_process_frame(const bc_adapter_process *session, size_t *length);
/* The host must validate correlation and limits before approving a body. */
int bc_adapter_process_accept_body(bc_adapter_process *session, size_t length);
void bc_adapter_process_cancel(bc_adapter_process *session);
/* Attempts teardown. Zero retains the owner and all pending I/O storage.
   Poll close again until one indicates completed cleanup and frees owner. */
int bc_adapter_process_close(bc_adapter_process *session);

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

/* Includes two headers and the trailing-byte probe. Admission is read-only. */
uint32_t bc_adapter_slot_admits(const void *owner, size_t request_length, size_t reply_limit);
void *bc_adapter_slot_process(const void *owner, const void *engine, uintptr_t generation);
uintptr_t bc_adapter_slot_start(void *owner, const void *engine, const uint8_t *path,
    size_t path_len, const uint8_t *header, const uint8_t *body, size_t body_len,
    size_t reply_limit, uintptr_t deadline);
uint32_t bc_adapter_slot_close(void *owner);

#endif
