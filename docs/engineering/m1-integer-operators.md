# M1 Integer Bitwise Operators and Checked Shifts

- Status: implemented and verified on Windows; 75 native groups and 1,898 CLI cases in each development and release profile
- Scope: `~`, `&`, `^`, `|`, `<<`, and `>>` in `brownie.m1-scalar/1`

These operators preserve the exact `i32`, `i64`, `u8`, `u32`, or 64-bit guest
`usize` type. Both binary operands must have the same integer type, including the
shift amount. Uncast literals use the existing contextual typing rules. There is
no implicit promotion. Bool and wrappers are rejected as operands; operations on
an extracted i32 payload remain supported. Compound assignments remain unavailable.

## Source behavior

`~`, `&`, `^`, and `|` operate on the type's fixed-width two's-complement bit
pattern, including signed values. Complement is limited to the exact 8-, 32-, or
64-bit width. Bitwise operations themselves cannot overflow.

Both shifts require `0 <= amount < width`. An invalid amount produces the guest
`overflow` outcome, even for zero shifted by the width or a larger amount. The
amount is checked before any native shift or left-shift range check. This profile
deliberately keeps its existing error categories; it adds no invalid-shift JSON
kind. A valid left shift computes the mathematical value times `2^amount` and
fails with `overflow` if that value does not fit the operand type. Thus i32
`-1 << 31` succeeds with MIN, while `1 << 31` and `-2 << 31` fail.

Signed right shift is arithmetic, rounding toward negative infinity: `-7 >> 1`
is `-4`. Unsigned right shift fills with zero. A zero count preserves the operand,
including signed MIN. Counts are not masked or reduced modulo the width.

Precedence is listed from tightest to loosest:

| Operators | Association |
| --- | --- |
| Postfix `?` | Left |
| Unary `-`, `!`, `~` | Right |
| `as` | Left |
| `*`, `/`, `%` | Left |
| `+`, `-` | Left |
| `<<`, `>>` | Left |
| `<`, `<=`, `>`, `>=` | Left |
| `==`, `!=` | Left |
| `&` | Left |
| `^` | Left |
| `\|` | Left |
| `&&` | Left |
| `\|\|` | Left |

For example `1 << 2 + 1` is 8, and `16 >> 1 >> 1` is 4. Use `(flags & mask) == 0`
for a bit test: equality binds before bitwise AND. `~x as i64` complements the
source type before widening; `~(x as i64)` complements the widened type.
The cast lookahead recognizes all new binary operators as operand boundaries.

Operands execute once, left to right. Bitwise operations are eager; `0 & (1/0)`
still fails. An operand error precedes any shift check. Existing `&&`, `||`,
branches, and propagation can skip a complete operation. All existing scalar
expression positions admit these operators, including pure classic-for headers.

## Private IR and native execution

Opcodes 27 through 32 are `BNOT`, `BAND`, `BXOR`, `BOR`, `SHL`, and `SHR`.
Each names a fresh destination value register with the operand's exact integer
type. Operand A names its source register; binary instructions name their second
source in operand B. `BNOT` has B zero. Reserved bytes are zero.

The verifier checks exact integer types, initialized non-slot readable sources in
the same function, unique destinations, and existing CFG and reserved-byte rules.
The VM verifies the full program before execution. `src/bits.fy` masks unsigned
bit patterns and sign-extends i32 results before cell encoding. `src/shifts.fy`
validates the count and left-shift range, then uses only unsigned native shifts.
Signed right shifts use explicit sign fill. No native signed shift or out-of-range
cast determines the guest result. Negative left-shift inputs discard only their
sign-extension bits before the checked unsigned host shift.

Each executed operation costs one Fuel and consumes one instruction and one value
register. There is no constant folding or elision. `return 21 << 1;` costs 4 Fuel,
and `return ~0;` costs 3. These operators add no guest heap or frame growth and keep
all existing caps. The entry point, CLI profile, and `return_i32` field are unchanged.

## Evidence and limits

The [dated receipt](../evidence/m1-integer-operators-windows-20261023.json) records
75 native groups and 1,898 CLI cases in each development and release profile:
eight new native groups and the 1,272-case previous corpus plus 292 bitwise and
334 shift cases. The former bool `&` and `|` rejection cases now report `type`
instead of `lexical`; bool remains unsupported for both.

Both profiles used identical fixtures. All 78 frozen verification inputs remained
unchanged during documentation. The receipt records toolchain and native artifact
hashes and the example's result of 42. The retained compiler is Fairy C `4ce12642`,
language `fairyc-language/20`. M0 was not rerun because all 18 recorded inputs and
the compiler binary are unchanged. No performance measurement was added.

`examples/bitwise.brc` returns 42. Source commits are `dcb6de2` (bitwise)
and `80c7e18` (shifts). This increment does not complete M1 or add compound
assignments, richer switch-expression arm statements, arrays, workers, or DLLs.
Windows isolation, clean-machine packaging, and performance remain unverified.
