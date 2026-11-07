# RET payload admission in the saved VM

Implementation: `2a13049` (2026-11-08). Four actual Engine groups and
existing regressions pass Windows development/O2 with default stacks and zero
SDK heap at exit. The [Windows evidence](../evidence/runtime-return-work-chunks-windows-20261108.json)
records the receipt, exact committed input identities and native sizes.

## Shared payload allowance

The saved dispatcher accounts for return validation alongside CALL, array/record
work and output copying. Each batch resets the four `last` counters and enforces:

```text
returned.last + call.last + array.last + output.last <= 4096
```

The instruction quantum and this byte-work allowance are separate limits. A
single admitted return can consume its complete payload allowance even with an
instruction quantum of one. The allowance includes validation reads and scratch
work; it does not imply that a return copies its payload into caller storage.

[`return_work_execution::required`](../../src/return_work_execution.fy) computes
the requirement from instruction and catalog metadata, without reading payload:

| Return path | Payload work admitted in one batch |
| --- | --- |
| Bool ARET39 | Array length: at most 4096 canonical-bool byte reads. |
| Non-bool ARET39 | Zero; ordinary scalar array bytes are not scanned. |
| Record SRET50 | `128 + struct_work::measure(catalog, nominal, false)`, at most 512 for an admitted record. |
| Scalar RET8, void RET82 | Zero. |
| Borrowed/reference and static returns, RET65/79 | Zero; descriptor/loan transfer still has metadata work. |

The record measure is `size + scalar_bytes + bools`. The additional 128 counts
initialization of the fixed scratch buffer; the measure includes clearing its
selected extent, snapshotting scalar bytes and separate canonical-bool reads.
Record payload size is at most 128 bytes. The scratch snapshot is discarded after
validation; the existing owner is transferred. Zero payload work does not mean
zero instruction, metadata or Fuel cost.

## Defer before charging the return

After the existing zero-Fuel precheck, the
[`slice_result_execution`](../../src/slice_result_execution.fy) dispatcher obtains
the whole return requirement before consuming the instruction unit or charging
its instruction and return Fuel. A requirement above 4096 is rejected. If the
requirement exceeds the shared bytes remaining in this batch, dispatch yields
with that return still at the same PC and frame.

Deferral performs no return payload read, destination write, owner/token change,
loan restoration or frame publication. It consumes no return instruction unit
or Fuel and records no accepted return. Earlier instructions in the batch keep
their effects and charges; the ordinary per-batch `last` reset still applies.
For example, a one-byte emit leaves only 4095 bytes, so a `bool[4096]` ARET waits
for a fresh batch rather than validating a prefix.

[`return_work_cursor::State`](../../src/return_work_cursor.fy) is an accounting
receipt containing `total`, `last`, `pc`, `frame`, `required` and `op`. It holds no
owner, borrowed payload pointer, partial validation position or pending result.
Its check guards the allowance and cumulative-counter overflow before admission.
Recording follows a successful return transaction. The immutable Program,
catalog and live backing remain subject to the owning execution contract.

## Complete validation and atomic handoff

Once admitted, the complete return validation and successful token handoff run
without yielding. There is no partially validated return continuation. Existing
Fuel prices and error ordering remain in effect after admission; byte accounting
does not replace the Fuel meter or make an unpaid return executable.

[`slice_result_owned_execution::leave`](../../src/slice_result_owned_execution.fy)
prechecks the existing leave and aggregate-result prices, prepares the result
without mutation, restores canonical loans through `runtime::leave_call`, and
then publishes the caller binding and frame transition. Ordinary source cleanup
has already ended the other local owners. Payload validation precedes loan
restoration and token publication.

For SRET, [`struct_result_vm::prepare_frame`](../../src/struct_result_vm.fy)
retains the function/result/type and nominal checks, requires an empty caller
destination token `(slot=0, generation=0)`, checks all sixteen child array tokens
and all sibling record tokens are empty, then calls
`owners::validate_record_result` on the actual backing. That validation includes
nested canonical bools and retains the existing owner-error conversion. ARET
likewise validates its result owner and any bool payload before transfer.
Successful validation moves the existing token; it reserves no replacement
payload and copies no aggregate into the caller.

Atomic here means no yield inside the successful validation/restoration/handoff
sequence. It does not assert rollback of earlier guest effects or a wall-clock
duration bound.

## Frame-local owner extraction

Saved return preparation borrows the canonical owner table. It does not clone
that table or materialize a global 512-token record bank. Sparse record bindings
retain at most sixteen owners shared with arrays across all frames.
`slice_result_record_bindings::frame_tokens` scans those sixteen owner entries
once to extract a sixteen-token map for the current frame. The caller separately
looks up the existing parent destination. Array child tokens are borrowed as the
sixteen-element slice beginning at `frame * 16`.

At the native 64-bit token width (two `usize`, 16 bytes), each removed 512-token
bank is 8192 bytes. Saved record-return preparation replaces two such bank
copies (16384 bytes) with one 16-token map (256 bytes), and additionally avoids
the compatibility owner-table clone. This describes source-level temporary
construction; it is not a measured stack high-water or throughput result.

`struct_result_vm::prepare_frame` accepts exactly sixteen record child tokens,
exactly sixteen array child tokens, the owner table and that parent token.
Its `Transfer` preserves absolute compatibility indices:

```text
child  = frame * 16 + source
parent = (frame - 1) * 16 + destination
```

The legacy `prepare_data` adapter checks `0 < frame < 32` and source/destination
indices below sixteen before slicing its existing 512-token banks. It delegates
to the same frame-local validator. This compatibility adapter does not require
saved execution to expand sparse record bindings into a 512-entry temporary.

## Native initialization stack

An initial development run hit the default-stack limit before reaching the new
return groups. Diagnostic-only generated-C traces identified native Core
initialization calling the full by-value `Frames::empty` factory. Native Core
initialization now fills the existing frame storage directly with the same
sentinels and bank lengths. Legacy value-returning initialization remains for
compatibility. Layout-retention witnesses also use separate helper calls to
avoid overlapping unrelated compiler temporaries. No stack or compiler override
is used; final native results below own the evidence.

## Executed verification and storage

The source suite
[`engine_return_work_tests.fy`](../../tools/runtime-engine/engine_return_work_tests.fy)
executes four actual-source/owning-Engine groups:

- Maximum `bool[4096]` ARET, shared-budget deferral after an emit, fixed and mixed
  instruction quanta, exact/one-less whole-run Fuel and return-admission Fuel.
- Padded nested records with bools, a work measure derived from the compiled
  source catalog, and scalar, void and non-bool-array zero-payload returns.
- Cancellation of a deferred return, peer interleaving, Engine moves, released
  Program pins, output availability and accounting/refund checks.
- A 4000-byte bool return followed by array COPY and a 3880-byte bool return
  followed by record COPY in the same batch. Admission and initial destination
  copying both subtract all four counters, including earlier CALL/RET work.

The four groups and existing Engine/kernel regressions pass development/O2.
Quanta 1, 7, 4096 and mixed 1/7/3/4096/2 preserve actual results, diagnostics,
Fuel and binary output. Every tested resume denies SDK allocations and records
zero attempts; terminal cleanup leaves zero SDK allocations. Reference-return
zero-payload accounting is source-inspected here; these four groups do not add a
dedicated reference-return test. A one-less whole-run Fuel failure may occur at
the output seal with offset zero; synchronous and stepped diagnostics match.

Both profiles measure return state 48 bytes, Cursor 1016 (+48),
Machine 1464 (+48) and unchanged Core 120880. Reserved Vec8
return state adds 384 bytes; combined array/CALL/RET work adds
7552. Existing native-size admission charges this storage
before allocation. All 268 receipt inputs plus two audit inputs match raw checkout
and committed Git. All 263 production modules retain LF; the root locked check
passes 271 sources/3032 MIR functions. The reviewed transport has 33 typed
bindings and 32 layouts. Full M2/CLI matrices were not rerun.

## Remaining obligations

Return payload admission addresses only the work described above. Metadata and
catalog traversal, broader CALL/RET metadata planning, cleanup and abort work,
setup/proof/seal, deadlines and poison handling, and the public lifecycle/ABI/CLI
remain open. The [remaining-work inventory](../product/04-remaining-work.md) and
[completion plan](completion-plan.md) still govern completion; R03-R05 remain
incomplete. The shared byte allowance is not a wall-clock bound and does not
establish the public bounded-step contract.
