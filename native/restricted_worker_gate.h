#ifndef BC_RESTRICTED_WORKER_GATE_H
#define BC_RESTRICTED_WORKER_GATE_H

#include "restricted_worker_stream.h"

typedef enum bc_worker_gate_status {
    BC_WORKER_GATE_PENDING,
    BC_WORKER_GATE_DELIVERED,
    BC_WORKER_GATE_CANCELLED,
    BC_WORKER_GATE_EXPIRED,
    BC_WORKER_GATE_PROTOCOL,
    BC_WORKER_GATE_EXIT,
    BC_WORKER_GATE_IO
} bc_worker_gate_status;

typedef struct bc_worker_gate {
    const uint8_t *candidate;
    size_t length;
    uint64_t deadline;
    bc_worker_gate_status status;
    bool stdout_eof;
    bool exit_ok;
} bc_worker_gate;

/* Initialize after START. Serialize observations and sample a common
   monotonic clock before each call. A deadline tick is already expired.
   The caller keeps validated candidate storage immutable until take or
   failure, and owns it after take. */
void bc_worker_gate_begin(bc_worker_gate *gate, uint64_t deadline);

/* Validate the entire payload before allowing it to become a candidate. */
typedef bool (*bc_worker_result_validator)(const uint8_t *body, size_t length);
void bc_worker_gate_stage(bc_worker_gate *gate, const bc_worker_rx *rx,
    bc_worker_result_validator validate, uint64_t now);

/* Call once stdout is known to be finished or any trailing byte is seen.
   Report process exit only after an OS wait observed the process signal. */
void bc_worker_gate_stdout_end(bc_worker_gate *gate, bool clean_eof, uint64_t now);
void bc_worker_gate_exit(bc_worker_gate *gate, uint32_t code, uint64_t now);
void bc_worker_gate_io_error(bc_worker_gate *gate, uint64_t now);
void bc_worker_gate_cancel(bc_worker_gate *gate, uint64_t now);

/* Deliver once, only before the deadline and after both EOF and exit 0.
   Leave length untouched on pending or failure. */
const uint8_t *bc_worker_gate_take(bc_worker_gate *gate, size_t *length, uint64_t now);

#endif
