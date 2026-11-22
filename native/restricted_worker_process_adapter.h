#ifndef BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H
#define BC_RESTRICTED_WORKER_PROCESS_ADAPTER_H

#include "host_adapter_process.h"
#include "restricted_worker_process_route.h"

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
