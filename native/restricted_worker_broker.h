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
    BC_WORKER_BROKER_WAIT_HOST,
    BC_WORKER_BROKER_REAP_HOST,
    BC_WORKER_BROKER_SEND_HOST_REPLY,
    BC_WORKER_BROKER_READ_EOF,
    BC_WORKER_BROKER_WAIT_EXIT,
    BC_WORKER_BROKER_FINISH,
    BC_WORKER_BROKER_CANCEL_TX,
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
    size_t adapter_slots;
    size_t io_slots;
    size_t pipe_buffer_bytes;
    size_t host_request_bytes;
    size_t host_reply_bytes;
    size_t handle_slots;
} bc_worker_broker_amounts;

/* The ordinary transfer and the graceful cancellation write each own a slot. */
enum {
    BC_WORKER_BROKER_IO_SLOTS = 2,
    /* Events, both ends of each pipe, then Job, process, thread and token. */
    BC_WORKER_BROKER_HANDLE_SLOTS = BC_WORKER_BROKER_IO_SLOTS + 2 * BC_WORKER_PIPE_COUNT + 4
};

/* Initialize the limits and zero the reservations. The owner serializes
   all sessions using this budget and keeps it alive through their close. */
typedef struct bc_worker_broker_budget {
    bc_worker_broker_amounts limit;
    bc_worker_broker_amounts reserved;
} bc_worker_broker_budget;

/* A synchronous, bounded policy callback. Return zero to reject the request.
   The spans stay disjoint and live through session close. */
typedef size_t (*bc_worker_host_reply)(void *context, uint64_t correlation,
    const uint8_t *request, size_t length, uint8_t *reply, size_t capacity);

typedef struct bc_worker_broker_host {
    bc_worker_host_reply respond;
    void *context;
    /* Supply two disjoint spans, or leave both NULL for broker-owned staging. */
    uint8_t *request, *reply;
    size_t request_capacity, reply_capacity;
    uint32_t max_calls;
} bc_worker_broker_host;

typedef enum bc_worker_host_progress {
    BC_WORKER_HOST_PENDING,
    BC_WORKER_HOST_READY,
    BC_WORKER_HOST_REJECTED
} bc_worker_host_progress;

/* Trusted, bounded callbacks. Begin is called once per complete request and
   may borrow it until close succeeds. Poll writes a reply only on READY.
   Close stops pending work and collects its resources, including after a
   failed begin. The host context must stay live until broker close succeeds. */
typedef struct bc_worker_host_adapter {
    bool (*begin)(void *context, uint64_t correlation, const uint8_t *request,
        size_t length, uint64_t deadline);
    bc_worker_host_progress (*poll)(void *context, uint8_t *reply, size_t capacity, size_t *length);
    bool (*close)(void *context);
    /* Maximum simultaneous overlapped I/O owners, including startup and reaping. */
    uint32_t io_slots;
    /* Sum of buffer sizes requested for all pipes in one adapter slot. */
    uint32_t pipe_buffer_bytes;
    /* OS-enforced commit ceiling for the child Job owned by one slot. */
    size_t child_commit_bytes;
    /* Peak parent handles owned by this route, including temporary launch handles. */
    uint32_t handle_slots;
} bc_worker_host_adapter;

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
    const void *expectation;
    size_t request_length, result_capacity;
    bc_worker_broker_host host;
    uint8_t *host_staging;
    const bc_worker_host_adapter *adapter;
    size_t host_reply_length;
    uint32_t requests, replies;
    bool cancel_reply, adapter_active;
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
    size_t adapter_wire_bytes;
    size_t adapter_parent_bytes;
    const uint8_t *request;
    size_t request_length;
    uint8_t *result;
    size_t result_capacity;
    bc_worker_result_validator validate;
    const void *expectation;
    bc_worker_broker_host host;
    const bc_worker_host_adapter *adapter;
} bc_worker_broker_run;

/* One START/RESULT session with optional sequential host exchanges. Serialize calls and start from a zeroed owner
   at a stable address. Request and result spans must be disjoint and remain
   valid through close, along with the immutable validator expectation.
   Admission reserves a session, its control and span
   bytes, combined worker and adapter Job commit and wire envelopes against
   the shared budget.
   A deferred route also reserves one adapter slot before launch. The slot
   stays reserved across sequential requests and through final cleanup.
   Each I/O slot covers one event and its outstanding overlapped operation.
   Pipe buffer reservations account for requested Win32 buffer sizes.
   Parent handle reservations include worker and adapter launch peaks and
   stay held until both owners have been reaped.
   The host payload allowances are reserved by direction for all allowed calls.
   The trusted route supplies its additional process transport envelope in
   adapter_wire_bytes. It shares the session wire limit and release condition.
   adapter_parent_bytes covers route storage and peak launch heap until close.
   The absolute session deadline uses QueryInterruptTimePrecise ticks.
   Startup covers launch through READY; after READY each completed transfer
   renews the idle window within the session deadline.
   Call close even on start failure, until it reports the owner released. */
DWORD bc_worker_broker_start(bc_worker_broker *broker, const bc_worker_broker_run *run);

/* One nonblocking I/O or adapter advance, or process observation per call. */
bc_worker_gate_status bc_worker_broker_step(bc_worker_broker *broker);
const uint8_t *bc_worker_broker_take(bc_worker_broker *broker, size_t *length);

/* Resolve cancellation and expiry against one clock sample. Close still
   owns transport shutdown and releases the session after reaping. */
bc_worker_gate_status bc_worker_broker_cancel(bc_worker_broker *broker);

/* Freeze the terminal outcome, then advance graceful shutdown or reaping.
   Partially sent START or HOST_REPLY finishes before CANCEL. After the grace deadline the
   Job is stopped. A false return retains the reservations until worker,
   pipe I/O and adapter cleanup are all complete. */
bool bc_worker_broker_close(bc_worker_broker *broker);

#endif
