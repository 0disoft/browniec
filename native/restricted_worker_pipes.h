#ifndef BC_RESTRICTED_WORKER_PIPES_H
#define BC_RESTRICTED_WORKER_PIPES_H

#include <windows.h>

enum { BC_WORKER_STDIN, BC_WORKER_STDOUT, BC_WORKER_STDERR, BC_WORKER_PIPE_COUNT };

typedef struct bc_worker_pipes {
    HANDLE broker[BC_WORKER_PIPE_COUNT];
    HANDLE child[BC_WORKER_PIPE_COUNT];
} bc_worker_pipes;

/* Open connected unidirectional byte pipes with a logon-scoped DACL. The
   broker endpoints support overlapped I/O and are not inheritable. The
   child endpoints are blocking and may only be inherited by the launcher.
   Start with a zeroed owner and serialize access. No I/O is pending on
   return. A failed open leaves the owner empty. */
DWORD bc_worker_pipes_open(bc_worker_pipes *pipes);

/* Close the broker's copies of the child endpoints after suspended launch. */
void bc_worker_pipes_close_child(bc_worker_pipes *pipes);

/* The broker must reap any outstanding I/O before closing its endpoints. */
void bc_worker_pipes_close(bc_worker_pipes *pipes);

#endif
