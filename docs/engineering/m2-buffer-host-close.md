# Explicit host shutdown of one native Buffer root

Implemented and verified on Windows in development and release. Root
`fairyc check` passed (74 sources, 599 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`. The
[receipt](../evidence/m2-buffer-host-close-windows-20261029.json) records the tested
inputs, instrumented native artifacts and allocator counters.

## Ownership-returning shutdown

`buffer_host_close::shutdown(root, source, pool, table, ledger, plan)` takes
ownership of one caller-bound native Buffer and returns `Result<usize, Buffer>`.
On success it returns remaining Instance usage. On failure it returns ownership
of the surviving root, which the caller must retain if cleanup is to be retried.
The error payload is an owned resource rather than a borrowed alias or an error
code. Stages remain discoverable through the associated Pool and close Plan.

For an inactive Plan it executes:

1. Shut down the associated session Pool, releasing its leases and logical charge.
2. Run the existing checked close begin to retire the selected owner token while
   retaining its full payload/owner charge and complete accounting snapshot.
3. Move the owned Buffer into a nested scope. Its actual SDK resource cleanup
   destroys the native allocation when that scope ends.
4. Run checked close finish to return the payload plus 64-byte owner charge.

Destruction is now inside the host shutdown operation, before owner refund. The
caller no longer has to insert a root destruction step between begin and finish.
Shutdown adds no allocation, payload copy, Fuel charge, policy-limit check or
external-effect replay. It preserves unrelated Engine usage and observed peaks.

## Failure and retry stages

| Failure stage | Returned root and retained state | Explicit retry |
| --- | --- | --- |
| Pool cleanup/refund | Original root; unresolved leases/charge and Closing remain recorded | Repair metadata/accounting and pass the returned root again |
| Close begin | Original root and inactive Plan; Pool cleanup/refund may already have committed | Repair preflight state and retry; no second Pool refund |
| Close finish after destruction | Empty root; active Plan and payload/owner charge remain | Preserve Plan and accounting, repair inconsistency and retry finish only |

An active Plan selects the accounting-only retry path. It requires Closed and
unadmitted Pool state, the Plan's source token and an empty supplied root. A
nonempty root, mismatched source or wrong Pool phase returns that root without
destroying it or changing the ledger. The existing finish then independently
validates all table/accounting snapshots and subtraction bounds. The active
Plan clears only on successful accounting completion.

Earlier cleanup is not rolled back when later preflight fails. A completed call
leaves the owner token stale. Repeating shutdown with that token returns the
supplied empty root as an error; it cannot refund again or advance generation.
An empty error payload alone does not identify a stage (the original Buffer may
itself be empty); inspect the retained Plan/Pool and keep their associations.

## Native evidence

Development and release each passed **91 scenarios**: four new host-close cases
and 87 existing lifecycle/allocator cases. All **182 processes** exited with
zero tracked live allocations. Each new case allocates/frees exactly one initial
256-byte payload and adds no allocation during shutdown or retry.

| New scenario | Executed coverage |
| --- | --- |
| `close-host-success` | A partially scanned leased root is drained, retired, destroyed and refunded in one call with no Fuel; old token repetition preserves final usage and generation |
| `close-host-retry` | Stale lease-source generation makes cleanup fail; ownership, payload and charges survive; repairing the fixture metadata allows successful shutdown |
| `close-host-preflight` | A descriptor length mismatch fails after committed Pool shutdown and returns the root; a pending growth reservation also blocks root close; cancel/repair permits retry without another metadata refund |
| `close-host-accounting` | A still-live root is rejected for an active Plan. The fixture then explicitly destroys it and constructs the documented failed-finish state; malformed accounting, wrong Pool phase and mismatched source preserve the Plan, and repaired empty-root retry refunds once |

The accounting test deliberately constructs the retry state using existing
begin/destruction APIs; it does not inject a race or native failure between the
new helper's destruction and finish. Checks cover final FY system-heap counts,
not all process memory or a failed native Buffer destructor.

The shared harness now copies sixteen product modules and fourteen fixtures
byte for byte, and rechecks 36 inputs, 30 generated sources, generated lock and
both binaries. The Provider probe was also rerun against the expanded module
selection: four faults and four controls per profile, 16 processes with `live=0`.
Its focused [receipt](../evidence/m2-buffer-provider-host-close-windows-20261029.json)
retains that distinct test-binary/injection scope.

## Integration boundary

This is one explicit host operation over one owned root, not a complete Instance
owner or an automatic destructor. It drains the associated Pool (including any
other registered roots' sessions), but destroys only the supplied root. Other
roots and their charges remain caller-owned. Use stable root/token/table/ledger/
Pool/Plan associations, retain error resources and do not interleave close
snapshots with other accounting or owner mutation. Native identity remains a
trusted host binding; equal length/capacity does not authenticate a root.

Arbitrary corrupted roots, failed SDK destruction, automatic Instance lifecycle,
guest syntax/VM dispatch, scheduler and thread safety remain unfinished. Full
native/CLI suites, M0, Linux, DLL embedding, isolation, packaging and elapsed-time
performance were not run for this slice. Earlier receipts remain historical.
