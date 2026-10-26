# M2 Private Struct IR and Verification

- Status: private entry-owned struct IR and verifier implemented. Its 46-group native and 115-case CLI results are historical after changed runtime, test, harness, and root-lock inputs.
- Scope: struct bindings and lifetime verification. Private metered execution continues in the [struct VM contract](m2-struct-vm.md).
- Implementation: [src/ir.fy](../../src/ir.fy), [src/verifier.fy](../../src/verifier.fy), [src/struct_meta.fy](../../src/struct_meta.fy), and [src/struct_verifier.fy](../../src/struct_verifier.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--ir`.
- Historical native evidence: [Windows receipt](../evidence/m2-struct-ir-windows-20261026.json).
- Historical focused CLI evidence: [Windows receipt](../evidence/m2-struct-ir-cli-windows-20261026.json).

This increment adds private IR for named record bindings owned by the entry
function. The catalog binds at most 16 selected record definitions. Struct
bindings never occupy scalar registers; scalar registers carry only scalar
values. Record parameters, record results, source struct syntax, and borrows
remain outside this and the private VM slice.

## Instruction encoding

Every instruction is eight bytes. For struct opcodes 41..46, bytes 4 through 7
are zero. Opcode 47 uses bytes 4/5 for target/source leaf ordinals and keeps
bytes 6/7 zero. The first four bytes are `op, dst, a, b`.

| Opcode | Name | Operands |
| --- | --- | --- |
| 41 | `SINIT` | `dst` = binding, `a` = first consecutive scalar register, `b` = 0 |
| 42 | `SCOPY` | `dst` = new binding, `a` = live source binding, `b` = 0 |
| 43 | `SREAD` | `dst` = new scalar register, `a` = binding, `b` = flattened leaf ordinal |
| 44 | `SWRITE` | `dst` = binding, `a` = flattened leaf ordinal, `b` = scalar value register |
| 45 | `SDROP` | `dst` = binding, `a` = 0, `b` = 0 |
| 46 | `SASSIGN` | `dst` = live mutable destination, `a` = live source, `b` = 0 |
| 47 | `SSUBASSIGN` | `dst` = live mutable target, `a` = live source, `b` = selected nominal record; bytes 4/5 = target/source leaf starts |

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

`vm::run` verifies first. The earlier unavailable kind-11 boundary no longer
applies: private dispatch and Fuel accounting for opcodes 41..46 are defined in
the [struct VM contract](m2-struct-vm.md). The source frontend still does not emit
these instructions from struct declarations.

## Verification status

`python -B tools/verify-m2-struct-layout.py --ir` passed 46 native groups per
development and release profile: 9 struct-IR groups and 37 regressions
comprising array IR (5), array calls (9), array results (6), array-result VM
(6), branches (5), and loops (6). Both profiles selected the same identities
with stable source hashes and the pinned Fairy C compiler `4ce1264273be`. The
focused repeated-literal assignment CLI suite also passed 115 cases per profile.

Those results are historical for changed `src/vm.fy`, `tests/m2/struct_ir.fy`,
the harness, and root-lock inputs. In particular, the IR smoke now expects kind 8
at zero Fuel and successful metered execution at sufficient Fuel; the old
kind-11 assertion no longer describes the runtime. The focused CLI suite was
rerun for both profiles in the struct VM slice.

The current [struct VM contract](m2-struct-vm.md) owns dispatch, shared storage,
Fuel charges, and runtime failure behavior. Its [native receipt](../evidence/m2-struct-vm-windows-20261026.json)
passes 38 groups per development/release profile, including all nine struct-IR
groups. Its [focused CLI receipt](../evidence/m2-struct-vm-cli-windows-20261026.json)
passes 115 cases per profile. Full native suites,
full CLI matrices, M0, Linux, OS isolation, DLL, packaging, allocator
instrumentation, and performance were not rerun.

Next is source struct declaration and type-catalog work, followed by lowering for
complete initializers and field access.

The [atomic subrecord successor](m2-struct-subassign-atomic.md) independently
checks nominal record nodes at both leaf starts, liveness, mutability, and
reserved bytes. It changes no scalar SSA definitions or owner live sets. Its
combined selection includes all nine existing IR groups on the updated verifier.
