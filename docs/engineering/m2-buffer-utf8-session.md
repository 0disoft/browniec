# Private leased UTF-8 scan sessions

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (72 sources, 579 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-session-windows-20261029.json)
records the tested inputs and both instrumented native binaries.

The [host registry successor](m2-buffer-utf8-pool.md) stores up to 16 sessions
behind generation-checked Tickets and supplies batch cleanup. The loose Session
API and 75-scenario checkpoint below retain their original lifecycle scope.

`buffer_utf8_session` binds the existing [read lease](m2-buffer-read-lease.md) to
bounded UTF-8 progress. A private Session stores the lease token separately from
its Cursor and records whether the lease is still held. Session state is plain
native data; it neither owns the native Buffer nor supplies a resource destructor.

## Entry and prepayment

`begin(cancel_requested, table, token, buffer, ledger, fuel)` returns Cancelled
before reading native state or charging when cancellation is already requested.
Otherwise it prepays 256 Fuel; shortage preserves Fuel and the entire table.
It constructs the initial Cursor, then acquires the read lease. No fallible work
follows successful acquisition. Failed begin never owns a new lease and cannot
accidentally release an existing caller-managed lease. Identity, exact backing,
whole-table and idle-accounting checks retain their underlying semantics.

`step(cancel_requested, table, buffer, max_bytes, session, fuel)` prepays
`256 + 4*min(max_bytes,256)` when not cancelling. The extra fixed allowance covers
lease validation and possible terminal release in addition to scanner work.
The request is capped before arithmetic; MAX requests cost 1,280. These are
private conservative logical prices, not measured execution time or public guest
opcode prices. No payload allocation or copy is added.

With sufficient Fuel, step requires an owned reading descriptor and the same token
in the separate lease and Cursor. It then processes at most 256 new bytes using
the existing scanner. Every admitted error retains its charge. A request of zero
pays 256 and terminates with State. Inactive sessions also pay before State is
returned. A valid 259-byte input scanned with requests MAX and 3 consumes
`256 + 1280 + 268 = 1804`; a requested final span is charged even if fewer bytes
remain. Empty input completes in one positive-budget step, after acquisition.

## Lifecycle

| Outcome | Lease and Cursor |
| --- | --- |
| More input remains | Keep the lease and active progress; mutation stays blocked. |
| Insufficient Fuel | Preserve the complete Session, table and Fuel. The lease stays held for explicit resumption or abandonment. |
| Successful completion | End the lease before returning true; retire progress. |
| Token/State/Utf8 scan failure | Retire progress and attempt release using the separately captured lease token before returning the error. |
| Cancellation | Attempt release before Fuel/backing/budget checks; charge nothing and return Cancelled when cleanup succeeds. |
| Cleanup failure | Return State, retire progress and keep `held=true`. Do not report completion or forget the unresolved lease. |

`abandon(table, session)` is the explicit host-exit cleanup path. It needs neither
Fuel nor the native root, retires progress and ends a held lease. Repeated cleanup
after success returns zero without touching the table. Cancellation delegates to
this same bounded cleanup; it may perform a 16-slot descriptor scan even with zero
Fuel. Cleanup failure overrides the original error and is not silently ignored.
The trusted caller must resolve metadata inconsistencies before retrying cleanup;
it must not reacquire a lease or restart the same retired Session automatically.

The API automatically binds acquisition/release only for these executed lifecycle
paths. A caller that drops or overwrites a live plain Session without `abandon`
can still leave a lease held. Host unwinding, scope-based destruction and complete
Instance teardown are not implemented by this slice.

## Caller and integration boundary

Use the same owner table and associated native root throughout the scan. Keep the
root alive, maintain exclusive table access and use descriptor-aware mutations.
Their guards block writes, resizing, replacement, close and release while the
Session is active or suspended for Fuel. Raw SDK views, direct native destruction,
public metadata mutation, duplicate roots, forged/cloned/replayed Session state
and premature lower-level `end_read` remain outside this private boundary.

The Session is not a guest handle or general borrow checker. No VM dispatch,
source syntax, scheduler callback, cross-thread cancellation or version capability
is added. Cancellation is a caller-supplied snapshot at each call boundary. The
original scan, metered and explicit-lease APIs remain lower-level trusted tools.
Terminal release preserves tokens, bytes, capacity, initialized length and all
ledger fields; earlier effects and Fuel charges are not rolled back.

## Focused Windows evidence

Development and release each passed 75 native scenarios: four new session cases
and 71 lifecycle/allocator regressions. All 150 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/utf8_session.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `session-success` | Empty native root, automatic acquisition, write rejection, a four-byte scalar crossing the 256-byte cap, exact 1,804-unit charge with seven units left over, complete table restoration, and writes enabled after completion. |
| `session-fuel` | Begin with 255 units and steps with 259 return Fuel without mutation. Partial scalar/carry and the lease survive shortages; exact refuelling finishes and releases. Completed-session short/enough budgets preserve existing Fuel/State precedence. |
| `session-errors` | Cancelled/invalid-token/wrong-backing/dirty-ledger begin cannot leak a lease; nested begin cannot release an existing manual lease. Wrong backing, mismatched Cursor token, zero budget and malformed UTF-8 terminate and release. A malformed unrelated descriptor makes cleanup fail with `held=true`; after fixture metadata restoration, repeated abandon succeeds without Fuel. |
| `session-cancel` | Cancellation after 1, 2 and 3 bytes of a four-byte scalar releases the lease with zero Fuel even when passed missing backing and MAX/zero byte budgets. Repeated cancellation is harmless. Explicit abandonment also unlocks subsequent writing. |

Success seeds one 512-byte native payload; the other three cases each seed one
256-byte payload. Each allocates/frees exactly one payload. Session operations add
no heap allocation. Counts cover the FY system heap, not all process memory.

The archive rechecks 32 input hashes, 26 generated sources (fourteen byte-identical
production modules and twelve fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, the additional descriptor/replacement native suite, M0,
Linux, DLL embedding, isolation, packaging, elapsed-time performance and Provider
inconsistency fault injection were not run for this slice. The prior read-lease
checkpoint retains its additional development native/CLI evidence.
