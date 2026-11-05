# Scalar projections of array literals

Date: 2026-11-06. Successor to [list source contexts](array-list-contexts.md) and
[assignment](array-list-assignment.md). This connects literal values to existing
scalar expressions; broader aggregate-valued expressions remain separate work.

## Source and types

Element lists and repeated literals accept `[x,y][index]`, `[value;N][index]`,
`[x,y].len` and `[value;N].len`. Parentheses around the literal are supported,
including `(([20,42]))[1]`. Scalar projections work in inferred/annotated locals,
assignments, operators, scalar CALL actuals, record fields, tagged payloads and
other list cells. Nested scalar projections do not add nested array elements.

All six existing scalar domains keep exact typing and contextual integer
literals. Length is `usize` and supplies no element-type expectation; for example,
`[true,false].len` keeps bool cells. Dynamic indices require `usize`, and complete
admission plus runtime bounds checks remain mandatory. Unknown members, empty or
mixed/non-scalar lists, wrong index types and malformed separators fail honestly.

Read-only lexer lookahead distinguishes a projected literal from an owned array
initializer or ordinary grouped scalar expression. It never evaluates a guest
expression or changes the active cursor/token count. Grouping uses the existing
depth budget. An inferred `let n=[20,42][1];` therefore binds an i32 scalar,
while `let a=[20,42];` retains its original owned-array initializer.

The existing `text::valid_utf8` literal route now also accepts exact-u8 element
lists, including its existing static/computed ranges. Repeated fillers keep their
previous route and one-time behavior. This adds no general owned-array range
value, escaping view, new text representation or runtime-view equality API.

## Evaluation and lifetime

Cells evaluate once from left to right; a repeated filler evaluates once. All
cells/filler effects and complete initialization precede index evaluation.
Length still evaluates and initializes the literal; it does not skip effects or
allocation merely because the shape is statically known. Short-circuit operators
skip their unevaluated guest expressions normally; invocation scratch preparation
still follows the existing whole-Program requirement.

Literal and CALL-result projections share one completed-owner finalizer. Before
an effectful index, the initialized temporary joins lexical cleanup through a
hidden binding. Return, propagation, break and continue release exactly the
owners whose scopes they leave. After a successful read/length, the temporary is
dropped immediately, so later expressions/iterations reuse backing and slots.
Pending initialization never registers a partial owner. Earlier RHS/guest effects
are not rolled back on a later exit or runtime failure.

## Fuel, bounds and discovery

No opcode, VM price or capacity changes. List creation remains `56+N+3*B` and
once-per-invocation setup remains `257+2*M+S`, or zero without lists. Repeated
initialization, reads, drops, UTF-8 and retained dispatch/entry/leave keep their
existing charges. Public default 256 and ceiling 16000000 remain unchanged.

| Source body | Native Fuel with 8 backing bytes | Public Fuel |
| --- | ---: | ---: |
| `return [20,42][1];` | 450 | 65978 |
| `return [42;2][1];` | 170 | 65698 |

Independent exact/one-short/one-more oracles also check the first source IR in the
retained coordinator at 410045 Fuel. The source limit, 1024 tokens, 128 registers,
256 instructions, 16 sites, 32 frames, 4096-entry operand pool and aggregate
backing limits retain their existing separate meanings. Grouping/nesting consumes
the original expression-depth budget; no compiler/stack override is introduced.

Version JSON adds `array_literal_projections` and `array_utf8_element_lists`.
Existing flags/profile names retain their meanings; restricted/embed stay false.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-literal-projections
python -B tools/verify-static-execution.py --profile release --selection array-literal-projections
python -B tools/verify-local-inference-cli.py --profile development --array-literal-projections
python -B tools/verify-local-inference-cli.py --profile release --array-literal-projections
```

Native selection includes eight new groups and six affected regressions: real
qualified module calls on both compiler routes, original list declaration
source/register/32-depth boundaries, assignment exit cleanup, existing list
CALL/result exact Fuel and existing UTF-8 literal price/endpoint cleanup. New
cases also cover nested indices, 16/17 sites, sequential four-byte backing reuse,
six domains, grouping/lookahead immutability, side effects, short-circuiting,
return/propagation/loop exits, retained execution and bounds/type errors.
CLI selection retains all 79 preceding cases and adds literal projections,
UTF-8, error/exit/profile behavior, exact Fuel and capability discovery with no
runtime tools on PATH. CLI builds are serialized.

Implementation `cb44a35` passed all fourteen native groups and 112 CLI cases in
each Windows development/release profile. All 168 input paths in the union match
the checkout and implementation Git raw bytes. Both locked LF mirrors pass with
156 LF production modules; the common discovery identity covers 268 test files.
All final runs use no compiler/stack overrides or historical-result reuse. Both
CLI artifact hashes and all reports/receipts are recorded in
[Windows evidence](../evidence/array-literal-projections-windows-20261106.json).

Remaining language work includes broader aggregate expressions/projections over
grouped names/CALLs and control flow, plus nested/resource-bearing elements.
This increment does not complete L02/L03/C05 or the full objective. Full native/
CLI matrices, Linux, allocator fault injection, general stack/timing benchmarks,
Instance accounting/resumability, host/project CLI, worker, ABI and delivery are
separate obligations.
