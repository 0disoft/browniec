# Resumable scalar array initialization

Implementation: `21bcebb` (2026-11-08). Windows development/O2 each pass
five kernel/six Engine groups plus existing Engine regressions, default stacks
and zero SDK heap at exit. [Evidence](../evidence/runtime-array-fill-chunks-windows-20261108.json)
records commands, source/artifact hashes and the verified implementation commit.

## Scope and shared byte allowance

The [canonical dispatcher](../../src/slice_result_execution.fy) resumes scalar
CREATE (opcode 33), legacy FILL (opcode 40), and selected repeated replacement
(REPLACE87, array kind 3/fill mode 0) through
[array_fill_execution](../../src/array_fill_execution.fy) and
[array_fill_work](../../src/array_fill_work.fy), with a private
[saved cursor](../../src/array_fill_cursor.fy).
Scalar arrays have 1..4096 elements, strides 1/4/8 and at most 32768 payload bytes.
Actual source `a = [value; N]` uses REPLACE87. It retains its original SELECT
snapshot/ticket and selected-place price, rather than substituting legacy FILL.
Its saved work reports normalized `op=40`; the saved PC still identifies 87.

Each caller-visible step shares ONE 4096-byte allowance across array writes and
[output copies](runtime-output-chunks.md), including multiple instructions.
CREATE alignment padding is zeroed and counts as work; FILL counts payload only.
An aligned 32768-byte operation needs eight copying visits; padding or an earlier
operation can require another batch. Exhausted bytes return Pending even when
dispatch visits remain. Continuations consume visits, not new guest instructions.
`written` tracks this instruction; `total` accumulates array bytes and `last`
tracks this batch. Array `last` plus output `last` never exceeds 4096.

## Fuel, frozen execution and publication

Before the first byte, the dispatcher charges its existing unit and preflights
the full existing array price; successful recipe admission debits that price once.
Changing quantum preserves the old Fuel schedule. Continuations run before the
zero-Fuel gate, charge no additional Fuel and can finish with a zero balance.
The PC, frame, destination and encoded scalar value stay fixed while active;
the source register is not evaluated again. No other guest opcode runs until
completion, and output-copy and array-fill recipes cannot both be active.

CREATE reserves facts only: slot/generation, arena mark, aligned base/end and
shape. It publishes neither owner nor arena prefix during partial writes.
After the last byte and metadata reauthentication, it publishes arena usage,
owner/order/depth and then the destination token; only then does the PC advance.
FILL writes an existing owner's bytes incrementally, without replacing its token.
Its partial data stays private until completion lets the VM continue.
Selected replacement reauthenticates its exact SELECT row before every chunk;
only the final chunk marks that row consumed. Its later END still clears the row.

Cancellation/failure drops hidden partial data and staged output with VM backing,
preserves spent Fuel and follows the existing first-cause/teardown rules.
External effects are never rolled back, replayed or retried. Unfinished CREATE
publishes no owner; unfinished FILL is dropped with private execution storage.

## Admission and resume authority

[Owner helpers](../../src/array_owners.fy) preflight scalar shape/stride/length,
checked alignment and bounds/capacity, slot generations and writable loan state.
The scalar codec validates the value and saves at most eight encoded bytes before
payload work. Each chunk reauthenticates generations, shape, reservation bounds,
table depth and progress against the pinned table/backing; completion checks again.
Saved recipes are comparison facts, never authority for arbitrary guest/raw IR.
Chunks allocate no storage, take no table/payload snapshots and rescan no payload.
Existing atomic owner `create`/`fill` APIs remain unchanged.

The private [native Engine](../../native/runtime-engine/runtime_engine.fy) exposes guarded
`array_fill_progress` beside `output_copy_progress` for prepared/running Instances.
It returns saved recipe/counters, not payload; terminal states reject inspection.
[Program preparation caching](runtime-program-preparation-cache.md) still owns
immutable proof/plans; each invocation owns mutable continuation and storage.

## Native verification

Five passed groups in [array_fill_work_tests](../../tools/runtime-engine/array_fill_work_tests.fy):

- `scalar_edges_and_atomic_parity`
- `padding_and_delayed_publication`
- `preflight_rejections`
- `late_metadata_rejection`
- `maximum_extent_eight_batches`

Six passed groups in [engine_array_fill_tests](../../tools/runtime-engine/engine_array_fill_tests.fy):

- `exact_widths_batches_and_prepaid_continuations`
- `fixed_and_mixed_quanta_parity`
- `padding_multiple_arrays_and_output_share_allowance`
- `partial_creation_and_fill_cancel_refund`
- `interleaving_moves_and_released_program_pins`
- `exact_fuel_and_one_less_before_each_opcode`

Every Engine resume denies the next SDK allocation and records zero attempts.
The actual 32768-byte i64 create and selected fill each take eight batches;
i32 takes four. Exact and one-less Fuel cases preserve final balances and
original diagnostics. Padding plus several operations share the same batch;
one measured batch writes 1024 array bytes and copies 3072 output bytes.

The saved array recipe is 144 bytes; Cursor is 216, Machine is 664 and Core
remains 120880 bytes. The Machine Vec8 adds 1152 retained bytes per prepared
Instance, measured in both profiles and charged through existing native layout
facts. No new scratch buffer, payload snapshot or resume allocation was added.
All 248 recorded inputs match checkout/committed Git; 33 bindings/30 layouts are
reviewed. Root locked check passes 260 sources/2950 MIR; 252 modules retain LF.
Separate OS I/O/metered-output/M2 images were not repeated for this slice.
No wall-clock performance result is claimed. The isolated native fixture now
records source/byte trap locations on failure; this does not alter production SDK.

## Remaining accepted work

The [scalar array copy/assignment successor](runtime-array-copy-chunks.md) now
shares this allowance, including bool validation reads and selected STORE85.
List values, records, CALL/RET, seal/cleanup and atomic setup still need bounded recipes. Deadlines, in-flight cancellation/poison containment
and full public lifecycle/ABI/CLI remain open in the [inventory](../product/04-remaining-work.md).
R03-R05 remain incomplete;
this byte allowance is not a bound on all metadata work, native time or latency.
