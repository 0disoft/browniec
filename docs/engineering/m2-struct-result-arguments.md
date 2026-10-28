# M2 Record Call Results as Arguments

- Status: implemented at `7671f2578bfc3402fb1f7aec1b2ff513e5e6ba89`;
  verified in development and release.
- Scope: a bare function call whose exact nominal result supplies an immutable
  record formal, such as `take(make())`.
- Implementation: [`compiler::record_argument`](../../src/compiler.fy), the
  shared recursive call path in [`call_value`](../../src/compiler.fy), and the
  existing binding-capture fallback in
  [`struct_call_source::capture`](../../src/struct_call_source.fy).
- Shared cleanup: [`array_source::release_from`](../../src/array_source.fy)
  handles the mixed array and record captures already present in the call's
  lexical snapshot.
- Fixture: [record result-argument cases](../../tests/m2/struct_result_arguments.fy).
- Harness: [verify-m2-struct-result-arguments.py](../../tools/verify-m2-struct-result-arguments.py).
- Predecessors: [source record parameters](m2-struct-parameters-source.md),
  [source record results](m2-struct-result-source.md), and
  [direct record return calls](m2-struct-return-calls.md).
- Evidence: [Windows receipt](../evidence/m2-struct-result-arguments-windows-20261028.json).

This slice lets a call result satisfy a nominal record formal without first
declaring a named temporary. The result still follows the existing CALL and
`SRET` ownership path; the new work is source lowering, capture timing, and
cleanup placement in the caller.

```brownie
module main;
struct P { i32 x; }

fn P make() {
    return P { .x = 42 };
}

fn i32 take(P p) {
    return p.x;
}

fn i32 main() {
    return take(make()); // 42
}
```

## Accepted form

When `record_argument` sees a function identifier followed by `(`, it resolves
that identifier through the predeclared function catalog. The callee's record
result must have the exact nominal identity of the record formal. A visible local
binding with the callee's spelling rejects the call, so local shadowing cannot be
mistaken for a function reference.

The call uses the normal argument grammar for its own arguments. This makes
nested result calls work left to right, including `id(id(make()))`, and lets the
consumer itself return a scalar, an array, or a shallow wrapper. The fixture
covers `take(make())`, nested `id` calls, and array-returning and
wrapper-returning consumers.

The accepted position is the argument of an exact-nominal record formal. Other
record-shaped expressions do not become general call arguments or general
aggregate expressions through this slice.

## Lowering and capture timing

`record_argument` reserves one dead, immutable, function-owned anonymous record
site through `record_results::destination` before the nested arguments evaluate.
The site is absent from the local name table. It then consumes the function name
and calls `call_value` recursively with that site as destination, the current
result context, and expression depth plus one. Existing depth limits, argument
arity, scalar types, aggregate types, captures, and CALL construction remain in
force.

After the recursive CALL, `record_argument` requires the next token to be a comma
or the outer call's closing parenthesis. Only after CALL completion and that
delimiter check does it declare an anonymous record binding for the destination.
The binding has an empty source span, so later arguments cannot refer to it by a
guest name. A malformed delimiter therefore fails before the result is entered
into the caller's lexical snapshot.

Arguments are evaluated left to right. The anonymous result becomes a stable
argument at its own source position, so later arguments may change the original
bindings or perform early transfers without changing the pending value. Existing
named pure bindings still use the direct visible owner. The mutable-binding
fallback remains in `record_calls::capture`: an exact-type mutable binding is
snapshotted with `SCOPY` before later arguments evaluate, while an immutable or
already captured record can be passed directly.

## Cleanup and ownership

The nested CALL writes its returned owner into the anonymous destination. Once
the delimiter check succeeds, that owner participates in the outer call's
lexical snapshot. The outer CALL evaluates its remaining arguments and, after a
successful CALL, the shared `release_from` suffix cleanup drops argument captures
in reverse lexical order, including the anonymous record result.

Early `return`, `?`, `break`, and `continue` during argument evaluation use the
same mixed cleanup path. They drop captures that are already live, including
results registered by earlier arguments. Pending destinations remain invisible
until their own CALL and delimiter validation complete, so cleanup cannot drop
an owner that has not been published into the lexical snapshot.

The outer CALL copies the captured result into the immutable callee formal using
the existing mixed aggregate-copy transaction. The existing record-result VM
performs the inner `SRET` ownership transfer. The existing owner budget and
ownership protocol are unchanged, as are opcodes, VM rules, Fuel charges,
profile strings, and version fields.

## Resources and limits

Every syntactic nested result consumes one static record site. The existing
sixteen-site and sixteen-shared-owner budgets are unchanged, as are the 65,536-byte
payload arena, 128 registers, 256 instructions, 32 VM frames, eight arguments per
call, and 32 call sites. A loop reuses its syntactic result site; recursive frames
retain frame-local tokens over the same shared owner table.

The inner result and the outer callee formal can be live together. A four-byte
result plus a four-byte formal needs eight payload bytes before other captures or
locals; seven bytes fails with the existing quota error. More arguments or
snapshots can raise the peak through the existing transaction checks.

## Rejected forms

In a record argument position, this slice rejects constructor operands, field
paths, parenthesized calls, wrong
nominal result types, unknown and locally shadowed callees, `call().field`, and
array-returning calls used as array arguments. This does not add general aggregate expressions; other formal types retain
their existing argument rules. These cases fail
during compilation rather than reaching a partially published destination.

## Verification

The focused fixture has seven native groups containing fifteen positive programs
and twelve negative programs. It covers forward and nested nominal results,
scalar extrema, nested result calls, array- and wrapper-returning consumers,
earlier results surviving later mutations, mixed array/record/scalar arguments,
early scalar/record/`?` exits, outer loop transfers with inner-loop capture
preservation, repeated calls, and all rejected forms listed above.

One group compares `take(make())` with an explicit named temporary. The programs
must produce the same instruction stream and record-site count. The group also
checks the eight-versus-seven payload boundary and rejects a mutated stream whose
anonymous capture is not dropped by the shared cleanup sequence.

The new CLI selection has 154 cases: 27 fixture programs through both `check` and
`run` (54), 48 scalar-boundary programs through both commands (96), and two
static-site programs through both commands (4). Static case 13 passes `check` and
exhausts the CLI's 1,000,000 Fuel allowance at runtime; static case 14 reports
`compile_limit`.

Development and release each passed 29 native groups and 588 CLI cases.
`core` selects the seven new groups. `regressions` selects 22 groups: eight source
record-parameter, eight source record-result, and six constructor child-call
groups. The CLI total is 154 new, 114 source parameter, 166 source result, and
154 constructor child-call cases. The four phase selections use the same fixture
and input set.

Development core ran from baseline `7f758e4` with the implementation files
uncommitted; the other three phases ran from `7671f25`. All four invocations
rechecked the same 214 input hashes and matching compiler/SDK identities. Both
retained development and release executable hashes were confirmed against their
CLI receipts before archival. These were separate core/regression phases, not
one aggregate invocation.

Earlier receipts remain historical for their original inputs. This focused slice
does not cover full native or CLI suites, M0, Linux, isolation, DLL embedding,
packaging, allocation instrumentation, or performance.
