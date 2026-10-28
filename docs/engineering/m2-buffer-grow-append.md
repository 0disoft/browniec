# Private Buffer grow-and-append preparation

Implemented and verified in development and release. See the
[Windows receipt](../evidence/m2-buffer-grow-append-windows-20261029.json).

`buffer_replacement::prepare_append` combines growth reservation, replacement
allocation, copying initialized bytes and appending input into that unpublished
replacement. It extends the [replacement protocol](m2-buffer-replacement.md),
without adding guest Buffer syntax, VM instructions or implicit native publication.
When the appended length fits existing capacity, it returns `NoGrowth`; use
[`buffer_append::within_capacity`](m2-buffer-append.md) for that case.

## Preparation and completion

Preparation checks an inactive Plan, source token and native metadata, then checks
length addition for overflow before requesting growth. Existing storage admission
chooses preferred capacity or the minimum permitted by policy limits and accounts
for old and new roots simultaneously. Allocation and Provider failures clean up
the unpublished helper root before cancelling its reservation. No hidden retry is
introduced; callers may explicitly retry an Allocation error.

`Plan.length` starts at the original initialized length for plain `prepare` and is
updated only after combined append succeeds. Append must report the expected
length, native length and unchanged prepared capacity. Failure drops that
replacement before cancellation. The table, old root and old token remain usable
until the caller publishes and commits; input may therefore be a shared view of
the old root itself. Preparation copies O(old length + input length) bytes, uses
one replacement allocation on success, and does not resize the old allocation.

The trusted caller chooses one completion path:

1. Replace its owning local with the prepared root, destroying the old root, then
   call `commit`. Completion checks full table/ledger snapshots, planned length
   bounds and published native length/capacity. It updates both descriptor length
   and capacity, advances generation and installs final usage. The old token then
   becomes invalid. No fallible operation follows descriptor publication.
2. Destroy the unpublished replacement, then `cancel`. Validation includes
   `Plan.length` bounds as well as the existing snapshots. Cancellation restores
   usage and retains old data/token and observed accounting peaks.

Native publication and metadata commit are separate operations. The API cannot
prove destruction or undo an incorrectly published root if snapshot validation
later fails. Plan fields are private trusted native state, not authenticated guest
capabilities. Exclusive root/table/ledger association, correct phase ordering,
borrow lifetimes and avoiding copied-Plan replay remain caller responsibilities.

## Verified examples

A 256-byte root containing `keep` has Instance/Engine usage 320/352, including
32 bytes of background Engine usage. Appending 253 bytes requires length 257:

- Preferred capacity 384 reserves peak usage 768/800 and commits at 448/480.
- Limits 704/736 select minimum capacity 320 and commit at 384/416.
- A one-shot 320- or 384-byte allocation failure restores 320/352, preserves
  original data/token and leaves an inactive Plan. Explicit retry succeeds.
- Abandonment destroys the replacement before cancellation, restoring 320/352.
  An out-of-bounds planned length rejects cancellation without changing usage;
  repairing the private fixture permits completion.
- A root initialized to 200 bytes appends its full own view, producing length 400
  at preferred capacity 448. Reads sample the preserved prefix, copied boundary
  and final byte after publication.

The successful preferred scenario then retires the new token, destroys its root
and finishes [close accounting](m2-buffer-close.md), reaching 0/32 usage while
retaining peaks. In other success scenarios native scope cleanup is counted, but
final ledger close is not claimed for those cases.

## Focused Windows evidence

`python -B tools/verify-m2-buffer-failure.py` runs 20 scenarios per profile: seven
grow-and-append cases plus thirteen existing lifecycle/allocator regressions.
The seven cover preferred/minimum growth, both one-shot OOM/retry sizes,
abandonment, self-append and preflight rejection (empty/in-capacity input, invalid
identity and insufficient quota). Both new OOM cases report exactly one failure,
two attempts at the target size, three total attempts and two frees. Ordinary
grow/abandon/self cases report two attempts and two frees; preflight reports one
initial allocation and one free. Every process reports zero tracked live
allocations at exit; only the FY system-heap seam is instrumented.

The archive records 13 selected input hashes, seven generated-source hashes,
generated SDK lock and both retained executable hashes. Generated copies of all
six production Buffer modules match their originals. Baseline `b8a1c66` identifies
pre-commit provenance; input hashes identify the tested implementation.

Provider inconsistency injection is still absent. Guest syntax, VM integration,
borrow enforcement, atomic native root publication, physical table/Plan admission
and whole-Instance cleanup remain unfinished. Full native/CLI suites and the
previous 31-group selection, M0, Linux, isolation, DLL embedding, packaging and
elapsed-time performance were not run. Prior receipts remain historical.
