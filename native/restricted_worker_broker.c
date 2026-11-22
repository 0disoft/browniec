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
        !fits(used->wire_bytes, limit.wire_bytes, charge.wire_bytes) ||
        !fits(used->adapter_slots, limit.adapter_slots, charge.adapter_slots) ||
        !fits(used->io_slots, limit.io_slots, charge.io_slots) ||
        !fits(used->pipe_buffer_bytes, limit.pipe_buffer_bytes, charge.pipe_buffer_bytes) ||
        !fits(used->host_request_bytes, limit.host_request_bytes, charge.host_request_bytes) ||
        !fits(used->host_reply_bytes, limit.host_reply_bytes, charge.host_reply_bytes)) return false;
    used->sessions += charge.sessions;
    used->parent_bytes += charge.parent_bytes;
    used->child_commit_bytes += charge.child_commit_bytes;
    used->wire_bytes += charge.wire_bytes;
    used->adapter_slots += charge.adapter_slots;
    used->io_slots += charge.io_slots;
    used->pipe_buffer_bytes += charge.pipe_buffer_bytes;
    used->host_request_bytes += charge.host_request_bytes;
    used->host_reply_bytes += charge.host_reply_bytes;
    return true;
}

static void refund(bc_worker_broker *b) {
    bc_worker_broker_amounts *used = &b->budget->reserved;
    used->sessions -= b->charge.sessions;
    used->parent_bytes -= b->charge.parent_bytes;
    used->child_commit_bytes -= b->charge.child_commit_bytes;
    used->wire_bytes -= b->charge.wire_bytes;
    used->adapter_slots -= b->charge.adapter_slots;
    used->io_slots -= b->charge.io_slots;
    used->pipe_buffer_bytes -= b->charge.pipe_buffer_bytes;
    used->host_request_bytes -= b->charge.host_request_bytes;
    used->host_reply_bytes -= b->charge.host_reply_bytes;
}

DWORD bc_worker_broker_start(bc_worker_broker *b, const bc_worker_broker_run *run) {
    if (b->phase != BC_WORKER_BROKER_IDLE) return ERROR_BUSY;
    if (!run->budget || !run->commit_bytes || !run->startup_ms || !run->io_idle_ms ||
        !run->shutdown_grace_ms || run->shutdown_grace_ms > 5000 ||
        (run->request_length && !run->request) ||
        !run->result || !run->result_capacity ||
        !run->validate || run->request_length > BC_WORKER_FRAME_PAYLOAD_MAX ||
        run->result_capacity > BC_WORKER_FRAME_PAYLOAD_MAX) return ERROR_INVALID_PARAMETER;
    const bc_worker_broker_host host = run->host;
    const bc_worker_host_adapter *adapter = run->adapter;
    if (host.max_calls) {
        if ((host.respond != NULL) == (adapter != NULL) ||
            (adapter && (!adapter->begin || !adapter->poll || !adapter->close)) ||
            !host.request || !host.reply || !host.request_capacity ||
            !host.reply_capacity || host.request_capacity > BC_WORKER_FRAME_PAYLOAD_MAX ||
            host.reply_capacity > BC_WORKER_FRAME_PAYLOAD_MAX) return ERROR_INVALID_PARAMETER;
    } else if (host.respond || adapter || host.request || host.reply || host.request_capacity ||
        host.reply_capacity) return ERROR_INVALID_PARAMETER;
    if (!adapter && (run->adapter_wire_bytes || run->adapter_parent_bytes)) return ERROR_INVALID_PARAMETER;
    size_t wire = 5 * BC_WORKER_FRAME_BYTES + run->request_length + run->result_capacity + 1;
    const size_t per_call = 2 * BC_WORKER_FRAME_BYTES + host.request_capacity + host.reply_capacity;
    if (wire > run->wire_limit || host.max_calls > (run->wire_limit - wire) / per_call)
        return ERROR_NOT_ENOUGH_QUOTA;
    wire += host.max_calls * per_call;
    if (run->adapter_wire_bytes > run->wire_limit - wire) return ERROR_NOT_ENOUGH_QUOTA;
    wire += run->adapter_wire_bytes;
    const size_t parent = sizeof(*b) + run->request_length + run->result_capacity +
        host.request_capacity + host.reply_capacity;
    const size_t launch_heap = bc_restricted_worker_launch_heap_bytes();
    if (!launch_heap) return ERROR_INVALID_DATA;
    if (launch_heap > SIZE_MAX - parent || run->adapter_parent_bytes > SIZE_MAX - parent - launch_heap)
        return ERROR_NOT_ENOUGH_QUOTA;
    const uint64_t now = now_ticks();
    if (now >= run->deadline) return ERROR_TIMEOUT;
    const bc_worker_broker_amounts charge = {
        .sessions = 1,
        .parent_bytes = parent + launch_heap + run->adapter_parent_bytes,
        .child_commit_bytes = run->commit_bytes,
        .wire_bytes = wire,
        .adapter_slots = adapter ? 1 : 0,
        .io_slots = BC_WORKER_BROKER_IO_SLOTS + (adapter ? (size_t)adapter->io_slots : 0),
        .pipe_buffer_bytes = BC_WORKER_PIPE_BUFFER_RESERVATION +
            (adapter ? (size_t)adapter->pipe_buffer_bytes : 0),
        .host_request_bytes = host.max_calls * host.request_capacity,
        .host_reply_bytes = host.max_calls * host.reply_capacity
    };
    if (!reserve(run->budget, charge)) return ERROR_NOT_ENOUGH_QUOTA;

    b->budget = run->budget;
    b->charge = charge;
    bc_worker_gate_begin(&b->gate, run->deadline);
    b->phase_deadline = bounded_deadline(now, (uint64_t)run->startup_ms * 10000, run->deadline);
    b->idle_ticks = (uint64_t)run->io_idle_ms * 10000;
    b->grace_ticks = (uint64_t)run->shutdown_grace_ms * 10000;
    b->phase = BC_WORKER_BROKER_SEND_HELLO;
    b->request = run->request;
    b->request_length = run->request_length;
    b->result = run->result;
    b->result_capacity = run->result_capacity;
    b->validate = run->validate;
    b->expectation = run->expectation;
    b->host = host;
    b->adapter = adapter;
    DWORD status = bc_worker_io_open(&b->io);
    if (!status) status = bc_worker_io_open(&b->cancel_io);
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

static DWORD advance_tx(bc_worker_broker *b, bc_worker_io *io) {
    const uint8_t *bytes;
    const size_t length = bc_worker_tx_window(&b->tx, &bytes);
    if (!length) return ERROR_SUCCESS;
    DWORD count = 0;
    const DWORD status = io->pipe ? bc_worker_io_poll(io, &count) :
        bc_worker_io_start(io, b->pipes.broker[BC_WORKER_STDIN], NULL, bytes, (DWORD)length, &count);
    if (status) return status;
    return bc_worker_tx_advance(&b->tx, count) ? ERROR_SUCCESS : ERROR_INVALID_DATA;
}

static void expect_worker(bc_worker_broker *b, bool allow_request) {
    const uint64_t sequence = 2ULL + b->requests;
    const bc_worker_frame result = header(b, BC_WORKER_RESULT, sequence, b->result_capacity);
    bc_worker_rx_begin(&b->rx, &result, b->result, b->result_capacity);
    if (allow_request && b->requests < b->host.max_calls) {
        bc_worker_frame request = header(b, BC_WORKER_HOST_REQUEST, sequence, b->host.request_capacity);
        request.correlation = 1ULL + b->requests;
        bc_worker_rx_alternate(&b->rx, &request, b->host.request, b->host.request_capacity);
    }
}

static bool queue_host_reply(bc_worker_broker *b, size_t length) {
    if (!length || length > b->host.reply_capacity) return false;
    bc_worker_frame reply = header(b, BC_WORKER_HOST_REPLY, 3ULL + b->replies, length);
    reply.correlation = b->rx.received.correlation;
    if (!bc_worker_tx_begin(&b->tx, &reply, b->host.reply)) return false;
    b->phase = BC_WORKER_BROKER_SEND_HOST_REPLY;
    return true;
}

static bool dispatch_host_request(bc_worker_broker *b) {
    const bc_worker_frame *request = &b->rx.received;
    if (!request->length) return false;
    ++b->requests;
    if (b->adapter) {
        b->adapter_active = true;
        b->phase = BC_WORKER_BROKER_WAIT_HOST;
        const bool started = b->adapter->begin(b->host.context, request->correlation,
            b->rx.body, request->length, b->phase_deadline);
        return phase_live(b, now_ticks()) && started;
    }
    const size_t length = b->host.respond(b->host.context, request->correlation, b->rx.body,
        request->length, b->host.reply, b->host.reply_capacity);
    return phase_live(b, now_ticks()) && queue_host_reply(b, length);
}

static bool close_host_adapter(bc_worker_broker *b) {
    if (b->adapter_active && b->adapter->close(b->host.context)) b->adapter_active = false;
    return !b->adapter_active;
}

static void step_host(bc_worker_broker *b) {
    if (b->phase == BC_WORKER_BROKER_WAIT_HOST) {
        size_t length = 0;
        const bc_worker_host_progress progress = b->adapter->poll(b->host.context,
            b->host.reply, b->host.reply_capacity, &length);
        const uint64_t now = now_ticks();
        if (!phase_live(b, now) || progress == BC_WORKER_HOST_PENDING) return;
        if (progress != BC_WORKER_HOST_READY || !length || length > b->host.reply_capacity) {
            bc_worker_gate_stdout_end(&b->gate, false, now);
            return;
        }
        b->host_reply_length = length;
        b->phase = BC_WORKER_BROKER_REAP_HOST;
        return;
    }
    if (!close_host_adapter(b)) return;
    const uint64_t now = now_ticks();
    if (phase_live(b, now) && !queue_host_reply(b, b->host_reply_length))
        bc_worker_gate_stdout_end(&b->gate, false, now);
}

static void step_tx(bc_worker_broker *b) {
    const DWORD status = advance_tx(b, &b->io);
    if (status == ERROR_IO_PENDING) return;
    const uint64_t now = now_ticks();
    if (!phase_live(b, now) || status) {
        if (status) {
            bc_worker_gate_io_error(&b->gate, now);
            b->phase = BC_WORKER_BROKER_FINISH;
        }
        return;
    }
    if (b->phase != BC_WORKER_BROKER_SEND_HELLO) renew_idle(b, now);
    const uint8_t *bytes;
    if (bc_worker_tx_window(&b->tx, &bytes)) return;
    if (b->phase == BC_WORKER_BROKER_SEND_HELLO) {
        const bc_worker_frame ready = header(b, BC_WORKER_READY, 1, 0);
        bc_worker_rx_begin(&b->rx, &ready, NULL, 0);
        b->phase = BC_WORKER_BROKER_READ_READY;
    } else {
        if (b->phase == BC_WORKER_BROKER_SEND_HOST_REPLY) ++b->replies;
        expect_worker(b, true);
        b->phase = BC_WORKER_BROKER_READ_RESULT;
    }
}

static DWORD read_chunk(bc_worker_broker *b, bool probe_eof, DWORD *count) {
    if (b->io.pipe) return bc_worker_io_poll(&b->io, count);
    uint8_t *bytes = &b->trailing;
    const size_t length = probe_eof ? 1 : bc_worker_rx_window(&b->rx, &bytes);
    return bc_worker_io_start(&b->io, b->pipes.broker[BC_WORKER_STDOUT], bytes, NULL,
        (DWORD)length, count);
}

static void step_rx(bc_worker_broker *b) {
    const bool probe_eof = b->phase == BC_WORKER_BROKER_READ_EOF;
    DWORD count = 0;
    const DWORD status = read_chunk(b, probe_eof, &count);
    if (status == ERROR_IO_PENDING) return;
    const bool eof = status == ERROR_BROKEN_PIPE;
    const uint64_t now = now_ticks();
    if (!phase_live(b, now)) {
        // The completion was already collected. Retain its cursor position
        // for a legal late drain, or stop if the stream cannot be continued.
        if (!probe_eof && !status) {
            if (bc_worker_rx_advance(&b->rx, count) != BC_WORKER_RX_REJECTED) return;
        }
        b->phase = BC_WORKER_BROKER_FINISH;
        return;
    }
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
    } else if (b->rx.received.kind == BC_WORKER_HOST_REQUEST) {
        if (!dispatch_host_request(b))
            bc_worker_gate_stdout_end(&b->gate, false, now_ticks());
    } else {
        bc_worker_gate_stage(&b->gate, &b->rx, b->validate, b->expectation, now);
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
    case BC_WORKER_BROKER_SEND_START:
    case BC_WORKER_BROKER_SEND_HOST_REPLY: step_tx(b); break;
    case BC_WORKER_BROKER_WAIT_HOST:
    case BC_WORKER_BROKER_REAP_HOST: step_host(b); break;
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

static bool begin_cancel_frame(bc_worker_broker *b) {
    const bc_worker_frame cancel = header(b, BC_WORKER_CANCEL, 3ULL + b->replies, 0);
    if (!bc_worker_tx_begin(&b->tx, &cancel, NULL)) return false;
    b->phase = BC_WORKER_BROKER_SEND_CANCEL;
    return true;
}

static void settle_cancel(bc_worker_broker *b, uint64_t now) {
    if (b->phase != BC_WORKER_BROKER_IDLE && phase_live(b, now))
        bc_worker_gate_cancel(&b->gate, now);
}

bc_worker_gate_status bc_worker_broker_cancel(bc_worker_broker *b) {
    settle_cancel(b, now_ticks());
    return b->gate.status;
}

static void begin_shutdown(bc_worker_broker *b, uint64_t now) {
    settle_cancel(b, now);
    b->shutdown_deadline = bounded_deadline(now, b->grace_ticks, UINT64_MAX);
    if (b->gate.status == BC_WORKER_GATE_CANCELLED || b->gate.status == BC_WORKER_GATE_EXPIRED) {
        if (b->phase == BC_WORKER_BROKER_SEND_START || b->phase == BC_WORKER_BROKER_SEND_HOST_REPLY) {
            if (b->tx.sent || b->io.pipe) {
                b->cancel_reply = b->phase == BC_WORKER_BROKER_SEND_HOST_REPLY;
                b->phase = BC_WORKER_BROKER_CANCEL_TX;
                return;
            }
            if (b->phase == BC_WORKER_BROKER_SEND_HOST_REPLY) {
                expect_worker(b, false);
                if (begin_cancel_frame(b)) return;
            }
        }
        if ((b->phase == BC_WORKER_BROKER_WAIT_HOST || b->phase == BC_WORKER_BROKER_REAP_HOST ||
             b->phase == BC_WORKER_BROKER_READ_RESULT || b->phase == BC_WORKER_BROKER_READ_EOF) &&
            begin_cancel_frame(b)) return;
        if (b->phase == BC_WORKER_BROKER_WAIT_EXIT) {
            b->phase = BC_WORKER_BROKER_DRAIN_EXIT;
            return;
        }
    }
    b->phase = BC_WORKER_BROKER_REAPING;
    if (b->io.pipe) bc_worker_io_cancel(&b->io);
}

static void drain_completed_frame(bc_worker_broker *b) {
    if (b->rx.received.kind == BC_WORKER_HOST_REQUEST) {
        // Never dispatch a request collected after the outcome was settled.
        b->requests = (uint32_t)(b->rx.received.sequence - 1);
        expect_worker(b, false);
        b->phase = BC_WORKER_BROKER_DRAIN_RESULT;
    } else {
        b->phase = BC_WORKER_BROKER_DRAIN_EOF;
    }
}

/* Return true while graceful progress remains possible. */
static bool shutdown_step(bc_worker_broker *b) {
    if (now_ticks() >= b->shutdown_deadline) return false;
    const uint8_t *window;
    switch (b->phase) {
    case BC_WORKER_BROKER_CANCEL_TX:
    case BC_WORKER_BROKER_SEND_CANCEL: {
        const bool finishing_frame = b->phase == BC_WORKER_BROKER_CANCEL_TX;
        const DWORD status = advance_tx(b, finishing_frame ? &b->io : &b->cancel_io);
        if (status) return status == ERROR_IO_PENDING;
        if (bc_worker_tx_window(&b->tx, &window)) return true;
        if (finishing_frame) {
            if (b->cancel_reply) ++b->replies;
            expect_worker(b, true);
            return begin_cancel_frame(b);
        }
        if (bc_worker_rx_frame(&b->rx)) drain_completed_frame(b);
        else b->phase = BC_WORKER_BROKER_DRAIN_RESULT;
        return true;
    }
    case BC_WORKER_BROKER_DRAIN_RESULT:
    case BC_WORKER_BROKER_DRAIN_EOF: {
        const bool probe_eof = b->phase == BC_WORKER_BROKER_DRAIN_EOF;
        DWORD count = 0;
        const DWORD status = read_chunk(b, probe_eof, &count);
        if (status == ERROR_IO_PENDING) return true;
        if (status == ERROR_BROKEN_PIPE) {
            if (!probe_eof && bc_worker_rx_eof(&b->rx) != BC_WORKER_RX_EOF) return false;
            b->phase = BC_WORKER_BROKER_DRAIN_EXIT;
            return true;
        }
        if (status || probe_eof) return false;
        const bc_worker_rx_status received = bc_worker_rx_advance(&b->rx, count);
        if (received == BC_WORKER_RX_COMPLETE) drain_completed_frame(b);
        return received != BC_WORKER_RX_REJECTED;
    }
    case BC_WORKER_BROKER_DRAIN_EXIT:
        return WaitForSingleObject(b->worker.process, 0) == WAIT_TIMEOUT;
    default:
        return false;
    }
}

bool bc_worker_broker_close(bc_worker_broker *b) {
    if (b->phase == BC_WORKER_BROKER_IDLE) return true;
    if (!b->shutdown_deadline) begin_shutdown(b, now_ticks());
    const bool adapter_reaped = close_host_adapter(b);
    if (b->phase != BC_WORKER_BROKER_REAPING) {
        if (shutdown_step(b)) return false;
        if (b->worker.job && now_ticks() >= b->shutdown_deadline)
            TerminateJobObject(b->worker.job, ERROR_TIMEOUT);
        if (b->io.pipe) bc_worker_io_cancel(&b->io);
        if (b->cancel_io.pipe) bc_worker_io_cancel(&b->cancel_io);
        b->phase = BC_WORKER_BROKER_REAPING;
    }
    if (!bc_restricted_worker_stop(&b->worker)) return false;
    DWORD count;
    if (b->io.pipe && bc_worker_io_poll(&b->io, &count) == ERROR_IO_PENDING) return false;
    if (b->cancel_io.pipe && bc_worker_io_poll(&b->cancel_io, &count) == ERROR_IO_PENDING) return false;
    if (!adapter_reaped || !bc_restricted_worker_close(&b->worker) || bc_worker_io_close(&b->io) ||
        bc_worker_io_close(&b->cancel_io)) return false;
    bc_worker_pipes_close(&b->pipes);
    refund(b);
    *b = (bc_worker_broker){0};
    return true;
}
