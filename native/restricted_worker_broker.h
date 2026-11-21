#ifndef BC_RESTRICTED_WORKER_BROKER_H
#define BC_RESTRICTED_WORKER_BROKER_H

#include "restricted_worker.h"
#include "restricted_worker_gate.h"
#include "restricted_worker_io.h"
#include "restricted_worker_pipes.h"

typedef enum bc_worker_broker_phase {
    BC_WORKER_BROKER_IDLE,
    BC_WORKER_BROKER_SEND_HELLO,
    BC_WORKER_BROKER_READ_READY,
    BC_WORKER_BROKER_SEND_START,
    BC_WORKER_BROKER_READ_RESULT,
    BC_WORKER_BROKER_READ_EOF,
    BC_WORKER_BROKER_WAIT_EXIT,
    BC_WORKER_BROKER_FINISH,
    BC_WORKER_BROKER_REAPING
} bc_worker_broker_phase;

typedef struct bc_worker_broker {
    bc_restricted_worker worker;
    bc_worker_pipes pipes;
    bc_worker_io io;
    bc_worker_gate gate;
    bc_worker_rx rx;
    bc_worker_tx tx;
    const uint8_t *request;
    uint8_t *result;
    bc_worker_result_validator validate;
    size_t request_length, result_capacity;
    uint8_t trailing;
    bc_worker_broker_phase phase;
} bc_worker_broker;

typedef struct bc_worker_broker_run {
    const wchar_t *application;
    wchar_t *command_line;
    const wchar_t *directory;
    PSID profile;
    SIZE_T commit_bytes;
    DWORD cpu_ms;
    uint64_t deadline;
    size_t wire_limit;
    const uint8_t *request;
    size_t request_length;
    uint8_t *result;
    size_t result_capacity;
    bc_worker_result_validator validate;
} bc_worker_broker_run;

/* One request/RESULT session. Serialize calls and start from a zeroed owner
   at a stable address. Request and result spans must be disjoint and remain
   valid through close. The deadline uses QueryInterruptTimePrecise ticks.
   Call close even on start failure, until it reports the owner released. */
DWORD bc_worker_broker_start(bc_worker_broker *broker, const bc_worker_broker_run *run);

/* One nonblocking I/O submission, poll, or process observation per call. */
bc_worker_gate_status bc_worker_broker_step(bc_worker_broker *broker);
const uint8_t *bc_worker_broker_take(bc_worker_broker *broker, size_t *length);

/* Begin cancellation on an unfinished session. The first call stops the Job
   and requests I/O cancellation. A false return retains the owner. */
bool bc_worker_broker_close(bc_worker_broker *broker);

#endif
