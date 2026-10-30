# Private shared read-only array slices

The [source successor](m2-array-utf8-slices.md) now exposes lexical read-only
u8 slice bindings and UTF-8 scans with reverse-order scope/exit cleanup. Guest
indexing, length, reslicing, aliases, parameters/results and temporary roots
remain unavailable. The private backend contract below is unchanged.

The [private VM successor](m2-array-slice-vm.md) now adds verified origins,
open/UTF-8/close instructions, metering and whole-invocation cleanup on VM
success/error. Guest syntax and automatic lexical lowering remain pending.
The native registry contract below retains its explicit caller obligations.

Implementation: `12071a8`.

The private `array_slices` module provides sixteen retained range entries over
existing live scalar-array owners. It composes checked
[views](m2-array-views.md) with explicit [read sessions](m2-array-read-leases.md).
It is groundwork for guest slices: no guest syntax, VM instruction, independent
IR loan verification, Fuel charge or version capability is added.

## Handles and shared sessions

A `Pool` contains sixteen metadata slots. Each live slot stores its generation,
checked root-relative `View` and root `ReadLease`. A `Ticket` identifies a slot
and generation; it contains no payload pointer. The native caller owns the pool.

| Operation | Behavior |
| --- | --- |
| `open(pool, table, root, start, end, capacity)` | Validate a range and publish one independently closable entry |
| `subslice(pool, parent, table, start, end, capacity)` | Flatten parent-relative bounds into a new independent entry |
| `length(pool, ticket, table, capacity)` | Revalidate and return the selected element count |
| `read(pool, ticket, table, index, bytes)` | Revalidate and decode one selected scalar |
| `utf8(pool, ticket, table, bytes)` | Revalidate and scan a selected u8 range |
| `close(pool, ticket, table, capacity)` | Retire one entry; end its root session only when no sibling remains |
| `clear(pool, table, capacity)` | Stage metadata cleanup and publish only after every close succeeds |

The first entry for a root acquires its explicit read session. Subsequent
entries in the same pool share that session without another begin. Closing a
parent does not invalidate separately registered children or peers. The last
entry ends the session, restoring owner writes, fills, destination assignment,
result transfer and release. Value copies remain allowed and begin unleased.
Unrelated explicit sessions remain owned by their original caller; a pool never
joins an externally acquired session or another pool's session.

Copying a ticket aliases one entry; it does not register another lifetime.
Closing either alias invalidates both. Reused entry slots advance their own
generation independently of the root/session generations. Maximum generations
retire to zero and never wrap; exhausted slots cannot be reused.

## Validation and failure behavior

All live pool entries are validated before an operation changes state or returns
a range result. Validation checks active root/session identity, original scalar
shape, range and the current owner/arena chain against the supplied backing
capacity. Reads then use the existing leased scalar codec; UTF-8 checks use the
leased u8 scan. Empty ranges remain valid and return true for UTF-8 only after
validation. Empty reads fail. Parent-relative bounds are checked before addition;
maximum-usize bounds cannot wrap into a valid range.

Slot admission and range validation precede a new session acquisition. Failures
leave pool metadata, owner metadata and payload unchanged. `close` retains its
entry when validation or session end fails. `clear` works on fixed-size copies of
pool/owner metadata and commits only the two slot arrays after successful staged
closes. It never copies payload, releases owners, changes arena usage or ends
unrelated sessions. Invalid/stale retained metadata blocks cleanup for explicit
caller repair; this is not an automatic abort recovery mechanism.

The registry creates no payload allocation, copy or owner slot. All sixteen
owners may be occupied while sixteen slice entries remain usable. Pool metadata
is additional fixed native state; no process-memory/allocator measurement is
claimed. With D=16 descriptor slots and O=16 owner slots, ordinary operations
perform O(D*O) bounded metadata work, and UTF-8 adds O(K) for K selected bytes
(up to 4096). Staged clear performs O(D*D*O) work and O(D+O) metadata scratch.
These bounds are deliberately conservative and are not timing measurements.

## Native integration obligations

Pools, tickets, owner tables and backing allocations are table-local. Native
callers must preserve their association, keep state stable during a call and
balance explicit close/clear. A pool must not be cloned into independently
managed registries. Raw owner session termination, direct payload writes and
metadata corruption are native caller violations; handles fail on stale sessions
but do not authenticate foreign/cloned tables or same-sized backing allocations.
Guest origins, lexical exit cleanup, Instance abort wiring and metering must be
implemented before exposing `ref u8[]` values. Existing source ranges and Fuel
prices remain unchanged; no `array_utf8_slices` capability is advertised.

## Focused verification

Run `python -B tools/verify-m2-array-utf8.py --profile development --slices` and
repeat with `--profile release`. Each profile passed 28 native groups: seven new
slice groups, five sessions, five views, five owner groups and six array-result
VM groups. Each also passed 14 tool-free CLI sentinels, including honest rejection
of guest slice and Buffer syntax.

New tests cover independent parent/child/peer cleanup, duplicate ticket aliases,
root conflict gates and allowed copies, nested/empty/multibyte UTF-8 ranges,
all six scalar tags, aligned storage, 4096-byte scans, sixteen entries on one
root and sixteen roots at full owner capacity, admission failures, malformed
metadata, short backing, stale handles, slot/session exhaustion without wrap,
atomic failed clear and unrelated external sessions. Snapshots compare every
pool/owner field and backing bytes for selected rejected mutations.

The [Windows evidence](../evidence/m2-array-slices-windows-20261030.json) records
both profiles with matching input hashes, compiler/SDK identity, native reports,
original receipt hashes and retained CLI hashes. Full suites, other frontend
matrices, M0, Linux, DLL embedding, Windows isolation, packaging, allocator
instrumentation and timing benchmarks were not rerun.
