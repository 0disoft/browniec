# M1 Scalar Slice

- Status: experimental compiler/verifier/VM and source CLI implemented; bool/branch and loop slices verified
- Scope: M1 expressions, i32/bool locals and functions, structured branches, and bounded loops; not full M1 or profile conformance

The admitted source is `module main;` followed by one or more
`fn (i32|bool) NAME((i32|bool) PARAM, ...) { BODY }` declarations, including
exactly one `fn i32 main()` with no parameters. See [direct functions](m1-functions.md)
for calls, parameter rules, private metadata, and VM frame behavior, and
[bool and branches](m1-branches.md) for the current control-flow contract.
See [loops](m1-loops.md) for `while`, classic `for`, `break`/`continue`, and backedge
rules.
EXPR supports decimal i32 literals, `true` and `false`, parentheses, unary minus,
`!`, arithmetic, ordering, equality, short-circuit `&&` and `||`, previously visible
local names, and direct function calls.
Whitespace and `//` comments are accepted.
The negative minimum literal is admitted directly; positive 2147483648 is rejected.
STMT includes typed `let` and `var` declarations, `NAME = EXPR;`, `return EXPR;`,
`if`/`else if`/`else`, standalone `{ ... }` blocks, `while (COND) { ... }`, classic
`for (INIT; COND; POST) { ... }`, `break;`, and `continue;`. Every local requires an
initializer. Only var may be reassigned. Names are ASCII identifiers and case
sensitive. A declaration is not visible within its own initializer. Declaring a
name already visible as a local or parameter is rejected; sibling blocks may reuse a
name after the earlier block ends. Compound assignment, assignment expressions,
imports, other types, and host effects are not admitted yet. [locals.fy](../../src/locals.fy)
owns the bounded active-name table and reserved-name list for this subset.

## Limits and representation

The compiler accepts at most 4096 UTF-8 source bytes, 1024 tokens, structural parser
depth 32 (nested blocks and control constructs, including else-if chains),
expression depth 32, loop depth 32, 64 simultaneously visible bindings per function including
parameters, 128 global i32/bool register cells, 128 constants, and 256 instructions.
The function, call-site, arity, and VM-frame limits remain 16, 32, 8, and 32.
Structural parser depth and expression depth are separate counters. `var` slots and
short-circuit bool result slots use the same 128-cell register file as value
registers. Fixed arrays bound compiler and VM storage. These are temporary
implementation ceilings, not performance results.

Private instructions are eight bytes: opcode, destination, operand A, operand B,
then four zero reserved bytes. Constants live in a separate bounded i64 array with
i32 range checks. Source offsets are a separate diagnostic map. Opcodes 17 through
21 are `LOAD`, `STORE`, `JUMP`, `JFALSE`, and `JTRUE`. Opcode 22 is a strictly backward
backedge within one function. Opcodes 19 through 21 remain forward jumps.
The independent verifier processes instructions in forward order and reconstructs
definite initialization at every forward join by intersecting incoming paths. For
each backedge, the incoming state must contain the target's first-entry invariant;
this is a conservative inductive check, not a cyclic worklist or fixed-point
solver. It validates operands, scalar types, forward and backward target bounds,
constant ranges, reserved bytes, counts, function/call metadata, and return
completeness. All functions are verified before execution. Source checking also
proves lexical visibility, required initialization, and let immutability.

Parameters are initialized at call entry and `let` names bind to single-definition
value registers. Each non-parameter value register has one static defining
instruction. A `var` has a stable typed storage slot and may have multiple `STORE`
sites. Reading it emits `LOAD` into a fresh value register; assignment emits `STORE`
to the slot. A previous copy therefore keeps its value after assignment, and joins
share the slot rather than a mutable value register. Slots consume the same 128-cell
global budget as value registers. Arithmetic initializers and assignment RHS
instructions are retained even if their final value is unused, so traps and
left-to-right execution are preserved.

The VM re-verifies before every run, reads the Program by shared borrow, and creates
fresh frame state for each one-shot execution. Every executed instruction, including
`LOAD`, `STORE`, `JUMP`, `JFALSE`, `JTRUE`, opcode 22, and return, costs one Fuel;
CALL costs one plus its argument count. Unevaluated short-circuit operands and
unselected branches do not execute. Loops reuse their bounded frame and register
cells without per-iteration VM allocation or native recursion. Insufficient Fuel
returns an error.

Arithmetic widens i32 operands to i64, checks the result, and returns guest errors
for overflow and division/remainder by zero. Evaluation executes left to right;
negative division truncates toward zero. Bool is canonical 0/1 with no conversion
to or from i32. `!`, `&&`, and `||` accept bool; ordering accepts i32; equality
requires two i32 values or two bool values. `&&` and `||` short-circuit. No guest
heap allocation or external effect is needed. There is no public bytecode loader or
runtime compiler subprocess.

## Validation

`build/toolchain/fairyc.exe test --native --capture-output --json` and
`tools/verify-m1.ps1` run the native and black-box profile checks. The
[loop receipt](../evidence/m1-loops-windows-20261023.json) records 26 native groups
and 332 CLI cases in each of development and release.

The loop corpus verifies both loop forms, optional clauses, `for` header purity,
nearest-loop transfer ownership, `continue` post behavior, break/return post
skipping, conservative return completeness, lexical reinitialization, loop depth,
opcode 22 bounds and backedge initialization, dead-post handling, loop Fuel, and
prior scalar/branch regressions. The [branch receipt](../evidence/m1-branches-windows-20261023.json)
remains historical for its 20-group/248-case slice. Receipts are also retained in
`build/m1/receipt.json` and per-profile `cli-receipt.json` files. The original
expression-only, [locals](../evidence/m1-locals-windows-20261023.json), and
[function](../evidence/m1-functions-windows-20261023.json) receipts are likewise
historical for narrower slices.

## Run the implemented subset

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe check examples/answer.brc --json
./build/browniec.exe run examples/locals.brc --json
./build/browniec.exe run examples/functions.brc --json
./build/browniec.exe run examples/branches.brc --json
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
./build/browniec.exe run examples/answer.brc --fuel 4 --json
pwsh -NoProfile -File tools/verify-m1.ps1
```

A guest return of 42 is JSON result data and the process exits 0. Text mode leaves
stdout empty and writes `return_i32=42` to stderr. `check` verifies without executing;
for example `1/0` passes check and traps on run. Fuel defaults to 256 and accepts
0..1000000. `--fuel` is run-only. Duplicate/unknown options fail. `--isolated` is
unavailable and never falls back to an unrestricted worker.

Only explicitly selected local disk files are supported, with a 4096-byte source
snapshot limit and a 4096-byte UTF-8 argument buffer. This is a trusted-local-source
engineering CLI. There is no project/config loader, guest I/O, worker, DLL, or sandbox.
The native executable has no compiler/interpreter subprocess execution path.
Builds use the M0 compiler artifact without modifying the separate Fairy checkout.
The loop receipt does not establish full M1, clean-machine, OS isolation, DLL ABI,
or performance results.
