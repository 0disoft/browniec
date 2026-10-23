# M2 Private Array Instructions

- Scope: entry-function array IR and independent verification, not source grammar.
- Implementation: `array_meta.fy`, `array_verifier.fy`, `ir.fy`, `verifier.fy`.
- Harness: `tools/verify-m2-arrays.ps1 -Slice ir`.
- Evidence: [Windows IR receipt](../evidence/m2-array-ir-windows-20261024.json).

This increment gives the [array owners](m2-array-owners.md) a private instruction
contract. Source parsing still admits only the existing scalar grammar. The first
IR increment rejects verified array programs as unavailable in the VM until the
subsequent dispatch increment; it never executes them as scalar instructions.

## Catalog and instructions

Program contains at most 16 array declarations. Each has one scalar element tag,
literal length 1..4096, and mutability flag. Every declared layout is checked;
unused catalog entries must be zero. Arrays are separate from scalar registers:
neither a scalar constant nor a scalar cast can manufacture an array owner token.

Private instructions remain eight bytes. All four reserved bytes are zero for
these opcodes. Array IDs refer to the catalog; register indices refer to scalar
values in the current function, never storage slots.

| Opcode | Bytes 0..3 | Effect |
| --- | --- | --- |
| 33 AINIT | `33,array,fill,0` | Initialize a dead array from a matching scalar register |
| 34 ACOPY | `34,destination,source,0` | Copy a live array into a dead array of identical element type and length |
| 35 AREAD | `35,scalar-destination,array,index` | Read an element into a new scalar value register |
| 36 AWRITE | `36,array,index,value` | Write a matching scalar into a live mutable array |
| 37 ADROP | `37,array,0,0` | Release a live array |

Index registers have exactly guest usize type. Fill, write and read values have
the exact declared element type, with no implicit promotion. AREAD has a unique
scalar destination; every other array instruction defines no scalar register.
ACOPY preserves the source and the destination declaration's mutability.

## Lifetime verification

The verifier tracks one 16-bit live-array set at every reachable instruction,
independently of scalar definite initialization. AINIT/ACOPY require a dead
destination and make it live. Reads/writes/copy sources/drop require a live array;
ADROP makes it dead. Every normal return requires the empty live set.

Every forward join requires exactly matching incoming live sets. Backedges must
preserve the target's first-entry live set as well as the existing scalar
initialization invariant. A loop may create and drop the same declaration on
each iteration. An unbalanced branch, double initialization/drop, use after drop,
or return with live ownership is rejected before execution. This is a conservative
bounded state analysis, not a complete source ownership/borrow checker.

Array instructions are admitted only in the entry function. When an array
catalog is present, CALL cannot target the entry function, including from an
unused function. Scalar callees cannot access parent arrays. This prevents a
recursive entry frame from reusing the first increment's Instance-local array IDs.
Array function parameters, results and non-entry locals remain outside this slice.

Verification still rejects malformed code/metadata in all functions before any
guest instruction runs. MATCH_FAIL remains a terminal internal failure; runtime
failure cleanup is a separate execution responsibility.

## Evidence and next step

Five new native groups cover valid builders and exact copy types, catalog and
reserved-byte corruption, scalar/index types, immutable writes, matching forward
joins, balanced backedges, required drops, non-entry access and entry recursion.
The IR harness also reruns the existing five branch and six loop groups: 16 native
groups in development and release. Full scalar CLI regression is deferred to the
dispatch increment, where the common VM implementation changes.

No source-array or array-VM execution, allocation/Fuel policy, function-frame
cleanup, OS isolation, DLL, packaging or performance result follows from this IR
receipt. The next increment must connect real owner dispatch with metered
preparation and array work, then source construction/indexing can use this IR.
