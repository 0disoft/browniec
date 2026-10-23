# M1 Scalar Slice

- Status: native compiler/verifier/VM modules implemented; CLI integration pending
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
The public CLI entry remains a placeholder until the next integration commit.
