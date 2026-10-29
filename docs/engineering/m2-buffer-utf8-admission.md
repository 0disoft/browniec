# Fixed storage admission for the private UTF-8 registry

Implemented and verified in development and release on Windows by root
`fairyc check` and `python -B tools/verify-m2-buffer-failure.py`.
The [receipt](../evidence/m2-buffer-utf8-admission-windows-20261029.json) records
the tested sources, generated project and instrumented binaries.

## Fixed logical reservation

`buffer_utf8_pool::empty()` creates unadmitted host bookkeeping. Before its first
session, call `admit(pool, limits, ledger)`. It charges **2,112 logical bytes**:
a 64-byte header plus sixteen 128-byte slots, including stored Ticket generation
and scan/lease progress. The entire fixed registry is charged even when no slot
is live; retiring a session does not shrink the Pool. Caller-owned external
Ticket copies are outside this charge.

This is accounting policy, like the existing 64-byte Buffer owner charge. It
does not measure `sizeof(Pool)`, stack usage, allocator size or process RSS.
The caller supplies the plain record before admission; a hard process-memory
limit or quota-aware native metadata allocator is not implemented.

Admission requires a valid Open, unadmitted Pool and idle, consistent accounting.
It checks unsigned addition for both used counters before checking quotas.
The charge must fit both Instance and Engine ceilings; the Buffer payload object
ceiling does not apply. Failure returns State, Overflow or Quota without changing
the Pool, ledger or peaks. Duplicate admission returns State. Successful admission
updates both usage counters and observed peaks, then publishes `admitted=true`
without further fallible work. Admission also works with an unowned zero ledger.

## Use and shutdown

`begin(true, ...)` retains Cancelled precedence. Otherwise, begin requires Open
and admitted state before Fuel or byte access. It validates registry consistency,
the owner table and coverage of all live Buffer charges plus the registry charge.
Undercoverage returns State without acquiring a lease or consuming Fuel. Existing
Session checks then enforce idle accounting and the unchanged 256-Fuel prepayment.
Step prices and step/Ticket ordering are unchanged.

`abandon` and `drain` release leases but keep the whole registry charge. The
[shutdown hook](m2-buffer-utf8-shutdown.md) now takes
`shutdown(pool, table, ledger)`:

1. Enter Closing before cleanup; try every registered lease as before.
2. If cleanup fails, retain Closing, `admitted=true` and the full metadata charge.
3. Once drain succeeds, validate all owner descriptors and sum their live payload
   plus 64-byte owner charges using checked arithmetic. Require their total plus
   2,112 bytes to remain covered by Instance usage.
4. Require idle, consistent ledger state, subtract 2,112 from both usage counters,
   retain peaks, clear admission and publish Closed.

If accounting validation fails after leases have been released, shutdown returns
State while preserving the full charge and Closing state. Earlier lease releases
remain committed. Preserve the Pool, root bindings, table and ledger; repair the
inconsistency and explicitly retry. The later success refunds exactly once, and
returns only the sessions released during that successful call (possibly zero).
Repeated valid Closed shutdown returns zero and cannot refund again. An untouched
unadmitted Pool can shut down without a refund. Closed cannot be readmitted.
Cleanup takes no Fuel and does not consult current quota ceilings, so lowered
policy limits cannot trap an already held reservation.

The owner sum guards against returning metadata bytes taken from still-live
Buffer accounting. Invalid owner state, unsigned sum overflow or insufficient
coverage fails before subtraction. `release_metadata` also validates counter
ordering, peaks, idle transaction fields and subtraction bounds. Historical
peaks never decrease. Checks are bounded by the fixed 16 owners/registry slots;
admission/refund add no payload copy or heap allocation.

## Trusted host boundary

Use the same stable ledger, owner table and Pool throughout their lifetime.
The private boolean is reservation bookkeeping, not authentication of ledger
identity. Do not copy/replay Pool metadata or refund it through lower-level
accounting helpers. Serialize admission/refund with Buffer transactions; finish
or cancel a replacement first, and do not interleave them with a captured
two-phase close Plan. Such plans snapshot accounting outside the Ledger.

Admission does not charge every unrelated host record, native root binding,
temporary copy or concurrent Instance. Shutdown still requires an explicit host
call, and native root destruction/owner refunds remain separately ordered caller
steps. Common Instance ownership, automatic teardown, guest syntax/VM dispatch,
scheduler binding and thread safety remain unfinished.

## Focused Windows evidence

Both profiles passed 87 native scenarios: four new admission scenarios and 83
lifecycle/allocator regressions, updated to admit before registry use. All 174
processes exited with `live=0`. Every new scenario allocates/frees one initial
256-byte payload; metadata admission/refund adds no allocation. Counters cover
the FY system heap, not all process memory.

| Scenario | Executed checks |
| --- | --- |
| `pool-admit-success` | Unadmitted begin rejects without Fuel/lease changes; exact Instance/Engine limits with zero payload-object ceiling admit; duplicate rejects; abandon/drain keep the charge; shutdown refunds once while retaining peaks; Closed cannot reopen. |
| `pool-admit-quota` | Instance and Engine limits one byte below the charge reject independently; already-over-limit usage rejects; near-MAX Instance and Engine-only addition overflow reject without publication; explicit retry succeeds. |
| `pool-admit-state` | Nine inconsistent/pending ledger variants and malformed registry reject unchanged; real growth reservation blocks admission until cancel; zero-ledger admission/shutdown restores both counters to zero. |
| `pool-admit-release` | Undercovered begin consumes no Fuel; shutdown releases the session but retains its charge on undercoverage; pending accounting and malformed owner state prevent refunds; repair/retry refunds once without further Ticket retirement. |

Existing shutdown retry checks additionally verify the charge stays intact during
partial lease-cleanup failure. The root-close regression destroys the actual
native Buffer only after successful registry cleanup/refund and restores owner
accounting while preserving unrelated Engine usage.

The archive rechecks 34 inputs, 28 generated sources, generated lock and both
binaries. Full native/CLI suites, descriptor/replacement suite, M0, Linux, DLL
embedding, isolation, packaging, elapsed-time performance and Provider
inconsistency fault injection were not run. Earlier receipts remain historical
for their recorded inputs and scope.
