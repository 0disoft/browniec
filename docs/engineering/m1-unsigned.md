# M1 Unsigned Scalars

- Status: implemented and verified on Windows; historical after explicit widening; 59 native groups and 1,159 CLI cases in each development and release profile
- Scope: `u8`, `u32`, and 64-bit guest `usize` scalars in `brownie.m1-scalar/1`

This increment adds unsigned scalars to the existing i32, bool, i64, branch,
loop, tagged, propagation, and switch-expression slices. The entry point remains
exactly `fn i32 main()` with no parameters.

## Source contract

`u8`, `u32`, and `usize` are distinct scalar types. They are admitted in typed
locals, function parameters and results, call arguments and returns, assignments,
copies, recursion, loop initialization and post steps, and switch-expression
result joins. `u32` and `usize` remain different types when the same value fits
both. Bool remains separate and has no implicit integer conversion.

Integer operators require two operands of the same type. Unary `-` is forbidden
for every unsigned type, including `-0`. Arithmetic and equality do not convert
between signed and unsigned types. Explicit widening is limited to the separate
[widening contract](m1-widening.md). Wrappers remain limited to i32/bool payloads:
`Option<u8>`, `Option<u32>`, `Option<usize>`, `Option<i64>`, and every `Result`
containing one of those types are rejected. Functions returning an unsigned scalar
reject postfix `?`.

Classic `for` headers remain pure scalar. Initialization accepts a declaration or
assignment, the post clause accepts an assignment only, and the condition is bool.
Direct calls, postfix `?`, and switch expressions remain forbidden in every header
clause.

## Literals and context

An unsuffixed decimal literal defaults to i32. Unsigned context comes only from a
typed initializer, assignment target, function argument, function return, or the
already typed left operand of a binary expression. Typing is left to right with no
lookahead inference for uncast literals. There are no implicit conversions or
suffixes. An explicit widening cast does not supply a type to its source literal:
use a typed unsigned local as the source.

The ranges are:

| Type | Tag | Range |
| --- | --- | --- |
| `u8` | 10 | 0 .. 255 |
| `u32` | 11 | 0 .. 4294967295 |
| `usize` | 12 | 0 .. 18446744073709551615 |

The lexer accumulates the complete unsigned magnitude with prechecked multiply
and add, then stores the encoded i64 cell. Signed contexts reject a positive value
above their signed maximum. The direct unary-minus special for i64 MIN remains for
`-9223372036854775808`; it does not admit unsigned negation.

## Arithmetic

Same-type `+`, `-`, `*`, `/`, and `%` are checked against the operand type's own
range. Unsigned underflow and overflow produce the guest `overflow` error. A zero
divisor produces the guest `zero_divisor` error. Ordering decodes the stored cell
as unsigned. Equality and inequality require the same type and compare the stored
bit pattern.

`src/arithmetic.fy` adapts the checked unsigned guards from M0. The unsigned
increment added no opcode or guest heap allocation and kept existing Fuel costs. A simple program that
binds `6 * 7` to an unsigned value and returns i32 42 costs 5 Fuel.

## Representation and limits

The existing scalar tags remain unchanged: i32 is 1, bool is 2, wrappers are 3
through 8, and i64 is 9. Unsigned types use tags 10 through 12. The existing
`i64[128]` constant array and `i64[4096]` VM register array are retained, as are the
current instruction, frame, cap, and Fuel limits.

`src/cells.fy` provides reversible `pack` and `unpack` conversions. Values below
2^63 keep their existing cell representation. Values at or above it are stored as
negative bit patterns. Both halves use checked conversions after splitting at
2^63, so no out-of-range cast depends on host behavior.

## Example and evidence

`examples/unsigned.brc` uses an unsigned local and returns guest i32 42 from
`main`.

```powershell
./build/browniec.exe run examples/unsigned.brc --json
```

The CLI profile remains `brownie.m1-scalar/1`, and JSON output still reports
`return_i32`; unsigned values remain internal to the guest program.

The [dated receipt](../evidence/m1-unsigned-windows-20261023.json) remains
historical and records 59
native groups and 1,159 CLI cases in both development and release: 760 prior cases
plus 399 unsigned cases. The native total includes two codec groups and eight
unsigned scalar groups. Both profiles used identical fixtures, and all frozen
verification inputs remained unchanged during documentation. Source commits are
`818111a` (cell codec) and `733b403` (unsigned source/VM support). M0's 18 recorded
inputs and the Fairy C `4ce12642` compiler identity remain unchanged.

Explicit widening is implemented and verified separately. Its
[receipt](../evidence/m1-widening-windows-20261023.json) records 67 native groups
and 1,272 CLI cases in each profile, including 113 widening cases.

This slice does not complete M1. Shifts, bitwise operations, fallible narrowing, arrays and
structs, richer value-arm statements, workers, DLL embedding, Windows isolation,
and performance results remain outside it.
