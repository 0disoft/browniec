#ifndef BC_RESTRICTED_WORKER_PROCESS_ROUTE_H
#define BC_RESTRICTED_WORKER_PROCESS_ROUTE_H

#include "restricted_worker_broker.h"

typedef bool (*bc_worker_process_encode)(void *, uint64_t, const uint8_t *, size_t, uint8_t *);
typedef bool (*bc_worker_process_reply_size)(void *, const uint8_t *, size_t, size_t, size_t *);
typedef size_t (*bc_worker_process_decode)(void *, const uint8_t *, size_t, uint8_t *, size_t);

extern const bc_worker_host_adapter bc_worker_process_callbacks;

/* One serial adapter slot. Only the trusted parent supplies the path and codec.
   Release the route after broker close has collected its live process. */
void *bc_worker_process_route_create(const uint8_t *path, size_t path_length, size_t reply_limit,
    uint32_t launches, size_t wire_limit, void *codec, bc_worker_process_encode encode,
    bc_worker_process_reply_size reply_size, bc_worker_process_decode decode);
void bc_worker_process_route_release(void *owner);

#endif
