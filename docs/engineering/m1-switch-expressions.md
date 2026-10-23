# M1 Shallow Switch Expressions

- Status: implemented and verified on Windows; historical after the i64 increment; 41 native groups and 580 CLI cases in each development and release profile
- Scope: exhaustive shallow-wrapper switch expressions in `brownie.m1-scalar/1`

This increment extends the tagged switch statement into expression position. It
admits both variants of the existing one-level `Option` and `Result` families in
either order. It does not add nested patterns, default arms, fallthrough, new
scalar types, aggregates, or `brownie.safe/0.3` conformance.

## Source form

An exhaustive shallow-wrapper switch is an ordinary operand:

```text
switch (SUBJECT) {
    case .some(value): { FINAL_EXPR }
    case .none: { FINAL_EXPR }
}
```

Result values use `.ok(value)` and `.err(value)`. A value arm may contain zero or
more typed local `let`/`var` declarations and plain assignments, followed by one
final expression without a semicolon. It may instead end in `return EXPR;`, which
returns from the enclosing function. Conditional and loop statements, standalone
blocks, and transfers such as `break` or `continue` are not admitted inside a value
arm. The existing statement switch remains available for the broader statement subset.

At least one arm must yield a value. Two direct-return arms are rejected because the
current subset has no bottom or never type. A direct-return arm does not constrain
the switch value type. Every yielding arm must produce the same exact type: i32,
bool, or one of the six existing shallow wrapper types.

An expected expression type supplies constructor context. Otherwise, the first
yielding arm determines the output type and supplies constructor context to later
arms. A bare wrapper constructor without wrapper context remains rejected. This
allows a typed wrapper variable as the first yield and a context constructor as a
later yield, including when a switch expression is used with postfix `?` under a
scalar expected type.

## Evaluation and scope

The subject is evaluated once. A mutable subject is snapshotted before matching.
Both variants must appear exactly once in either ordering. A named payload is
immutable, `_` discards it, and a payload binding cannot redeclare a visible local
or parameter. There is no default arm, nested pattern, or fallthrough.

Each arm gets a private copy of the visible bindings. Declarations stay inside their
arm and cannot escape or shadow a visible name, while assignments to an outer `var`
persist. Sibling arms may reuse declaration names.

Switch expressions compose wherever an operand is admitted: nested expressions,
call arguments, return expressions, assignment right sides, while conditions,
short-circuit operands, and postfix `?`. All three classic `for` header clauses
remain pure scalar and reject switch expressions.

## Limits and private IR

Arm nesting adds two levels to expression depth and the subject adds one. The
existing expression-depth ceiling remains 32: 16 nested switch expressions are
admitted and 17 are rejected. A statement initializer inside a value arm preserves
the arm's depth instead of resetting it. Other source, token, instruction, register,
binding, function, call-site, loop, and frame limits are unchanged.

Lowering uses the existing `CASE`, `STORE`, `JUMP`, `MATCH_FAIL`, and `LOAD`
instructions. No VM opcode is added. Yielding arms use one lazy typed join slot:
only value-producing paths `STORE` to it and then jump forward to a shared `LOAD`.
Direct-return arms do not join. A final variant mismatch targets `MATCH_FAIL`, and
the existing verifier proves the join slot is initialized before `LOAD`.

Every executed instruction charges the existing Fuel. For example,
`let Option<i32> x = .some(42); return switch (x) { case .some(v): { v } case .none: { 0 } };`
costs 7 Fuel and fails at 6. A subject call is evaluated exactly once; its fixture
costs 9 Fuel. Switch expressions make no guest heap allocation and no performance
claim.

## Example and evidence

`examples/switch-expression.brc` returns 42. The `answer` function maps an Option
payload to a Result with a switch expression; `main` uses a second switch expression
to read that Result.

The [dated receipt](../evidence/m1-switch-expressions-windows-20261023.json)
records 41 native groups and 580 black-box CLI cases in each development and release
profile. This increment adds 70 CLI cases and leaves all 39 frozen inputs unchanged.
The prior propagation receipt remains historical at 37 native groups and 510 CLI
cases; the tagged receipt remains historical at 33 and 423. The successor
[i64 contract](m1-i64.md) records 49 native groups and 760 CLI cases in each
profile. Richer value-arm statements, remaining scalar types, arrays, structs, M2 and
later milestones, workers, the DLL ABI, Windows isolation, and performance remain
outside this slice.
