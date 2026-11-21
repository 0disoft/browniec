#ifndef BC_RUNTIME_INPUT_READER_H
#define BC_RUNTIME_INPUT_READER_H
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <stdint.h>
#include <wchar.h>
#define BC_RIR_LIMIT 1048576u
#define BC_RIR_PATH_UNITS 32767u
typedef struct bc_rir_snapshot bc_rir_snapshot;
typedef enum bc_rir_status {
    BC_RIR_OK=0, BC_RIR_ARGUMENT, BC_RIR_LIMIT_ERROR, BC_RIR_KIND,
    BC_RIR_OS, BC_RIR_ALLOCATION, BC_RIR_CANCELLED, BC_RIR_DEADLINE
} bc_rir_status;
/* Private trusted-native APIs. Live pointer ranges and serialized handle use
   are caller obligations. *out must be NULL; every failure leaves it unchanged.
   limit is payload bytes, 0..1MiB. Returned immutable bytes are owned by out.
   path is an explicit absolute drive path, with no embedded NUL, length in
   UTF-16 units (excluding terminator). No search, CWD or environment expansion.
   Path resolution is trusted host authority, NOT guest filesystem containment. */
bc_rir_status bc_rir_path(const wchar_t *path,size_t length,size_t limit,
                         bc_rir_snapshot **out,DWORD *error);
/* Duplicates caller's synchronous disk/byte-pipe handle; never closes original.
   Reads from current position. Duplicate shares cursor/pipe consumption, even
   on failure. No seek/rollback, automatic retry or point-in-time consistency.
   Async, character, message-mode/nonblocking pipe handles are unsupported.
   EOF is required, including a one-byte probe at the exact limit; can block.
   Successful zero-byte pipe reads fail with BC_RIR_OS/ERROR_NO_DATA (no retry).
   ERROR_BROKEN_PIPE remains normal pipe EOF; successful disk zero is EOF. */
bc_rir_status bc_rir_handle(HANDLE input,size_t limit,bc_rir_snapshot **out,DWORD *error);
/* Apply a monotonic deadline and optional cancel predicate to redirected pipes.
   A disk handle uses the synchronous reader. The caller's handle remains open. */
bc_rir_status bc_rir_stdin(HANDLE input,size_t limit,DWORD timeout_ms,uint32_t (*cancelled)(void),
                          bc_rir_snapshot **out,DWORD *error);
size_t bc_rir_length(const bc_rir_snapshot *snapshot);
const uint8_t *bc_rir_bytes(const bc_rir_snapshot *snapshot);
void bc_rir_close(bc_rir_snapshot *snapshot);
#ifdef BC_RIR_TEST
void bc_rir_test_fail_after(long count);
long bc_rir_test_live(void);
long bc_rir_test_attempts(void);
long bc_rir_test_partial_reads(void);
#endif
#endif
