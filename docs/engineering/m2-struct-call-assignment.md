# M2 Root Record Assignment from Call Results

- Status: implemented at `0a6a759`; verified in development and release on Windows.
- Scope: `p = make(args);` for a mutable, exact-nominal root record `p`.
- Implementation: [assignment branch](../../src/compiler.fy), [result helper](../../src/struct_result_source.fy), [fixture](../../tests/m2/struct_call_assignment.fy), [harness](../../tools/verify-m2-struct-call-assignment.py).
- Predecessor: [direct nominal record constructor returns](m2-struct-return-constructors.md).
- Successor: [exact-nominal child call-result assignment](m2-struct-child-call-assignment.md).
- Evidence: [Windows receipt](../evidence/m2-struct-call-assignment-windows-20261028.json).

This slice lets a record-result call replace an existing mutable root payload using CALL, SASSIGN, and SDROP.

```brownie
module main;
struct Pair { i32 x; i32 y; }
fn Pair make(i32 x, i32 y) { return Pair { .x = x, .y = y }; }
fn i32 main() {
    var Pair p = Pair { .x = 0, .y = 0 };
    p = make(20, 22);
    return p.x + p.y; // 42
}
```

## Accepted form

`record_write_statement` recognises an identifier immediately followed by `(` after `=` before
its constructor and bare-binding branches. The name must resolve to a function whose record result
has the destination's exact nominal identity. A visible local with that spelling rejects the assignment.

The form works in ordinary function statements and statement-bearing scalar `switch` value arms.
The [child call-assignment successor](m2-struct-child-call-assignment.md) extends the
same destination rule to exact-nominal child paths, including deep paths. For-header
clauses remain unavailable; a parenthesized call (`p = (make())`) and general
aggregate expressions do not enter this branch.

## Evaluation and publication

Before arguments, `record_results::destination` reserves a dead, immutable, function-owned anonymous
result site. It is absent from locals, so `return`, `?`, `break`, and `continue` cleanup cannot drop
an unborn result. Mutable `p` remains live through argument evaluation, CALL, and capture cleanup.

`call_value` evaluates arguments left to right. Record and array captures occur before later effects;
mutable aggregates are copied at their source position. Existing arity, type, and aggregate checks
remain. A normal CALL writes the result site and releases argument captures.

`record_results::assigned` requires a distinct destination and temporary in the same function, matching
nominal type, and a mutable destination. It emits `SASSIGN` into existing `p`, then `SDROP` of the
temporary. This is not whole-invocation rollback: arguments may mutate `p` before the normal copy.

`SASSIGN` retains `p`'s owner slot, owner order, generation, and base/length/alignment descriptor.
The payload is overwritten in place; the temporary owner is released and `p`'s descriptor remains.

## Resources and limits

Peak payload includes old `p`, the result extent, argument captures, and callee formal copies.
Four-byte `p` plus a four-byte zero-argument result needs eight bytes, not four; a by-value or self
call can need at least twelve before other arguments.

Each syntactic assignment takes one fresh static record site from the shared 16-site catalog.
A runtime loop reuses that site and releases the returned owner each iteration. No opcode, VM
dispatch, Fuel charge, profile string, or version field changes.

## Verification

Six native `@test` groups cover twelve successful programs, twelve type negatives, IR equivalence
with an explicit scoped temporary, an 8-versus-7 payload quota boundary, and a verifier mutation
that removes `SDROP`. The IR case compares `p = make();` with
`{ let P temporary = make(); p = temporary; }`; the corruption case is rejected independently.

Run `python -B tools/verify-m2-struct-call-assignment.py --phase core|regressions --profile development|release`.

`core` selects six new groups; `regressions` selects 24 (six constructor, eight named result-source,
six direct return-call, four array assignment). Each profile selects 30 native groups. The regression
phase also runs 725 CLI cases: 148 call-assignment, 144 constructor, 166 named result-source, 152
return-call, and 115 array-assignment.

Earlier receipts are historical for their original inputs. Full suites, M0, Linux, isolation, DLL,
packaging, allocation instrumentation, and performance were not run.

Development and release each passed all 30 native groups and 725 CLI cases. The four separate
phase invocations share 202 matching rechecked input hashes and the same compiler/SDK identities;
both CLI hashes were rechecked against retained executables. Development core ran before
`0a6a759` with its implementation files uncommitted; the other phases ran after that commit.
