#ifndef BC_RESTRICTED_WORKER_FRAME_H
#define BC_RESTRICTED_WORKER_FRAME_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum {
    BC_WORKER_FRAME_BYTES = 48,
    BC_WORKER_NONCE_BYTES = 16,
    BC_WORKER_FRAME_REVISION = 1,
    BC_WORKER_FRAME_PAYLOAD_MAX = 4 * 1024 * 1024 - BC_WORKER_FRAME_BYTES
};

typedef enum bc_worker_frame_kind {
    BC_WORKER_HELLO = 1,
    BC_WORKER_READY,
    BC_WORKER_START,
    BC_WORKER_HOST_REQUEST,
    BC_WORKER_HOST_REPLY,
    BC_WORKER_CANCEL,
    BC_WORKER_RESULT,
    BC_WORKER_ERROR
} bc_worker_frame_kind;

typedef struct bc_worker_frame {
    uint8_t nonce[BC_WORKER_NONCE_BYTES];
    uint64_t sequence;
    uint64_t correlation;
    uint32_t length;
    bc_worker_frame_kind kind;
} bc_worker_frame;

bool bc_worker_frame_encode(uint8_t header[BC_WORKER_FRAME_BYTES], const bc_worker_frame *frame);

/* Validate the complete header before acquiring storage or reading a body.
   expected.length is the receiver's per-message ceiling. The expected nonce
   may be all zero only for the child's initial HELLO on its inherited input.
   A failed preflight leaves the output untouched. */
bool bc_worker_frame_preflight(const uint8_t *header, size_t bytes,
    const bc_worker_frame *expected, bc_worker_frame *frame);

/* A completed bounded record must contain exactly the preflighted body. */
bool bc_worker_frame_complete(const bc_worker_frame *frame, size_t body_bytes);

#endif
