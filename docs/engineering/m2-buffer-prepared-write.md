# Private Buffer writes before replacement publication

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (68 sources, 551 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
The [Windows receipt](../evidence/m2-buffer-prepared-write-windows-20261029.json)
records the tested inputs and both native binaries.

`buffer_replacement::write_prepared(table, replacement, start, input, limits,
ledger, plan)` copies binary input into an unpublished replacement's initialized
range and returns `input.len`. This fills the bytes exposed by
[`prepare_resize`](m2-buffer-grow-resize.md) before publication, while preserving
the live original root. It can also overwrite the replacement's copied prefix.
It does not resize, allocate, change a token, or mutate the table, ledger or Plan.

## Preflight and mutation

1. Reuse the transaction's existing `validate` helper. Require an active Plan,
   exact snapshots of all 16 descriptors and all nine ledger fields, a valid
   source token and full owner table, an available next generation, consistent
   capacities and planned length, and valid pending accounting arithmetic.
   Validation runs `growth::commit` on a local ledger copy only. Any failure
   becomes `WriteError::State`.
2. Require the native replacement's length and capacity to match the Plan exactly;
   otherwise return `State`.
3. Require replacement capacity, current Instance usage and current Engine usage
   to fit their respective limits; otherwise return `Quota`. Current usage
   includes both live roots and both logical owners, not just final usage.
4. Require `start <= plan.length`, then `input.len <= plan.length - start`;
   otherwise return `Bounds`. No unchecked `start + input.len` is used.
5. Obtain the mutable initialized view and copy. No fallible call follows the
   first write. Empty input still passes every preflight check.

Successful writing leaves the Plan active. The caller can perform more writes,
then explicitly replace its owning root and commit the transaction. Commit
advances generation exactly once; writing does not. Alternatively, the caller
drops the replacement before cancellation, retaining the original root and token.
Inactive Plans reject even empty writes after either completion path.

The operation performs bounded descriptor/snapshot scans plus O(input length)
copying, with fixed-size stack snapshots and zero heap allocation. It never
exposes capacity beyond the initialized length. No timing benchmark is claimed.

## Trusted caller boundary

The native replacement must be the root belonging to the Plan, and input must
not alias that replacement. Input may be a shared view of the distinct old root;
the success scenario exercises that case. Root association, lifetime, exclusivity
and non-aliasing remain caller responsibilities. Plan snapshots are private plain
data and do not authenticate arbitrary roots or protect against consistent forgery.

The [ordinary guarded write API](m2-buffer-write.md) still rejects pending growth.
Callers must not bypass this through raw native views or low-level `owners::write`.
Publication and metadata/accounting commit remain separate trusted caller steps,
as described in the [replacement contract](m2-buffer-replacement.md).
This slice adds no guest Buffer syntax, VM dispatch, borrow enforcement, opcode,
Fuel price or version capability.

## Focused Windows evidence

Development and release each passed 51 native scenarios: four new prepared-write
cases plus 47 lifecycle/allocator regressions. All 102 processes exited with
`live=0`. The authoritative fixture is
`probes/m2-buffer-failure/src/prepared_write.fy`.

| New scenario | Verified coverage |
| --- | --- |
| `prepared-write-success` | Binary prefix overwrite, copying the old root into the replacement's tail, zero-length write at the end, untouched zero-filled middle, unchanged old root/snapshots, publication and one generation advance, stale token and inactive Plan rejection. |
| `prepared-write-bounds` | MAX start, empty input beyond the end, nonempty input at the end, crossing the end and oversized input fail without byte changes; exact full-range binary overwrite succeeds and survives commit. |
| `prepared-write-preflight` | Independent corruption of nine ledger fields, eight Plan fields/snapshots, unrelated slot mutation, matching malformed table snapshots and matching invalid pending-ledger snapshots are rejected. Old-root backing and wrong initialized length are rejected. Object/Instance/Engine quotas reject writes, including empty writes; exact reservation ceilings succeed. |
| `prepared-write-abandon` | Successful binary writes affect only the unpublished replacement; dropping it before cancel restores Instance/Engine usage to 320/352, retains the original bytes/table/token and peaks 768/800, and rejects subsequent empty writes. |

Each new scenario performs exactly two FY system-heap allocations and two frees:
the initial 256-byte root and its 384-byte replacement. Writes add no allocation.
Successful publication finishes at Instance/Engine usage 448/480; cancellation
finishes at 320/352. Both retain peaks 768/800.

The archive rechecks 22 input hashes, 16 generated sources (ten byte-identical
production modules and six fixture modules), the generated lock and two binaries.
Earlier receipts retain their original inputs and historical scope.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider inconsistency fault injection were not run.
Whole-Instance Buffer cleanup and guest Buffer/VM integration remain unfinished.
