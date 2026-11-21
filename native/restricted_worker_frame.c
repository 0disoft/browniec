#include "restricted_worker_frame.h"
#include <string.h>

static const uint8_t magic[] = {'B', 'C', 'W', 'K'};
static const uint8_t empty_frame_nonce[BC_WORKER_NONCE_BYTES] = {0};

static void put_le(uint8_t *bytes, size_t length, uint64_t value) {
    for (size_t i = 0; i < length; ++i) {
        bytes[i] = (uint8_t)value;
        value >>= 8;
    }
}

static uint64_t get_le(const uint8_t *bytes, size_t length) {
    uint64_t value = 0;
    while (length) value = (value << 8) | bytes[--length];
    return value;
}

static bool valid(const bc_worker_frame *frame) {
    if (frame->kind < BC_WORKER_HELLO || frame->kind > BC_WORKER_ERROR ||
        !frame->sequence || frame->length > BC_WORKER_FRAME_PAYLOAD_MAX ||
        !memcmp(frame->nonce, empty_frame_nonce, sizeof(empty_frame_nonce))) return false;
    if (frame->kind == BC_WORKER_HELLO || frame->kind == BC_WORKER_READY)
        return frame->sequence == 1 && !frame->correlation && !frame->length;
    if (frame->kind == BC_WORKER_CANCEL && frame->length) return false;
    return frame->sequence > 1;
}

bool bc_worker_frame_encode(uint8_t header[BC_WORKER_FRAME_BYTES], const bc_worker_frame *frame) {
    if (!valid(frame)) return false;
    memcpy(header, magic, sizeof(magic));
    put_le(header + 4, 2, BC_WORKER_FRAME_REVISION);
    put_le(header + 6, 2, (uint64_t)frame->kind);
    put_le(header + 8, 4, frame->length);
    memset(header + 12, 0, 4);
    put_le(header + 16, 8, frame->sequence);
    put_le(header + 24, 8, frame->correlation);
    memcpy(header + 32, frame->nonce, sizeof(frame->nonce));
    return true;
}

bool bc_worker_frame_preflight(const uint8_t *header, size_t bytes,
    const bc_worker_frame *expected, bc_worker_frame *frame) {
    if (bytes != BC_WORKER_FRAME_BYTES || memcmp(header, magic, sizeof(magic)) ||
        get_le(header + 4, 2) != BC_WORKER_FRAME_REVISION || get_le(header + 12, 4) ||
        get_le(header + 6, 2) != (uint64_t)expected->kind) return false;
    bc_worker_frame parsed = {0};
    parsed.kind = expected->kind;
    parsed.length = (uint32_t)get_le(header + 8, 4);
    parsed.sequence = get_le(header + 16, 8);
    parsed.correlation = get_le(header + 24, 8);
    memcpy(parsed.nonce, header + 32, sizeof(parsed.nonce));
    if (!valid(&parsed) || parsed.length > expected->length ||
        parsed.sequence != expected->sequence || parsed.correlation != expected->correlation)
        return false;
    const bool initial_hello = expected->kind == BC_WORKER_HELLO &&
        !memcmp(expected->nonce, empty_frame_nonce, sizeof(empty_frame_nonce));
    if (!initial_hello && memcmp(parsed.nonce, expected->nonce, sizeof(parsed.nonce))) return false;
    *frame = parsed;
    return true;
}

bool bc_worker_frame_complete(const bc_worker_frame *frame, size_t body_bytes) {
    return body_bytes == frame->length;
}
