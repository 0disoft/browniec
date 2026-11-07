# Private retained-value safe casts

The private retained-value source compiler now accepts explicit value-preserving
scalar widening through `as`. It reuses the public scalar compiler's existing
matrix and canonical WIDEN26 instruction, verifier, execution and price.

```c
module main;
fn i32 main() {
    let u8 byte = 42;
    let i64 wide = byte as i32 as i64;
    if (wide == 42) { return 42; }
    return 0;
}
```

## Source and type rules

Unary and postfix work finishes before a cast; casts finish before binary
operators. Chains associate left to right. An explicit cast clears the expected
type of its operand, matching the existing public scalar compiler: a destination
or parameter cannot silently change the source literal's scalar domain.

| Source | Admitted destinations |
| --- | --- |
| u8 | i32, i64, u32, usize |
| i32 | i64 |
| u32 | i64, usize |
| i64, usize, bool | none |

These are seven admitted pairs out of the six-by-six scalar matrix. Same-type,
narrowing, signedness-changing and bool conversions still reject. No implicit
conversion is introduced. Reachable operands must be real scalar values;
wrappers, Buffer, views and void CALL results reject before IR publication.
Every successful result keeps its exact scalar catalog node for subsequent
wrapper, argument, return, assignment and control-expression typing.

`value_source::converted` sits between the existing atom/unary/postfix parser and
binary expression parser. It uses `casts::follows`, `types::parse`, the existing
capture/read/drop helper and `ir::widen`. Cast chains add no recursive unary
frames. Nested tail if/switch recognition now includes a following `as` suffix.
An operand, CALL, projection or control arm and its cleanup execute once.

## Terminal operands

A fully terminal operand has already emitted its return, break, continue or
propagation cleanup. Every following target must still parse as scalar syntax,
but no scalar value is read or captured, no target node is interned and no WIDEN
or enclosing consumer is emitted. Since there is no continuing source value,
the ordinary scalar-pair matrix is not applied between bottom's suffixes.

The regression compares a terminal cast chain with its no-cast counterpart:
identical instruction bytes, register count and catalog count, with zero WIDEN26,
SCALAR_READ96 and SCALAR_VALUE97 instructions. Malformed and non-scalar target
syntax still rejects. This extends [terminal expressions](value-bottom.md), not
the remaining general unreachable-code grammar.

## Verification

`python tools/verify-value-safe-casts.py` selects 15 isolated native groups per
profile: five new cast groups and ten loop-header-owner, typed if/switch join,
terminal-control and unchanged admitted32/rejected33 depth regressions. The two
profiles run concurrently in disjoint locked mirrors using default native stacks
and no compiler/linker overrides.

The new groups cover all 36 scalar pairs, 47 successful execution fixtures,
21 further type rejections and eight malformed/non-scalar bottom targets. Every
admitted pair also executes, and both boundary values of each widening are
covered. Successful guests independently verify before VM execution. Cases
include wrapper/argument/return contexts, chains, projections, actual CALLs,
Option/Result propagation, once-only effects and temporary/view cleanup. The
header-owner fixture returns before its first rebind and after a real backedge,
restoring the `r[0] as i32` expression previously outside this private grammar.

Implementation `4b0601b` passed all 15 selected groups in each Windows native
profile. All 227 inputs match checkout and Git raw bytes; all 216 production
modules retain LF. The complete combined admitted32/rejected33 source fixture
is byte-identical to `fb58bfb` and ran in both profiles. See the
[focused evidence](../evidence/value-safe-casts-windows-20261107.json) and its
linked input manifest. These are fresh integrated results, not the independent
sidecar's earlier development-only run.

## Remaining work

Public source/CLI admission is unchanged. There are no new VM fields, opcodes or
existing price changes; Fuel remains default256/ceiling16000000. Fresh anonymous
loop-carried owners, other bottom contexts and unreachable diagnostics, general
references, methods/public AllocError and the wider runtime/host/platform/delivery
inventory remain open. This focused increment does not establish public CLI,
Linux/macOS, allocation-failure, process-isolation or full lifecycle evidence.
