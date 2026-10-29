# Private prepaid Buffer UTF-8 validation

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (71 sources, 564 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-utf8-meter-windows-20261029.json)
records the tested inputs and both native binaries.

`buffer_utf8_meter` adds explicit Fuel accounting around the existing
[resumable scanner](m2-buffer-utf8-scan.md). Both `begin(table, token, buffer,
fuel)` and `step(table, buffer, max_bytes, cursor, fuel)` take an exclusive native
`usize` Fuel counter. Begin returns the scanner's private Cursor; step returns
its completion boolean. Neither operation allocates or changes Buffer data,
descriptors, tokens or lifecycle accounting.

## Prepayment and errors

| Operation | Logical charge |
| --- | --- |
| `begin_cost()` / `begin` | 128 |
| `step_cost(B)` / `step` | `128 + 4 * min(B, 256)` |

The fixed allowance covers bounded descriptor/cursor checks and carry work; the
per-request allowance covers SDK scanning and bounded suffix handling. These are
private conservative logical prices, not measured CPU instructions, elapsed time,
or a published guest opcode schedule. The arithmetic is capped before multiplying,
so even a MAX byte request costs at most 1,152 and cannot overflow.

Each call computes its price without reading the table, Buffer or Cursor. If the
counter is below that price, it returns Fuel with the entire counter and Cursor
unchanged. This precedence applies even when the token, backing or Cursor is bad.
There is no automatic refill or retry; a trusted caller can explicitly add budget
and resume the same Cursor while maintaining the source's lifetime and contents.

With sufficient Fuel, the call deducts the full price before invoking scanner
validation. Token, State and Utf8 errors retain that charge. Charging is based on
the bounded request rather than unvalidated Cursor arithmetic, actual remaining
input or the point where an error occurs. An empty completion with request 1
costs 132; request 256 costs 1,152 even if fewer bytes remain. Request 0 pays the
128-unit preflight price and returns State. An inactive Cursor also costs the
requested price before State is returned. The existing scanner's error semantics
are preserved: metadata errors leave progress unchanged, while Utf8 retires the
Cursor without committing the failing step's offset/carry.

For a valid N-byte input and fixed positive request B, total price is
`128 + max(1, ceil(N/min(B,256))) * (128 + 4*min(B,256))`.
Pricing is independent of UTF-8 scalar boundaries. For the 259-byte fixture,
begin plus requests MAX and 3 consumes `128 + 1152 + 140 = 1420`; using 259
one-byte requests consumes `128 + 259*132 = 34316`.

## Scope and caller boundary

This is private runtime Fuel plumbing. No VM opcode, dispatcher, verifier, source
syntax, error-code number or version capability changes. Existing unmetered
scanner/SDK helpers remain lower-level trusted APIs. Actual VM dispatch must
select the metered entrypoints and own the counter before guest work can use them.

All resumable-scanner obligations remain: keep the same native root alive and
immutable throughout a scan, use the correct table, and treat the Cursor as plain
private progress rather than an authenticated guest handle. Content writes may
preserve generation; Fuel accounting does not enforce a borrow across calls.
The caller can yield or poll cancellation between steps, but scheduler callbacks,
guest borrow enforcement and guest Buffer/text integration remain unfinished.

## Focused Windows evidence

Development and release each passed 63 native scenarios: four new metered cases
and 59 lifecycle/allocator regressions. All 126 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/utf8_meter.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `utf8-meter-success` | Empty-root completion; exact prices at requests 0/1/256/257/MAX; a four-byte scalar spanning the 256-byte cap; exact charges and seven units left over after a two-step scan; 259 one-byte steps finish with exactly zero Fuel. |
| `utf8-meter-fuel` | Begin with 127 units, step with zero or 131 units, and MAX request with 1,151 units return Fuel without changing the counter or Cursor. Exact budgets resume saved carry. A MAX Fuel counter safely subtracts the clamped charge. After completion, a short budget returns Fuel; sufficient budget pays for State. |
| `utf8-meter-errors` | Fully prepaid invalid-token and missing-root begin errors consume 128. Zero byte request, malformed Cursor, unrelated invalid descriptor, invalid identity and missing backing consume their step charge without progress changes. Broken-continuation and final-truncation errors consume Fuel and retire the Cursor while preserving the previous offset/carry. |
| `utf8-meter-pending` | A four-byte scalar is scanned before/during/after replacement discard/cancel. Wrong replacement backing incurs a paid State error without progress changes. Exact total 788 includes begin, four successful one-byte steps and one rejected one-byte step. Plan/table/reserved usage stay unchanged during reads; cancellation restores usage 320/352 and keeps peaks 768/800. |

The success case seeds one 512-byte native allocation; Fuel/errors each seed one
256-byte allocation. Each frees that allocation at exit. Pending allocates/frees
two payloads for the old root and replacement. Metered begin/step add no heap
allocation. Counts cover the FY system heap, not all process memory.

The archive rechecks 28 input hashes, 22 generated sources (thirteen byte-identical
production modules and nine fixture modules), generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
Whole-Instance Buffer cleanup remains unfinished.
