# M1 Scalar Slice

- Status: experimental native compiler/verifier/VM and source CLI implemented
- Scope: first M1 increment, not full M1 or brownie.safe/0.3 conformance

The admitted source is `module main; fn i32 main() { return EXPR; }`.
EXPR supports decimal i32 literals, parentheses, unary minus, and left-associative
`+ - * / %` with conventional precedence. Whitespace and `//` comments are accepted.
The negative minimum literal is admitted directly; positive 2147483648 is rejected.
No variables, calls, branches, imports, other types, or host effects are admitted yet.

## Limits and representation

The compiler accepts at most 4096 UTF-8 source bytes, 1024 tokens, parser depth 32,
128 i32 registers, 128 constants, and 256 instructions. Fixed arrays bound compiler
and VM storage. These are temporary implementation ceilings, not performance results.

Private instructions are eight bytes: opcode, destination, operand A, operand B,
then four zero reserved bytes. Constants live in a separate bounded i64 array with
i32 range checks. Source offsets are a separate diagnostic map.
The independent verifier reconstructs initialized registers, validates operands,
constant ranges, reserved bytes, counts, and one final return. This is the entire
Flow obligation for a straight-line expression without variables or ownership.

The VM re-verifies before every run, reads the Program by shared borrow, and creates
fresh register state for each one-shot execution. Each instruction including return
costs one Fuel. Zero or exhausted Fuel returns an error. This subset has no loops;
future control-flow admission must retain metering on every executed path.

Arithmetic widens i32 operands to i64, checks the result, and returns guest errors
for overflow and division/remainder by zero. Evaluation executes left to right;
negative division truncates toward zero. No guest heap allocation or external effect
is needed. There is no public bytecode loader or runtime compiler subprocess.

## Validation

`build/toolchain/fairyc.exe test --native --capture-output --json` runs five native
groups covering arithmetic boundaries, precedence, source rejection, Fuel/reuse,
and corrupted private bytecode. The toolchain is the M0-recorded Fairy C build.
`tools/verify-m1.ps1` runs these groups in development and release, builds both
native binaries, and checks 81 black-box CLI cases per profile with a cleared
environment and tool-free runtime PATH. The corpus includes fixed arithmetic and
trap results, compile/depth/register/source ceilings, malformed UTF-8, independent
seeded arithmetic vectors, option rejection, and stream separation.
Receipts are in `build/m1/receipt.json` and per-profile `cli-receipt.json` files.

## Run the implemented subset

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe check examples/answer.brc --json
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
