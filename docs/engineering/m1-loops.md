# M1 while and Classic for Loops

- Status: implemented and verified for the loop slice; historical after the tagged, propagation, and switch-expression increments
- Scope: bounded `while` and classic `for`, `break`/`continue`, and metered backedges in `brownie.m1-scalar/1`

This increment extends the M1 scalar slice with lexical loops. It keeps the
existing i32/bool values, functions, locals, branches, and direct-call rules. The
separate [tagged increment](m1-tagged.md) adds shallow Option/Result and switch. This
document does not define the full `brownie.safe/0.3` profile, Windows isolation, or
the embed ABI.

## Source surface

The admitted loop forms are:

```text
while (CONDITION) { BODY }

for (INIT; CONDITION; POST) { BODY }
```

The `while` condition must have type bool. The `for` header may omit its init,
condition, or post clause. An omitted condition behaves as `true`; an omitted init
and post perform no work. Loop bodies follow the existing statement and lexical-block
rules. Bodies have their own lexical scope and declarations are reinitialized on
each iteration.

A `for` init is either one initialized `let`/`var` declaration or one plain
assignment. A `for` post is a plain assignment only. `for` init, condition, and post
must be pure scalar code: all direct function calls are forbidden in those three
clauses, including a call in an expression that would be skipped. A `while`
condition and loop body may contain direct calls under the normal function rules.
The later [propagation contract](m1-propagation.md) also rejects `?` in all three
`for` header clauses while admitting it in while conditions and loop bodies.
Switch expressions are likewise rejected in all three `for` header clauses.

Header locals are visible in the condition, body, and post, and are removed after
the loop. Body locals are not visible in the `for` post. The nearest lexical loop
owns a `break` or `continue`; there are no labels or labeled transfers.

`break` exits the nearest loop. `continue` starts the next iteration: a `while`
continue goes back to its condition, while a `for` continue runs the post and then
the condition. `break` and `return` skip the `for` post. A `break` or `continue` outside a loop,
or a statement after an unconditional transfer in the same lexical block, is
rejected.

For return-completeness checking, the compiler conservatively treats every loop as
possibly zero-trip, including a literal `true` or omitted condition. A function
therefore still needs a following return after a loop. This admission does not
prove loop termination; an infinite loop is bounded by Fuel rather than by a static
termination proof.

## Compiler and private IR

The existing eight-byte instruction envelope is unchanged. Existing forward
branches keep their meanings. Opcode 22 is a backedge:

```text
22,dst=0,a=earlier-pc,b=0,0,0,0,0
```

The target must be a strictly earlier instruction in the same function. Opcodes 19,
20, and 21 remain forward jumps; opcode 22 is the only backward transfer. A
backedge is also an executed instruction and costs one Fuel.

For a `while`, the condition is emitted at the loop head, followed by a forward
exit branch, the body, and a normal-fallthrough backedge to the head. A `while`
`continue` emits its own backedge directly to the condition. If no normal or
continue path reaches the end of the body, no implicit fallthrough backedge is
emitted. For a `for`, the header condition is followed by a forward exit branch;
each normal iteration emits the body, then the post, then a backedge to the
condition. A `continue` in a `for` jumps forward to the post; a `break` jumps
forward to the loop exit.

The post is validated before the body so it cannot see body locals. Its temporary
instructions, registers, and constants are then discarded. It is re-emitted after
the body only when a normal or `continue` path can reach it. A post that is checked
but unreachable because the body always breaks or returns emits no runtime
instructions and consumes no Fuel.

## Verifier and initialization

The verifier retains a bounded forward-graph definite-initialization pass. Forward
joins intersect initialized cells. For each backward edge, the incoming initialized
state must contain every initialized cell required by the target's first-entry
invariant.

This is a conservative inductive invariant check, not a cyclic worklist or
fixed-point solver. Every instruction node must have forward reachability, and a
read cannot be justified only by initialization that happens in a later iteration.
The existing single static value-definition checks remain in force. Each
non-parameter value register has one static defining instruction; parameters are
initialized at call entry. Storage slots may have multiple `STORE` sites. Reexecution
reuses the same bounded cells; it does not create new value definitions.

The check therefore rejects a read that would be uninitialized on the first pass or
on any backedge, while still allowing a loop local to be reinitialized on each
iteration. A loop with no forward path from the function entry is rejected. The
compiler's separate zero-trip possibility for return completeness does not weaken
the backedge initialization check.

## Limits, Fuel, and runtime

The loop increment keeps the existing bounded resources and adds a separate loop
depth limit:

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
| Structural parser depth | 32 |
| Expression depth | 32 |
| Loop depth | 32 |

Every executed instruction costs one Fuel, including conditional branches,
forward jumps, and opcode 22 backedges. `CALL` remains one Fuel plus its argument
count. A loop does not allocate a VM frame or native call frame per iteration; it
reuses its bounded frame and register storage. Only executed instructions consume
Fuel.

## CLI behavior and evidence

`check` compiles, type checks, and verifies loops without executing them. `run`
uses the same validation before execution. The result framing is unchanged; `main`
remains a zero-argument i32 function and guest bools remain internal values.

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

The historical [loop receipt](../evidence/m1-loops-windows-20261023.json) records 26 native
groups and 332 black-box CLI cases for each development and release
profile. Its coverage includes both loop forms, omitted clauses, pure-header call
rejection, `break`/`continue` ownership and post behavior, zero-trip completeness,
reinitialization, forward-reachability and backedge initialization checks,
dead-post handling, loop depth and instruction budgets, opcode-22 corruption, Fuel,
and prior scalar/branch regressions. The earlier branch receipt remains historical
evidence for the branch slice.

The later [propagation contract](m1-propagation.md) owns postfix `?`, and the
[switch-expression contract](m1-switch-expressions.md) owns expression-position
exhaustive arms. Its current receipt records 41 native groups and 580 CLI cases per
profile. Full M1 still needs other scalar types and richer value-arm statements. Workers, the DLL ABI,
Windows isolation, clean-machine packaging, and performance targets remain
unverified. No OS sandbox or performance claim follows from loop support.
