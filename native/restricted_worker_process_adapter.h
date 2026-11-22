#ifndef BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H
#define BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H

#include "host_adapter_process.h"
#include "restricted_worker_broker.h"

/* The trusted parent supplies an executable, a shared process budget and the
   catalog codec. The guest supplies only the import ID and typed request bytes.
   Keep the owner, path, codec context and budget stable until broker close. */
typedef struct bc_worker_process_adapter {
    bc_adapter_slot slot;
    const uint8_t *path;
    size_t path_length, reply_limit;
    void *codec;
    bool (*encode)(void *codec, uint64_t correlation, const uint8_t *request,
        size_t length, uint8_t header[BC_ADAPTER_HEADER_BYTES]);
    bool (*reply_size)(void *codec, const uint8_t *header, size_t length,
        size_t limit, size_t *body_length);
    size_t (*decode)(void *codec, const uint8_t *frame, size_t length,
        uint8_t *reply, size_t capacity);
} bc_worker_process_adapter;

extern const bc_worker_host_adapter bc_worker_process_callbacks;

#endif
