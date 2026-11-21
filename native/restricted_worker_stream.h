#ifndef BC_RESTRICTED_WORKER_STREAM_H
#define BC_RESTRICTED_WORKER_STREAM_H

#include "restricted_worker_frame.h"

enum { BC_WORKER_IO_WINDOW = 4096 };

typedef enum bc_worker_rx_status {
    BC_WORKER_RX_HEADER,
    BC_WORKER_RX_BODY,
    BC_WORKER_RX_COMPLETE,
    BC_WORKER_RX_EOF,
    BC_WORKER_RX_TRUNCATED,
    BC_WORKER_RX_REJECTED
} bc_worker_rx_status;

typedef struct bc_worker_rx {
    bc_worker_frame expected;
    bc_worker_frame received;
    bc_worker_frame alternate;
    uint8_t header[BC_WORKER_FRAME_BYTES];
    uint8_t *body;
    uint8_t *alternate_body;
    size_t used;
    bc_worker_rx_status status;
} bc_worker_rx;

/* A cursor borrows body storage until frame delivery or abandonment.
   Keep the cursor and its storage stable through every I/O completion. */
void bc_worker_rx_begin(bc_worker_rx *rx, const bc_worker_frame *expected,
    uint8_t *body, size_t capacity);
/* Optional alternate kind at the same sequence, with its own body storage. */
void bc_worker_rx_alternate(bc_worker_rx *rx, const bc_worker_frame *expected,
    uint8_t *body, size_t capacity);
size_t bc_worker_rx_window(bc_worker_rx *rx, uint8_t **bytes);
bc_worker_rx_status bc_worker_rx_advance(bc_worker_rx *rx, size_t transferred);
bc_worker_rx_status bc_worker_rx_eof(bc_worker_rx *rx);
const bc_worker_frame *bc_worker_rx_frame(const bc_worker_rx *rx);

typedef struct bc_worker_tx {
    uint8_t header[BC_WORKER_FRAME_BYTES];
    const uint8_t *body;
    size_t length;
    size_t sent;
} bc_worker_tx;

/* Keep the cursor and immutable body stable through I/O completion. */
bool bc_worker_tx_begin(bc_worker_tx *tx, const bc_worker_frame *frame, const uint8_t *body);
size_t bc_worker_tx_window(const bc_worker_tx *tx, const uint8_t **bytes);
bool bc_worker_tx_advance(bc_worker_tx *tx, size_t transferred);

#endif
