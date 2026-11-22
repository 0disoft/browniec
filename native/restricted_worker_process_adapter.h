#ifndef BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H
#define BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H

#include "host_adapter_process_types.h"
#include "restricted_worker_broker.h"

typedef bool (*bc_worker_process_encode)(void *, uint64_t, const uint8_t *, size_t, uint8_t *);
typedef bool (*bc_worker_process_reply_size)(void *, const uint8_t *, size_t, size_t, size_t *);
typedef size_t (*bc_worker_process_decode)(void *, const uint8_t *, size_t, uint8_t *, size_t);

/* The trusted parent supplies an executable, a shared process budget and the
   catalog codec. The guest supplies only the import ID and typed request bytes.
   Keep the owner, path, codec context and budget stable until broker close. */
typedef struct bc_worker_process_adapter {
    bc_adapter_slot slot;
    const uint8_t *path;
    size_t path_length, reply_limit;
    void *codec;
    bc_worker_process_encode encode;
    bc_worker_process_reply_size reply_size;
    bc_worker_process_decode decode;
} bc_worker_process_adapter;

#endif
