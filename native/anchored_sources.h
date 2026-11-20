#ifndef BC_ANCHORED_SOURCES_H
#define BC_ANCHORED_SOURCES_H
#include <stddef.h>
#include <stdint.h>
#include <wchar.h>

/* Private Windows OS primitive, not a public VM/host ABI. Native pointers must
   be live caller-owned memory. Explicit root only; never discovers any files. */
#define BC_AS_FILES 16u
#define BC_AS_BYTES 4096u
#define BC_AS_PATH 240u
#define BC_AS_ROOT_CHARS 1024u
#define BC_AS_ROOT_COMPONENTS 64u

typedef struct bc_as_root bc_as_root;
typedef struct bc_as_snapshot bc_as_snapshot;
typedef struct bc_as_path { const uint8_t *data; size_t length; } bc_as_path;
typedef struct bc_as_identity { uint64_t volume; uint8_t file[16]; } bc_as_identity;
typedef struct bc_as_view {
    const uint8_t *name; size_t name_length;
    const uint8_t *bytes; size_t length; bc_as_identity identity;
} bc_as_view;
typedef enum bc_as_status {
    BC_AS_OK=0, BC_AS_ARGUMENT, BC_AS_NAME, BC_AS_LIMIT, BC_AS_OS,
    BC_AS_REPARSE, BC_AS_KIND, BC_AS_IDENTITY, BC_AS_CHANGED,
    BC_AS_ALLOCATION, BC_AS_UNSUPPORTED, BC_AS_DEADLINE
} bc_as_status;
typedef struct bc_as_error { uint32_t win32; int32_t ntstatus; size_t index; } bc_as_error;

/* Exact project_names::member_path spelling predicate; no I/O or allocation. */
int bc_as_member_path(const uint8_t *path,size_t length);
/* Caller owns the resulting anchor and must close it. Only explicit X:\... on
   a local fixed NTFS volume, <=64 components, <=1024 UTF-16 units. Every ancestor
   from the volume root remains open, no write/delete sharing, until root_close.
   No UNC, relative root, device namespace, SUBST subdirectory or trailing slash.
   *out must be NULL. Failure leaves it unchanged; error is diagnostic only. */
bc_as_status bc_as_root_open(const wchar_t *path,size_t length,bc_as_root **out,bc_as_error *error);
void bc_as_root_close(bc_as_root *root);
bc_as_status bc_as_root_identity(const bc_as_root *root,bc_as_identity *out);
/* Read one explicit UTF-16 configuration leaf under the same root used for
   source collection. Destination bytes are defined only on success. */
bc_as_status bc_as_read_config(const bc_as_root *root,const wchar_t *name,size_t units,
                              uint8_t *out,size_t capacity,size_t *length);
/* All-or-error publication of bounded owned copied bytes; no point-in-time file
   consistency or global filesystem transaction is promised.
   1..16 explicit relative names; total source_bytes <=4096. All requested names
   are validated before I/O. Reject case-folded duplicate names and duplicate file
   identities. Each leaf must have exactly one hard link at every inspection,
   even if only one alias was requested. No JSON/UTF-8/source parsing here.
   No callbacks in production. Caller serializes collect/close for the same root.
   *out must be NULL; failure publishes nothing and releases temporary handles. */
bc_as_status bc_as_collect(const bc_as_root *root,const bc_as_path *paths,size_t count,
                          size_t source_bytes,bc_as_snapshot **out,bc_as_error *error);
/* Absolute Windows interrupt-time ticks; zero disables expiry checks. */
bc_as_status bc_as_collect_until(const bc_as_root *root,const bc_as_path *paths,size_t count,
                                size_t source_bytes,uint64_t deadline,bc_as_snapshot **out,bc_as_error *error);
size_t bc_as_count(const bc_as_snapshot *snapshot);
size_t bc_as_size(const bc_as_snapshot *snapshot);
bc_as_status bc_as_file(const bc_as_snapshot *snapshot,size_t index,bc_as_view *out);
void bc_as_snapshot_close(bc_as_snapshot *snapshot);
#ifdef BC_ANCHORED_SOURCES_TEST
#include <windows.h>
/* Deterministic OS interleavings and allocator failure, test build only. */
void bc_as_test_checkpoint(unsigned stage,HANDLE handle);
void bc_as_test_fail_alloc_after(long count);
long bc_as_test_live_allocations(void);
#endif
#endif
