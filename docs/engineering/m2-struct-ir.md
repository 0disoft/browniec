# M2 Private Struct IR and Verification

- Status: private entry-owned struct IR and verifier verified; development and release passed.
- Scope: struct bindings, lifetime verification, and the honest VM-unavailable boundary.
- Implementation: [src/ir.fy](../../src/ir.fy), [src/verifier.fy](../../src/verifier.fy), [src/struct_meta.fy](../../src/struct_meta.fy), and [src/struct_verifier.fy](../../src/struct_verifier.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--ir`.
- Native evidence: [Windows receipt](../evidence/m2-struct-ir-windows-20261026.json).
- Focused CLI evidence: [Windows receipt](../evidence/m2-struct-ir-cli-windows-20261026.json).

This increment adds private IR for named record bindings owned by the entry
function. The catalog binds at most 16 selected record definitions. Struct
bindings never occupy scalar registers; scalar registers carry only scalar
values. Record parameters, record results, source struct syntax, borrows, and
struct execution remain outside this slice.

## Instruction encoding

Every instruction is eight bytes. Bytes 4 through 7 are zero. The first four
bytes are `op, dst, a, b`.

| Opcode | Name | Operands |
| --- | --- | --- |
| 41 | `SINIT` | `dst` = binding, `a` = first consecutive scalar register, `b` = 0 |
| 42 | `SCOPY` | `dst` = new binding, `a` = live source binding, `b` = 0 |
| 43 | `SREAD` | `dst` = new scalar register, `a` = binding, `b` = flattened leaf ordinal |
| 44 | `SWRITE` | `dst` = binding, `a` = flattened leaf ordinal, `b` = scalar value register |
| 45 | `SDROP` | `dst` = binding, `a` = 0, `b` = 0 |
| 46 | `SASSIGN` | `dst` = live mutable destination, `a` = live source, `b` = 0 |

`SINIT` consumes every depth-first scalar leaf in declaration order from
consecutive registers beginning at `a`. Each register must have the leaf's exact
scalar type. Initialization is all or nothing: a missing register, mismatched
type, undefined value, storage slot, or array parameter placeholder is rejected
before the binding becomes live. Already defined input values may be reused. Nested leaves use flattened
ordinals, not source field paths or byte offsets.

`SCOPY` requires a dead destination and a live source with the exact nominal
record ID. `SASSIGN` requires a live mutable destination and a live source with
the same nominal ID; records with identical physical layouts but different IDs
do not match. Self-assignment is valid. `SREAD` requires a live binding and
defines a fresh scalar register with the leaf type. `SWRITE` requires a live
mutable binding and a readable exact-type scalar value. `SDROP` requires a live
binding and clears only its lifetime bit.

## Catalog and lifetime checks

Every verification pass replans the complete immutable catalog: at most 32
definitions, 16 fields per record, and structural depth 16. Selected roots are
limited to 128 bytes and 128 scalar leaves; valid unselected definitions may be
larger. The catalog admits at most 16 record bindings.
Unused definitions and padded inactive binding slots are still validated.

Preparation flattens each selected root iteratively into a fixed 2048-byte tag
array, indexed as `binding * 128 + leaf`. This is an algorithmic scratch bound,
not a measured stack size or allocation guarantee.

Combined aggregate liveness occupies 32 bits: array lifetimes use bits 0..15
and record lifetimes use bits 16..31. Forward joins and backedges require exact
combined live sets. Scalar returns require no live arrays or records; array
returns retain the existing sole-live-array transfer rule. Static binding sites
do not reserve storage or guarantee allocation: the runtime owner primitives
still share sixteen slots across arrays and records.

Struct instructions are accepted only in the entry function. Calls into the
entry function are rejected whenever any array or record binding exists,
including calls in otherwise unused functions. Existing array calls, array
results, and their verifier paths continue independently.

`vm::run` verifies first. For any nonempty record binding catalog it then
returns error kind 11 before payload preparation, owner setup, or guest
execution, including when no struct instruction is reachable. Struct VM
dispatch and Fuel accounting are the next slice.

## Verification status

`python -B tools/verify-m2-struct-layout.py --ir` passed 46 native groups per
development and release profile: 9 new struct-IR groups and 37 regressions
comprising array IR (5), array calls (9), array results (6), array-result VM
(6), branches (5), and loops (6). Both profiles selected the same identities
with stable source hashes and the pinned Fairy C compiler `4ce1264273be`.

The focused repeated-literal assignment CLI suite passed 115 cases per profile,
including the prior composed depth-10 success and depth-11 compile-limit boundary.
Full CLI matrices were not rerun.

The previous struct-owner-copy receipt is historical for changed IR, harness,
and root-lock inputs; unchanged primitive source evidence remains valid for its
original scope. M0, Linux, OS isolation, DLL, packaging, allocator instrumentation,
and performance were not rerun. Next: struct VM dispatch and Fuel.
