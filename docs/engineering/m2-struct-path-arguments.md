# M2 Exact-Nominal Record Path Arguments

- Status: implemented at `9650f123dfc43d15690221d38298df09dfea6dca`; verified in
  development and release.
- Scope: a bare record path, such as `take(outer.child)` or
  `take(outer.middle.child)`, whose endpoint has the exact nominal type of an
  immutable record formal.
- Implementation: [`compiler::record_argument`](../../src/compiler.fy),
  `struct_value_source::extracted_argument`, and the private shared extractor in
  [`struct_value_source`](../../src/struct_value_source.fy).
- Shared cleanup: [`array_source::release_from`](../../src/array_source.fy)
  handles the mixed array and record captures already present in the call's
  lexical snapshot.
- Fixture: [record path-argument cases](../../tests/m2/struct_path_arguments.fy).
- Predecessors: [source record parameters](m2-struct-parameters-source.md) and
  [record call results as arguments](m2-struct-result-arguments.md).
- Evidence: [Windows receipt](../evidence/m2-struct-path-arguments-windows-20261028.json).
- Harness: [verify-m2-struct-path-arguments.py](../../tools/verify-m2-struct-path-arguments.py).

This slice lets an exact-nominal subrecord selected from a visible record path
satisfy a record formal without first declaring a named temporary. The selected
leaves are copied into an anonymous immutable capture, then the existing CALL
transaction copies that capture into the callee's by-value formal. The source
record stays live.

```brownie
module main;

struct Pair { i32 x; i32 y; }
struct Bundle { u8 tag; Pair pair; }

fn i32 take(Pair pair) {
    return pair.x + pair.y;
}

fn i32 main() {
    let Bundle bundle = Bundle {
        .tag = 1,
        .pair = Pair { .x = 20, .y = 22 },
    };
    return take(bundle.pair); // 42
}
```

## Accepted form

For a record formal, `record_argument` inspects an identifier followed by `.`.
The path branch resolves the visible root binding, walks the field path, and
requires an exact-nominal record endpoint of the formal's type. The path is a
bare dotted operand: it begins with one visible record binding and continues
through named record fields to the selected endpoint.

Deep paths are accepted. Preceding scalar fields add one leaf to the endpoint's
offset; preceding record fields add their complete depth-first scalar-leaf
range. The selected type, not its structural layout, must match the formal.

The existing forms remain available in the same argument position:

- a bare visible exact-nominal binding, such as `take(pair)`;
- a bare exact-nominal call result, such as `take(make_pair())`;
- nested result calls, such as `take(id(id(make_pair())))`.

A dotted identifier selects the path branch before those fallbacks. A delimiter
after the path must be a comma or the outer call's closing parenthesis.

## Shared extraction and lowering

The path branch calls
`struct_value_source::extracted_argument`. It shares the private
`extract_operand` implementation with the existing `extracted` wrapper used by
declaration initializers and record returns. The wrappers preserve their
different delimiter contracts:

- `extracted` consumes the terminating semicolon exactly as before;
- `extracted_argument` requires a comma or closing parenthesis but leaves that
  delimiter unconsumed for the outer argument loop.

`extract_operand` resolves the visible root binding and path, checks the exact
nominal endpoint, validates the appropriate delimiter, and computes the
endpoint's consecutive leaf count. It then emits one `SREAD` per selected leaf.
Those results occupy consecutive scalar registers. It allocates one immutable,
function-owned anonymous record site with `record_in` and emits one `SINIT` over
the consecutive registers.

No user expression is evaluated between the `SREAD` leaves, so the consecutive
register range remains the complete input to `SINIT`. There are no staging
`STORE`/`LOAD` operations or `SCOPY`. `SINIT` allocates the final snapshot owner
and payload extent; no extra intermediate owner is needed.

After `SINIT` completes, `record_argument` declares an anonymous immutable
capture over the new site. Its source span is empty, so later guest expressions
cannot refer to it by name. A malformed delimiter fails before the destination
is published into the caller's lexical snapshot.

## Lifetime and evaluation order

Arguments continue to evaluate from left to right. A path argument is snapshotted
even when its root binding is immutable. For a mutable root, later argument
expressions can change the original root without changing the pending capture, and the capture cannot
be changed through the anonymous name. This differs intentionally from a direct
immutable binding, whose visible owner can be passed without a snapshot: a path
copy always represents the value at its own argument position.

The original root remains live through extraction, capture publication, later
arguments, CALL, and argument cleanup. The callee receives a second, independent
copy through the existing CALL formal-copy transaction. In a program with a
root record, a path capture, and a record formal, all three can be live together.

The shared mixed cleanup path handles the capture after normal CALL completion.
Captures are dropped in reverse lexical order with the existing `SDROP`
instruction, including neighboring array captures. Early `return`, `?`, `break`,
and `continue` paths release captures already visible at the transfer. An inner
loop's transfer preserves captures belonging to the enclosing argument
expression, including the path capture.

Argument effects and external effects are not rolled back. A failure after an
earlier argument's effect follows the existing call-failure behavior.

## Ownership and resources

Each syntactic path argument consumes one of the 16 static record sites. The
shared budget also includes root records and every declared record formal; no additional
site table or quota is introduced. A loop reuses the same static site at runtime,
and recursive frames retain frame-local tokens over the shared 16-owner table.

For `struct P { i32 x; }` nested in `struct R { P p; }`, the live root needs four
payload bytes, the path capture another four, and the by-value formal another
four. The call therefore requires 12 payload bytes. A payload limit of 12
passes; 11 fails through the existing quota error. Other captures, locals, or
arguments can raise peak use through the existing transaction checks.

The existing 65,536-byte payload arena, 128 registers, 256 instructions, 32 VM
frames, eight arguments per call, 32 call sites, path depth, and per-record size
limits are unchanged. This slice adds no opcode, verifier rule, VM dispatch,
Fuel price, owner-descriptor format, payload cap, profile string, or version field. It
reuses the existing `SREAD`, `SINIT`, CALL formal copy, `SDROP`, mixed cleanup,
IR verifier, metered VM, profile selection, and version reporting.

The snapshot and formal copy pay their existing Fuel prices. The new argument
lowering emits the same instructions as a named subrecord extraction followed
by the call; it introduces no claim about measured allocation or execution speed.

## Rejected forms

A record path argument fails during compilation when its endpoint is not an
exact-nominal record or the syntax is not a bare record path. The focused cases
cover:

- a path whose nominal endpoint differs from the formal, including a matching
  field layout under another nominal type;
- a scalar endpoint such as `outer.child.scalar`;
- unknown fields and unknown root names;
- roots that are scalars, arrays, or wrappers rather than record bindings;
- parenthesized paths such as `take((outer.child))`;
- a field selected from a call result, such as `take(make().child)`;
- record constructors;
- casts of a path;
- equality or other general argument expressions built from paths.

These checks do not add general aggregate expressions, record borrows, `ref` or
`var` record parameters, or implicit conversion of subrecord values to scalars. Direct
exact-result arguments and bare exact-type bindings continue to use their
existing paths.

## Verification

The fixture has six native groups containing 15 successful programs and 12
compile-time type rejections. It covers forward calls, deep paths, nonzero leaf
offsets, scalar extrema, mutable roots, array- and wrapper-returning consumers,
repeated paths, mixed arguments, evaluation order, early scalar/record/`?` exits,
`break` and `continue`, and preservation of an enclosing capture by an inner
loop.

One group compares `take(root.child)` with the explicit named extraction
`let P temporary = root.child; return take(temporary);`. Both programs must
produce byte-equivalent IR. The same group runs the direct program with 12 and
11 payload bytes and requires success followed by the existing quota failure.
It also mutates the `SDROP` after the outer CALL to another opcode and requires
the independent verifier to reject the missing capture cleanup.

The new CLI selection contains 154 cases:

- 27 fixture programs through both `check` and `run` (54 cases);
- 48 scalar-boundary programs through both commands (96 cases);
- two static-site programs through both commands (four cases).

Static case 14 passes `check` with 14 repeated path arguments and reports Fuel
exhaustion from `run` at the CLI's 1,000,000 allowance. Static case 15 reports
`compile_limit`. These exercise the fixed limits without reusing successful
runtime results.

Development and release each passed 27 native groups: six new path-argument,
seven result-argument, eight source-parameter, and six subrecord-return groups.
Each profile also passed 570 CLI cases: 154 new, 154 result-argument, 114
source-parameter, and 148 return-path cases.

The successful profiles ran as two combined focused invocations, one per
profile. Development ran from baseline `7e404bf` with the implementation files uncommitted; release ran
after implementation commit `9650f12`. Both invocations rechecked the same 217
input hashes and matching compiler/SDK identities. Both retained executable hashes
were confirmed against the corresponding CLI receipts before archival. Earlier
receipts remain historical for their original inputs.

An earlier development native attempt passed 26 of 27 groups and failed the
obsolete source-parameter path-rejection test. After replacing that rejection
with the scalar endpoint, the full development native and CLI selections were
rerun. The final receipts use only the corrected inputs and fresh outcomes.

The existing [record result-argument fixture](../../tests/m2/struct_result_arguments.fy)
and [source-parameter fixture](../../tests/m2/struct_parameters_source.fy)
previously used `r.p` as a rejection case. A record path is now valid there, so
those negative cases reject the scalar endpoint `r.p.x` instead. This compatibility
change is part of the path-argument fixture update.

This focused slice does not cover full native or CLI suites, M0, Linux, runtime
isolation, DLL embedding, packaging, allocation instrumentation, or performance.
The receipt records these skips, both profile outcomes, baseline and implementation
commits, toolchain and artifact identities, commands, and input hashes.
