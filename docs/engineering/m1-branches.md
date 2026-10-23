# M1 Bool and Branch Slice

- Status: implemented and verified for the branch slice; historical after the loop and tagged increments
- Scope: bool scalars, lexical blocks, structured branches, early returns, and CFG checks in `brownie.m1-scalar/1`

This increment keeps the experimental `brownie.m1-scalar/1` profile bounded. It
extends the existing i32 expression, local, and direct-call pipeline with bool
values and branch control flow. The separate [loop increment](m1-loops.md) extends
the same grammar with `while`, classic `for`, `break`, `continue`, and backedges.
Neither document defines the full `brownie.safe/0.3` profile, aggregates, host
calls, Windows isolation, or the embed ABI.

## Source surface

Functions may return i32 or bool and may take i32 or bool parameters. The entry
point remains exactly `fn i32 main()` with no parameters. `i32` and `bool` are the
only scalar types in this increment.

```text
fn i32 classify(i32 value) {
    if (value < 0) {
        return -1;
    } else if (value == 0) {
        return 0;
    } else {
        return 1;
    }
}

fn i32 main() {
    return classify(7);
}
```

A statement may be a typed `let` or `var` declaration, an assignment, an
`if`/`else if`/`else` statement, a standalone `{ ... }` block, or a `return`.
Every local declaration has an initializer. Declarations, assignments, and return
statements end with a semicolon; blocks and if/else statements do not. Braces
delimit control-flow bodies.

Conditions must have type bool. The syntax is `if (CONDITION) { ... }`, optionally
followed by `else if (CONDITION) { ... }` and one final `else { ... }`. A
standalone block creates a lexical scope. Structural parser depth is limited to 32
for nested blocks and control constructs, including else-if chains. Expression
depth has a separate 32-level limit. Branch admission does not include loops; loop
syntax and limits are owned by the [loop contract](m1-loops.md).

Every reachable path through every function must end in a return whose value has
the declared result type. Early returns are allowed. A statement after a point
where all paths have already returned is unreachable and is rejected, including
statements after an exhaustive if/else chain. A branch-only path cannot fall off the
end of a function; loop exits retain the compiler's conservative zero-trip return
requirement.

## Bool and operators

Boolean literals are `true` and `false`. The runtime representation is canonical
0 or 1. There are no implicit conversions between bool and i32: integer literals,
arithmetic results, and parameters do not become bool conditions, and bool values
cannot be assigned to i32 storage or passed to i32 parameters.

The admitted operators are:

| Operators | Operands | Result |
| --- | --- | --- |
| `!` | bool | bool |
| unary `-`, `*`, `/`, `%`, `+`, `-` | i32 | i32 |
| `<`, `<=`, `>`, `>=` | i32 | bool |
| `==`, `!=` | i32 with i32, or bool with bool | bool |
| `&&`, `||` | bool with bool | bool |

Precedence, from tightest to loosest, is `!` and unary `-`, then `* / %`, then
`+ -`, then `< <= > >=`, then `== !=`, then `&&`, then `||`. Binary operators are
left-associative. A comparison chain that would require comparing a bool with an
i32 is rejected.

`&&` and `||` evaluate their left operand once and short-circuit: a false left
operand skips the right operand of `&&`, and a true left operand skips the right
operand of `||`. The skipped expression performs no call, trap, or other work. The
result is a canonical bool value held in a bool slot. The slot consumes one of the
same 128 global register cells as value registers and `var` slots. The compiler
implements the skip with a forward conditional jump and a join.

## Names, scopes, and storage

Parameters and `let` names are immutable single-definition registers. A parameter
may be copied into a `var` when mutation is needed. A name is not visible in its
own initializer, and declaration-before-use remains required within a scope.

A `var` has one stable storage slot of its declared type. Slots share the same
bounded 128-cell global register file as value registers; they are not a second
allocation space. Reading a `var` emits `LOAD` into a fresh value register.
Assignment evaluates its right side and then emits `STORE` to the stable slot.
This preserves snapshots: a value copied before an assignment keeps the old value,
and both sides of a join can read the same typed slot.

Block-local names cannot escape their block. Declaring any name already visible as
a local or parameter is rejected. Sibling blocks may reuse a name after the first
block has ended. At most 64 bindings may be simultaneously visible in a function,
including parameters.

## Private IR and CFG verification

Instructions retain the private eight-byte `op,dst,a,b,0,0,0,0` layout. Existing
opcodes keep their meanings. This increment adds:

| Opcode | Name | Role |
| --- | --- | --- |
| 17 | `LOAD` | Read a typed storage slot into a fresh value register |
| 18 | `STORE` | Write a value to a typed storage slot |
| 19 | `JUMP` | Continue at a later instruction |
| 20 | `JFALSE` | Continue at a later instruction when a bool condition is false |
| 21 | `JTRUE` | Continue at a later instruction when a bool condition is true |

Every branch jump is strictly forward and stays inside its function. The branch-only
CFG is acyclic; the loop increment adds opcode 22 backedges under a separate
contract.

The independent verifier processes each function in forward instruction order. It
keeps unique value definitions separate from slot stores, validates scalar types,
and rejects a read unless the value is initialized on every incoming path. At a
join it intersects definite initialization from predecessor paths; initialization
performed on only one branch is therefore unavailable afterward. It also checks
instruction targets, forward-jump bounds, function-local register ranges, return
types, and termination. All functions are verified before guest execution.

The compiler and verifier must keep the distinction between allocation of a slot
and definition of a value. Compiler metadata does not override the verifier's
recomputed initialization and control-flow facts.

## Limits and Fuel

The branch increment uses the existing bounded program and frame resources:

| Resource | Limit |
| --- | --- |
| UTF-8 source | 4096 bytes |
| Tokens | 1024 |
| Instructions | 256 |
| Constants | 128 |
| Functions | 16 |
| Arguments per function or call | 8 |
| Static call sites | 32 |
| VM frames | 32 |
| Global register cells, including `var` and short-circuit slots | 128 |
| Simultaneously visible bindings per function | 64 |
| Expression depth | 32 |
| Structural parser depth, including else-if chains | 32 |

Structural parser depth and expression depth are separate counters. Nested blocks
and control constructs, including each else-if level, consume structural parser
depth; expression nesting consumes its own 32-level budget. The loop increment owns
the separate loop-depth limit.

Every executed instruction, including `LOAD`, `STORE`, `JUMP`, `JFALSE`, `JTRUE`,
and return, costs one Fuel. A taken or untaken branch instruction has the same
cost. `CALL` remains one Fuel plus its argument count. Work in an unevaluated
short-circuit operand or an unselected branch is not executed and costs no Fuel.

## CLI behavior and evidence

`check` compiles, type checks, and verifies the program without executing it.
`run` uses the same validation before execution. Both keep the existing command
surface and result framing. Since `main` still returns i32, the `return_i32` result
field describes successful completion; bool results appear only inside the guest
program and cannot be used as a CLI process exit code.

```powershell
./build/browniec.exe run examples/branches.brc --json
```

The historical [dated branch receipt](../evidence/m1-branches-windows-20261023.json) records
20 native groups and 248 black-box CLI cases for each development and release
profile, along with the Windows compiler and artifact identities, source and harness
digests, executed and skipped checks, and remaining limitations.

The expression, locals, and direct-function receipts remain historical evidence for
their narrower slices; none of them is evidence for branches or LOAD/STORE/CFG
behavior. Postfix `?` is owned by the later
[propagation contract](m1-propagation.md). Full M1, broader switch expressions,
other scalar types, Windows isolation, and performance remain unverified. No OS
sandbox, performance target, clean-machine package, or DLL ABI claim follows from
this increment.
