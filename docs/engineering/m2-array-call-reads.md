# M2 Direct Array Call-Result Reads

- Status: implemented at `b8220890cb2c7a7aed6579c35c572e69ee43cc2a`; verified in
  development and release.
- Scope: `make(...)[INDEX]` and `make(...).len` in scalar expressions.
- Implementation: [`compiler::array_call_read`](../../src/compiler.fy).
- Fixture: [native checks](../../tests/m2/array_call_reads.fy).
- Harness: [focused native/CLI verifier](../../tools/verify-m2-array-call-reads.py).
- Evidence: [Windows receipt](../evidence/m2-array-call-reads-windows-20261028.json).

```brownie
module main;
fn i32[1] make() { return [42; 1]; }
fn i32 main() { return make()[0]; }
```

The function catalog supplies the exact result shape. After ordinary callee
resolution and local-shadow checks, the compiler reserves an anonymous immutable
destination and executes the existing array CALL/ARET transfer. Pending call
destinations remain absent from names during argument evaluation. No payload
copy is added for the result transfer.

After CALL and its argument-capture cleanup, a local snapshot publishes the
returned owner as an empty-span capture. The index evaluates once, after the
call, with exact `usize` context. `AREAD` materializes the scalar before `ADROP`
releases the result. The scalar can then participate in operators, casts,
arguments, initializers and returns without retaining the owner. Nested reads
such as `make()[index()[0]]` keep the outer owner alive through the inner read.

For `.len`, CALL still executes and must succeed before the constant shape
length is materialized. The result is exact `usize`. Arguments, Fuel failures,
payload limits and other call effects are preserved; this is not a skipped call
or a pure type-level query. `ADROP` follows the length operation as well.

The lexical snapshot makes the returned owner visible to cleanup during index
evaluation. `return`, `?`, `break` and `continue` release the correct reverse
mixed array/record suffix. Inner loop transfers preserve the surrounding read's
capture. Earlier enclosing argument captures remain live until their own CALL
or exit. Earlier effects are not rolled back on failure.

No VM, opcode, Fuel price, profile or version field changes. A result read uses
one anonymous static site and the transferred owner/extent. An `i32[1]` read or
length query needs four payload bytes; three fails. Separate completed reads
reuse that payload, including across loop iterations. A return from pending
callee argument evaluation needs zero payload when no earlier array is live.
Nested reads may require multiple live extents and alignment padding. The tested
`i32[1]` outer result plus `usize[1]` index result needs sixteen bytes, including
four bytes of padding before the eight-byte-aligned inner extent. All existing limits remain:
sixteen array sites/shared owners, eight arguments, thirty-two frames, 128
registers, 256 instructions, thirty-two call sites and 65,536 payload bytes.

Bare array results still cannot be scalar values. Wrong index types, unknown
members, wrong arity, and local callee shadowing fail compilation. A scalar
element still cannot satisfy an array formal, so `take_array(make()[0])` remains
rejected. Slices, borrowed results and general aggregate expressions are outside
this slice. Existing [array result](m2-array-result-source.md), [array argument
result](m2-array-result-arguments.md) and [literal argument](m2-array-literal-arguments.md)
paths retain their own grammar and cleanup rules.

## Verification

Development and release each passed eighteen native groups:
four new read, eight source-array-result and six literal-argument groups. Its
335 passed CLI cases comprise 106 new, 119 source-array-result and 110 literal-argument
cases, executed with a tool-free runtime environment.

Two combined profile invocations rechecked 229 identical inputs and matching
compiler/SDK identities. Development ran from `231403d` with implementation files
uncommitted; release ran after `b822089`. Both retained executable hashes
were confirmed against their CLI receipts before archival.

The new CLI selection checks fifteen successful programs and ten type rejections
through `check`/`run` (50), six scalar tags at both extrema and lengths 1/2 (48),
two runtime bounds failures (4), and fourteen/fifteen captured-site boundaries
(4). The static fixture uses two maker sites; fourteen read sites fit and fifteen
exceed the limit. Native checks additionally require identical instruction bytes
and site count to a named temporary, missing-ADROP verifier rejection, immediate
payload reuse, four/three-byte read and length boundaries, and zero-payload
pending-call exits.

An earlier development invocation exposed an incorrect twelve-byte ceiling in
the nested mixed-width read fixture. It was corrected to sixteen bytes to include
alignment padding before the final profile invocations.

Earlier receipts remain historical for their original inputs. Full native/CLI
suites, M0, Linux, isolation, DLL embedding, packaging, allocation instrumentation
and elapsed-time performance are outside this focused selection.
