# Resumable scalar array copy and assignment

Implementation: `1601b78` (2026-11-08), with Engine fixtures `c58ebf2`. Windows
development/O2 each pass five kernel/six Engine groups plus existing regressions,
with default stacks and zero SDK heap at exit. The
[Windows evidence](../evidence/runtime-array-copy-chunks-windows-20261108.json)
records commands and exact source/artifact identities.

## Scope and shared byte allowance

The [canonical dispatcher](../../src/slice_result_execution.fy) resumes scalar
COPY34, legacy ASSIGN38 and selected whole-array STORE85 (kind 3) through
[array_copy_execution](../../src/array_copy_execution.fy) and
[array_copy_work](../../src/array_copy_work.fy).
Actual source `b = a` uses STORE85 and retains its SELECT ticket/snapshot and
selected-place price. Its saved recipe uses `op=38`; its saved PC identifies 85.
Scalar arrays have 1..4096 elements, strides 1/4/8 and at most 32768 payload bytes.

Copies reuse the existing [array_fill_cursor::State](../../src/array_fill_cursor.fy)
and array backing bank described in [array initialization](runtime-array-fill-chunks.md).
Exactly four `usize` words extend the shared recipe: `source_slot`,
`source_generation`, `source_base`, `source_end`; `empty()` initializes them to zero.
No second persistent array cursor, backing bank or transfer snapshot is introduced.

Each caller-visible batch shares ONE 4096-byte allowance across fills, copies,
assignments and [output copies](runtime-output-chunks.md), including multiple
instructions. A transfer byte counts once for its source read plus target write;
COPY alignment padding counts once per zero write. Bool preflight reads also count.
`written` starts at zero and counts transfer/padding bytes for this instruction;
`total` accumulates array work including bool reads, and `last` counts this batch.
Array `last` plus output `last` must not exceed 4096; only the parent resets `last`.

## Fuel, frozen execution and publication

Before admitting a bool copy/assignment, the dispatcher requires room for the
entire source scan (at most 4096 bytes). If it exceeds
`4096 - output.last - array.last`, execution returns Pending at the same PC,
before the instruction unit or full instruction price is debited.
Admission checks the existing full price before scanning and debits that price
only after successful `begin`; the dispatcher charges its normal unit once.
Continuations consume dispatch visits, not new guest instructions or Fuel, and
run before the zero-Fuel gate. The PC advances once, only on completion.

The PC, frame, destination, source token and source extent stay fixed while active.
The parent pins the table, backing and source and prevents every other guest
opcode from executing until completion. Source expressions are not reevaluated;
array and output recipes cannot both be active. Invocation storage remains
separate even when Instances share an immutable prepared Program.

COPY plans a free slot/generation and aligned future extent, including padding.
Partial writes publish neither an owner nor a larger arena prefix. After the
last byte, completion reauthenticates metadata, publishes arena/owner/order/depth,
then installs the destination token before advancing the PC.
ASSIGN writes existing target bytes incrementally and preserves its token and
generation. It has no rollback: a later error or cancellation cannot restore
already overwritten bytes. Engine teardown discards private invocation storage.

Exact ASSIGN identity still requires a writable target, source resolution and
the complete bool scan. It returns an inactive NoOp recipe with `written=0`,
retains any scan counts and pays its ordinary instruction price once.
Selected STORE85 reauthenticates the original SELECT row on each chunk and
consumes it only on completion, including identity; the later END clears the row.
Unfinished COPY leaves only unpublished spare bytes. Spent Fuel remains spent;
external effects are never rolled back, replayed or retried.

## Admission and resume authority

[Owner helpers](../../src/array_owners.fy) expose `prepare_copy`, `validate_copy`
and `publish_copy` over the existing private owner validators.
ASSIGN prepares/validates its writable target before resolving the source;
COPY resolves its source before reserving its destination. Admission checks
canonical layout, exact scalar shape, capacity, checked alignment/bounds,
generations and loans. Source write loans are rejected; a target must have no
read or write loan. Source/target payloads must be disjoint, or exact legal identity.

`begin` performs no payload writes or owner/arena publication. For bool only,
it validates every source byte as 0 or 1 before transfer and adds those reads
to the returned `total`/`last`. Non-bool admission accesses no payload.
An admitted 4096-byte bool scan fills a fresh batch without transferring a byte.
`advance` never rescans bool payload; the pinned-source contract preserves it.

Each chunk reauthenticates both tokens, source bounds, destination bounds or
future reservation, scalar shape/stride, table depth, loans and disjointness.
It checks allowance 1..4096, `last <= 4096`, `allowance <= 4096-last`, progress
and counter overflow before writes; completion reauthenticates before publication.
Saved fields are comparison facts, not guest/raw-IR authority. Chunk work takes
no Table snapshots, scratch allocations or payload snapshots. Existing atomic
`owners::copy` and `owners::assign`, and existing fill behavior, remain unchanged.

The private [native Engine](../../native/runtime-engine/runtime_engine.fy) exposes
`array_copy_progress` through the existing guarded array progress accessor.
It reports the shared recipe/counters, not payload; terminal states reject access.

## Native verification

Both development and O2 pass all five kernel/six Engine groups plus existing
regressions. Five passed groups in
[array_copy_work_tests](../../tools/runtime-engine/array_copy_work_tests.fy) assert:

- `scalar_and_atomic_parity`: six scalar tags, split encodings, atomic parity and identity.
- `padding_publication_and_bool_accounting`: padding, final-byte publication and scan reads.
- `preflight_rejections`: invalid bools including identity, shapes, tokens, loans and limits.
- `resume_rejections`: late metadata/generation/loan faults, budgets and overflow before writes.
- `maximum_extents_and_batch_cap`: eight aligned wide transfer batches and full bool scan batches.

Six groups in
[engine_array_copy_tests](../../tools/runtime-engine/engine_array_copy_tests.fy) assert:

- `full_width_copy_and_selected_assignment_eight_batches`: actual COPY34/STORE85 and stable identities.
- `fixed_and_mixed_quanta_and_scalar_endpoints`: synchronous parity, Fuel, diagnostics and binary output.
- `shared_padding_output_and_bool_validation_admission`: one shared budget, scan deferral and identity.
- `partial_copy_and_assignment_cancel_refund`: hidden output, retained input and cancellation accounting.
- `interleaving_moves_and_released_program_pins`: independent recipes, Engine moves and Program pins.
- `exact_fuel_and_one_less_before_copy_and_selected_store`: prepaid continuation and no-write rejection.

Every resume runs with the next SDK allocation forced to fail and the allocation
attempt count unchanged. Both profiles end with zero SDK heap allocations and
use the default 1048576-byte stack reserve/4096-byte commit. Actual 32768-byte
i64 COPY/selected ASSIGN each use eight transfer batches. One shared batch
performs 2056 array bytes and 2040 output bytes. Full bool scanning
uses 4096 reads and zero writes, with transfer in the next batch; even one prior
array/output byte defers that scan without charging Fuel. Exact/one-less Fuel,
cancel/refund, Engine moves and released Program pins pass.

The shared array recipe is 176 bytes (+32); Cursor is 248 (+32), Machine is
696 (+32), and Core remains 120880. Vec8 work adds 1408 bytes, an increase of
256 over the fill checkpoint; existing native layout accounting charges it.
All 252 receipt inputs match checkout and committed Git; the transport review
covers 33 typed bindings and 30 layouts. Root locked check passes 262 sources/
2961 MIR, with 254 production LF modules. Separate OS I/O/metered-output/full M2
images were not repeated. No wall-clock throughput/latency benchmark is claimed.

## Remaining accepted work

The [element-list successor](runtime-array-list-chunks.md) now gathers, encodes
and commits scalar lists through this shared allowance. Bounded record transfers,
CALL/RET, seal/cleanup and atomic setup remain open. Deadlines, in-flight cancellation/poison
containment and full public lifecycle/ABI/CLI remain in the
[inventory](../product/04-remaining-work.md). R03-R05 remain incomplete.
The shared byte allowance does not bound all metadata work, native time or latency.
