# M1 Explicit Integer Widening

- Status: implemented and verified on Windows; 67 native groups and 1,272 CLI cases in each development and release profile
- Scope: `EXPR as TYPE` for seven domain-preserving integer pairs in `brownie.m1-scalar/1`
- Evidence: [Windows 2026-10-23 receipt](../evidence/m1-widening-windows-20261023.json)

This increment adds explicit integer widening without implicit conversion or
promotion. It preserves the existing `fn i32 main()` entry point and scalar CLI
profile.

## Source contract

The syntax is `EXPR as TYPE`. Postfix `?` binds first, then unary operators, then
`as`, then every binary operator. Casts associate left to right. Therefore
`-x as i64` widens the already negated `x`, while `-(x as i64)` widens before
negation. Chains such as `x as u32 as i64` are evaluated from left to right.

Exactly these pairs are admitted:

| Source | Target |
| --- | --- |
| `u8` | `i32` |
| `u8` | `i64` |
| `u8` | `u32` |
| `u8` | `usize` |
| `u32` | `i64` |
| `u32` | `usize` |
| `i32` | `i64` |

Every pair preserves the source domain in the target type. The rule is static;
a value that happens to fit a rejected pair does not make it valid. For example,
a `u32` zero cast to `i32` is rejected. Identity casts, narrowing, `i32`/`i64` to
unsigned, `usize` to `i64`, bool/integer casts, and wrapper or aggregate casts are
rejected.

No implicit integer conversion or promotion is added. Unsigned unary negation
remains forbidden. The source of a cast receives no expected type from its target
or surrounding context. Thus `1 as i64` defaults its source to i32 and succeeds,
while `1 as u8` is rejected; `2147483648 as i64` is rejected because its source
defaults to i32 outside a typed context. A typed `u32` local can instead widen to
`i64`. Existing contextual typing of uncast literals is unchanged.

A bounded lexer snapshot looks ahead for `as` as an operator on the current
unary/postfix operand. It ignores parentheses, calls, and switch-expression arms
when finding that boundary, so their context cannot type the source literal. This
adds no duplicate AST or parser state change.

Casts compose where the surrounding position accepts their target type: locals,
assignments, arguments, returns, expressions within branches and loops, switch
yields, and constructor payloads whose final payload is i32 or bool. `x? as i64`
in an admitted wrapper-returning function propagates the wrapper before widening
its i32 payload. Classic `for` headers may contain widening, but still reject
calls, `?`, and switch expressions.

Wrappers remain limited to i32/bool payloads. There is no automatic payload
mapping, so a wrapper containing u8, u32, usize, or i64 remains unsupported.

## Representation and verification

Opcode 26 is `WIDEN`. Its destination is a new value register whose type metadata
holds the target tag; operand A is the source register index, operand B is zero,
and all reserved bytes are zero. The compiler and the
independent verifier both enforce the seven-pair table. The verifier also requires
a readable initialized non-slot source in the same function, a unique destination,
and the existing CFG rules.

The VM copies the encoded i64 cell exactly. No arithmetic or range helper is needed
because every admitted source domain already fits the shared encoded cell. Each
executed cast costs one Fuel, including each step of a chain; casts are not elided.
A cast consumes one instruction and one new value register. Existing instruction,
register, frame, cap, and Fuel limits are unchanged. A cast creates no guest heap
allocation and does not grow a frame.

For example, `let u8 b = 42; return b as i32;` costs 3 Fuel and fails at 2.

## CLI boundary

The profile remains `brownie.m1-scalar/1`, the entry point remains `fn i32 main()`,
and JSON keeps `return_i32`. `examples/widening.brc` returns 42 through an explicit
widening step.

## Recorded evidence

The dated receipt records 67 native groups and 1,272 black-box CLI cases in each
development and release profile, including eight new native groups and 113 new
widening cases. The CLI expectations derive the permitted pairs independently
from the source and target domains. Coverage includes every pair's boundary values,
rejected conversions, literal context, precedence, chains, calls, loops, switch
joins, propagation, malformed IR, register/depth caps, and exact Fuel boundaries.
Both profiles used identical fixtures. All 54 frozen verification inputs remained
unchanged while documentation was finalized. Source commit: `8acc675`.

The receipt records the Fairy C `4ce12642` language `fairyc-language/20` compiler
identity and the native artifact hashes. M0 was not rerun: its 18 recorded inputs
and the compiler binary are unchanged.

This increment adds no shift, bitwise, fallible narrowing, or implicit conversion
operator. Full M1 remains partial. Arrays are M2 work; workers, DLL embedding, and
Windows isolation remain unimplemented or unverified. No performance claim is made.
M0 sources and the selected Fairy C `4ce12642` language `20` toolchain remain
unchanged.
