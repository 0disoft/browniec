# Private Buffer grow-and-resize preparation

Implemented and verified in development and release. Root `fairyc check` passed
with a lock refresh (66 sources, 544 MIR functions), followed by
`python -B tools/verify-m2-buffer-failure.py`.
See the [Windows receipt](../evidence/m2-buffer-grow-resize-windows-20261029.json).

`buffer_replacement::prepare_resize` prepares a larger replacement with the old
initialized prefix and a zeroed suffix before caller publication. It shares the
[replacement protocol](m2-buffer-replacement.md) and existing `Plan`, `commit` and
`cancel`, like [grow-and-append](m2-buffer-grow-append.md). It is growth-only:
after preflight, length at or below old capacity returns `NoGrowth`. Use
[`buffer_resize::within_capacity`](m2-buffer-resize.md) for that range.

## Preparation and completion

`prepare_resize` delegates to `prepare`: inactive Plan, token/full table, exact
old-root length/capacity, generation headroom, growth admission and checked
capacity arithmetic are validated before allocation. This includes clean ledger,
current quotas and simultaneous old-plus-new payload/owner charges. An exhausted
generation returns `Owners`; an unrepresentable required capacity returns
`Overflow`. There is no implicit retry after `Allocation` failure.

The helper calls `bytes::resize_zeroed` on the unpublished replacement and checks
its reported length, native length and unchanged prepared capacity. `Plan.length`
starts at the original initialized length and becomes the requested length only
after success. SDK error or inconsistent metadata returns `Provider`; the helper
drops its replacement before cancellation restores usage and deactivates the Plan.
A cancellation validation failure returns `State`. The old root/data/token stay
unchanged and usable during preparation and after abandonment.

The trusted caller must choose one completion path:

1. Publish the prepared root, destroying the old root, then `commit`. Existing
   completion validates full table/ledger snapshots, planned length bounds and
   published length/capacity. It installs final usage, updates descriptor length
   and capacity, advances generation once and invalidates the old token.
2. Destroy the unpublished replacement, then `cancel`. Existing validation restores
   original usage while retaining observed peaks and the original token/data.

Native publication is separate from metadata commit. The API cannot prove root
destruction or undo publication if commit later fails. Root/table/ledger association,
exclusive access, borrow lifetimes and correct Plan ordering remain trusted caller
responsibilities. Provider fault injection is absent; guest syntax, VM integration,
borrow enforcement and whole-Instance cleanup remain unfinished.

## Focused Windows evidence

Development and release each passed 35 native scenarios: seven new modes plus
28 existing regressions. The authoritative new fixture is
`probes/m2-buffer-failure/src/grow_resize.fy`.
A 256-capacity root holding `keep` starts at Instance/Engine usage 320/352.
Requested length 257 preserves `keep` and zeroes every byte in `[4, 257)`.
Full suffix checks pass before and after commit; the old data/token remain valid
and the table unchanged while the replacement is pending. After commit, a fresh
token reads zero at index 256; the old token with empty backing returns exactly
`Token`, confirming identity rejection before backing metadata checks.

- `grow-resize-preferred`: capacity 384, pending usage 768/800, final usage
  448/480. It also begins close, destroys the root and finishes at 0/32 with
  peaks preserved.
- `grow-resize-min`: limits 704/736 choose capacity 320, pending usage 704/736
  and final usage 384/416.
- `grow-resize-oom-min` and `grow-resize-oom-preferred`: a one-shot failure at
  320 or 384 restores 320/352, the old data/token and an inactive Plan; explicit
  retry succeeds.
- `grow-resize-abandon`: destroys the replacement before cancel, restoring old
  usage/data/token and retaining peaks.
- `grow-resize-truncated`: grows truncated `ke` to length 257, checking all of
  `[2, 257)` is zero before and after commit while preserving `ke`.
- `grow-resize-preflight`: returns `NoGrowth` for lengths 0 and 256; rejects an
  invalid token, Instance quota 703, `usize::MAX` capacity overflow and generation
  `MAX`, preserving root/table/usage and an inactive Plan.

Normal cases report two allocation attempts/two frees; OOM/retry cases three
attempts, one failure, two target-size attempts/two frees; preflight one initial
allocation/one free. All 70 processes exit with `live=0`; only the FY system-heap seam is
instrumented. The receipt records 16 input hashes, ten generated
sources (eight byte-identical production modules and the `main.fy`/`grow_resize.fy`
fixtures) and two retained binaries. Full native/CLI suites, M0, Linux, isolation,
DLL embedding, packaging and elapsed-time performance were not run. Earlier
receipts retain their original inputs.
