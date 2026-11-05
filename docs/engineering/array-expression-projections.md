# Grouped array values and scalar projections

Date: 2026-11-06. This is a source-language increment within L02/L03. It does
not establish full language, C05, Instance or delivery completion.

## Supported forms

Parentheses now preserve the existing fixed scalar-array value in these places:

- Index and `.len` projections on named owners and array-returning CALLs,
  including nested grouping and inferred scalar locals.
- Inferred or annotated `let`/`var` array initializers, by-value array arguments,
  owned array returns, and whole-array assignment right-hand sides.
- Grouped list/repeated literals in those same by-value contexts.
- `text::valid_utf8` arguments over grouped exact-u8 owners, literals and CALL
  results, with existing immediate or computed range suffixes.

For example:

```brownie
fn i32[2] make() { return ([20,22]); }
fn i32 sum(i32[2] values) { return (values)[0]+(values)[1]; }
fn i32 main() {
    let a=(make());
    let b=((a));
    return sum((b));
}
```

All six existing scalar element domains retain exact types and shape. Grouping
performs no implicit conversion, capability grant or source-name resolution
fallback. Qualified module calls use the same scoped lookup on both compiler
routes. Version JSON exposes `array_expression_projections: true` and
`array_grouped_values: true` for this specific source scope.

## Ownership and evaluation

Read-only lookahead classifies a possible grouped atom; it grants no authority
and evaluates no guest expression. The actual parser rechecks the owner/function,
exact element/length and matching closing tokens before publishing its context.

A named projection reads the original owner after its index effects. An array
CALL executes once before its suffix, even for `.len`. Completed literal/CALL
owners join hidden lexical cleanup before evaluating endpoints, then drop promptly
after the scalar read or UTF-8 predicate. Return, `?`, break and continue use the
original mixed reverse-order cleanup. Earlier guest writes/effects stay applied.

Declarations copy named values into independent extents. Mutable by-value CALL
arguments snapshot before later argument effects; immutable named arguments need
no copy before the existing CALL value copy. Array results use the original move,
assignment and finalization recipes. Parenthesized list/repeated replacement
emits the existing in-place replacement/refill, with no temporary owner or extra
backing quota. Five source pairs compare grouped and ungrouped
instruction bytes and register/array/list counts, then execute with four/eight
backing bytes, including full-quota replacement and owned result transfer.

The immutable argument-prefix path also recognizes grouped names. It keeps a
large lexical-table snapshot out of recursive source CALL frames, preserving the
existing 32-level parser boundary. Parentheses count against the same expression
budget as index expressions; a grouped projection cannot reset that budget.

## Native development harness

The first development native run stopped the existing leading-immutable-array
32-level CALL case with Windows stack-overflow status `-1073741571`. Isolated
probes passed the ordinary case and reproduced the retained-case failure. The
shared test source builder also reserved its unused ordinary `Program`/`Result`
staging on the retained call path. Moving ordinary compile/run into a separate
test helper removed that reservation while retaining every original source,
32/33 boundary, assertion, backing quota and execution route. The original
combined test then passed without a compiler or stack override. This is scoped
harness evidence, not a general native API stack guarantee.

Advisory grouped-projection classification also returns only a boolean to the
recursive scalar operand parser; its larger lookahead plan stays in a separate
helper frame. This preserves ordinary scalar parsing and does not change guest IR.

## Verification and remaining scope

Windows development and release each passed **14 native groups and 145 tool-free
CLI cases** on 166 checkout/Git-raw-matching input paths, 157 LF production modules
and the common 269-file discovery identity. Both locked LF mirrors pass. Runs
started on `f295771`; the captured source/test/tool bytes match implementation
`658ef47`. See [Windows evidence](../evidence/array-expression-projections-windows-20261106.json).

Reproduce on the pinned compiler:

```text
python -B tools/verify-static-execution.py --profile development --selection array-expression-projections
python -B tools/verify-static-execution.py --profile release --selection array-expression-projections
python -B tools/verify-local-inference-cli.py --profile development --array-expression-projections
python -B tools/verify-local-inference-cli.py --profile release --array-expression-projections
```

CLI builds share their output and must be serialized. The focused native
selection combines new cases with original literal effect/cleanup/Fuel cases,
original 32/33 captured-CALL boundaries, and actual qualified module compilation
through ordinary and retained routes. The CLI selection keeps the earlier
literal/list cases and adds the grouped forms, error kinds and depth boundaries.
The native runner checks a locked LF production mirror and rejects changed inputs
and native compiler/stack overrides. No opcode, operation price, default 256 or
explicit CLI ceiling 16000000 changes are introduced.

Grouped aggregate control-flow results, record expression integration, nested or
resource-bearing array elements, grouped lvalues and `ref (array)` source forms
remain outside this increment. General returned references, full C05 capacities,
Instance accounting/stepping, host APIs, Linux and restricted/embed delivery remain
open. No whole-project benchmark or general stack-size guarantee is claimed.
