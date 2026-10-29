# Private cooperative Buffer UTF-8 cancellation

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (71 sources, 567 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-cancel-windows-20261029.json)
records the tested inputs and both native binaries.

`buffer_utf8_meter::begin_cancellable(cancel_requested, table, token, buffer,
fuel)` and `step_cancellable(cancel_requested, table, buffer, max_bytes, cursor,
fuel)` add a caller-supplied cancellation snapshot around the
[prepaid scanner](m2-buffer-utf8-meter.md). Their separate ControlError enum adds
Cancelled without changing the existing metered Error enum or entrypoints.

## Ordering and state

| Condition at entry | Result and effects |
| --- | --- |
| Cancellation requested | Return Cancelled before Fuel, token, table, backing, byte-budget or Cursor validation. Begin creates no Cursor. Step sets only `cursor.active=false`, preserving offset, carry and all other fields. No Fuel is consumed. |
| No cancellation, insufficient Fuel | Return Fuel; preserve the counter and entire Cursor, as in the prepaid API. |
| No cancellation, sufficient Fuel | Prepay the existing price and delegate. Token/State/Utf8 errors retain their charge; completion and failure keep the existing scanner semantics. |

Cancellation is terminal for that Cursor, including when a scalar is split across
calls. Clearing the cancellation snapshot does not resume it: with sufficient
Fuel, the next non-cancelled step pays its price and returns State. Repeated
cancellation is idempotent and returns Cancelled without charging, including for
an already completed/failed Cursor. A fresh begin is an explicit new scan, not an
automatic retry or replay. The caller owns any persistent cancellation signal and
decides whether a fresh begin is permitted.

Checking cancellation at the boundary performs O(1) work, allocates nothing, reads
no Buffer bytes, and changes no token, descriptor, native storage or lifecycle
accounting. Retained offset/carry are diagnostic progress, not valid text output.
Cancellation does not refund Fuel spent by earlier successful steps.

With no cancellation, one step still processes at most 256 new bytes. A request
that arrives after the caller captured `cancel_requested=false` is observed only
when the caller polls again before a later call. No atomic flag, callback,
cross-thread synchronization, scheduler or elapsed-time latency guarantee is
introduced. The same-root lifetime and immutability obligations remain in force
until completion or abandonment. Guest borrow enforcement and VM/source dispatch
remain unfinished.

Cancelling a scan does not cancel an independent prepared Buffer replacement.
That Plan and its reservation remain active. The trusted caller must still choose
the normal publication/commit path or drop the replacement before cancelling its
reservation. The API does not destroy roots, release charges, roll back external
effects, or restart work automatically.

## Focused Windows evidence

Development and release each passed 67 native scenarios: four new cancellation
cases and 63 lifecycle/allocator regressions. All 134 processes exited with
`live=0`. The authoritative fixture is
`probes/m2-buffer-failure/src/utf8_cancel.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `utf8-cancel-entry` | Cancelled begin precedes invalid token, missing backing and zero Fuel; a MAX Fuel counter stays unchanged. Cancellation prevents empty-input completion at zero Fuel. A fresh non-cancelled empty scan consumes exactly 260 units and completes; cancelling that completed Cursor remains free. |
| `utf8-cancel-mid` | A four-byte scalar is cancelled after 1, 2 and 3 consumed bytes. Offset/carry and zero Fuel are preserved, active is cleared, repeated cancellation is free, and a non-cancelled retry pays for State. Explicit fresh begin completes with exactly 656 Fuel and unchanged original content/table. |
| `utf8-cancel-errors` | Non-cancelled begin/step propagate Fuel, Token, State and Utf8 with existing charges. Cancellation wins over malformed identity/offset, missing backing and zero byte budget. Cancelling before a broken continuation returns Cancelled without reading it; a fresh non-cancelled scan reaches the Utf8 failure and retains its charge. |
| `utf8-cancel-pending` | Scan cancellation during a real replacement reservation leaves the complete Plan, all descriptors and all nine ledger fields unchanged. Replacement destruction and explicit reservation cancellation restore usage 320/352 with peaks 768/800. The retired scan cannot resume; a fresh scan validates the original bytes. |

Each of the first three new processes allocates/frees one initial 256-byte payload.
The pending process allocates/frees two payloads for the old root and replacement.
Cancellation and both control entrypoints add no heap allocation. Counts cover
the FY system heap, not all process memory.

The archive rechecks 29 input hashes, 23 generated sources (thirteen byte-identical
production modules and ten fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
Whole-Instance Buffer cleanup remains unfinished.
