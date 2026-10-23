# M1 Scalar Checkpoint Audit

- Date: 2026-10-23
- Decision: the roadmap's bounded M1 scalar source-to-native-VM exit condition is met.
- Scope: `brownie.m1-scalar/1`, not the full `brownie.safe/0.3` profile.
- Evidence: [identity audit](../evidence/m1-checkpoint-audit-20261023.json) and
  [executed Windows receipt](../evidence/m1-switch-arm-statements-windows-20261023.json).

This audit compares the product specification, roadmap, and all twelve M1
engineering contracts with the implemented source and recorded tests. It reuses
the executed development/release evidence after checking its input, compiler,
artifact, and report identities. It does not label a documentation review as a
new native test run.

## Requirements and evidence

| M1 obligation | Implementation and coverage | Finding |
| --- | --- | --- |
| Bounded UTF-8 source, tokens, parsing, diagnostic offsets | `src/lexer.fy`, `src/compiler.fy`, `src/functions.fy`; `tests/core.fy`, `tests/i64_scalars.fy`, CLI source/token/depth cases | Met for the documented ceilings |
| i32/i64/u8/u32/64-bit usize and canonical bool | `src/types.fy`, `src/cells.fy`; `tests/bools.fy`, `tests/cells.fy`, `tests/i64_scalars.fy`, `tests/unsigned_scalars.fy` | Met; exact types and no implicit promotion |
| Initialized locals, immutable let/parameters, typed var, lexical scope | `src/locals.fy`, `src/compiler.fy`; `tests/core.fy`, `tests/branches.fy`, CLI scope cases | Met; assignment is a statement |
| Direct functions, ordered argument evaluation, bounded guest recursion | `src/functions.fy`, `src/vm.fy`; `tests/functions.fy`, `tests/branches.fy` | Met; VM frames, no native guest recursion |
| Checked arithmetic and first executed failure | `src/arithmetic.fy`; `tests/core.fy`, `tests/i64_scalars.fy`, `tests/unsigned_scalars.fy` | Met; overflow/zero divisor are guest outcomes |
| Fixed-width bitwise operators and checked shifts | `src/bits.fy`, `src/shifts.fy`; `tests/bitwise.fy`, `tests/shifts.fy` | Met for every admitted integer type |
| Explicit domain-preserving widening | `src/casts.fy`, `src/types.fy`, opcode 26; `tests/widening.fy` | Met for the seven documented pairs |
| Short-circuit bool, branches, terminal paths | `src/compiler.fy`, `src/verifier.fy`; `tests/branches.fy`, `tests/bools.fy` | Met; untaken work does not run |
| while/for, lexical transfers, post ordering, metered backedges | `src/loops.fy`, `src/compiler.fy`, `src/verifier.fy`; `tests/loops.fy` | Met; pure for headers and conservative zero-trip completeness |
| Shallow tagged constructors, by-value copies, exhaustive statement switch | `src/types.fy`, `src/tagged.fy`, `src/patterns.fy`; `tests/tagged.fy` | Met for i32/bool payloads only |
| Postfix question-mark success/failure and exact Result error types | `src/propagation.fy`, `src/compiler.fy`; `tests/propagation.fy` | Met for those shallow wrappers |
| Expression switch, typed value joins, statements inside arms | `src/compiler.fy`, `src/verifier.fy`; `tests/switch_expression.fy`, `tests/switch_arm_statements.fy` | Met; at least one yielding arm, no never type |
| Independent private-IR verification before execution | `src/verifier.fy`, `src/vm.fy`; corrupt-IR cases across the native groups | Met for current scalar IR; not an aggregate/ownership verifier |
| Fuel, fresh run state, reusable Program, stable CLI result/failure framing | `src/vm.fy`, `src/main.fy`, `src/render.fy`; `tests/core.fy`, `tests/functions.fy`, `tools/check-m1-cli.py` | Met; guest nonzero is data, check does not run source |
| Native executable without a runtime compiler/interpreter dependency | Fairy dispatch and CLI; both profiles' recorded empty-PATH CLI runs | Met for the tested environment; clean-machine packaging is M5 |

The cumulative receipt records 81 native groups and 1,969 CLI cases in each
profile. These counts identify that run, not independent proofs for every row.
The audit found no missing requirement within the declared scalar checkpoint.

## Limits that remain explicit

The admitted syntax and implementation ceilings remain those of the
[scalar contract](m1-scalar-slice.md). Main is zero-argument i32. Wrapper payloads
are i32/bool only; wide and unsigned wrappers are deliberately rejected. Classic
for headers exclude calls, switches, and question-mark propagation. Imports,
compound assignment, suffixes, narrowing, nested wrappers, and aggregate values
are outside this checkpoint. Passing this gate does not silently admit them.

Earlier contracts describe historical increments. Their statements that M1 still
needs integer operators, conversions, or richer switch arms are superseded by the
later widening, integer-operator, and arm-statement contracts and this audit.
No historical execution receipt is rewritten.

## Next boundary

M2 owns arrays, structs, borrows, Buffer, input/output, and UTF-8 operations. Its
first slice should establish bounded scalar-array storage before source syntax:
lengths 1..4096 must not consume one of the 128 value registers per element.
Compact payload bytes need independent layout validation, overflow-safe indexing,
and quota preflight. Source construction, by-value copies, frame reclamation,
and aggregate metering need their own subsequent implementation and evidence.

M3 host suspension, M4 Windows isolation, M5 DLL/packaging, and measured performance
remain separate gates. Full-profile ownership, allocation and staged-output
requirements are not discharged by scalar M1.
