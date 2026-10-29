# Private resumable Buffer UTF-8 validation

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (70 sources, 559 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-scan-windows-20261029.json)
records the tested inputs and both native binaries.

`buffer_utf8_scan::begin(table, token, buffer)` creates a private Cursor after
checking token identity, the complete 16-slot owner table and exact native
initialized length/capacity. The Cursor starts active at byte offset zero,
including for empty input. It captures the source token, length and capacity.

`step(table, buffer, max_bytes, cursor)` processes at most
`min(max_bytes, 256, length - offset)` new bytes. Successful nonempty steps advance
by exactly that amount. `ok(false)` means more work is required; `ok(true)` means
the whole initialized range has passed and retires the Cursor. A positive-budget
step completes an empty input without reading bytes. A zero budget returns State.
The caller can yield or abandon the Cursor between calls without native cleanup.

## Chunk boundaries and state

The implementation reuses the pinned SDK's UTF-8 validator for complete slices.
It performs at most two SDK calls per step: one for a scalar assembled from the
previous suffix, and one for the complete remaining prefix. A backward search of
at most three positions finds a possibly incomplete trailing scalar. At most
three trailing bytes persist in a fixed four-byte assembly array. The scanner
does not copy the payload or allocate; the SDK remains responsible for checking
overlong encodings, surrogate encodings and the Unicode upper bound.

Every step checks active state first, then resolves the captured token before
native metadata access. Stale/invalid identity returns Token. Malformed table,
backing mismatch, changed source length/capacity, malformed Cursor fields or a
zero budget returns State. Offset must be within length; carry size is at most
three, is no greater than offset, and describes an incomplete 2/3/4-byte sequence
with continuation bytes and zeroed unused slots. These checks precede subtraction,
end-offset addition or byte access. Metadata errors leave the Cursor unchanged.

Local progress is staged until a step succeeds. Malformed UTF-8 or an incomplete
scalar at the final byte returns Utf8 and retires the Cursor without committing
that step's offset/carry. Those fields retain the previous successful step and
are not an error location. Another call on a completed or failed Cursor returns
State. No automatic restart or replay is attempted.

An active offset includes any unvalidated trailing suffix. Neither offset nor
`ok(false)` certifies a valid prefix as text; only `ok(true)` accepts the complete
input. A malformed partial sequence may be rejected when its scalar completes
or when the final byte is reached, rather than at the first offending byte.

## Caller and integration boundary

The trusted caller must bind the same table and native root, keep that root alive,
and prevent content writes from begin through completion or abandonment. Native
borrows do not span calls. Content writes can preserve token generation, so this
API cannot detect changes to already consumed bytes. Cursor fields are plain
private progress, not authenticated, linear or guest-accessible state. Consistent
forgery, replay, concurrent content mutation and matching-metadata wrong roots
remain outside this boundary. Completed results are not permanent text flags.

Read-only scanning can resume on the old root while a replacement is pending and
after it is discarded/cancelled; table/token/backing checks still apply. There is
no ledger argument and no quota mutation. Buffer bytes, length/capacity, tokens,
owner descriptors and accounting remain unchanged.

Each call does O(16 + processed bytes) work with O(1) auxiliary space. With a fixed
positive budget B, a valid N-byte input takes `max(1, ceil(N/min(B,256)))` calls.
Only the fixed carry may be revisited; the full prefix is not rescanned. The caller
can poll cancellation between steps. Fuel charging, a scheduler/cancellation
callback, guest borrow enforcement, Buffer/text syntax and VM dispatch are not
connected by this slice. This private primitive alone does not close M2's full
source-level UTF-8 milestone. No elapsed-time benchmark is claimed.

## Focused Windows evidence

Development and release each passed 59 native scenarios: four new resumable-scan
cases and 55 lifecycle/allocator regressions. All 118 processes exited with
`live=0`. The authoritative fixture is
`probes/m2-buffer-failure/src/utf8_scan.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `utf8-scan-valid` | Empty native root, allocated empty range, binary UTF-8 boundaries including NUL/BOM/U+10FFFF, mixed Korean/emoji/ASCII, and a 259-byte input with a four-byte scalar starting at byte 255. Budgets 1, 2, 3, 4, 5 and MAX agree with the synchronous SDK API; every successful step advances exactly its bounded allowance. |
| `utf8-scan-invalid` | All 256 isolated bytes, overlong 2/3/4-byte encodings, surrogate and out-of-range scalars, illegal leaders, every truncated prefix of a four-byte scalar, a truncated three-byte scalar, a broken continuation, stray and repeated continuation bytes and an invalid tail. The same six budgets agree with the synchronous SDK. UTF-8 failures retire progress while preserving prior offset/carry; valid input succeeds after fresh begin. |
| `utf8-scan-state` | Zero budget, missing/wrong backing, malformed unrelated descriptor, changed source length, nine independently changed Cursor fields, stale-token precedence, unchanged progress on rejection and valid generation-MAX completion. |
| `utf8-scan-pending` | A scalar is scanned across four one-byte steps before, during and after replacement discard/cancel. Wrong replacement backing is rejected without progress changes. Table, active replacement Plan and reserved ledger stay unchanged during reads; cancellation restores usage 320/352 and retains peaks 768/800. |

The valid case seeds one 512-byte native allocation; invalid/state each seed one
256-byte allocation. Each frees its single allocation at exit. The pending case
allocates/frees two payloads for the old root and replacement. Begin and repeated
steps add no allocation. Counts cover the FY system heap, not all process memory.

The archive rechecks 26 input hashes, 20 generated sources (twelve byte-identical
production modules and eight fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
Whole-Instance Buffer cleanup remains unfinished.
