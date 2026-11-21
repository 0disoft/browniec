#include "restricted_worker_stream.h"

static size_t window_size(size_t remaining) {
    return remaining > BC_WORKER_IO_WINDOW ? BC_WORKER_IO_WINDOW : remaining;
}

void bc_worker_rx_begin(bc_worker_rx *rx, const bc_worker_frame *expected,
    uint8_t *body, size_t capacity) {
    const bc_worker_frame pending = *expected;
    *rx = (bc_worker_rx){.expected = pending, .body = body, .status = BC_WORKER_RX_HEADER};
    if (!body) capacity = 0;
    if (capacity < rx->expected.length) rx->expected.length = (uint32_t)capacity;
}

void bc_worker_rx_alternate(bc_worker_rx *rx, const bc_worker_frame *expected,
    uint8_t *body, size_t capacity) {
    rx->alternate = *expected;
    rx->alternate_body = body;
    if (!body) capacity = 0;
    if (capacity < rx->alternate.length) rx->alternate.length = (uint32_t)capacity;
}

size_t bc_worker_rx_window(bc_worker_rx *rx, uint8_t **bytes) {
    *bytes = NULL;
    if (rx->status == BC_WORKER_RX_HEADER) {
        *bytes = rx->header + rx->used;
        return sizeof(rx->header) - rx->used;
    }
    if (rx->status == BC_WORKER_RX_BODY) {
        *bytes = rx->body + rx->used;
        return window_size(rx->received.length - rx->used);
    }
    return 0;
}

bc_worker_rx_status bc_worker_rx_advance(bc_worker_rx *rx, size_t transferred) {
    uint8_t *window;
    const size_t available = bc_worker_rx_window(rx, &window);
    if (!available) return rx->status;
    if (!transferred || transferred > available) return rx->status = BC_WORKER_RX_REJECTED;
    rx->used += transferred;
    if (rx->status == BC_WORKER_RX_HEADER && rx->used == sizeof(rx->header)) {
        if (!bc_worker_frame_preflight(rx->header, rx->used, &rx->expected, &rx->received)) {
            if (!rx->alternate.kind ||
                !bc_worker_frame_preflight(rx->header, rx->used, &rx->alternate, &rx->received))
                return rx->status = BC_WORKER_RX_REJECTED;
            rx->body = rx->alternate_body;
        }
        rx->used = 0;
        rx->status = rx->received.length ? BC_WORKER_RX_BODY : BC_WORKER_RX_COMPLETE;
    } else if (rx->status == BC_WORKER_RX_BODY && rx->used == rx->received.length) {
        rx->status = BC_WORKER_RX_COMPLETE;
    }
    return rx->status;
}

bc_worker_rx_status bc_worker_rx_eof(bc_worker_rx *rx) {
    if (rx->status == BC_WORKER_RX_HEADER)
        rx->status = rx->used ? BC_WORKER_RX_TRUNCATED : BC_WORKER_RX_EOF;
    else if (rx->status == BC_WORKER_RX_BODY)
        rx->status = BC_WORKER_RX_TRUNCATED;
    return rx->status;
}

const bc_worker_frame *bc_worker_rx_frame(const bc_worker_rx *rx) {
    return rx->status == BC_WORKER_RX_COMPLETE ? &rx->received : NULL;
}

bool bc_worker_tx_begin(bc_worker_tx *tx, const bc_worker_frame *frame, const uint8_t *body) {
    *tx = (bc_worker_tx){0};
    if ((frame->length && !body) || !bc_worker_frame_encode(tx->header, frame)) return false;
    tx->body = body;
    tx->length = sizeof(tx->header) + frame->length;
    return true;
}

size_t bc_worker_tx_window(const bc_worker_tx *tx, const uint8_t **bytes) {
    *bytes = NULL;
    if (tx->sent == tx->length) return 0;
    if (tx->sent < sizeof(tx->header)) {
        *bytes = tx->header + tx->sent;
        return sizeof(tx->header) - tx->sent;
    }
    *bytes = tx->body + (tx->sent - sizeof(tx->header));
    return window_size(tx->length - tx->sent);
}

bool bc_worker_tx_advance(bc_worker_tx *tx, size_t transferred) {
    const uint8_t *window;
    if (!transferred || transferred > bc_worker_tx_window(tx, &window)) return false;
    tx->sent += transferred;
    return true;
}
