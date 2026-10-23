# M1 Switch-Expression Arm Statements

- Status: implemented and verified on Windows; 81 native groups and 1,969 CLI cases in each development and release profile
- Scope: structured statements and lexical loop transfers inside shallow switch-expression arms

This increment extends the [switch-expression contract](m1-switch-expressions.md)
without changing `brownie.m1-scalar/1`, `fn i32 main()`, or the `return_i32` field.
It adds no opcode, scalar type, wrapper family, heap allocation, or frame growth.

## Arm grammar and values

An arm may contain typed local declarations, assignments, standalone statement
blocks, `if`/`else if`/`else`, `while`, classic `for`, `return`, and lexical
`break`/`continue`. Statements use the ordinary statement grammar. In particular,
an `if` branch or standalone statement block is not a value-producing expression.

```text
case .some(value): {
    var i32 total = 0;
    for (var i32 i = 0; i < 7; i = i + 1) {
        if (i == 3) { continue; }
        total = total + value;
    }
    total
}
```

Every continuing path must reach one final expression without a semicolon. If a
statement prefix is terminal on every path, the arm closes immediately instead.
For example, `if (ready) { return 42; } value` is admitted; an if/else whose two
branches return needs no final value in that arm and rejects a following expression.
All loops are conservatively possibly zero-trip, even literal-true or omitted
conditions. A loop alone cannot discharge the arm's final-value obligation.
Flow analysis does not fold conditions to establish that a statement is terminal.

At least one arm must statically yield, and all yielding arms have the same exact
type. No bottom/never type is added. Terminal arms do not constrain the value type.
Existing contextual constructors, integer literal rules, and shallow i32/bool-only
wrapper payloads remain unchanged. A final value may have any existing scalar or
shallow-wrapper type; this adds no implicit conversion.

A leading `switch` at the arm's statement/value boundary is parsed as the final
switch expression, preserving the existing nested-expression form. To use a switch
statement before the final value, put that statement in a standalone `{ ... }`
block. A switch whose arms all return is still rejected in expression position;
the statement form inside a block can terminate the surrounding arm.

## Scope, transfers, and evaluation

The subject is evaluated once and mutable subjects remain snapshotted. Payloads
are immutable. Arm and nested-block declarations retain ordinary lexical scope:
they cannot escape, shadow an active binding, or become visible in a for post.
Assignments to outer `var` slots persist. Sibling scopes can reuse inactive names.

`return` exits the enclosing function. `break` and `continue` target the nearest
lexically enclosing loop, including a loop outside the switch expression. They
skip remaining operand/argument work, value stores, and the shared join load.
A classic-for continue executes its post once, while break skips that post. Local
loops inside an arm own their transfers instead of transferring to an outer loop.
Transfers outside any loop are syntax errors.

A while loop owns transfers in its condition as well as its body. A break from a
condition arm exits that while; a continue reevaluates its condition. The compiler
enters that loop before compiling the condition. Nested while conditions therefore
cannot accidentally transfer to an outer loop. Classic-for headers remain pure:
switch expressions, calls, and postfix `?` remain rejected in all three clauses.

Ordinary left-to-right and short-circuit evaluation still apply. Postfix `?` inside
a nested arm statement can return the enclosing Option/Result failure. Unselected
variants and branches execute no work; an infinite arm loop is bounded by Fuel.

## Depth, lowering, and verification

Expression and structural depth each remain capped at 32. A switch expression adds
one level for its subject and two for its arms in both inherited budgets. Ordinary
blocks, branches, loops, and statement-switch arms consume the existing structural
levels. Statements nested in a value arm retain its expression-depth base for
initializers, conditions, returns, and for clauses; they never reset that base to
zero. This bounds alternating statement/expression nesting as well as either
kind alone. Pure root-level nested switch expressions retain the 16/17 boundary.
Within a root arm, 30 nested statement blocks fit and 31 fail; a return expression
with 30 parentheses fits and 31 fails. The mixed switch/if fixture fits at 10 levels
and fails at 11. Other source, binding, instruction, register, loop, and frame caps
are unchanged.
Structural depth now includes surrounding statement scopes when entering a switch
expression. Previously admitted mixed forms that exceed this combined structural
budget can now fail with `compile_limit`; the numeric ceiling itself is unchanged.

The existing statement compiler emits control flow inside each arm. Only paths
that yield store into the lazy typed join slot and jump to its shared load.
Terminal paths never join. The unchanged IR verifier proves definite initialization
across branch joins and inductive loop backedges. Native tests also corrupt a
conditional arm's join store to prove that bypassing it cannot read a stale value.

Every executed instruction keeps its existing Fuel cost. No optimization or new
schedule is introduced. The conditional fixture with `if (false) { return 0; } v`
costs 9 Fuel on its selected some arm and fails at 8. The earlier simple value-arm
fixture still costs 7 and fails at 6.

## Evidence and limits

The [dated receipt](../evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each development and release
profile, including six new native groups and 71 new arm-statement cases. The former
`if-in-arm` rejection fixture is now an admitted case returning 0; its old receipt
remains historical. Both profiles used identical fixtures. All 81 frozen source
and verification inputs remained unchanged during documentation. The receipt
records compiler/artifact hashes and the example's result of 42. It uses Fairy C
`4ce12642`, language `fairyc-language/20`. M0 was not rerun because its 18 recorded
inputs and the retained compiler binary are unchanged. No performance measurement
was added.

Source commits are `ea2b915` (parser context) and `aa131b6` (arm statements).
`examples/switch-arm-statements.brc` returns 42. This is a scalar CLI increment,
not full-profile conformance. Arrays, structs, and borrows remain M2 work. Workers,
DLL embedding, Windows isolation, clean-machine packaging, and performance remain
unimplemented or unverified.
