#define WIN32_LEAN_AND_MEAN
#include "restricted_worker_broker.h"
#include <string.h>

#pragma comment(lib, "mincore.lib")

static uint64_t now_ticks(void) {
    ULONGLONG now;
    QueryInterruptTimePrecise(&now);
    return now;
}

static uint64_t bounded_deadline(uint64_t now, uint64_t duration, uint64_t session) {
    return now >= session || duration >= session - now ? session : now + duration;
}

static bool phase_live(bc_worker_broker *b, uint64_t now) {
    if (b->gate.status != BC_WORKER_GATE_PENDING) return false;
    if (now < b->phase_deadline) return true;
    bc_worker_gate_expire(&b->gate);
    return false;
}

static void renew_idle(bc_worker_broker *b, uint64_t now) {
    b->phase_deadline = bounded_deadline(now, b->idle_ticks, b->gate.deadline);
}

static bc_worker_frame header(const bc_worker_broker *b, bc_worker_frame_kind kind,
    uint64_t sequence, size_t length) {
    bc_worker_frame frame = {.kind = kind, .sequence = sequence, .length = (uint32_t)length};
    memcpy(frame.nonce, b->pipes.nonce, sizeof(frame.nonce));
    return frame;
}

static bool fits(size_t reserved, size_t limit, size_t required) {
    return reserved <= limit && required <= limit - reserved;
}

static bool reserve(bc_worker_broker_budget *budget, bc_worker_broker_amounts charge) {
    bc_worker_broker_amounts *used = &budget->reserved;
    const bc_worker_broker_amounts limit = budget->limit;
    if (!fits(used->sessions, limit.sessions, charge.sessions) ||
        !fits(used->parent_bytes, limit.parent_bytes, charge.parent_bytes) ||
        !fits(used->child_commit_bytes, limit.child_commit_bytes, charge.child_commit_bytes) ||
        !fits(used->wire_bytes, limit.wire_bytes, charge.wire_bytes)) return false;
    used->sessions += charge.sessions;
    used->parent_bytes += charge.parent_bytes;
    used->child_commit_bytes += charge.child_commit_bytes;
    used->wire_bytes += charge.wire_bytes;
    return true;
}

static void refund(bc_worker_broker *b) {
    bc_worker_broker_amounts *used = &b->budget->reserved;
    used->sessions -= b->charge.sessions;
    used->parent_bytes -= b->charge.parent_bytes;
    used->child_commit_bytes -= b->charge.child_commit_bytes;
    used->wire_bytes -= b->charge.wire_bytes;
}

DWORD bc_worker_broker_start(bc_worker_broker *b, const bc_worker_broker_run *run) {
    if (b->phase != BC_WORKER_BROKER_IDLE) return ERROR_BUSY;
    if (!run->budget || !run->commit_bytes || !run->startup_ms || !run->io_idle_ms ||
        (run->request_length && !run->request) ||
        !run->result || !run->result_capacity ||
        !run->validate || run->request_length > BC_WORKER_FRAME_PAYLOAD_MAX ||
        run->result_capacity > BC_WORKER_FRAME_PAYLOAD_MAX) return ERROR_INVALID_PARAMETER;
    const size_t wire = 4 * BC_WORKER_FRAME_BYTES + run->request_length + run->result_capacity + 1;
    if (wire > run->wire_limit) return ERROR_NOT_ENOUGH_QUOTA;
    const uint64_t now = now_ticks();
    if (now >= run->deadline) return ERROR_TIMEOUT;
    const bc_worker_broker_amounts charge = {
        .sessions = 1,
        .parent_bytes = sizeof(*b) + run->request_length + run->result_capacity,
        .child_commit_bytes = run->commit_bytes,
        .wire_bytes = wire
    };
    if (!reserve(run->budget, charge)) return ERROR_NOT_ENOUGH_QUOTA;

    b->budget = run->budget;
    b->charge = charge;
    bc_worker_gate_begin(&b->gate, run->deadline);
    b->phase_deadline = bounded_deadline(now, (uint64_t)run->startup_ms * 10000, run->deadline);
    b->idle_ticks = (uint64_t)run->io_idle_ms * 10000;
    b->phase = BC_WORKER_BROKER_SEND_HELLO;
    b->request = run->request;
    b->request_length = run->request_length;
    b->result = run->result;
    b->result_capacity = run->result_capacity;
    b->validate = run->validate;
    DWORD status = bc_worker_io_open(&b->io);
    if (!status) status = bc_worker_pipes_open(&b->pipes);
    if (!status) {
        const bc_worker_frame hello = header(b, BC_WORKER_HELLO, 1, 0);
        if (!bc_worker_tx_begin(&b->tx, &hello, NULL)) status = ERROR_INVALID_DATA;
    }
    if (!status) status = bc_restricted_worker_prepare(&b->worker, run->application,
        run->command_line, run->directory, run->profile, b->pipes.child, run->commit_bytes, run->cpu_ms);
    bc_worker_pipes_close_child(&b->pipes);
    if (!status) status = phase_live(b, now_ticks()) ?
        bc_restricted_worker_resume(&b->worker) : ERROR_TIMEOUT;
    if (status) {
        bc_worker_gate_io_error(&b->gate, now_ticks());
        bc_worker_broker_close(b);
    }
    return status;
}

static void step_tx(bc_worker_broker *b) {
    const uint8_t *bytes;
    DWORD count = 0;
    DWORD status;
    if (b->io.pipe) {
        status = bc_worker_io_poll(&b->io, &count);
    } else {
        const size_t length = bc_worker_tx_window(&b->tx, &bytes);
        status = bc_worker_io_start(&b->io, b->pipes.broker[BC_WORKER_STDIN], NULL, bytes,
            (DWORD)length, &count);
    }
    if (status == ERROR_IO_PENDING) return;
    const uint64_t now = now_ticks();
    if (!phase_live(b, now)) return;
    if (status || !bc_worker_tx_advance(&b->tx, count)) {
        bc_worker_gate_io_error(&b->gate, now);
        return;
    }
    if (b->phase == BC_WORKER_BROKER_SEND_START) renew_idle(b, now);
    if (bc_worker_tx_window(&b->tx, &bytes)) return;
    if (b->phase == BC_WORKER_BROKER_SEND_HELLO) {
        const bc_worker_frame ready = header(b, BC_WORKER_READY, 1, 0);
        bc_worker_rx_begin(&b->rx, &ready, NULL, 0);
        b->phase = BC_WORKER_BROKER_READ_READY;
    } else {
        const bc_worker_frame result = header(b, BC_WORKER_RESULT, 2, b->result_capacity);
        bc_worker_rx_begin(&b->rx, &result, b->result, b->result_capacity);
        b->phase = BC_WORKER_BROKER_READ_RESULT;
    }
}

static void step_rx(bc_worker_broker *b) {
    const bool probe_eof = b->phase == BC_WORKER_BROKER_READ_EOF;
    DWORD count = 0;
    DWORD status;
    if (b->io.pipe) {
        status = bc_worker_io_poll(&b->io, &count);
    } else {
        uint8_t *bytes = &b->trailing;
        const size_t length = probe_eof ? 1 : bc_worker_rx_window(&b->rx, &bytes);
        status = bc_worker_io_start(&b->io, b->pipes.broker[BC_WORKER_STDOUT], bytes, NULL,
            (DWORD)length, &count);
    }
    if (status == ERROR_IO_PENDING) return;
    const bool eof = status == ERROR_BROKEN_PIPE;
    const uint64_t now = now_ticks();
    if (!phase_live(b, now)) return;
    if (status && !eof) {
        bc_worker_gate_io_error(&b->gate, now);
        return;
    }
    if (probe_eof) {
        bc_worker_gate_stdout_end(&b->gate, eof, now);
        if (eof) renew_idle(b, now);
        b->phase = BC_WORKER_BROKER_WAIT_EXIT;
        return;
    }
    const bc_worker_rx_status received = eof ? bc_worker_rx_eof(&b->rx) :
        bc_worker_rx_advance(&b->rx, count);
    if (b->phase == BC_WORKER_BROKER_READ_RESULT && count) renew_idle(b, now);
    if (received == BC_WORKER_RX_HEADER || received == BC_WORKER_RX_BODY) return;
    if (received != BC_WORKER_RX_COMPLETE) {
        bc_worker_gate_stdout_end(&b->gate, false, now);
        return;
    }
    if (b->phase == BC_WORKER_BROKER_READ_READY) {
        const bc_worker_frame start = header(b, BC_WORKER_START, 2, b->request_length);
        if (!bc_worker_tx_begin(&b->tx, &start, b->request)) {
            bc_worker_gate_io_error(&b->gate, now);
            return;
        }
        renew_idle(b, now);
        b->phase = BC_WORKER_BROKER_SEND_START;
    } else {
        bc_worker_gate_stage(&b->gate, &b->rx, b->validate, now);
        b->phase = BC_WORKER_BROKER_READ_EOF;
    }
}

bc_worker_gate_status bc_worker_broker_step(bc_worker_broker *b) {
    if (b->gate.status != BC_WORKER_GATE_PENDING || b->phase == BC_WORKER_BROKER_IDLE)
        return b->gate.status;
    const uint64_t now = now_ticks();
    if (!phase_live(b, now)) return b->gate.status;
    switch (b->phase) {
    case BC_WORKER_BROKER_SEND_HELLO:
    case BC_WORKER_BROKER_SEND_START: step_tx(b); break;
    case BC_WORKER_BROKER_READ_READY:
    case BC_WORKER_BROKER_READ_RESULT:
    case BC_WORKER_BROKER_READ_EOF: step_rx(b); break;
    case BC_WORKER_BROKER_WAIT_EXIT: {
        const DWORD wait = WaitForSingleObject(b->worker.process, 0);
        if (wait == WAIT_TIMEOUT) break;
        DWORD code = 0;
        const BOOL known = wait == WAIT_OBJECT_0 && GetExitCodeProcess(b->worker.process, &code);
        const uint64_t observed = now_ticks();
        if (!phase_live(b, observed)) break;
        if (known) bc_worker_gate_exit(&b->gate, code, observed);
        else bc_worker_gate_io_error(&b->gate, observed);
        b->phase_deadline = b->gate.deadline;
        b->phase = BC_WORKER_BROKER_FINISH;
        break;
    }
    default: break;
    }
    return b->gate.status;
}

const uint8_t *bc_worker_broker_take(bc_worker_broker *b, size_t *length) {
    return b->phase == BC_WORKER_BROKER_FINISH ? bc_worker_gate_take(&b->gate, length, now_ticks()) : NULL;
}

bool bc_worker_broker_close(bc_worker_broker *b) {
    if (b->phase == BC_WORKER_BROKER_IDLE) return true;
    if (b->phase != BC_WORKER_BROKER_REAPING) {
        const uint64_t now = now_ticks();
        if (phase_live(b, now)) bc_worker_gate_cancel(&b->gate, now);
        if (b->io.pipe) bc_worker_io_cancel(&b->io);
        b->phase = BC_WORKER_BROKER_REAPING;
    }
    if (!bc_restricted_worker_stop(&b->worker)) return false;
    DWORD count;
    if (b->io.pipe && bc_worker_io_poll(&b->io, &count) == ERROR_IO_PENDING) return false;
    if (!bc_restricted_worker_close(&b->worker) || bc_worker_io_close(&b->io)) return false;
    bc_worker_pipes_close(&b->pipes);
    refund(b);
    *b = (bc_worker_broker){0};
    return true;
}
