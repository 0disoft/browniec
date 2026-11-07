# Shared Buffer-view signatures and retained calls

This increment connects private shared `ref u8[]` function parameters and results
to the typed value verifier and retained native VM. Publication is conditional
on the complete canonical scalar/owner/loan/place proof and the independent
value and view CFG proofs. Native binding numbers never become guest authority.
Verification is pending while the implementation is being integrated.

## Signatures and instructions

The existing private value metadata reserves disjoint encodings. Parameters
1..16 remain owning value slots plus one; 17..32 denote per-frame readonly view
IDs plus17. Function results1..16 remain owning anchors plus one; 17..24 select
one shared-view input by argument ordinal plus17. Every selected input must
really be a shared-view formal. Entry parameters/results cannot be references.
Ordinary register types and owning cells contain no reference descriptors.

CALL actuals208..223 retain their typed value meaning; 224..239 name shared-view
IDs. Opcode93 still calls mixed signatures returning scalars/void/owned values.
New opcode114 returns a shared view (`dst=view`, `a=callee`, `b=argument map`).
New opcode113 returns one shared view (`dst=0`, `a=view`, `b=0`). Reserved bytes
remain zero. Ordinary public/image admission does not acquire this dialect.

The view CFG initializes each formal with origin17+argument ordinal; local
Buffer origins remain1..16. Aliases and ranges inherit origins. A returned CALL
result inherits its selected actual, retaining the caller root through all
transitive calls. RETURN must leave exactly its selected-origin descriptor and
no canonical owned values. Local roots, wrong inputs, conflicting owner moves,
dead actuals, occupied destinations and malformed metadata fail admission.

## Runtime transaction

Argument aliases reuse the bounded native registry. Authenticate frames,
prepay512 Fuel per alias and stage complete metadata before publication alongside
ordinary/typed actuals. Shared arguments copy no payload and preserve caller
descriptors. A returned descriptor must fit within the selected caller-origin
window on the exact authenticated physical root; the move costs256 Fuel in
addition to the existing surrounding frame/ordinary work. No-view programs keep
their old prices and setup. Failure drains views before roots, without requiring
remaining Fuel or replacing the first failure.

Source calls use explicit `ref` actuals. Reference result inference supplies
advisory selected-input hints for forward/transitive calls; independently proved
IR remains mandatory. Argument captures evaluate once before later operands.
The selected result survives caller capture cleanup; its final alias releases
an otherwise anonymous retained root. Directly naming a temporary Buffer view
still does not implicitly extend its owner lifetime.

## Scope and verification

The focused runner is `tools/verify-value-view-call-program.py`, with separate
`core`, `source` and `regression` batches and development/release native mirrors.
Public syntax/capabilities, mutable/non-byte/general references, view-valued
joins, methods, public AllocError, host/I/O and full delivery remain separate
requirements in the [remaining-work audit](../product/04-remaining-work.md).
