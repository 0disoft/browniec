#define WIN32_LEAN_AND_MEAN
#include "restricted_worker_io.h"
#include "restricted_worker_stream.h"

DWORD bc_worker_io_open(bc_worker_io *io) {
    if (io->event || io->pipe) return ERROR_INVALID_STATE;
    io->event = CreateEventW(NULL, TRUE, FALSE, NULL);
    return io->event ? ERROR_SUCCESS : GetLastError();
}

DWORD bc_worker_io_start(bc_worker_io *io, HANDLE pipe, uint8_t *read,
    const uint8_t *write, DWORD length, DWORD *count) {
    if (io->pipe) return ERROR_BUSY;
    if (!io->event || !pipe || pipe == INVALID_HANDLE_VALUE ||
        (read == NULL) == (write == NULL) || !length || length > BC_WORKER_IO_WINDOW)
        return ERROR_INVALID_PARAMETER;
    if (!ResetEvent(io->event)) return GetLastError();
    io->operation = (OVERLAPPED){.hEvent = io->event};
    const BOOL complete = read ? ReadFile(pipe, read, length, NULL, &io->operation) :
        WriteFile(pipe, write, length, NULL, &io->operation);
    if (!complete) {
        const DWORD status = GetLastError();
        if (status == ERROR_IO_PENDING) io->pipe = pipe;
        return status;
    }
    io->pipe = pipe;
    return bc_worker_io_poll(io, count);
}

DWORD bc_worker_io_poll(bc_worker_io *io, DWORD *count) {
    if (!io->pipe) return ERROR_INVALID_STATE;
    DWORD done = 0;
    const BOOL complete = GetOverlappedResult(io->pipe, &io->operation, &done, FALSE);
    const DWORD status = complete ? ERROR_SUCCESS : GetLastError();
    if (status == ERROR_IO_INCOMPLETE) return ERROR_IO_PENDING;
    io->pipe = NULL;
    if (complete) *count = done;
    return status;
}

DWORD bc_worker_io_cancel(bc_worker_io *io) {
    if (!io->pipe) return ERROR_INVALID_STATE;
    return CancelIoEx(io->pipe, &io->operation) ? ERROR_SUCCESS : GetLastError();
}

DWORD bc_worker_io_close(bc_worker_io *io) {
    if (io->pipe) return ERROR_IO_PENDING;
    if (io->event && !CloseHandle(io->event)) return GetLastError();
    *io = (bc_worker_io){0};
    return ERROR_SUCCESS;
}
