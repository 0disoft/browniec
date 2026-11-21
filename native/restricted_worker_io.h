#ifndef BC_RESTRICTED_WORKER_IO_H
#define BC_RESTRICTED_WORKER_IO_H

#include <windows.h>
#include <stdint.h>

typedef struct bc_worker_io {
    HANDLE event;
    HANDLE pipe;
    OVERLAPPED operation;
} bc_worker_io;

/* Zero-initialize and keep this owner at a stable address. The event is
   private, manual reset and noninheritable. Calls are serialized. */
DWORD bc_worker_io_open(bc_worker_io *io);

/* Use exactly one direction and an overlapped pipe. ERROR_IO_PENDING keeps
   the operation, pipe and caller's buffer borrowed until poll reports a
   terminal status. Count is written only for successful completion. */
DWORD bc_worker_io_start(bc_worker_io *io, HANDLE pipe, uint8_t *read,
    const uint8_t *write, DWORD length, DWORD *count);
DWORD bc_worker_io_poll(bc_worker_io *io, DWORD *count);

/* A cancellation request, including ERROR_NOT_FOUND, releases nothing. */
DWORD bc_worker_io_cancel(bc_worker_io *io);

/* ERROR_IO_PENDING leaves the entire owner unchanged. Reap first. */
DWORD bc_worker_io_close(bc_worker_io *io);

#endif
