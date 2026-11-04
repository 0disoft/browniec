# Private returned CALL binding proof

Date: 2026-11-04. This B04 increment adds independent IR lifetime/origin proof.
Source result-binding lowering and executable binding dispatch remain pending.
The full objective remains [completion of the accepted design](completion-plan.md).

## Representation

The private `slice_result_ir::Program` keeps its existing layout and adds three
instruction markers. Ordinary Program admission still rejects these opcodes.

| Opcode | Fields | Meaning |
| --- | --- | --- |
| 66 CALL_BIND | dst=opaque proof identity, a=callee, b=CALL map; byte4=END mask, byte5=result site, byte6=surviving parent, byte7=0 | Call an exact borrowed-result function and reserve its caller destination |
| 68 END_CAPTURE | dst=child, a=parent, b=0; bytes4..7=0 | Account for an anonymous exclusive argument ended by canonical handoff |
| 67 BIND_RESULT | dst=result site, a=surviving parent, b=lower witness register, byte4=upper witness register; bytes5..7=0 | Establish the returned view's live caller binding |

CALL_BIND must reach its matching BIND_RESULT through only END_CAPTURE, slice
CLOSE, array DROP or record DROP. Branches and function starts cannot enter this
interior. Metadata and finalizer must name the same child and surviving parent.
The END mask uses formal argument positions, not slice site numbers.

The new `slice_result_call_ir` module normalizes a local copy to ordinary CALL,
reborrow END and shared SUBSLICE/exclusive BEGIN. Full existing CFG, definition,
type, live-root, loan-stack and cleanup proof then runs on that copy. The copy is
never executed or exposed as ordinary Program. The finalizer's range registers
are proof witnesses; they do not describe or truncate the actual returned range.
The native construction test uses the same zero register for both witnesses.

Recipe proof additionally checks the callee's independently inferred selected
input, exact element/access, caller destination and surviving parent. Every mask
bit requires exactly one matching END_CAPTURE for a pre-existing exclusive child.
Acquisitions must agree with argument order; normalized loan proof requires the
reverse release order. Unselected arguments still receive their existing cleanup.
The opaque CALL identity cannot feed scalar arithmetic, returns, arguments,
stores, constructor leaves, indices, ranges or other scalar consumers. Ordinary
CALL-map uniqueness continues to be checked by the base verifier.

## Origin and execution boundaries

When bindings are present, the origin solver follows actual SUBSLICE/BEGIN and
CALL binding definitions, including the selected callee argument. It accepts only
formal input anchors as grounded roots. A flattened `slice_origins` claim cannot
seed a recursive result cycle. Shared sites used in this trace must have a unique
static definition; owned roots and conflicting return paths cannot escape.
Source advisory hints are not admission evidence.

The solver still has at most seventeen rounds and sixteen site hops per origin.
Definition walks have bounded O(17 * S * I^2) work for S <= 16 sites and I <= 256
instructions. Recipe/consumer scans add O(I^2) bounded work and O(I) scratch, plus
one bounded Program normalization copy. These are compile-time bounds, not
runtime Fuel, native stack-size or speed measurements. No Fuel price or CLI limit
changes in this increment.

`slice_result_ir::from_proxy` constructs the private representation; independent
`slice_result_verifier::inspect` rechecks it without compiler signatures or hints.
The compiler still does not emit binding recipes from source. Both public result
syntax and capability promotion remain gated. Private VM entry rejects these
unsupported markers before independent admission/initial ownership transfer.
It therefore preserves native owner tokens, pool tickets and backing bytes.

## Verification and next work

The focused [Windows evidence](../evidence/m2-slice-result-call-ir-windows-20261104.json)
records 26 development native groups (nine new binding, ten existing IR and seven
scalar-entry groups), and the nine new groups in release. All 122 captured input
hashes still match; all 116 production modules use LF, and an LF mirror passed
`check --locked`. Standalone CLI and broader/full-profile/platform/delivery/
performance checks were not run. New cases cover
all six scalar types in both access modes, non-first selected inputs, anonymous
exclusive capture cleanup, recursive-origin laundering, scalar identity misuse,
malformed masks/markers, interior CFG entry and native pre-entry preservation.
The large IR construction fixture runs before the runtime-state fixture in a
separate function: their combined development stack previously overflowed and
that exploratory result is excluded. Final runs use the default compiler and
stack settings, with no historical-result reuse.

Next connect source result destinations to these recipes and native retained
Held bindings, including fresh parent tickets and selected temporary owner
retention. Then add borrowed-result argument/projection handling, Static backing
and independent public admission/dispatch. This proof prerequisite does not
complete B04 or the full implementation objective.
