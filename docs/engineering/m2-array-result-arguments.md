# M2 Array Call Results as Arguments

- Status: implemented at `03795b9602eaa160e633d750a91c98743b23dc97`; verified in
  development and release.
- Scope: a bare exact-shape array-result call used directly as an immutable
  scalar-array argument, such as `take(make())`.
- Implementation: [`compiler::array_argument`](../../src/compiler.fy), the
  shared recursive call path in [`call_value`](../../src/compiler.fy),
  [`array_results::destination`](../../src/array_result_source.fy), and the
  existing binding fallback in [`array_calls::capture`](../../src/array_call_source.fy).
- Shared cleanup: [`array_source::release_from`](../../src/array_source.fy)
  releases mixed array and record captures in reverse lexical order.
- Fixture: [array result-argument cases](../../tests/m2/array_result_arguments.fy).
- Harness: [verify-m2-array-result-arguments.py](../../tools/verify-m2-array-result-arguments.py).
- Predecessors: [array parameters](m2-array-parameters.md), [array
  results](m2-array-result-source.md), and [record result
  arguments](m2-struct-result-arguments.md).
- Evidence: [Windows receipt](../evidence/m2-array-result-arguments-windows-20261028.json).

This slice lets an array-result call satisfy an exact-shape scalar-array formal
without a preceding named temporary. The result continues through the existing
CALL/`ARET` ownership-transfer path. The new source work is destination
reservation, recursive argument lowering, name visibility, and cleanup timing in
the caller.

```brownie
module main;

fn i32[1] make() {
    return [42; 1];
}

fn i32 take(i32[1] a) {
    return a[0];
}

fn i32 main() {
    return take(make()); // 42
}
```

## Accepted form

`compiler::array_argument` recognizes a callee identifier followed immediately
by `(`. A visible local binding with that spelling rejects the call, so a local
cannot shadow the function reference. The target is resolved through the
predeclared function catalog and must return the formal's exact element tag and
exact nonzero length.

`array_results::destination` performs that exact-type check before reserving a
dead anonymous array site. The destination is one of the unencoded array IDs
`0..15`. `call_value` then recurses with the destination, expression depth plus
one, and all existing result-context and loop state. The recursive parser handles
the callee's own arguments normally, including nested exact-shape array calls.

After the recursive CALL, the next token must be either the outer call's comma or
closing parenthesis. Only after both CALL completion and delimiter validation
does the compiler declare an anonymous immutable lexical capture encoded as
`128 + site`. Its source span is empty, so no later argument can refer to it by a
guest name. A malformed tail fails before the result enters the caller's lexical
snapshot.

The accepted programs include `take(make())` and `id(id(make()))`. Consumers may
return a scalar, an array, a nominal record, or a shallow wrapper. The fixture
covers scalar, array, record, and `Option<i32>` consumers. These cases use the
ordinary call-result destination rules for their own result type.

A bare array binding still goes through `array_calls::capture`. An immutable
exact-shape binding is passed directly. A mutable exact-shape binding is copied
to an anonymous immutable snapshot before later arguments evaluate, preserving
the established by-value argument semantics.

## Capture timing and cleanup

Reserving the destination creates catalog metadata only. It does not allocate an
owner or payload extent before result transfer. The pending destination is absent
from the local name table until the inner CALL and its delimiter check succeed.
Consequently, an early exit during that call's arguments cannot release an owner
that has not been published as a call-result capture.

Arguments in mixed array, record, and scalar calls evaluate left to right. The
anonymous result becomes stable at its own source position, so a later argument's
effects cannot change an earlier capture. On normal CALL completion,
`array_source::release_from` drops argument captures in reverse lexical order.
The same path handles argument-evaluation `return`, `?`, `break`, and `continue`,
dropping every capture that is already live. Nested loops preserve captures owned
by the surrounding call expression; an inner loop transfer releases only its own
lexical suffix.

The outer CALL copies the captured array into the immutable callee formal through
the existing mixed aggregate-copy transaction. The completed inner array CALL
writes the returned catalog owner into the anonymous destination. No second
owner is allocated for the destination and no payload copy is introduced by the
result transfer itself. Existing parameter copies, mutable snapshots, and
capture extents retain their established costs.

## Resources and limits

A concrete `i32[1]` result and its `i32[1]` formal each need four payload bytes.
Both must be live at parameter entry, so eight bytes are required. Seven bytes
fails with the existing quota error. More arguments or captures can raise the
peak through the existing transaction checks.

An early `return` inside the nested `make(...)` arguments needs zero array payload
bytes because the pending result does not yet exist and the outer formal is never
entered. The fixture checks this path with a zero-byte array arena.

Each syntactic captured result consumes one static array site. The sixteen-site
limit is unchanged, and result anchors, formals, and body declarations share it.
In the static boundary fixture, three sites are already used; thirteen syntactic
captured calls fit and run to 42 with a 1,000,000 Fuel allowance. Fourteen calls
report `compile_limit`.

The other bounds remain unchanged: sixteen shared owners, thirty-two VM frames,
eight arguments per call, 128 registers, 256 instructions, 32 call sites, and a
65,536-byte payload arena. A loop reuses its syntactic sites while recursive
frames retain separate frame tokens over the shared owner table.

This slice adds no VM, opcode, Fuel price, profile, or version-field change. The
version JSON does not add `array_results` or `array_parameters` booleans. It keeps
the existing `array_profile`, `array_write_profile`, `array_copy_profile`, and
struct capability fields.

## Rejected forms

In an exact-shape array formal position, compilation rejects:

- an array result with the wrong element tag;
- an array result with the wrong or zero length;
- a scalar, nominal-record, or wrapper result;
- an unknown callee, an arity mismatch, or a callee shadowed by a visible local;
- a parenthesized call such as `take((make()))`;
- indexing a result, as in `take(make()[0])`;
- an array literal such as `take([42; 1])`; and
- mutation of the formal inside the consumer.

These rules do not add general aggregate expressions. Bare names retain their
parameter rules, and other formal types retain their existing argument grammar.

## Verification

The native fixture has six groups with fifteen successful `value()` programs and
twelve type-rejection programs. The successful cases cover forward declarations,
lengths 1 and 2, all consumer result kinds named above, nested result calls,
mixed array/record/scalar captures, mutation after an earlier capture, early
array-result return, early scalar return, `?`, `break`, `continue`, and an inner
loop inside a surrounding call expression.

One group compares `take(make())` with a named `let` array temporary. It requires
identical instruction bytes and array-site counts. The same group probes the
eight-versus-seven payload boundary and the zero-payload early-return case. It
also mutates the anonymous result's missing `ADROP` in the verified instruction
stream and requires the independent verifier to reject it.

The new CLI selection has 154 cases: 27 fixture programs through both `check` and
`run` (54), 48 scalar-boundary programs through both commands (96), and two
static-site programs through both commands (4). The scalar matrix covers six
element tags, both extrema per tag, lengths 1 and 2 for each case, and both a
direct maker and a forwarding maker. The thirteen-call static case succeeds and
returns 42 at 1,000,000 Fuel; the fourteen-call case reports `compile_limit`.

Development and release each passed 29 native groups: six new
array-result-argument, eight array-parameter-source, eight array-result-source,
and seven record-result-argument groups. Each profile also passed 507 CLI cases:
154 new, 80 array-parameter, 119 array-result-source, and 154 record-result-argument
cases.

These were two combined focused profile invocations. Development ran from
baseline `b1fe83f` with the implementation files uncommitted; release ran after
implementation commit `03795b9`. Both invocations rechecked the same 223 input
hashes and matching compiler/SDK identities. Both retained executable hashes
were confirmed against their CLI receipts before archival.

The existing `struct_result_arguments` fixture's former bare-array-call rejection
now uses the still-rejected parenthesized form `take((make()))`. Its case counts
are unchanged. Earlier receipts remain historical for their original compiler,
fixture, and harness inputs.

This focused slice skips full native and CLI suites, M0, Linux, isolation, DLL
embedding, packaging, allocation instrumentation, and performance measurement.
