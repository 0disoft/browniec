# Automatic descriptor enumeration for explicit host shutdown

Implemented and verified on Windows in development and release. Root
`fairyc check` passed (75 sources, 611 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`. The
[receipt](../evidence/m2-buffer-host-sweep-windows-20261029.json) identifies tested
inputs, native binaries and allocator counters.

## Reuse the existing inventory

`buffer_host_sweep` enumerates the existing owner table instead of maintaining a
second list of Buffer tokens. The host still owns native resources and supplies
the resource associated with each offered token. Sweep state owns no native
roots: it contains a phase, 16-bit visited mask, offered token and the one shared
close Plan required by the [multi-root protocol](m2-buffer-host-batch.md).

| Operation | Behavior |
| --- | --- |
| `empty()` | Create New control state with no offer or pending close |
| `begin(sweep, pool, table, ledger)` | Validate control/table state, enter Active and invoke Pool shutdown. A partial cleanup error preserves Active so other roots can still be visited |
| `next(sweep, table)` | Offer the highest live unvisited slot. Repeat the same offer until it is attempted; return None when the current pass is exhausted |
| `close_current(root, sweep, pool, table, ledger)` | Consume the host-supplied resource through `close_stopped`, using the offered token rather than a second caller-supplied token |
| `retry(sweep, table)` | Reset the visited mask only after all live entries have been attempted and no offer/Plan remains |
| `finish(sweep, pool, table, ledger)` | Require no offer or pending Plan and delegate complete table/accounting/Pool validation to `finish_all`; then enter Finished |

The order is descending **slot index**, not reverse allocation order: slot reuse
does not encode allocation chronology. Holes and inactive entries are skipped.
Repeated `next` validates the offered generation and cannot silently substitute
a replacement owner. Invalid token shape, control phase or mask beyond 16 bits
returns State. New/Finished state rejects enumeration and attempts; Finished
also rejects restart/retry while repeated valid finish preserves accounting.

## Failures and explicit passes

Successful close marks the slot visited and clears its offer. Failed preflight
returns the owned Buffer and also advances this pass, allowing the next root to
be offered. The caller must retain that returned resource and repair its failure.
None means only pass exhaustion: failed live roots remain in the authoritative
table, so finish rejects them. No missing root is silently considered closed.

Explicit retry begins another pass over remaining live entries. It rejects an
outstanding offer, active close Plan or a live slot not yet attempted this pass.
It does not automatically retry Pool shutdown or replay failed work. After a
partial lease failure, repair/retry Pool cleanup separately while the Plan is
inactive, then restart enumeration. Ordinary guest admissions remain blocked by
the stopped Pool.

If native destruction completed but close finish failed, the offer and shared
Plan stay pinned. `next` returns that same token even though its owner descriptor
is already retired. Only matching empty-root accounting retry can complete it;
passing another nonempty root returns that resource unchanged. Retry/finish
cannot discard the Plan or proceed to another owner. After settlement, normal
enumeration resumes. Existing checked aggregate coverage, backing validation,
retirement, real resource destruction and refunds remain in `close_stopped`.

## Native evidence

Both profiles passed **99 scenarios**: four new sweep cases and 95 existing
lifecycle/allocator cases. All **198 processes** exited with `live=0`. Each new
case owns two distinct native payloads (256 and 64 bytes) and allocates/frees
exactly twice. Enumeration, failure retention and pass retry add no allocation.

| New case | Executed coverage |
| --- | --- |
| `close-sweep-order` | Slot 15 then slot 0 with holes; stable repeated offers; unknown mask and generation mismatch reject; Open/premature operations reject; both roots close without a caller-supplied close token |
| `close-sweep-preflight` | Length mismatch returns the offered root and advances to another owner; exhausted pass cannot finish while the failed root lives; explicit repaired retry enumerates only the survivor |
| `close-sweep-leases` | Partial Pool shutdown leaves a failed lease while another root closes; the full metadata charge remains held. Explicit repaired Pool cleanup plus pass retry closes the retained root |
| `close-sweep-accounting` | A deliberately constructed failed-finish Plan retains its offer over an already retired descriptor, blocks other roots/retry/finish and resumes enumeration only after accounting repair |

All new cases restore Instance usage to zero, retain 32 bytes of unrelated
Engine usage and preserve peaks at 2,560/2,592. Both owner generations advance
once. Repeated finish does not change counters. The accounting case constructs
the retry state with existing close APIs; it does not inject a concurrent failure
inside native destruction.

The archive rechecks 39 inputs, 33 generated sources (17 product modules and
16 fixtures), generated lock and two binaries. Counts cover FY system-heap
allocations, not all process memory. No timing benchmark is claimed.

## Remaining boundary

The module enumerates descriptors, not raw pointers, and cannot locate or retain
a Buffer that the caller lost. Root/token binding remains trusted; matching
length/capacity does not authenticate identity. Use one stable Sweep and its
table/ledger/Pool, preserve returned resources and do not clone control state,
mutate descriptors behind an offer, use independent close Plans or mutate
accounting while a Plan is active.

This bounded caller-owned metadata has no separate quota admission and adds no
guest API or authenticated capability. It is not an owning Instance container,
automatic scope cleanup, VM dispatch or scheduler integration. Each call has
fixed 16-slot bounds and no Fuel charge; repeated host calls are caller-driven.

Native SDK destruction failure, arbitrary corrupted roots and concurrency remain
outside the evidence. Provider injection was not rerun because provider/storage
code is unchanged. Full native/CLI suites, M0, Linux, DLL embedding, isolation,
packaging and elapsed-time performance were not run. Earlier receipts remain
historical for their exact recorded inputs.
