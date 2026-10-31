# Private exclusive array sessions

This is the native owner-layer foundation for mutable scalar slices. It adds
explicit exclusive sessions, not guest mutable-slice syntax or VM dispatch.
Public readonly scalar slices retain their existing contract.

Implementation: `78685b1`.

## Entry, access and exit

`begin_write(table, root, start, end, capacity)` validates the full owner/arena
chain, exact live scalar-array token, half-open range and available session
generation before changing metadata. It locks the whole root, including for an
empty selected range. A shared read session or another exclusive session blocks
entry. Record roots cannot enter an array session.

The returned `WriteLease` contains the checked view and session generation.
`exclusive_length`, `exclusive_read` and `exclusive_write` revalidate the token,
session, element tag, original length, range and backing on every use. Indexing
is relative to the selected range. The existing scalar codec covers `i32`,
`bool`, `i64`, `u8`, `u32` and `usize`, including signed and unsigned cell edges.
Writes stage at most eight canonical bytes before publishing one element.
Invalid values, bounds, descriptors and backing leave bytes and session state
unchanged. Read operations still reject invalid bool bytes.

While the root is exclusive, ordinary root and bare-view reads, UTF-8 checks,
view construction, writes, fills, copies, assignment sources/destinations,
result-transfer preflight and new shared/exclusive sessions fail. Both array
and mixed array/record CALL copy batches reject exclusive sources against the
original table before any payload or owner publication. Release and whole-table
clear also fail; unrelated roots remain usable.

`end_write` revalidates the complete lease before unlocking. A failed end keeps
the lock and metadata for explicit repair/retry. Ending any copy of the ticket
invalidates all its copies. This is one session, not multiple independent loans.

Read and write sessions share the existing `read_generation` epoch. Both kinds
advance it on successful end. Old read tickets cannot close a new writer, and
old writers cannot close a new reader or writer. The maximum epoch is usable
once; closing it stores zero instead of wrapping. Ordinary owner access and
release remain possible after exhaustion. A recreated root has a different
owner generation and a fresh session epoch.

The full metadata validator rejects simultaneous read/write flags, locks on
dead/free or record owners, and active sessions with zero epochs.

## Limits and integration boundary

The existing sixteen-slot owner table is retained. Metadata adds one boolean
per owner; no process-memory or native-layout size measurement is claimed.
Session entry/exit creates no owner, extent, payload clone or allocation path.
Checks remain bounded by the existing O(16) metadata passes. Each element write
encodes at most eight bytes; this is structural accounting, not a benchmark.

Leases are private table-local metadata. The trusted native caller must preserve
the table/backing association, keep tickets private, route access through checked
APIs and explicitly balance session exit. Public native structs are not an
authentication boundary against a caller forging descriptors, copying tables or
writing raw backing bytes. No subloan registry, splitting, reborrowing, returned
borrow, automatic abort cleanup or runtime mutability bit is added here.

Guest integration still needs origins, exclusive borrow-flow validation,
mutability checks, instruction builders, metering, dispatch and lexical/error
cleanup. No opcode, Fuel price, version capability or guest admission changes.

## Focused verification

```text
python -B tools/verify-m2-array-utf8.py --profile development --write-leases
python -B tools/verify-m2-array-utf8.py --profile release --write-leases
```

The selection includes six exclusive-session groups and regressions for five
read-session, five owner, seven shared-slice and nine CALL-copy groups: 32 native
groups in total. CLI selection includes fourteen tool-free sentinels and the
192-case public readonly scalar-slice matrix. Development and release each passed
all 32 selected native groups and 206 CLI cases. Both matched 351 identical
current input hashes; pinned compiler, retained CLI and public matrix receipt
identities were rechecked. See the
[Windows evidence](../evidence/m2-array-write-leases-windows-20261101.json).

Full native suites, full M1, other M2 suites, Linux, M0, isolation, packaging,
allocator and timing checks are outside this selection. Earlier receipts remain
historical for their original source hashes. No push, publication, packaged
release or deployment is part of this local delivery.
