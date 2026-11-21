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
    BC_WORKER_BROKER_CANCEL_START,
    BC_WORKER_BROKER_SEND_CANCEL,
    BC_WORKER_BROKER_DRAIN_RESULT,
    BC_WORKER_BROKER_DRAIN_EOF,
    BC_WORKER_BROKER_DRAIN_EXIT,
    BC_WORKER_BROKER_REAPING
} bc_worker_broker_phase;

typedef struct bc_worker_broker_amounts {
    size_t sessions;
    size_t parent_bytes;
    size_t child_commit_bytes;
    size_t wire_bytes;
} bc_worker_broker_amounts;

/* Initialize the limits and zero the reservations. The owner serializes
   all sessions using this budget and keeps it alive through their close. */
typedef struct bc_worker_broker_budget {
    bc_worker_broker_amounts limit;
    bc_worker_broker_amounts reserved;
} bc_worker_broker_budget;

typedef struct bc_worker_broker {
    bc_restricted_worker worker;
    bc_worker_pipes pipes;
    bc_worker_io io;
    bc_worker_io cancel_io;
    bc_worker_gate gate;
    bc_worker_rx rx;
    bc_worker_tx tx;
    bc_worker_broker_budget *budget;
    bc_worker_broker_amounts charge;
    const uint8_t *request;
    uint8_t *result;
    bc_worker_result_validator validate;
    size_t request_length, result_capacity;
    uint64_t phase_deadline, idle_ticks, grace_ticks, shutdown_deadline;
    uint8_t trailing;
    bc_worker_broker_phase phase;
} bc_worker_broker;

typedef struct bc_worker_broker_run {
    bc_worker_broker_budget *budget;
    const wchar_t *application;
    wchar_t *command_line;
    const wchar_t *directory;
    PSID profile;
    SIZE_T commit_bytes;
    DWORD cpu_ms;
    DWORD startup_ms, io_idle_ms, shutdown_grace_ms;
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
   valid through close. Admission reserves a session, its control and span
   bytes, Job commit ceiling and wire envelope against the shared budget.
   The absolute session deadline uses QueryInterruptTimePrecise ticks.
   Startup covers launch through READY; after READY each completed transfer
   renews the idle window within the session deadline.
   Call close even on start failure, until it reports the owner released. */
DWORD bc_worker_broker_start(bc_worker_broker *broker, const bc_worker_broker_run *run);

/* One nonblocking I/O submission, poll, or process observation per call. */
bc_worker_gate_status bc_worker_broker_step(bc_worker_broker *broker);
const uint8_t *bc_worker_broker_take(bc_worker_broker *broker, size_t *length);

/* Freeze the terminal outcome, then advance graceful shutdown or reaping.
   Partially sent START finishes before CANCEL. After the grace deadline the
   Job is stopped. A false return retains buffers and both I/O leases. */
bool bc_worker_broker_close(bc_worker_broker *broker);

#endif
