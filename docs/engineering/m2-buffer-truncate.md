# Private Buffer truncate and clear

Implemented and verified in development and release. `fairyc check` passed with
a lock refresh, followed by `python -B tools/verify-m2-buffer-failure.py`.
See the [Windows receipt](../evidence/m2-buffer-truncate-windows-20261029.json).

`buffer_truncate::to_length` shortens an existing native root without releasing
capacity. `clear` delegates to it with length zero. These are private runtime APIs;
guest Buffer syntax, VM integration, borrow enforcement and whole-Instance
cleanup remain unfinished.

## Contract

Preflight checks run in this order, before SDK mutation:

1. `owners::describe` resolves the table-local slot/generation token and validates
   the entire owner table. Invalid identity returns `Token`; malformed table state
   returns `State`. Native length and capacity must exactly match the descriptor.
2. `growth::plan(capacity, capacity, limits, ledger)` requires a clean ledger and
   currently admitted capacity and Instance/Engine usage. Lowering the object
   limit below retained capacity or either usage limit below current usage returns
   `Quota`, even for shortening or a no-op: all capacity remains charged.
3. A requested length above initialized length returns `Bounds`, including
   `usize::MAX`. Equal length returns the original token without SDK mutation,
   including at generation `usize::MAX`.
4. Actual shortening requires generation headroom; generation `usize::MAX`
   returns `Owners`. Otherwise `bytes::truncate` must report the requested length,
   matching native length and unchanged capacity. Success changes only the source
   descriptor's length and advances its generation exactly once; the old token
   becomes stale. Clearing from `MAX - 1` reaches `MAX`, and another clear is a
   valid no-op.

Capacity, other slots and all nine ledger fields remain unchanged: `used`,
`engine_used`, `peak`, `engine_peak`, `pending`, `old_capacity`, `new_capacity`,
`before_used`, and `before_engine_used`. The retained prefix remains initialized;
reads at or beyond the new length fail. Logical clear is not secure erasure of
retained allocation bytes and releases no accounting charge.

Preflight failures preserve the root, table and ledger. An SDK error or unexpected
reported/native metadata returns `Provider`; unexpected SDK mutation is not rolled
back. Root/table/ledger association and exclusive access remain trusted caller
responsibilities. There is no Provider fault injection in this probe.

## Focused Windows evidence

Development and release each passed 24 native scenarios:
four truncate cases plus 20 existing lifecycle/allocator regressions. The four
new processes each report one initial native allocation, one final free and
`live=0`, with no extra allocation during shortening or clear. All 48 processes
exit with zero tracked live allocations at the FY system-heap seam.

- Success follows `keep` -> `ke` -> `ke!` -> clear -> `new`, rejects a stale
  token and a read at the shortened boundary, then begins close, destroys the
  native root and finishes accounting. Capacity stays 256; close reaches
  Instance/Engine usage 0/32 and preserves peaks.
- Bounds/identity checks cover length 5 and `usize::MAX` against `keep`, equal
  length, invalid token, mismatched backing and malformed unrelated table state.
- Generation checks reject shortening and nonempty clear at `MAX`, allow an
  equal-length no-op there, and clear from `MAX - 1` to `MAX` before another no-op.
- State/quota checks corrupt each of the nine ledger fields separately and
  preserve each rejected snapshot; they reject insufficient Instance/Engine
  limits on clear and an object limit below retained capacity on equal length.
  Every case checks unrelated slots remain unchanged.

The receipt records 14 input hashes, eight generated-source hashes,
seven byte-identical production modules and two retained executable identities.
Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging and
elapsed-time performance were not run. Earlier receipts retain their original
inputs; this focused probe does not establish guest or whole-Instance behavior.
