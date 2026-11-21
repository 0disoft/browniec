#ifndef BC_WINDOWS_SCALAR_WORKER_H
#define BC_WINDOWS_SCALAR_WORKER_H

#include <stddef.h>
#include <stdint.h>

size_t bc_scalar_worker_start(uint8_t *request, size_t capacity);
size_t bc_project_worker_begin(void);
uint32_t bc_project_worker_read(uint8_t *request, size_t length);
uint32_t bc_scalar_worker_finish(const uint8_t *result, size_t length);

/* Project host suspension. Returns 1 for a complete reply, 2 for CANCEL,
   or 0 for a terminal transport failure. Only success publishes length. */
uint32_t bc_project_worker_host(const uint8_t *request, size_t request_length,
    uint8_t *reply, size_t reply_capacity, size_t *reply_length);

#endif
