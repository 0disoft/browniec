#ifndef BC_RESTRICTED_WORKER_H
#define BC_RESTRICTED_WORKER_H

#include <windows.h>

typedef struct bc_restricted_worker {
    HANDLE job;
    HANDLE process;
    HANDLE thread;
} bc_restricted_worker;

/* Requested heap bytes for the worker's process attribute list.
   Zero means Windows could not size the list. */
SIZE_T bc_restricted_worker_launch_heap_bytes(void);

/* The broker owns the executable, working directory, profile SID, and three
   inheritable pipe endpoints. Command line storage may be modified by Win32.
   Start with a zeroed owner. Success leaves the verified worker suspended.
   Failure leaves the owner empty and does not start a second process. */
DWORD bc_restricted_worker_prepare(bc_restricted_worker *worker,
    const wchar_t *application, wchar_t *command_line, const wchar_t *directory,
    PSID profile, HANDLE child[3], SIZE_T commit_bytes, DWORD user_cpu_ms);

/* Fail closed if the worker was not suspended exactly once. */
DWORD bc_restricted_worker_resume(bc_restricted_worker *worker);

/* Close the kill-on-close Job while keeping process and thread handles. */
BOOL bc_restricted_worker_stop(bc_restricted_worker *worker);

/* Close the Job to stop the worker and retain the process handle until exit.
   A false result requires another poll. The broker owns pipe I/O separately. */
BOOL bc_restricted_worker_close(bc_restricted_worker *worker);

#endif
