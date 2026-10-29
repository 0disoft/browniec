# Private Buffer writes within initialized length

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (68 sources, 550 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-write-windows-20261029.json) is archived.

`buffer_write::within_length(table, token, start, buffer, input, limits, ledger)`
copies binary bytes from a shared native input slice into an existing mutable
native Buffer and returns `input.len`. The table and ledger are shared references.
It changes only the selected initialized bytes; input, initialized length,
capacity, token/generation, owner table and ledger stay unchanged. There is no
allocation, resize or exposure of uninitialized capacity.

## Preflight and caller contract

1. Resolve identity and validate the full 16-slot table through
   `owners::describe`. Invalid/stale identity returns `Token` before backing
   metadata access; malformed table state returns `State`.
2. Require backing length and capacity to exactly match the descriptor, otherwise
   return `State`.
3. Call `growth::plan(owner.capacity, owner.capacity, limits, ledger)` without
   requesting growth. This checks all nine ledger fields: counter ordering across
   `used`, `engine_used`, `peak` and `engine_peak`; zero `pending`,
   `old_capacity`, `new_capacity`, `before_used` and `before_engine_used`;
   and usage covering the current capacity plus its 64-byte logical owner.
   Invalid state returns `State`. Current capacity, Instance usage and Engine
   usage must fit their current limits, otherwise return `Quota`.
4. Require `start <= owner.length`, then
   `input.len <= owner.length - start`; violations return `Bounds`.
   Subtraction avoids overflowing a `start + input.len` range check.
5. Only after complete preflight, obtain the mutable initialized view and copy.
   No fallible call follows the first write. Rejection leaves the root unchanged.

Even empty input must pass identity, table, backing, ledger and current-quota
checks. With valid state and quotas, empty input at initialized length returns
zero; empty input beyond the end and nonempty input at the end return `Bounds`.
Generation `MAX` permits content writes without advancing generation, consistent
with low-level `owners::write`.

Pending growth returns `State`, including for an empty write. A prepared
replacement already contains an old-root snapshot; changing the old root could
otherwise lose those writes when the replacement is published. This guarded API
does not make legacy raw `owners::write` guest-safe: trusted callers must not
bypass the transaction protocol through that lower-level path.

The caller supplies distinct input that does not alias the Buffer root; native
root association, lifetime and non-aliasing remain trusted caller obligations.
Guest Buffer/VM integration and guest borrow enforcement are not implemented by
this slice. Valid writes cost one 16-slot validation scan plus an O(n) byte copy,
rather than `n` raw byte-write calls each scanning 16 slots. No elapsed-time
benchmark is claimed.

## Focused Windows evidence

Development and release each passed 47 native scenarios: four new write cases
plus 43 existing regressions. All 94 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/write.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `write-success` | Middle write of `[0,254,129]` at index 1 preserves the outside prefix/suffix and input; whole write of `[255,0,128,1,2,3]`, empty input at the end, exact counts and a full copy-out verify the final binary content. |
| `write-bounds` | `MAX` start, oversized input, nonempty input at the end and empty input beyond the end return `Bounds` without changing the root; empty input at the end succeeds. |
| `write-identity` | Invalid/stale identity returns exactly `Token` before missing-backing checks; bad backing and malformed table state return `State`. A fresh token writes the appended byte; generation `MAX` permits another content write without advancing generation or changing the original six-byte prefix. |
| `write-state` | Each of the nine corrupt ledger fields returns `State` without changing content or the supplied ledger. Instance quota rejects a content write; Engine and object quotas reject empty writes. A real pending replacement rejects both content and empty writes with `State`, preserving old-root content, the prepared prefix and reserved usage. |

FY system-heap counts are one initial payload allocation/one free for each of
the first three new cases and two allocations/two frees for the state case's
real pending replacement. Dropping the replacement before cancel restores
Instance/Engine usage 320/352 while retaining peaks 768/800.
Writes themselves add no allocation and leave length, capacity, token/generation,
table and ledger unchanged.

The archived receipt records 21 input hashes, 15 generated sources (ten
byte-identical production modules plus `main.fy`, `grow_resize.fy`, `create.fy`,
`copy_out.fy` and `write.fy`) and two binaries. Final inputs were unchanged after
the successful run. Earlier receipts retain their original inputs.

Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider fault injection were not run.
Guest Buffer/VM integration and guest borrow enforcement remain unfinished.
