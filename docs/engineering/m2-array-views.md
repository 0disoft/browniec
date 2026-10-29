# Checked array range descriptors

Implementation: `0c22fb8`.

The private owner layer now provides table-local, read-only range descriptors
over live scalar arrays. These are groundwork for later guest views, not guest
borrow values. No source syntax, opcode, verifier rule, Fuel price or version
capability changes in this slice.

## Representation and operations

`array_owners::View` stores a root slot/generation token, the original element
tag and length, and a half-open element range `[start,end)`. It contains no
payload pointer and owns no storage. The private API provides:

| Operation | Behavior |
| --- | --- |
| `view(table, token, start, end, capacity)` | Validate a live array and create a root-relative range |
| `view_length(table, view, capacity)` | Revalidate and return the selected element count |
| `subview(table, parent, start, end, capacity)` | Validate a parent-relative range and flatten it to the same root |
| `view_read(table, view, index, bytes)` | Revalidate and decode one selected scalar |
| `view_utf8(table, view, bytes)` | Revalidate a u8 range and return its current UTF-8 validity |

All six scalar element tags use element indices, including multi-byte aligned
arrays. Reading uses the existing scalar codec, preserving signed/unsigned bit
patterns and canonical bool rejection. Record tokens cannot become array views,
even when their byte extent matches an array shape.

Each operation resolves the current live token and validates the full bounded
owner/arena chain before trusting shape or range fields. The original element
and length must match. Creation requires `start <= end <= root.length`;
subview bounds are relative to the parent, not the entire root. A read requires
`index < end-start`. These checks precede subtraction, range translation and
payload access. All translated element indices are at most 4,096, and a valid
u8 layout proves byte-address additions cannot exceed the initialized extent.

Empty ranges are valid, including at an owner's end. Empty reads fail with
Bounds. Empty u8 UTF-8 ranges return true only after the root, shape, backing
bounds and range have passed validation. A stale empty view cannot bypass
lifetime checks. Invalid UTF-8 is false; stale tokens, wrong shape, records,
invalid metadata or backing bounds are errors.

## Scope and lifetime obligations

Release, clear and slot reuse invalidate descriptors through the existing
generation checks, including deferred reclamation of non-top owners. The view
layer introduces no owner slot, reservation, payload copy or metadata mutation.
It can create descriptors when all sixteen owner slots are occupied. No view
registry or hidden reference count is introduced.

This is a read-only interface, not an immutable loan: descriptors do **not** pin
roots or reject owner writes, assignment, movement or release. A permitted owner
write remains visible to a subsequent descriptor read or UTF-8 check. There is
no cached validity result. Future guest integration must add independently
verified loan origins, conflicts, cleanup and metering before exposing views.

Tokens remain local to the originating table. The trusted caller must pair a
descriptor with that same table and its associated backing storage, and keep
state stable during an operation. This API does not authenticate foreign/cloned
tables or a different same-sized byte allocation. Current backing *bounds* are
revalidated on every read; backing identity is still a caller obligation.

Metadata work covers sixteen owner slots in at most two bounded passes plus
a token lookup. Scalar reads and range operations are O(16); UTF-8 checks are O(16+K) for K selected bytes, with K at
most 4,096. Helpers use fixed scratch space and add no payload allocation or
copy. These are code-path bounds; allocator, process-memory and timing
measurements were not performed. The helpers have no guest Fuel entry point yet.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --views` and
repeat with `--profile release`. Development and release each passed sixteen native groups:
five new view groups, five owner regressions and six UTF-8 IR/VM regressions.
Each also passed fourteen tool-free CLI check/run sentinels covering scalar/array/record behavior,
all existing UTF-8 argument forms and honest rejection of Buffer/view syntax.

New coverage includes all six scalar tags at representation boundaries,
nonzero aligned bases, nested and empty ranges, multi-byte UTF-8 surrounded by
invalid bytes, truncated and continuation-only selections, current data after
mutation, noncanonical bool reads, dropped/cleared/reused roots, forged
shape/range metadata, maximum-usize indices, missing backing bounds and record
token rejection. Full-table tests create 100 descriptors with all sixteen owner
slots occupied and compare every owner field, arena counter and backing byte.
The maximum-length u8 range is scanned and its last element is read.

The [Windows evidence](../evidence/m2-array-views-windows-20261030.json) records
both profiles, matching input hashes, compiler/SDK identity, outcomes and both
retained CLI hashes. Earlier receipts remain historical for their exact inputs.
Full frontend/CLI suites, storage suites beyond the owner/UTF-8 selections,
Buffer lifecycle/Provider probes, M0, Linux, DLL embedding, Windows isolation,
packaging, allocator instrumentation and timing benchmarks were not rerun.
