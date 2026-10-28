# Private Buffer replacement transactions

Status: implemented and verified in development and release.
See the [Windows receipt](../evidence/m2-buffer-replacement-windows-20261029.json).

`src/buffer_replacement.fy` connects [owner descriptors](m2-buffer-owners.md),
[native storage](m2-buffer-storage.md) and [admission](m2-buffer-growth.md).
This private transaction adds snapshot validation around preparation and metadata
completion. Guest Buffer syntax, borrow tracking, VM instructions, Fuel prices
and capability flags remain unchanged.

## Preparation

`prepare` takes a table-local source token, the trusted caller's native Buffer,
limits, an exclusive ledger and an inactive Plan. It checks token identity before
native metadata or ledger arithmetic. Native capacity/initialized length must
match the descriptor. Generation MAX returns `Owners` before reservation or
allocation, because the same slot cannot publish a next generation safely.

Storage preparation reserves old-plus-new payload and owner charges, allocates
a replacement and copies initialized bytes. On success the Plan captures all
16 descriptors, all 9 ledger fields, the source token and replacement capacity.
It becomes active only after successful preparation. The original token and table
remain unchanged and valid for the old native root until completion.
Quota, overflow, no-growth and invalid state preserve the old root. Storage's
Allocation/Provider failure paths cancel after unpublished helper cleanup; their
fault-injection coverage is still deferred. An active Plan or pending ledger
rejects nested preparation. A failed prepare does not activate a new Plan.

## Completion

The trusted caller must keep table, ledger, old root and replacement associated
and exclusive until it chooses one of these paths:

- Replace the owning local with the returned Buffer, dropping the old allocation,
  then call `commit` with the published native root. Commit checks the exact
  descriptor and ledger snapshots, source token, accounting transaction and new
  capacity/initialized length before changing shared state. It derives the next
  generation without wrapping, updates capacity in the same slot and installs
  final accounting. No callback, allocation or fallible operation follows that
  descriptor update. Unrelated slots are unchanged.
- Drop the unpublished replacement, then call `cancel`. Cancellation checks both
  snapshots and transaction arithmetic before restoring usage. It keeps the old
  table/token and all observed accounting peaks.

Both consume the Plan by clearing its active flag. Duplicate completion returns
`State`. Changed metadata anywhere in the table, even a vacant slot's generation,
or any changed ledger field blocks completion without partially updating either
shared object. The caller must resolve an unexpected mismatch; no automatic replay,
rollback of native publication or retry is attempted.

For old capacity 256 containing `keep`, preferred replacement capacity 384 reserves
Instance usage 768, then commit finishes at 448 and advances generation once.
Cancellation restores 320 and keeps the original generation, retaining peak 768.
An Instance ceiling of 704 selects capacity 320; committing finishes at 384.
A full 16-slot table can grow an existing owner because completion reuses its slot;
the simultaneous replacement's logical owner charge is still reserved separately.
Generation MAX owners must instead be released through the existing lifecycle;
this transaction does not migrate them to a free slot.

## Scope and caller obligations

Owning-root replacement is explicit because the pinned compiler does not support
whole resource replacement through a mutable reference. This API cannot establish
that the caller published its root, dropped the old root, or dropped an abandoned
replacement. Thus root publication and descriptor/accounting completion are not
one atomic operation. `commit` must not receive a merely prepared root while the
old allocation still lives. Snapshot rejection after incorrect native publication
does not restore that old allocation.

The Plan is a plain private snapshot, not a sealed, authenticated or linear guest
handle. Consistent forged/replayed snapshots, wrong roots with matching metadata,
wrong tables, cross-Instance identity, concurrent mutation and duplicate root
registration remain outside this boundary. The caller must not bypass this API's
completion through lower-level ledger functions while its Plan is active.
Borrow lifetimes, final root destruction and descriptor/Plan memory admission
remain future work. Snapshot/table scans are bounded at 16 slots; preparation
copies O(initialized length) bytes, while completion performs no payload copy.

## Focused verification

Verified selection per profile: 8 replacement groups, 8 descriptor groups,
7 storage groups, 8 admission groups and 8 CLI sentinels, via
`tools/verify-m2-buffer-replacement.py`.

Replacement groups cover successful publication/token invalidation and replay;
abandonment/cancellation with minimum-capacity retry; pre-allocation failures;
stale-token precedence over invalid backing/ledger; exhausted generation rejection;
wrong published capacity and duplicate cancellation; changed ledger and unrelated
slot rejection without partial updates; and full-table growth/nested preparation.
The full-table fixture duplicates a native root only to exercise descriptor capacity;
production callers must bind one slot per owning root.

The CLI sentinels preserve scalar/array/record behavior and reject guest Buffer
syntax. They do not execute guest Buffer ownership. Full suites, M0, Linux,
isolation, DLL embedding, packaging, allocator-failure injection, allocation
instrumentation and elapsed-time performance were not run. Earlier receipts
remain historical evidence for their original inputs.

Both profiles ran from `f5f9abc` with the implementation uncommitted. The
archived receipt identifies the tested working tree through 259 matching
input hashes. Compiler/SDK identities matched and both retained executable
hashes were rechecked. The baseline SHA identifies provenance rather than
the new implementation.
