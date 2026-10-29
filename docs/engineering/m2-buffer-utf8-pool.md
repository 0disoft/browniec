# Private host registry for leased UTF-8 sessions

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (73 sources, 590 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-pool-windows-20261029.json)
records the tested inputs and both instrumented native binaries.

`buffer_utf8_pool` keeps up to 16 [leased sessions](m2-buffer-utf8-session.md) in
caller-owned host state. Callers keep a slot/generation Ticket instead of owning
loose Session copies. The Pool stores metadata/progress only, never native roots.
It adds no heap allocation or payload copy. The pinned compiler rejects mutation
of nested-record array elements, so the same fixed 16 slots use explicit fields
with internal bounded get/put dispatch.

## Admission and ticket lifecycle

`begin(cancel_requested, pool, table, source, buffer, ledger, fuel)` returns
Cancelled before inspecting the Pool when cancellation is already requested.
Otherwise it checks registry consistency and selects a vacant non-retired slot.
A malformed or full Pool returns State without changing Fuel or acquiring a lease.
It then delegates to Session begin, including its 256-unit prepayment and owner/
backing/accounting checks. Publication occurs only after successful acquisition;
no fallible operation follows that acquisition.

`step(cancel_requested, pool, ticket, table, buffer, max_bytes, fuel)` validates
Ticket identity before registry consistency, Fuel or native root access. Invalid,
stale, inactive and out-of-range tickets return Token, even for cancellation.
The underlying Session still governs scan progress, prepayment and cleanup:

- Partial progress or Fuel shortage keeps the same live Ticket and lease.
- Completion, cancellation or a scan error that successfully releases the lease
  retires the registry slot before returning its outcome.
- Failed cleanup keeps the slot live, including its retired Cursor and unresolved
  lease, for explicit repair/cleanup.

Retirement clears stored Session state and advances the slot generation once.
Generation MAX retires permanently to zero instead of wrapping. A stale Ticket
cannot cancel or abandon a replacement operation in the reused slot. Owner token
generation is separate and is unchanged by registry retirement.

Registry consistency requires each live slot to have a nonzero generation, a held
Session and valid source-token shape. Live slots cannot name the same owner slot
twice. Inactive slots cannot retain held/active Session state. A failed-cleanup
Session may have an inactive Cursor while remaining held.

## Individual and batch cleanup

`abandon(pool, ticket, table)` performs Session cleanup without Fuel or a native
root argument. It retires the slot only when the lease was released. Repeating
abandon on that retired Ticket returns Token.

`drain(pool, table)` attempts cleanup of every live slot in index order. It keeps
going after an individual error, retiring successful slots and retaining failed
ones. If any cleanup fails, it returns State; earlier successful releases are not
rolled back. After the caller resolves metadata inconsistencies, another drain
visits only the remaining live entries. On complete success it returns the number
of sessions released by that call; draining an empty Pool returns zero.

Registry bookkeeping is bounded host work and is not separately charged to Fuel;
the Session prices remain `256` for begin and `256+4*min(request,256)` for a normal
step. Registry validation uses at most 16 slot visits and 120 source-pair checks.
Drain attempts at most 16 lease releases, each with the existing 16-slot owner
validation. Storage and all work bounds are independent of payload size apart
from the delegated bounded scan. No elapsed-time benchmark is claimed.

## Caller and integration boundary

Use one stable Pool with its associated owner table and native root bindings.
The original registry slice requires explicit drain. The
[shutdown successor](m2-buffer-utf8-shutdown.md) adds one-way admission closure
and retryable cleanup; callers must invoke that hook before discarding host state.
Neither slice installs an Instance destructor. Dropping/overwriting
the whole plain Pool can still lose cleanup state. Do not clone/replay Pool or
Session metadata, end its leases through lower-level APIs, or use raw native
mutation/destruction while registered operations depend on roots.

Tickets are Pool-local private identities, not authenticated guest capabilities
or cross-Instance handles. Matching native metadata does not authenticate a root.
Pool storage admission, guest dispatch, scheduler integration, thread safety and
complete Instance root destruction/accounting cleanup remain unfinished. The
explicit 16-slot limit is a private implementation bound, not a public language
capacity guarantee.

## Focused Windows evidence

Development and release each passed 79 native scenarios: four new registry cases
and 75 lifecycle/allocator regressions. All 158 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/utf8_pool.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `pool-lifecycle` | Cancelled/short-budget begin does not publish state; Fuel shortages preserve complete registered progress and its write lock. Exact refuelling finishes, retires the Ticket once, clears Session state and rejects later use without charging Fuel. |
| `pool-tickets` | An old Ticket cannot cancel/abandon a new scan in its reused slot. Invalid Ticket precedence, malformed inactive state and duplicated live-source metadata reject without releasing the live operation. Wrong-backing failure and valid cancellation each release and retire their Ticket; cancellation needs no Fuel or valid backing. |
| `pool-capacity` | Sixteen real caller-owned roots (one allocated, fifteen empty) fill the registry. Full admission consumes no Fuel. A MAX-generation slot retires permanently; another released slot can be reused, and drain releases all 15 remaining operations. Every root stays live through those checks. |
| `pool-drain` | With two distinct live roots, a deliberately stale source token prevents one cleanup while the other succeeds and retires. The unresolved lease stays recorded; after fixture metadata repair, retry releases only that remaining session. Repeated drain returns zero. |

Every new scenario allocates/frees exactly one initial 256-byte payload. The extra
empty roots add logical owner charges but no payload allocation. Registry and
cleanup operations add no heap allocation. Counts cover the FY system heap, not
all process memory; logical owner teardown is outside this fixture's claim.

The archive rechecks 34 input hashes, 28 generated sources (fifteen byte-identical
production modules and thirteen fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, the additional descriptor/replacement native suite, M0,
Linux, DLL embedding, isolation, packaging, elapsed-time performance and Provider
inconsistency fault injection were not run for this slice.
