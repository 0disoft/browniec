# M2 Array Owner Lifetimes

- Scope: private Instance-local metadata over caller-owned backing bytes.
- Implementation: [`array_owners.fy`](../../src/array_owners.fy).
- Harness: [`verify-m2-owners.ps1`](../../tools/verify-m2-owners.ps1).
- Evidence: [Windows owner receipt](../evidence/m2-array-owners-windows-20261023.json).

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

Next: independent array copies that preflight destination capacity and source
validity before publishing new ownership. Full source-array, borrow, allocator,
worker, DLL, packaging and performance gates remain open.
