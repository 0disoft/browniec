# Anchored read-only source collection (C01 OS primitive)

Implemented: `native/anchored_sources.c/.h` opens an explicit caller-owned root,
collects only the supplied relative member names, and returns an owning bounded
byte snapshot or an error. This is a native Windows filesystem primitive, not a
JSON parser, source admission result, capability grant, CLI feature, or VM/Engine
binding. No ambient root discovery, directory enumeration or glob expansion exists.

## Boundary and API

`bc_as_root_open(wide_path, units, &root, &error)` accepts only an explicit
`X:\...` root on a local fixed NTFS volume. It rejects UNC/device/relative roots,
trailing separators (except `X:\` itself), dot/dot-dot, invalid components and
SUBST-style subdirectory roots. Limits are 1024 UTF-16 units and 64 components.
The initial drive handle must resolve to the volume GUID root itself; the volume
identity and filesystem are queried from that handle. Drive mapping is resolved
once during this explicit acquisition, not reused to reopen later members.
The caller owns the returned opaque anchor until `bc_as_root_close`.

`bc_as_collect(root, paths, count, source_bytes, &snapshot, &error)` takes 1..16
explicit byte-span paths and a total byte ceiling of 0..4096. Its native spelling
predicate ports the authoritative `project_names::member_path`: ASCII letters,
digits, underscore, dot, hyphen, slash-separated nonempty components, <=240 bytes,
`.brc` or `.fy` lowercase suffix, no trailing dot components or reserved device
stems. ADS colons, backslashes, absolute names, NUL, non-ASCII, dot/dot-dot and
wildcards fail. Case-folded duplicate paths and duplicate volume/file identities
fail before publication. Every leaf must also have exactly one hard link,
even when only one relative name is supplied. Names are copied into fixed
scratch before filesystem traversal. The verifier pins the reviewed grammar hash
and checks `source_snapshot`'s actual 16/4096 bounds to require an intentional
review if the authority changes; it does not invent a new project schema.

`bc_as_count`, `bc_as_size` and `bc_as_file` expose initialized counts, total source
bytes, names, exact byte spans and actual file identities. Views remain valid until
`bc_as_snapshot_close`, independently of source edits or anchor closure. Root and
snapshot outputs must initially be NULL; failures leave them unchanged. Root,
request buffers, output pointers and concurrent call serialization are trusted
native caller obligations, not a public hostile-pointer security API. Callers
must not close an anchor concurrently with collection. `bc_as_error` records the
failed request/check index, Win32 error or signed NTSTATUS; it is diagnostic only.
`bc_as_root_identity` returns identity metadata, not a guest authority token.

## Handle-based acquisition and TOCTOU protection

Every filesystem component is opened separately through `NtCreateFile` with the
already-open parent in `OBJECT_ATTRIBUTES.RootDirectory`, a single literal name,
`FILE_OPEN`, `FILE_OPEN_REPARSE_POINT`, synchronous I/O and `FILE_SHARE_READ` only.
There is no preflight string-containment check followed by a full-path reopen.
Microsoft documents both directory-relative resolution and bypassing the opened
object's normal reparse processing in
[NtCreateFile](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile).
Its user-mode attribute list names zero/OBJ_CASE_INSENSITIVE; this implementation
uses OBJ_CASE_INSENSITIVE and does **not** assume OBJ_DONT_REPARSE is a supported
security contract for that call. It also avoids depending on the documentation's
restricted `FILE_DIRECTORY_FILE` option combinations: object kind is checked on
the returned handle before traversal/read.

The opened root, every root ancestor from the volume root, every member ancestor
and each leaf is inspected through the handle. Any reparse attribute/tag, wrong
object kind, deleted object, unsupported information query or mismatched volume
fails closed. Ancestor handles remain live through collection; root ancestors
remain live until anchor close. The collector never follows a reparse target.
Microsoft describes the reparse semantics in
[Reparse Points and File Operations](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points-and-file-operations).

No write or delete sharing is offered. Ordinary conflicting writers/renames are
refused by the OS, as described under sharing modes in
[CreateFileW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew).
Sharing flags do not prohibit every metadata operation: the collector therefore
rechecks tags and directory/file change times, and compares leaf identity, size,
link count, creation/write/change times and attributes before publication. A real
metadata-write interleaving is tested and rejected as Changed. Reopening by a
validated string or comparing path prefixes is never used to authorize a child.
These checks protect the rooted object walk; they are not a global atomic
multi-file filesystem transaction or a proof against a hostile kernel/filter.
Leaves with `NumberOfLinks != 1` fail as Identity on every leaf inspection,
including the initial open before any source read and the final pre-publication
check. This deliberately rejects a single inside-root alias for a same-volume
outside-root file, as well as entirely inside-root hard-linked files. The count
comes from [FILE_STANDARD_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_standard_info).
[Hard Links and Junctions](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions)
documents that hard links name the same file on one volume. This conservative
acceptance rule does not establish historical provenance or exclusive ownership
against old aliases/handles. Canonical relative names, root/ancestor/leaf reparse
rejection and the handle-relative walk remain the primary containment boundary.

The returned value is an owned bounded copy, not a point-in-time consistent file
snapshot. In particular, this primitive does not establish point-in-time file
consistency against preexisting writable mappings; sharing modes and before/after
metadata checks are not a proof of that property. There is no writable-mapping
consistency test or claim. Once returned, copied bytes are independent of later
changes to the underlying file.

Handle metadata uses
[GetFileInformationByHandleEx](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex),
[FILE_ATTRIBUTE_TAG_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_attribute_tag_info),
[FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)
and [FILE_BASIC_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_basic_info).
The actual 128-bit ID plus volume serial is compared, not a fabricated filename ID
or content hash. Local NTFS support is checked through
[GetVolumeInformationByHandleW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumeinformationbyhandlew)
and the resolved volume root through
[GetFinalPathNameByHandleW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlew).

## Bounded reading and ownership

A fixed bounded scratch snapshot and handle arrays are used. The leaf's length
must fit the remaining total budget before any source read or snapshot allocation.
Each synchronous [ReadFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile)
request is capped by the remaining known length; short nonempty reads advance,
premature EOF fails. One extra byte per leaf probes exact EOF. Thus initialized
source bytes are <=4096 and read traffic is <=4096 plus at most 16 EOF-probe bytes.
Oversized files are rejected before reading. There is no file-size-driven malloc.
After all reads and rechecks pass, one fixed-size heap object is allocated and
published. Partial failures close all temporary handles and publish no snapshot.
The root uses one fixed-size heap object after root spelling/length validation.
No UTF-8, language, import, metadata, grant or entry binding is implied by these
raw bytes. OS reads are synchronous; bounded bytes do not imply a wall-time or
cancellation guarantee. Network/non-NTFS filesystems are deliberately unsupported.
The much larger accepted policy/manifest metadata ceilings do not expand the
current 16-file/4096-source-byte implementation bounds.

## Executed focused verification

Run `python tools/verify-anchored-sources.py`; both development `/Od` and release
`/O2` are selected by default. MSVC, a complete Windows SDK, Python and the ability
to create actual symbolic links (Developer Mode or the relevant privilege) are
required. Missing symlink support fails the test; it is never silently skipped.
There is no fairyc invocation or root lock refresh. Existing native build helpers
are reused only to resolve MSVC and inspect actual PE stack values.

Five groups per profile exercise actual temporary directories and files, exact
owned bytes and handle identities, source changes after collection, spelling/ADS/
device/escape errors, 16/17 files, exact/over/aggregate byte bounds, zero bytes,
wrong kinds, multi-link leaves including a single requested same-volume
outside-root hard-link alias (actual volume/128-bit ID and link count verified),
missing files/roots, explicit allocation failures,
actual root/member/leaf junction or symbolic-link rejection, conflicting writers,
and deterministic OS rename/write/metadata-change interleavings. Root/ancestor
and leaf handles are live at those mutation checkpoints. Repeated success/failure
loops assert unchanged process handle counts and zero remaining native allocations.
The callbacks/allocation fault controls exist only in a separate test object;
production object symbols are checked for their absence in each profile.

Junction fixtures use the documented
[FSCTL_SET_REPARSE_POINT](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_set_reparse_point)
and [mount-point buffer](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_data_buffer),
with a compile-time buffer-header offset assertion. Symlinks are created using
[CreateSymbolicLinkW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createsymboliclinkw).
Fixture removal is checked after the host exits; Windows junction cleanup is not
implemented by recursively traversing reparse targets. Only the verified run's
fixture directory is passed to cleanup.

Generated native objects, executables, test fixtures, logs and receipts stay below
`build/anchored-sources/<UTC-run>/`. Receipts include exact source/helper hashes,
commands, OS build, compiler identity, production/test object hashes, executable
hashes, native group output and fixture cleanup. CL/_CL_/LINK overrides are rejected,
native execution uses an empty tool PATH, and PE stack reserve/commit must remain
the default 1MiB/4KiB. No custom stack is requested. Broader source/VM/Engine/CLI
integration, hostile-kernel behavior, network/other OS support and global filesystem
snapshot semantics remain outside this concrete C01 prerequisite.
