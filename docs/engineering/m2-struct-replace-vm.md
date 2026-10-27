# M2 Metered Atomic Root Replacement

- Status: implemented and verified in development and release.
- Implementation commit: `6f1b38f`.
- Evidence: [Windows receipt](../evidence/m2-struct-replace-vm-windows-20261027.json).
- Predecessor: [scalar-value storage replacement](m2-struct-replace-values.md).
- Implementation: [IR](../../src/ir.fy), [verifier](../../src/struct_verifier.fy),
  [dispatch](../../src/struct_vm.fy).
- Tests: [native replacement cases](../../tests/m2/struct_replace_vm.fy).
- Combined selection: `python -B tools/verify-m2-struct-values.py --replace-vm`.

## Private instruction

`SREPLACE` (48) replaces one existing complete record from consecutive scalar
register cells. It uses the existing eight-byte instruction width:

| Byte | Meaning |
| --- | --- |
| 0 | 48 (`SREPLACE`) |
| 1 | Live mutable destination binding |
| 2 | First scalar input register |
| 3 | Exact nominal root record ID |
| 4..7 | Reserved zero |

The `record_replace` builder encodes these operands. Independent verification
requires an entry-owned live mutable binding, its exact nominal ID and a complete
consecutive register range matching all depth-first scalar leaf tags. Every input
must be defined, function-local, and an ordinary scalar value rather than a
mutable slot or array parameter. Physical layout equality cannot replace nominal
identity. No scalar definitions or owner live sets change; existing joins and
backedge invariants apply. `SINIT` and `SREPLACE` share the input-range checker.

## Dispatch and atomicity

The existing general struct dispatch route now handles opcode 48. It charges
46,145 Fuel before traversal, authority checks, byte staging or mutation:
`2*18432 + 2*4096 + 1024 + 65`. This ceiling covers two full catalog plans,
leaf-count and encoding traversals, canonical byte work and owner scans. It is
a bounded-work allowance, not a measured execution-time claim.

Dispatch rejects non-entry frames, dead/stale tokens, immutable destinations,
wrong nominal IDs and incomplete register ranges. The owner layer revalidates
the descriptor and whole catalog, then encodes all input cells into at most 128
canonical bytes before publishing the complete existing extent. Invalid scalar
values, layouts, bounds or metadata preserve the destination. Padding is zeroed;
neighboring bytes remain untouched. No fallible step or Fuel debit occurs during
the final byte commit. Registers, owner descriptors/tokens, generations, order,
arena cursor and capacity remain unchanged.

No temporary owner, record site or payload extent is reserved, including with
16 occupied owners and a full arena. Private dispatch accepts 128 leaves and
128-byte roots at depth at most 16. Other existing limits remain unchanged.
The small native IR example returns 42 with one eight-byte root and 133,650
total Fuel; one less fails. Instruction-local prepayment is tested separately
at 46,145 versus 46,144 Fuel. Later invocation failures do not undo a completed
replacement, earlier statements or external effects.

## Source boundary

Source lowering for `p = P { ... }` is not implemented in this slice. No version
capability or bytecode loader is added. Existing source profiles remain; private
flat-record replacement selects the copy family and nested programs retain
`brownie.m2-struct-nested/1`. CLI regression cases exercise existing source
behavior; the new opcode is exercised by native IR and dispatch tests.
The next source slice must evaluate all RHS fields in order and stage their
values before emitting this instruction.

## Verification

The initial six development groups passed: builder/verifier/VM execution with
exact total Fuel and payload boundaries; malformed nominal/type/register/live
state and reserved operands; instruction prepayment and state preservation;
all six scalar types and padding; 128 leaves with 16 owners and a full payload;
and unchanged scalar/live-set behavior across joins and backedges.

The combined selection adds eight existing struct VM, nine IR and four atomic
assignment groups, plus the 83 child-path and 131 assignment CLI cases in each
profile. The complete invocation passed in development and release
without reusing earlier results: 27 native groups and 214 CLI cases per profile.
The receipt records 102 input hashes, compiler/artifact identities, commands
and outcomes. Input and compiler hashes, the release binary hash and identical
native identities across profiles were rechecked before archival. The SDK lock
identity is unchanged. Full native suites, other CLI
matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and
performance are outside this selection. Earlier receipts remain historical for
changed verifier, VM, profile-selection, root-lock, test and harness inputs.
