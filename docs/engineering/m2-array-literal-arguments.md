# M2 Repeated Array Literals as Arguments

- Status: implemented at `ea6854f1e97cb6c2c6f85cdeee44d1800e078497`; verified in
  development and release.
- Scope: `[EXPR; N]` in an exact-shape immutable scalar-array formal position.
- Implementation: [`compiler::array_argument`](../../src/compiler.fy).
- Fixture: [array literal arguments](../../tests/m2/array_literal_arguments.fy).
- Harness: [focused native and CLI checks](../../tools/verify-m2-array-literal-arguments.py).
- Evidence: [Windows receipt](../evidence/m2-array-literal-arguments-windows-20261028.json).

```brownie
module main;
fn i32 take(i32[2] a) { return a[0] + a[1]; }
fn i32 main() { return take([21; 2]); }
```

The formal supplies the exact element type. The filler runs once, before any
payload allocation, and its value is repeated `N` times. `N` must be an integer
literal in 1..4096 and equal the formal's length. There is no implicit element
conversion. All six existing scalar element types are supported.

Only after filler evaluation, length validation, closing bracket, and argument
delimiter validation does the compiler reserve an anonymous immutable array
site, emit `AINIT`, and publish its empty-span lexical capture. Earlier argument
captures remain visible to cleanup while the filler executes. Later argument
effects cannot change the completed array. A filler failure preserves any effects
already performed; it does not publish the pending array.

The existing CALL copies this captured array into the callee's immutable formal.
Shared reverse mixed array/record cleanup releases captures after CALL, on
`return`, on `?` failure, and on `break` or `continue` leaving their lexical scope.
An inner loop preserves captures belonging to its surrounding call expression.
Array, record, and shallow-wrapper consumers use their existing result paths.

No opcode, VM, Fuel price, profile, or version field changes. A literal capture
uses one static site, one owner and one extent; the formal needs its independent
copy. An `i32[1]` literal and formal require eight payload bytes together; seven
fails. An early return from the filler needs zero payload when no earlier array
is live. Named immutable temporaries produce the same instruction bytes and
site count as direct literals in the tested equivalent program.

Existing bounds remain: sixteen static array sites and sixteen shared owners,
eight arguments, thirty-two frames, 128 registers, 256 instructions, thirty-two
call sites and a 65,536-byte payload arena. The static-site fixture uses one
formal and fifteen literal sites successfully; a sixteenth literal exceeds the
site limit. One `i64[4096]` literal plus its formal fills the payload arena;
two such literal arguments exhaust it when CALL attempts formal copies.

Parenthesized or indexed literals, nested arrays, and element-list literals
remain unsupported. A scalar formal does not accept an array expression. Wrong
lengths, wrong filler types and mutation of the formal fail compilation. This
extends [array parameters](m2-array-parameters.md) and composes with
[array call-result arguments](m2-array-result-arguments.md).

## Verification

Development and release each passed twenty native groups:
six new literal-argument, eight array-parameter and six array-result-argument
groups. Each profile passed 344 CLI cases: 110 new, 80 array-parameter and 154
array-result-argument cases, executed with a tool-free runtime environment.

Two combined profile invocations rechecked 226 identical inputs and matching
compiler/SDK identities. Development ran from `1eaf201` with implementation files
uncommitted; release ran after `ea6854f`. Both retained executable hashes
were confirmed against their CLI receipts before archival.

The new fixture has fifteen successful programs, ten type rejections and two
syntax rejections. The 110 new CLI cases cover those 27 programs through both
`check` and `run` (54), all six scalar tags at both extrema and lengths 1/2
(48), payload-arena boundaries (4), and static-site boundaries (4). Native checks
also verify equivalent IR bytes, missing-`ADROP` rejection, and the eight/seven
and zero-payload paths.

The preceding array-result fixture replaces its formerly rejected literal
argument with a still-rejected parenthesized literal; its case counts remain
unchanged. Earlier receipts remain historical for their original inputs.

Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.
