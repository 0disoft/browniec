# M2 Direct Record Call-Result Scalar Reads

- Status: implemented at `aee98856f2890f7fafe2c657712c1cadbff8250b`; verified in
  development and release.
- Scope: `make(...).field` and deeper paths ending at a scalar leaf.
- Implementation: [`compiler::record_call_read`](../../src/compiler.fy), reusing
  [`struct_value_source::read`](../../src/struct_value_source.fy).
- Fixture: [native checks](../../tests/m2/struct_call_reads.fy).
- Harness: [focused native/CLI verifier](../../tools/verify-m2-struct-call-reads.py).
- Evidence: [Windows receipt](../evidence/m2-struct-call-reads-windows-20261028.json).

```brownie
module main;
struct Point { i32 x; }
fn Point make() { return Point { .x = 42 }; }
fn i32 main() { return make().x; }
```

The ordinary function catalog and local-shadow checks resolve the exact nominal
result. An anonymous immutable destination uses the existing CALL/SRET owner
transfer and argument-capture cleanup. Pending destinations remain absent from
names during argument evaluation. Result transfer adds no payload copy.

The existing bounded field-path resolver locates the scalar leaf. `SREAD`
materializes that value, immediately followed by `SDROP` of the returned root.
Field paths contain no executable index expressions, so there is no exit between
these operations and no additional lexical capture is needed. The verifier
independently tracks the anonymous site's lifetime. A record endpoint such as
`make().child` is still rejected; `make().child.x` is accepted when `x` is scalar.

The read composes with operators, scalar casts, scalar arguments, array indexes,
constructor scalar fields and shallow-wrapper payloads. Enclosing argument
captures remain live until their own CALL or exit. Callee arguments execute once,
with existing `return`, `?`, `break` and `continue` cleanup. A return while the
callee arguments execute cannot release the unpublished result. Earlier effects
are not rolled back. Unknown members, wrong arity, local shadowing, bare record
results in scalar positions and parenthesized aggregate calls remain rejected.
Reading a scalar does not make it a nominal record argument.

No opcode, VM, Fuel price, profile or version flag changes. One read reserves one
static record site and transfers an existing owner/extent. An `i32`-only result
needs four payload bytes; three fails. Completed sequential reads and loop
iterations reuse those four bytes. A pending-call early return needs zero bytes
when no earlier aggregate is live. A live `i32[1]` result plus a returned
`usize` record used as its index requires sixteen bytes including alignment.
All existing site, owner, nominal-layout, depth, register, frame, instruction,
call and payload bounds remain unchanged.

This complements [record results](m2-struct-result-source.md), [record result
arguments](m2-struct-result-arguments.md) and [array call-result
reads](m2-array-call-reads.md). Record borrows remain unavailable. Aggregate
call-result subrecords in argument position now have a
[successor](m2-struct-call-path-arguments.md); scalar reads still reject record
endpoints.

## Verification

Development and release each passed sixteen native groups:
four new record-read, eight source-record-result and four array-read groups.
Each profile passed 374 CLI cases: 102 new, 166 source-record-result and 106 array-read
cases, executed with a tool-free runtime environment.

Two combined profile invocations rechecked 232 identical inputs and matching
compiler/SDK identities. Development ran from `189e5ad` with implementation files
uncommitted; release ran after `aee9885`. Both retained executable hashes
were confirmed against their CLI receipts before archival.

The new CLI matrix checks fifteen successful programs and ten type rejections
through both `check` and `run` (50), six scalar tags at both extrema through root
and nested fields (48), and fourteen/fifteen read-site boundaries (4). Fourteen
read sites plus two maker sites fit the catalog; fifteen exceeds it. Fourteen
record calls exceed the CLI's unchanged 1,000,000 Fuel ceiling; the native test
also runs that accepted program to 42 with 16,000,000 Fuel and four payload bytes.

Native checks additionally require identical instruction bytes and site count
to a named temporary, missing-SDROP verifier rejection, four/three-byte payload
boundaries, immediate reuse and zero-payload pending-call exits. Earlier receipts
remain historical for their original inputs. Full native/CLI suites, M0, Linux,
isolation, DLL embedding, packaging, allocation instrumentation and elapsed-time
performance are outside this focused selection.
