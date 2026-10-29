# Private Buffer bulk copy-out

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (67 sources, 549 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-copy-out-windows-20261029.json) is archived.

`buffer_owners::copy_out(table, token, start, buffer, output)` copies initialized
bytes into a distinct caller-owned mutable native byte slice and returns
`output.len`. It copies binary bytes unchanged, including NUL and non-ASCII
values; it performs no text decoding or terminator handling.

## Checks and caller contract

1. Resolve the table-local slot/generation token once. Invalid or stale identity
   returns `Token` before backing metadata access; malformed live-table state
   returns `State` through the existing full 16-slot validation.
2. Require backing length and capacity to exactly match the resolved descriptor;
   a mismatch returns `State`.
3. Require `start <= owner.length`, then
   `output.len <= owner.length - start`; either violation returns `Bounds`.
   Subtraction avoids overflowing a `start + output.len` range check.
4. Only after all checks, obtain the initialized view and copy the complete output
   range. Every rejected call preserves every output byte.

An empty output at initialized length succeeds with count zero. An empty output
beyond that length returns `Bounds`; nonempty output at the end also fails.
No allocation, token/generation update, owner metadata change or ledger change
occurs. A live token at generation `MAX` remains readable.

Like existing single-byte `read`, copy-out may read the old root while a
replacement is pending: its descriptor and backing still match until publication.
It neither commits nor cancels the transaction. Native root association and
lifetime remain trusted caller responsibilities; matching metadata does not prove
root identity. The native borrow must keep output distinct from, and non-aliasing
with, the source root. This is a private native API contract, not guest borrow
enforcement or guest Buffer/VM integration.

For a valid call copying `n` bytes, work is one 16-slot validation scan plus an
O(n) copy, rather than `n` single-byte reads each scanning 16 slots. This is an
operation-count comparison; no elapsed-time result is claimed.

## Focused Windows evidence

Development and release each passed 43 native scenarios: four new copy-out
cases plus 39 existing regressions. All 86 processes exited with `live=0`.
The authoritative fixture is `probes/m2-buffer-failure/src/copy_out.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `copy-out-success` | Six binary source bytes, including NUL, 255 and 128; full source range `0..6` and subrange `1..4`, with surrounding output canaries; returned counts and valid empty output at the end. |
| `copy-out-bounds` | `MAX` start, oversized output, nonempty output at the end and empty output beyond the end return `Bounds` without changing output; empty output at zero or the end succeeds. |
| `copy-out-identity` | Invalid/stale identity returns exactly `Token` before missing-backing checks; mismatched backing and malformed full-table state return `State`; failures preserve output. After append makes the source seven bytes long, a fresh token reads the appended byte; generation `MAX` remains readable and copies the six-byte source prefix with surrounding canaries. |
| `copy-out-pending` | Real `prepare_resize` keeps old-root bytes readable while pending; copy-out preserves reserved usage. After replacement destruction and cancel, usage returns to 320/352 with peaks 768/800 retained, and the old root remains readable. |

FY system-heap counts are one initial payload allocation/one free for each of the
first three new cases and two allocations/two frees for the pending case.
Copy-out itself adds no allocation and leaves token/generation, owner metadata
and ledger unchanged.

The archived receipt records 19 input hashes, 13 generated sources (nine
byte-identical production modules plus `main.fy`, `grow_resize.fy`, `create.fy`
and `copy_out.fy`) and two binaries. Final source and test inputs were unchanged
after the successful run. Earlier receipts retain their original inputs.

Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider fault injection were not run.
Guest Buffer/VM integration and guest borrow enforcement remain unfinished.
