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
   Deadline is absolute GetTickCount64 milliseconds. All calls are serialized.
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

#endif
