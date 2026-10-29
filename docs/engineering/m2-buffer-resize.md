# Private Buffer resize within retained capacity

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (66 sources, 542 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
See the [Windows receipt](../evidence/m2-buffer-resize-windows-20261029.json).

`buffer_resize::within_capacity` shrinks or grows initialized length up to retained
capacity using `bytes::resize_zeroed`. It preserves the retained prefix and zeroes
every newly exposed suffix byte, including bytes hidden by earlier
[truncate or clear](m2-buffer-truncate.md). It neither grows capacity nor retries.

## Contract

Preflight checks run in this order, before SDK mutation:

1. `owners::describe` resolves the table-local slot/generation token and validates
   the entire owner table. Invalid identity returns `Token`; malformed table state
   returns `State`. Native length and capacity must exactly match the descriptor.
2. `growth::plan(capacity, capacity, limits, ledger)` checks a clean ledger and
   current admission. Object limits below retained capacity or Instance/Engine
   limits below current usage return `Quota`, even on shrinking or a no-op.
3. Length above retained capacity returns `Capacity`, including `usize::MAX`.
   Equal length returns the original token without invoking `resize_zeroed`,
   including at generation `usize::MAX`.
4. Any actual length change requires generation headroom; generation `usize::MAX`
   returns `Owners`. Otherwise the SDK must report the requested length, matching
   native length and unchanged capacity. Success changes only descriptor length
   and increments generation once, invalidating the old token. Growth from
   generation `MAX - 1` may reach `MAX`; its newly exposed bytes must still be zero.

Capacity, unrelated slots and all nine ledger fields remain unchanged: `used`,
`engine_used`, `peak`, `engine_peak`, `pending`, `old_capacity`, `new_capacity`,
`before_used`, and `before_engine_used`. Shrinking retains the full capacity charge
and does not securely erase hidden bytes. Later growth zeroes those bytes before
exposing them again. No implicit allocation, growth reservation or retry occurs.

Preflight failures preserve the root, table and ledger. SDK error or unexpected
reported/native metadata returns `Provider`; unexpected SDK mutation is not rolled
back. Root/table/ledger association and exclusive access remain trusted caller
responsibilities. Provider fault injection is absent. This private API adds no
guest Buffer syntax, VM integration or borrow enforcement; whole-Instance cleanup
also remains unfinished.

## Focused Windows evidence

Development and release each passed 28 native scenarios: four resize cases plus
24 previous regressions. All 56 processes exit with `live=0`. Each new process
reports one initial native allocation and one final free, with no extra allocation
while resizing at the FY system-heap seam.

- `resize-success`: `keep` -> truncate to 2 -> resize to 4 (`ke` plus two zero
  bytes) -> write the suffix -> shrink to 2 -> grow to 256 -> clear -> grow to 16
  -> append `!` -> begin close, destroy the root, finish accounting. Zero checks
  cover every byte in `[2, 4)`, `[2, 256)` and `[0, 16)`; `ke` survives the first
  growth and shrink.
- `resize-capacity`: rejects over-capacity requests through `usize::MAX` and
  invalid token, backing metadata and table state without mutation.
- `resize-generation`: rejects actual changes at `MAX`, retains generation on
  equal-length no-op there, and grows length 4 to 5 from generation `MAX - 1` to
  `MAX`, checking the one newly exposed zero byte.
- `resize-state`: rejects each of the nine malformed ledger fields without changing
  its snapshot, and rejects current quota violations. Cases also check unchanged
  capacity/accounting and unrelated slots, plus stale-token rejection.

The receipt records 15 input hashes, nine generated-source hashes,
eight byte-identical production modules and two retained binaries. Full native/CLI
suites, M0, Linux, isolation, DLL embedding, packaging and elapsed-time performance
were not run. Earlier receipts retain their original inputs.
