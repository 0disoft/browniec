#ifndef BC_RESTRICTED_WORKER_PROCESS_ROUTE_H
#define BC_RESTRICTED_WORKER_PROCESS_ROUTE_H

#include "restricted_worker_process_adapter.h"

extern const bc_worker_host_adapter bc_worker_process_callbacks;

typedef struct bc_worker_process_route {
    bc_worker_process_adapter adapter;
    bc_adapter_budget budget;
} bc_worker_process_route;

/* Initialize caller-owned storage once. Keep the route at a stable address
   until broker close has collected its live process. */
bool bc_worker_process_route_init(bc_worker_process_route *owner,
    const uint8_t *path, size_t path_length, size_t reply_limit,
    uint32_t launches, size_t wire_limit, void *codec, bc_worker_process_encode encode,
    bc_worker_process_reply_size reply_size, bc_worker_process_decode decode);

#endif
