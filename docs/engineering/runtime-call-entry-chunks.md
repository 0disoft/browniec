# Owned CALL continuations in the saved VM

Implementation: `20e0bee` (2026-11-08). Four actual Engine/eight kernel groups
and existing regressions pass Windows development/O2 with default stacks and zero
SDK heap at exit. The [Windows evidence](../evidence/runtime-call-entry-chunks-windows-20261108.json)
records the receipt, committed input identities and native layouts.

The saved dispatcher routes CALL9/64/66/78 through
`call_work_execution`, using the [owned argument-copy kernel](runtime-call-argument-chunks.md).
This bounds CALL payload work; metadata planning and frame publication remain
atomic. The accepted R03-R05 and public lifecycle contracts remain incomplete.

## Admission and validation

The original instruction unit is consumed once. Existing frame-depth, input,
static/reference argument and complete CALL Fuel checks retain their order.
`slice_result_owned_execution::prepare_enter` gathers immutable descriptors and
captures for both atomic entry and the saved path. Actual argument expressions
have already run in the caller and are never evaluated again by a continuation.

`slice_result_runtime::prepare_entry` authenticates original captures and stages
authority/read loans in caller-owned temporary copies. It does not publish a
loan, copy the owner table or access payload. `frames::can_push` and input-window
preflight validate future destinations before destination work starts.

The copy kernel distinguishes array-only reservation-before-bool diagnostics
from mixed record/array bool-before-reservation diagnostics. Its `validate` entry
returns at the phase boundary without writing destinations. Thus validation can
span steps while a late bad bool or reservation failure keeps the original Fuel
result. Validation reads share the current step allowance.

After complete validation, the full existing owned CALL/cleanup price is deducted
exactly once. Copies then run before the dispatcher's zero-Fuel gate. A zero-Fuel
continuation can finish its prepaid copy; the next unpaid opcode still fails.
Cancellation keeps spent Fuel and discards unpublished spare bytes/output.

## Saved state and publication

The Cursor appends one `call_copy_cursor::State`. `pending` tracks the complete
VM transition; `active` tracks only kernel copying. Saved PC/frame/target/offset
and before/captured/after Fuel are comparison facts. No table, pool, authority,
payload snapshot, borrowed pointer or argument-expression continuation is saved.

Each advance reconstructs deterministic metadata using a local copy of the
original Fuel, then reauthenticates loans, destinations, source/target generations,
extents and reservations. Reconstructing metadata does not debit live Fuel.
The caller, Program, backing and input windows remain frozen and pinned.

Only the final copy publishes all argument owners. Already-preflighted authority,
pool, formal bindings, static/input words, scalar registers, frame and PC then
publish without yielding, allocation or external callbacks. The source/catalog
and frame plans stay immutable across this final sequence.

## Shared work and remaining obligations

`call.last + array.last + output.last <= 4096` in each actual step. All three
counters reset once per batch; each family's cumulative total is retained across
instructions. Kernel validation reads, copies and padding count as byte work.
The existing native size-based admission accounts for the appended cursor and
the reserved eight-Machine vector before allocation.

The private Engine observation `call_copy_progress` uses the same thread/busy/
phase/Instance checks and Program pin as existing progress APIs. It returns
comparison data and grants no execution or mutation authority.

The atomic native entry APIs remain available. The synchronous facade may drain
the same saved dispatcher, while Engine stepping returns Pending to its caller.
Full metadata-visit bounds, CALL frame/capture/result metadata recipes, RET,
setup/proof, seal/cleanup, deadlines, in-flight cancellation/STOPPING/poison and
public lifecycle/ABI/CLI integration remain in the
[accepted inventory](../product/04-remaining-work.md). Byte bounds do not establish
wall-clock latency or throughput guarantees.

## Executed verification and storage

Actual source tests pass quanta 1, 7 and mixed 1/7/3/4096/2. A maximum i64 source
and its CALL destination fill exactly 65536 bytes; copying takes eight full
advances. Mixed records/bools carry an actual local-array loan and preserve an
earlier record actual before a later argument mutates its source. Exact/one-less
whole-program and CALL-admission Fuel preserve diagnostics, including seven
remaining copy advances at zero Fuel. Interleaving, Engine moves, released
Program handles, cancellation/output suppression and exact SDK/ledger refunds
pass without any SDK allocation attempt during resume.

Native sizes match both profiles: CALL work 536 bytes, Cursor 968 (+536), Machine
1416 (+536), Core unchanged 120880. Reserved Vec8 CALL work adds 4288 bytes;
combined array/CALL work adds 7168. Size-based admission charges this storage
before allocation. All 265 receipt inputs match checkout and Git raw bytes; the
root locked check passes 269 sources/3024 MIR and all 261 production modules are
LF. The reviewed transport has 33 typed bindings and 31 layouts, including six
exact eight-element usize comparison banks. Full M2/CLI matrices were not rerun.
