# Private Buffer read leases

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (71 sources, 570 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-read-lease-windows-20261029.json)
records the tested inputs and both instrumented native binaries.

The native owner descriptor now includes `reading`, initially false. A live root
can hold one private read lease at a time. The table remains bounded at 16 slots;
the existing 64-byte logical owner charge is unchanged. No payload copy or heap
allocation is added by lease acquisition, release or rejected mutation.

## Acquisition and release

`buffer_owners::begin_read(table, token, buffer, ledger)` checks identity and the
complete table through `writable`, then exact native initialized length/capacity.
It validates idle accounting with `growth::plan` under MAX limits: counters and
current owner coverage must be valid, and every pending-reservation field must
be clear. This is a read-only accounting check, not new memory admission or a
current policy-quota check. A pending replacement rejects acquisition before any
descriptor flag changes, preserving its captured snapshots.

After successful checks, acquisition sets only the selected descriptor's reading
flag and returns the same slot/generation token. Nested acquisition returns State.
`end_read(table, token)` checks identity, complete table and active reading state,
then clears the flag. Repeated release returns State; wrong/stale identity returns
Token without unlocking the source. Both operations preserve length, capacity,
generation, bytes and all nine ledger fields. Generation MAX can be leased because
these operations do not advance generation. Vacant descriptors cannot be reading.

## Mutation gate

`owners::writable` resolves identity and the whole table, then rejects a reading
owner with State. It is now used before mutation by:

- Raw descriptor byte writes and descriptor release.
- Guarded range writes, including empty input.
- In-capacity append, resize, truncate and clear, including no-op requests.
- Replacement preparation, including grow-and-append and grow-and-resize.
- Close begin, before token retirement or any native root destruction.

Reads, copy-out and both synchronous/resumable UTF-8 validation remain allowed.
Raw descriptor byte writes retain one bounded 16-slot validation scan rather than
adding a second scan. Replacement and close snapshot equality now includes the
reading flag. Lease operations do not admit a replacement or release its charges.

## Scanner and caller boundary

This slice provides a mutation gate and explicit lease lifecycle, not automatic
scanner acquisition/cleanup. The trusted caller begins a lease, starts/scans the
same root, and ends the lease after completion, failure or abandonment. The native
fixture exercises this around [cancellable metered scanning](m2-buffer-utf8-cancel.md).
Cancelling a scan clears its Cursor's active flag but does not end the separate
read lease; mutation remains blocked until explicit `end_read`.

The returned token is an ordinary private owner token, not a sealed/linear guest
borrow ticket. The caller must not retain/replay a released lease token to unlock
a later lease, end a lease while another operation still depends on it, register
duplicate native roots, or bypass descriptor-aware operations through raw SDK
views, native destruction or direct metadata changes. Root association, lifetime,
cross-Instance identity and exclusive table access remain trusted obligations.
The pinned compiler does not support borrowing an owned Buffer field from a
composite resource in the attempted native wrapper; this slice uses runtime gates
without adding unsafe field access or copying payloads.

Acquisition/release do O(16) descriptor work with O(1) auxiliary storage. Full
guest borrow enforcement, automatic scan/lease lifetime binding, VM dispatch and
whole-Instance native root cleanup remain unfinished. No new opcode, guest
capability or public Fuel schedule is introduced.

## Focused Windows evidence

Development and release each passed 71 instrumented native scenarios: four new
read-lease cases and 67 lifecycle/allocator regressions. All 142 processes exited
with `live=0`. The authoritative fixture is
`probes/m2-buffer-failure/src/read_lease.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `read-lease-success` | Acquisition preserves identity; nested acquisition fails without changing the complete table. Byte read, binary copy-out and UTF-8 validation work during a lease. Explicit end restores the original table, repeated end fails, and generation MAX can acquire/release without wrapping. |
| `read-lease-mutations` | Raw/guarded writes, descriptor release, append, truncate/clear, resize, all three replacement preparations and close begin reject without changing bytes, the complete table, accounting or Plan activation. Empty/equal-size operations also reject. After end, guarded writing succeeds. |
| `read-lease-state` | Invalid identity, wrong backing, a vacant reading slot, each of nine independently corrupt ledger fields and a real pending replacement reject acquisition without mutation. After replacement destruction/cancel, acquisition succeeds; a wrong-generation end does not release it. |
| `read-lease-scan` | Metered scanning reads a leased root; writes reject both during progress and after scan cancellation. Cancellation preserves the lease and ledger. Explicit end enables raw writing again without changing owner identity. |

Success/mutations/scan each allocate/free one initial 256-byte payload. State
allocates/frees two payloads for the original root and a real replacement. Lease
operations and all rejected mutations add no allocation. Counts cover the FY
system heap, not all process memory.

The archive rechecks 30 input hashes, 24 generated sources (thirteen byte-identical
production modules and eleven fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.

An additional development-only regression via
`python -B tools/verify-m2-buffer-replacement.py --profile development` passed
31 native groups (8 replacement, 8 descriptors, 7 storage, 8 admission) and eight
CLI sentinels. Scalar/array/record sentinels pass, while guest Buffer syntax still
rejects. The same archive includes that run's input hashes, native/CLI outcomes,
commands, original receipt hash and retained development CLI binary hash. These
31 groups are uninstrumented; the zero-live-allocation claim applies to the
142 instrumented processes above. This extra regression was not repeated in release.

Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
