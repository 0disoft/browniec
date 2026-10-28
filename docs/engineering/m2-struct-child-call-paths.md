# M2 Call-Result Child Paths in Record Constructors

- Status: implemented at `c0d621745cd88b0de30e9c8a727e99e87dbc946e`; verified in development and release.
- Evidence: [Windows receipt](../evidence/m2-struct-child-call-paths-windows-20261028.json).
- Scope: select a path from a call-returned record while initializing a constructor child field.
- Implementation: [`compiler::record_child_call`](../../src/compiler.fy) and
  [`struct_value_source::stage_call_child` / `stage_part`](../../src/struct_value_source.fy).
- Predecessors: [constructor child calls](m2-struct-child-calls.md) and
  [constructor child paths](m2-struct-child-path.md).
- Fixture and checks: [`struct_child_call_paths.fy`](../../tests/m2/struct_child_call_paths.fy),
  [`check-m2-struct-child-call-paths.py`](../../tools/check-m2-struct-child-call-paths.py),
  and [`verify-m2-struct-child-call-paths.py`](../../tools/verify-m2-struct-child-call-paths.py).

An exact-nominal record returned by a bare function call can now supply an
exact-nominal child through one or more visible source segments. The destination
may be a constructor field at any supported depth.

```brownie
module main;
struct P { i32 x; }
struct R { i32 pad; P child; }
struct D { P p; }

fn R make() { return R { .pad = 0, .child = P { .x = 42 } }; }
fn i32 main() {
    let D d = D { .p = make().child };
    return d.p.x;
}
```

Deeper source paths such as `make().child.right`, including nominal children
contained in other returned records, use the same resolver. Selected paths work
in `let` and `var` declarations, whole-record and child-record constructor
replacement, and direct constructor returns. These contexts all reach the new
handling through the shared `record_constructor` path.

`record_child_call` reserves the anonymous result site using the actual callee's
nominal return type. Arguments retain the existing left-to-right evaluation and
cleanup rules, including mutable aggregate captures and their effects. `CALL`
produces one root result. `stage_call_child` resolves the returned root and path;
`stage_part` then validates that the endpoint matches the destination child's
exact nominal type and that the constructor delimiter is `,` or `}`. Each selected
scalar leaf is copied with `SREAD` and stored with `STORE` into the existing
parent staging slots. The root is released with `SDROP` before any later field
evaluates.

After the complete constructor parses, the shared path emits consecutive `LOAD`
operations, then creates the parent with `SINIT` or overwrites an existing parent
with `SREPLACE` or `SSUBREPLACE`. A constructor return subsequently reaches `SRET`.
A newly declared parent remains unnamed, dead, and pending
during field evaluation. An old parent in a replacement remains live and visible
until the new constructor overwrites it. There is one root result site per call;
the selected child has no independent source record, static site, or `SINIT`.

The source fields of a call result, the source path, and call captures are
snapshotted and evaluated once. Fields still run from left to right. An early
`return`, `?`, or loop transfer evaluated by a later field leaves no returned-root
owner or pending-parent owner behind. Effects performed before that exit are not
rolled back.

The feature adds no VM behavior, opcode, verifier rule, Fuel charge, profile, or
version field. Existing owner, record-site, instruction, and payload limits apply.
`record_child_call`, `stage_call_child`, and `stage_part` reuse the established
CALL, staging, and initialization machinery.

## Rejections and boundaries

General or parenthesized aggregate expressions are rejected. The endpoint and
destination must match nominally; scalar endpoints are rejected. A shadowed
callee, missing function, use of a pending destination name, or replacement of an
immutable parent is rejected during compilation. Record borrows remain unsupported.
Deep constructor scopes and surrounding sibling fields are covered. Bare
whole-record child-call fields and their existing procedure remain unchanged.

## Native contract

The focused native selection uses one instruction sequence to prove
`CALL -> SREAD -> STORE -> SDROP -> LOAD -> SINIT`. Replacing the expected `SDROP`
with an unrelated opcode must make the verifier fail. A newly declared `D { P p; }`
accepts the eight-byte anonymous root while the four-byte destination is pending:
an eight-byte payload arena passes and seven bytes fails. Replacing an existing
four-byte `D` keeps the old parent live while the eight-byte root is staged, so
twelve payload bytes pass and eleven fails.

The new CLI fixture has 144 cases: ten positive programs and ten type failures run
through `check` and `run` (40); six scalar tags at two extrema across declaration
and replacement and shallow/deep paths (96); the 13/14 static-site boundary (4);
and two delimiter syntax failures (4). The baseline fixture declares three record
sites; thirteen call results use the remaining thirteen of sixteen. Thirteen calls
compile but exhaust the unchanged one-million Fuel allowance at runtime; fourteen calls
hit the compile-time site limit.

Earlier receipts remain historical evidence for their original inputs.

Focused verification does not include full native or CLI suites, M0, Linux,
isolation, DLL embedding, packaging, allocation instrumentation, or performance.

## Archived verification

Development and release each passed 16 native groups and 442 CLI cases.
Both invocations rechecked 247 identical input hashes and matching compiler/SDK
identities; both retained executable hashes matched their CLI receipts. Development
ran from `cd87134` with implementation files uncommitted; release ran after
`c0d6217`. The selection above is now verified for these archived inputs.
