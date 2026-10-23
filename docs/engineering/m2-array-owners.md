# M2 Array Owner Lifetimes

- Scope: private Instance-local metadata over caller-owned backing bytes.
- Implementation: [`array_owners.fy`](../../src/array_owners.fy).
- Harness: [`verify-m2-owners.ps1`](../../tools/verify-m2-owners.ps1).
- Evidence: [Windows owner receipt](../evidence/m2-array-owners-windows-20261023.json).
- Copy increment: [Windows copy receipt](../evidence/m2-array-copy-windows-20261023.json),
  verified separately by [`verify-m2-copy.ps1`](../../tools/verify-m2-copy.ps1).

This slice adds typed allocation records and generation-checked tokens on top of
the [array storage primitives](m2-array-storage.md). Array source syntax and
aggregate VM instructions remain unavailable.

## Creation and access

One table holds 16 descriptors and a bounded allocation-order array. Each occupied
descriptor stores the canonical element tag/length, pre-alignment mark, payload
base/end, live state, and generation. A token contains only slot and generation;
read/write derive the type and extent from the matching descriptor.

Creation validates the table, reserves a reusable descriptor, then uses the
existing fallible storage initializer. The descriptor is published only after
the complete payload is initialized. Descriptor pressure, byte quota, and invalid
fill values fail without changing bytes, generations, order, or the used cursor.

Before payload access, the token must name an occupied live descriptor with the
same nonzero generation. A stale token is rejected even with an empty backing
view. The table validator checks at most 16 ordered descriptors: indices are
unique, canonical aligned extents form a nonoverlapping chain from zero, and the
chain ends at the published used cursor. It checks all cursor/capacity bounds
before using payload offsets. Element operations retain the storage codec's
canonical bool, checked bounds and failure-preservation rules.

## Release, reuse, and clear

Release makes the descriptor non-live and advances its generation immediately.
Generation MAX becomes zero and permanently retires that slot; it never wraps.
Releasing a middle extent leaves its bytes and descriptor retained until all
later extents have been released. Releasing the last live suffix walks backwards
through at most 16 dead descriptors, restoring each earlier mark including its
alignment padding. Reclaimed descriptors keep their advanced generation.

Thus a reused slot/base cannot revive an old token. Retained middle holes count
toward the 16-descriptor and byte ceilings; no compaction or implicit retry occurs.
Release reports the number of reclaimed backing bytes, possibly zero.

Clear invalidates every remaining live token, preserves retired slots, empties
the order table and resets the used cursor to zero. It is whole-table cleanup,
not guest function-frame unwinding. Bytes are not erased on release or clear;
new initialization overwrites the complete payload and padding before publishing.

## Independent copies

`copy(source_token, backing_bytes, table)` derives the exact element type and
length from the live source owner. It preflights a free descriptor and a fresh
aligned extent after the existing used prefix. Source and destination bytes plus
padding must fit simultaneously; this is an old-plus-new payload peak check,
not complete Instance/Engine or metadata accounting.

Before mutation, a bool source is scanned in full and every byte must be 0 or 1.
Every fixed-width integer byte pattern is canonical, so integer arrays need no
extra value scan. Invalid source tokens, quota/descriptor pressure, invalid table
state and invalid bool bytes leave all bytes, generations and cursor/order state
unchanged. No partial destination becomes visible.

After successful preflight, copy zeroes new padding and copies the payload into
the nonoverlapping destination, then advances the cursor and publishes one new
owner token. It preserves the source owner/generation and creates no loan or
reference to the source. Mutating either array leaves the other unchanged;
releasing the source cannot invalidate its copy. Raw copied payload is bounded by
32768 bytes and the extra bool scan by 4096 bytes. No allocator or retry is added.

## Boundary and evidence

The caller must bind one table to one stable backing byte region for that table's
entire lifetime. Tokens are scoped to that table lifetime; they are not public
handles or cross-Instance capabilities. Reconstructing a fresh table with reset
generations while retaining old tokens is forbidden. No guest-controlled table
metadata or backing-region selection is admitted by these private helpers.

The owner validator is bounded by 16 records per operation. Reclamation and clear
are bounded by the same limit; initialization retains the 32768-byte payload bound.
This is not a latency measurement or a complete memory-accounting policy. The
prototype adds no heap allocation, guest GC, owner-per-element object, source move
or borrow analysis, allocator ownership, aggregate IR/Fuel, or VM frame cleanup.

Five native groups run in development and release with Fairy C `4ce12642`.
Coverage includes typed access, stale read/write/double-release rejection,
generation reuse and retirement, whole-table clear, middle-hole and padding
reclamation, descriptor/byte pressure, invalid fill rollback, and corrupt order,
extent and cursor rejection. Earlier M0, M1, layout and storage evidence is reused
after identity checks; those executions are not relabeled as new runs.

Independent array copies were implemented in the later copy increment, with
destination capacity and source validity checked before publication. Four additional native
groups in development and release cover all six scalar types, two-way mutation
independence, survival after source release, quota rejection before padding writes,
late noncanonical bool rejection, stale source/descriptor pressure, and a full
4096-element usize copy with exact 65536-byte old-plus-new capacity and guards.
The earlier five-group owner receipt remains historical; its source changes are
limited to the new copy function and the root source lock.

Next: connect arrays to independent aggregate IR verification and metering, then
source construction/indexing and VM frame lifetime rules. Full source-array,
borrow, allocator, worker, DLL, packaging and performance gates remain open.
