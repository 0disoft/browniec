# Grouped assignment targets

Date: 2026-11-06. Successor to the [read-only syntax plan](grouped-place-syntax.md).

## Typed lowering and evaluation

Source statements now accept parentheses around a mutable target or a completed
prefix: `((x)) += n`, `((a)[i]) = n`, `(((slice))[i]) ^= n`,
`((record).child).field += n`, `(array) = values` and `(record.child) = value`.
Whole-array and whole/child-record assignment use the existing exact-shape/
nominal aggregate transactions. A CALL result, constructor or arithmetic value
does not become an assignable location by grouping it.

Only a leading grouped target reserves the syntax plan. Existing ungrouped
target paths retain their lowering; scalar assignments share their existing
LOAD/operation/STORE helper. Value-arm classification recognizes grouped
assignments before a final expression, while ordinary grouped values still go
through expression parsing. Pure for clauses accept grouped scalar assignments;
aggregate/slice destinations and effectful CALLs remain excluded there.

The plan resolves the visible mutable binding once and retains the pending
operator at its original source location. Each actual index is lowered once
from its saved lexer state, and must end at that plan's exact closing bracket.
Root grouping is handled iteratively; index expressions keep existing typed
expression-depth checks. Array/slice selection and bounds checks precede RHS
work. Compound READ captures the old scalar before any RHS mutation or CALL.

Grouped record fields resolve each original field span against the same scoped
nominal catalog. Each preceding scalar or subrecord contributes its depth-first
leaf count. The bounded resulting ordinal is used by existing record-place IR.
Qualified imported types and nested nonzero ordinals retain their original
owner, field type and neighboring bytes.

Scalar slots require no selected-place ID. Array, slice and record targets use
their existing shared IDs and snapshot/cleanup paths. CALL/reborrow restoration,
whole/child replacement, nested mixed writes, all return kinds, propagation and
loop transfers preserve the same targets and owner lifetimes. No new guest
opcode, owner, payload extent or runtime allocation is introduced by grouping.
Aborts preserve earlier effects and run existing prepaid cleanup without replay.

The five integer domains support all ten checked compounds. Plain bool and
existing tagged scalar assignment remain supported. Immutable/borrowed roots,
shared-slice writes, wrong types/fields, bool/aggregate compounds and assignment
expressions remain rejected. Version JSON adds `grouped_assignment_targets`;
grouped borrows are a separate remaining feature.

## Instruction-byte parity and Fuel

Seven native source pairs compare complete instruction bytes, instruction and
register counts and aggregate-site counts with the corresponding ungrouped
form. Diagnostic offsets intentionally refer to the respective original source.
Grouping introduces no guest instructions or preparation charge. Independent
ordinary and forced-retained exact/one-short checks cover all four scalar target
kinds; public CLI checks one-short, exact and one-more with and without a marker.

| Target fixture | Plain ordinary | Compound ordinary | Plain retained marker | Compound retained marker |
| --- | ---: | ---: | ---: | ---: |
| Scalar local | 6 | 8 | 344088 | 344090 |
| Owned i32 array element | 69308 | 69378 | 413396 | 413467 |
| Exclusive i32 slice element | 152817 | 156984 | 496907 | 501075 |
| Owned i32 record field | 240190 | 281220 | 584278 | 625309 |

These are complete fixtures in `tests/m2/grouped_assignment.fy`, not general
per-assignment prices. Forced retained entry without a marker subtracts18 from
the last two columns. Existing operation prices, default256, ceiling16000000,
source/token/register/instruction/CALL/backing limits remain unchanged.
All 64 bindings remain usable, thirty sequential record compounds reuse IDs,
and32 root groups pass while33 return a compile-limit error. The syntax
prerequisite's sixteen-selector and32-entry index-stack bounds still apply.

## Verification and frontier

Run `python -B tools/verify-static-execution.py --profile development
--selection grouped-assignment`, repeated for release. The eighteen groups are
seven new grouped-source groups, two syntax-plan groups and nine regression
scalar/array/slice/record exact-cost, local-slot, qualified-module and original
ordinary/retained32/33 CALL-bound regressions. Two hundred kind/type/operator
pairs exercise all current targets; other groups cover IR parity, index order,
bounds-before-RHS, restoration/replacement, returns/propagation/loop cleanup,
rejections,64 bindings, reuse and Fuel.

For each profile, build and check public Fuel with
`tools/verify-public-fuel.py --phase cli`, then run
`tools/check-grouped-assignment.py` against that profile's copied executable.
Both checkers run with a cleared, tool-free PATH. The grouped checker also
checks a nested nonzero ordinal and its untouched neighbors in both routes.

Grouped borrows, generic aggregate overlap proof, broader reference/resource
joins and full L04/C05/Instance/host/delivery remain open. Full language/original
full native Fuel matrices, Linux, OOM injection, general stack/performance,
worker isolation and clean-machine delivery are outside this focused selection.

Windows development/release each passed **18 native groups** and **416 tool-free
CLI cases**: 359 grouped assignment and57 public Fuel. The grouped checker also
includes twelve ordinary/retained cases for grouped final-value expressions and
one-time index CALLs. All 195 executed input hashes match checkout and
staged Git raw bytes; native/public Fuel phases capture
184/184 inputs. Both locked LF mirrors pass with 171 LF production
modules and 297-file discovery. The 40 unselected legacy CRLF/LF-only
fixture differences are recorded separately. No native compiler/linker/stack
overrides or historical result reuse were used. See
[Windows evidence](../evidence/grouped-assignment-windows-20261106.json).
The skipped scopes above remain unverified here.
