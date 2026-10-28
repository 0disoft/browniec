# M2 Returned Call-Root Child Paths

- Status: implemented at `c78930046a330cc940be20bfcfd4c5350047cbc5`; verified in development and release.
- Scope: `return make().child;` and deeper exact nominal child paths in record-result functions.
- Evidence: [Windows receipt](../evidence/m2-struct-call-path-returns-windows-20261028.json).

Implementation: [return branch](../../src/compiler.fy),
[shared call extractor](../../src/struct_value_source.fy), and
[record-result finisher](../../src/struct_result_source.fy).
Fixture: [call-path returns](../../tests/m2/struct_call_path_returns.fy).
Harness: [verify-m2-struct-call-path-returns.py](../../tools/verify-m2-struct-call-path-returns.py).
CLI matrix: [check-m2-struct-call-path-returns.py](../../tools/check-m2-struct-call-path-returns.py).

```brownie
struct P { i32 x; }
struct R { P child; }

fn R make() { return R { .child = P { .x = 42 } }; }
fn P pick() { return make().child; }
```

The call name must resolve to a function, not a visible local. The complete
dotted path must end at the enclosing function's declared record result with the
same nominal identity, and the return must end with a semicolon. A deeper path
such as `return make().child.right;` is admitted when every selected field
exists and the final endpoint is exact.

Bare `return make();` retains its direct result transfer. A named-path return
such as `return source.child;` retains its independent copy from a live source.
The new call-root path copies the selected child leaves out of the returned
temporary root, then releases that root.

## Lowering and ownership

For each dotted return, the compiler uses two static record sites in the
function: the actual callee's root result and the independently owned child.
The root destination is reserved as dead and unnamed before argument evaluation,
so it is absent from the binding table. CALL uses the existing `call_value`
path, including left-to-right argument evaluation and aggregate capture cleanup.
An early return, break, or continue from a pending argument publishes no result.

The shared `extracted_call` resolver checks the returned root's exact nominal
type, validates the declared result identity and trailing semicolon, and emits
consecutive SREAD operations for every child leaf. It then emits SDROP for the
root before creating and initializing the child. The required order is
`CALL -> SREAD* (43) -> SDROP (45) -> SINIT (41) -> SRET (50)`; the verifier
rejects a path with its root drop missing.

`finish` rechecks the selected result's function and nominal identity. It drops
all other visible mixed record and array bindings in reverse lexical order,
retains the selected record, and emits SRET. These other drops can occur between
SINIT and SRET. SRET transfers the selected owner;
the root temporary is no longer live.

No opcode, VM, Fuel, profile, or version changes are introduced. Existing
record-site, owner, register, instruction, path-depth, payload, frame, argument,
and call-site limits remain unchanged. A parent with one i32 pad and one child
totals eight bytes: the native test returns that child with a payload limit of
eight and fails at seven. Dead prefixes from older locals or argument captures
may still retain payload behind the result; this contract makes no general
compaction claim.

## Rejected forms

These forms remain unsupported and fail during compilation:

- parenthesized or general aggregate returns, including `return (make().child);`;
- wrong nominal or scalar endpoints, unknown fields, and a local name used as a callee;
- record borrows, `ref`/`var` record results, and wrapper results;
- constructor child-call field selection, such as `R { .child = make().child }`;
- scalar `?` in a record-result function.

## Focused verification

The fixture covers recursive forwarding, loop reuse, deep fields, scalar extrema,
early exits from pending arguments, wrong nominal/scalar endpoints, and the
missing-root-SDROP rejection.

The new 144 cases are:

| Selection | Cases |
| --- | ---: |
| 10 accepted positives and 10 rejected negatives, each in check and run | 40 |
| 6 tag types x 2 extrema x let/var x shallow/deep, each in check and run | 96 |
| Caller-site 11/12 boundaries: five baseline static sites plus eleven reaches sixteen; check accepts, run exhausts Fuel; twelve reaches `compile_limit` | 4 |
| Two malformed return-tail syntax cases, each in check and run | 4 |




## Archived verification

Development and release each passed 16 native groups and 444 CLI cases.
Both invocations rechecked 244 identical input hashes and matching compiler/SDK
identities; both retained executable hashes matched their CLI receipts. Development
ran from `32ce02d` with implementation files uncommitted; release ran after
`c789300`. The selection above is now verified for these archived inputs.
