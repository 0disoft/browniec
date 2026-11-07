# Resumable scalar array element lists

Implementation: `b0f0946` (2026-11-08). Windows development/O2 each pass five
kernel/five Engine groups plus existing regressions, with default stacks and
zero SDK heap at exit. The
[Windows evidence](../evidence/runtime-array-list-chunks-windows-20261108.json)
records commands and exact source/artifact identities.

## Scope and selected-place identity

The [canonical dispatcher](../../src/slice_result_execution.fy) routes list
creation (opcode 80), legacy list replacement (81), and selected REPLACE87
(array kind 3, mode 1) through
[array_list_execution](../../src/array_list_execution.fy) and
[array_list_work](../../src/array_list_work.fy).
Scalar arrays contain 1..4096 elements with strides 1/4/8, up to 32768 payload bytes.

Selected source replacement retains the original SELECT snapshot/ticket and
selected-place price. Its recipe uses `op=81`, while its saved PC still identifies
REPLACE87. The bridge reauthenticates the original selection and root token on
every advance; only completion consumes the selection. The later END clears it.

## Three stages and shared counters

The kernel reuses [array_fill_cursor::State](../../src/array_fill_cursor.fy).
Exactly two `usize` fields are added: `list_gathered` and `list_encoded`.
Both count cells, start at zero in `empty()`, and remain zero for other recipes.
Both native profiles measure State at 192 bytes (+16), Cursor 264 (+16), Machine
712 (+16), and unchanged Core 120880. Vec8 work adds 1536 bytes (+128); existing
native layout accounting charges the increase. Existing list scratch is reused.

Each list progresses through three ordered stages:

1. Gather each operand's scalar register cell into the existing `i64` cell scratch.
   One complete cell transfer costs eight budget bytes, regardless of element type.
   `list_gathered` advances once per transferred cell.
2. After ALL cells are gathered, encode each scalar through
   [scalar_codec](../../src/scalar_codec.fy) into the existing byte scratch.
   One complete encoding costs `stride` bytes; `list_encoded` advances once per
   successful scalar. Successfully encoded cells are never encoded again.
3. After ALL encodings succeed, zero creation padding and copy the encoded payload
   into destination backing, one budget byte per destination byte.

`written` counts only destination padding/payload bytes for this instruction.
`total` accumulates all three stages across array instructions; `last` counts
their work in the current caller-visible batch. The parent carries `total/last`
into the next recipe and resets `last` once per batch, never per kernel advance.

One 4096-byte allowance is shared with [fills](runtime-array-fill-chunks.md),
[copies/assignments](runtime-array-copy-chunks.md) and
[output copies](runtime-output-chunks.md), including multiple instructions.
Array `last` plus output `last` must not exceed 4096. A list of N cells and scalar
stride S accounts for `8*N + 2*N*S + creation_padding` bytes in total.
Both native profiles execute aligned 4096-cell i64 lists in 24 full batches:
eight gather, eight encode and eight commit, totaling 98304 work bytes. Bool
lists execute in ten batches (8+1+1), totaling 40960 work bytes. Creation and
replacement both match the existing atomic owner operations.

Gather and encode units cannot be split. If the next eight-byte gather or
stride-byte encoding does not fit, the kernel returns Pending without that unit
or any later-stage progress. Unused allowance is allowed; the dispatcher yields
on an unfinished list, including unchanged `total`, rather than spinning.
The final destination copy can split scalar encodings across batches.

## Scratch reuse, validation and publication

Invocation setup already allocates and initializes the list cell vector and
encoded byte buffer via [array_list_vm](../../src/array_list_vm.fy).
The bridge passes their existing mutable views and the instruction's operand
span to the kernel. Resume allocates no storage and creates no additional
snapshot or list buffer. Progress stays in the existing array cursor; the scalar
codec uses tiny local staging.

`begin` admits metadata only, mapping 80 to `owners::prepare_fill` opcode 33 and
81 to opcode 40, then preserving 80/81 in the returned recipe. It does not gather,
encode, write destination bytes or publish an owner.

Every advance reauthenticates the live owner or unpublished free reservation
through [owners::validate_fill](../../src/array_owners.fy), using a local recipe
normalized to 33/40. Saved cursor fields are comparison facts, not authority.
Before writes it checks stage ordering/counts, operand/cell/scratch extents,
allowance and actual planned counter headroom. Gather checks each register index
against both the 128-register bank limit and the supplied register slice length.

All operand gathering and full scalar-codec validation finish BEFORE any
destination byte, including padding, is touched. This preflight can span batches;
it is not an unbudgeted scan during admission. Invalid operands or codecs may
leave partial cell/encoded scratch, but preserve the destination.

After the last destination byte, only `owners::publish_fill` with the normalized
local recipe completes publication. Opcode 80 then publishes arena usage and the
new owner/order/depth, and the bridge installs its token. Opcode 81 preserves the
existing token and generation, including selected replacement.

## Fuel, frozen execution and cancellation

The dispatcher charges its ordinary instruction unit once. Successful admission
debits the existing full list price once, retaining selected-place pricing for
REPLACE87. Continuations run before the zero-Fuel gate, consume dispatch visits
and byte allowance, and neither repeat the instruction charge nor reevaluate
source expressions. The PC advances once, only after completion.

Source IR/operands, the register bank, cell/encoded scratch, owner table and backing
stay pinned. Saved PC, frame, destination and opcode stay fixed. Every other guest
opcode remains frozen while the list is active; output and array recipes cannot
both be active. Distinct invocations retain separate mutable scratch/cursors.

Unfinished creation leaves only hidden spare bytes: no new owner or larger arena
prefix is visible. Replacement changes live bytes incrementally only after full
codec preflight. A later cancellation/error does not roll those writes back;
invocation teardown discards private partial state and hidden staged output.
Spent Fuel remains spent. External effects are neither rolled back nor replayed.

## Native verification

Five groups in [array_list_work_tests](../../tools/runtime-engine/array_list_work_tests.fy)
pass in both profiles: scalar atomic parity, late operand/codec failures preserving
all destination bytes, padding/publication and small-budget deferral, late metadata/
loan/budget rejection, and maximum i64/bool batch counts with byte guards.
Five groups in [engine_array_list_tests](../../tools/runtime-engine/engine_array_list_tests.fy)
pass with actual 32/64-cell source lists: frozen stages/shared padding/output,
fixed quanta 1/7/4096 plus mixed 1/7/3/4096/2, cancellation in each stage for both
creation and selected replacement, exact/one-less Fuel, and interleaved Instances
through Engine moves and released Program pins. Three remaining bytes admit an
active prepaid list without gathering; 128/384/576 expose gather/encode/commit.
Every actual resume denies the next SDK allocation and records zero attempts.

Both profiles exit with zero SDK heap and default 1048576-byte stack reserve/
4096-byte commit. All 256 receipt inputs match checkout and committed Git; the
transport review covers 33 typed bindings and 30 layouts. Root locked check passes
264 sources/2967 MIR; all 256 production modules retain LF. Separate OS I/O,
metered-output, full M2 and public CLI matrices were not repeated. No wall-clock
throughput or latency measurement is claimed.

## Remaining accepted work

The [record successor](runtime-record-chunks.md) now admits canonical staging
and resumes whole/child creation/copy/replacement through this shared allowance.
Metadata/planning, CALL/RET, setup/compile proof, seal/cleanup, deadlines, in-flight cancellation/
poison containment and full public lifecycle/ABI/CLI remain in the
[accepted inventory](../product/04-remaining-work.md). R03-R05 remain incomplete.
The byte allowance does not bound all metadata work, native time or wall latency.
