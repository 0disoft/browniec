#ifndef BC_RESTRICTED_WORKER_STAGE_H
#define BC_RESTRICTED_WORKER_STAGE_H

#include <windows.h>

typedef struct bc_worker_stage {
    PSID profile;
    wchar_t name[64];
    wchar_t directory[4096];
    wchar_t image[4096];
    HANDLE pinned_image;
    BOOL owns_directory;
    BOOL owns_image;
} bc_worker_stage;

/* A trusted stop probe returns ERROR_SUCCESS, ERROR_TIMEOUT or ERROR_CANCELLED. */
typedef DWORD (*bc_worker_stage_stop)(void *context);

// Use a zero-initialized stage. Close it after the worker has been reaped,
// including when setup returns an error after acquiring some resources.
DWORD bc_worker_stage_open(bc_worker_stage *stage, const wchar_t *application,
    bc_worker_stage_stop stop, void *context);
BOOL bc_worker_stage_close(bc_worker_stage *stage);

/* Reclaim a successful session's stage before publishing its result.
   Preserve a stop observed before cleanup and sample again on clean close. */
DWORD bc_worker_stage_finish(bc_worker_stage *stage, bc_worker_stage_stop stop, void *context);

#endif
