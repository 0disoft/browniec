# M1 Scalar Slice

- Status: experimental native compiler/verifier/VM and source CLI implemented
- Scope: M1 expressions, initialized i32 locals, and direct functions; not full M1 or profile conformance

The admitted source is `module main;` followed by one or more
`fn i32 NAME(i32 PARAM, ...) { STMT* return EXPR; }` declarations, including
exactly one zero-argument main. See [direct functions](m1-functions.md) for calls,
parameter rules, private metadata, and VM frame behavior.
EXPR supports decimal i32 literals, parentheses, unary minus, and left-associative
`+ - * / %` with conventional precedence, previously declared local names, and
direct function calls.
Whitespace and `//` comments are accepted.
The negative minimum literal is admitted directly; positive 2147483648 is rejected.
STMT is `let i32 NAME = EXPR;`, `var i32 NAME = EXPR;`, or `NAME = EXPR;`.
Every local requires an initializer. Only var may be reassigned. Names are ASCII
identifiers, case sensitive, in one function-body scope. Duplicate declarations,
reserved names, and declaration-before-use violations are rejected. A declaration
is not visible within its own initializer. Nested blocks and block-local shadowing, compound
assignment, assignment expressions, branches, imports, other types, and host
effects are not admitted yet. [locals.fy](../../src/locals.fy) owns the bounded name table
and reserved-name list for this subset.

## Limits and representation

The compiler accepts at most 4096 UTF-8 source bytes, 1024 tokens, parser depth 32,
64 bindings per function including parameters, 128 global i32 registers, 128 constants,
and 256 instructions, plus the bounded function/call/frame limits. Fixed arrays bound compiler
and VM storage. These are temporary implementation ceilings, not performance results.

Private instructions are eight bytes: opcode, destination, operand A, operand B,
then four zero reserved bytes. Constants live in a separate bounded i64 array with
i32 range checks. Source offsets are a separate diagnostic map.
The independent verifier reconstructs initialized registers, validates operands,
constant ranges, reserved bytes, counts, function/call metadata, and one final return
per function. This is the runtime Flow obligation for the current straight-line scalar code. Source checking
also proves declaration order, required initialization, and let immutability.

Local declarations bind names to single-definition value registers. A var assignment
rebinds the name after its RHS is checked; it never overwrites an old value register.
Consequently a previous copy keeps its value after assignment. No new mutable-register
opcode or guest heap storage is needed for locals. Direct calls separately add
CALL and the private function directory. Pure name copies/rebindings need no extra
instruction or Fuel; their
compiler work is bounded by local/token/source limits. Arithmetic initializers and
assignment RHS instructions are retained even if their final value is unused, so
traps and left-to-right execution are preserved.

The VM re-verifies before every run, reads the Program by shared borrow, and creates
fresh frame state for each one-shot execution. Each ordinary instruction including
return costs one Fuel; CALL costs one plus its argument count. Insufficient Fuel
returns an error. This subset has no loops;
future control-flow admission must retain metering on every executed path.

Arithmetic widens i32 operands to i64, checks the result, and returns guest errors
for overflow and division/remainder by zero. Evaluation executes left to right;
negative division truncates toward zero. No guest heap allocation or external effect
is needed. There is no public bytecode loader or runtime compiler subprocess.

## Validation

`build/toolchain/fairyc.exe test --native --capture-output --json` runs twelve native
groups covering arithmetic boundaries, precedence, source rejection, Fuel/reuse,
corrupted private bytecode, local snapshots/rejections, and direct-call/frame behavior. The toolchain is the M0-recorded Fairy C build.
`tools/verify-m1.ps1` runs these groups in development and release, builds both
native binaries, and checks 143 black-box CLI cases per profile with a cleared
environment and tool-free runtime PATH. The corpus includes fixed arithmetic and
trap results, compile/depth/register/source ceilings, malformed UTF-8, independent
seeded arithmetic vectors, local binding/assignment and token/local limits, option
rejection, and stream separation.
Receipts are in `build/m1/receipt.json` and per-profile `cli-receipt.json` files.
The original expression-only receipt is retained as historical evidence; the
[locals receipt](../evidence/m1-locals-windows-20261023.json) records that increment;
the [function receipt](../evidence/m1-functions-windows-20261023.json) records current direct calls.

## Run the implemented subset

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe check examples/answer.brc --json
./build/browniec.exe run examples/locals.brc --json
./build/browniec.exe run examples/functions.brc --json
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
This receipt does not establish clean-machine distribution or a performance budget.
