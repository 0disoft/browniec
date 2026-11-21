#include "restricted_worker_gate.h"

static void finish(bc_worker_gate *gate, bc_worker_gate_status status) {
    gate->status = status;
    gate->candidate = NULL;
    gate->length = 0;
}

static bool live(bc_worker_gate *gate, uint64_t now) {
    if (gate->status != BC_WORKER_GATE_PENDING) return false;
    if (now < gate->deadline) return true;
    finish(gate, BC_WORKER_GATE_EXPIRED);
    return false;
}

void bc_worker_gate_begin(bc_worker_gate *gate, uint64_t deadline) {
    *gate = (bc_worker_gate){.deadline = deadline, .status = BC_WORKER_GATE_PENDING};
}

void bc_worker_gate_stage(bc_worker_gate *gate, const bc_worker_rx *rx,
    bc_worker_result_validator validate, uint64_t now) {
    if (!live(gate, now)) return;
    const bc_worker_frame *frame = bc_worker_rx_frame(rx);
    if (gate->candidate || gate->stdout_eof || !frame || frame->kind != BC_WORKER_RESULT ||
        !frame->length || !validate || !validate(rx->body, frame->length)) {
        finish(gate, BC_WORKER_GATE_PROTOCOL);
        return;
    }
    gate->candidate = rx->body;
    gate->length = frame->length;
}

void bc_worker_gate_stdout_end(bc_worker_gate *gate, bool clean_eof, uint64_t now) {
    if (!live(gate, now)) return;
    if (!clean_eof || !gate->candidate) {
        finish(gate, BC_WORKER_GATE_PROTOCOL);
        return;
    }
    gate->stdout_eof = true;
}

void bc_worker_gate_exit(bc_worker_gate *gate, uint32_t code, uint64_t now) {
    if (!live(gate, now)) return;
    if (code) {
        finish(gate, BC_WORKER_GATE_EXIT);
        return;
    }
    gate->exit_ok = true;
}

void bc_worker_gate_cancel(bc_worker_gate *gate, uint64_t now) {
    if (live(gate, now)) finish(gate, BC_WORKER_GATE_CANCELLED);
}

const uint8_t *bc_worker_gate_take(bc_worker_gate *gate, size_t *length, uint64_t now) {
    if (!live(gate, now) || !gate->stdout_eof || !gate->exit_ok) return NULL;
    const uint8_t *candidate = gate->candidate;
    *length = gate->length;
    finish(gate, BC_WORKER_GATE_DELIVERED);
    return candidate;
}
