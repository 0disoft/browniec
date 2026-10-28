# M2 Record Calls in Constructor Child Fields

- Status: implemented at `c4cd6ab` and verified for its original inputs. The
  [exact-result call-argument successor](m2-struct-result-arguments.md) is
  implemented at `7671f25`; it is verified in development and release with separate focused evidence.
- Implementation commit: `c4cd6ab4a317aedfe46af9266b10eee9de30a9e3`.
- Scope: an exact-nominal record call as a child field value, such as
  `Outer { .p = make(args) }`, including nested constructor positions.
- Implementation: [child-call lowering](../../src/compiler.fy) and [shared
  scalar-leaf staging](../../src/struct_value_source.fy).
- Fixture: [constructor child-call cases](../../tests/m2/struct_child_calls.fy).
- Harness: [verify-m2-struct-child-calls.py](../../tools/verify-m2-struct-child-calls.py).
- Predecessors: [record constructor returns](m2-struct-return-constructors.md),
  [child call-result assignment](m2-struct-child-call-assignment.md), and
  [constructor child paths](m2-struct-child-path.md).
- Successor: [record call results as arguments](m2-struct-result-arguments.md).
- Evidence: [Windows receipt](../evidence/m2-struct-child-calls-windows-20261028.json).

This slice lets a constructor child field receive the value returned by a
function call. It reuses the existing record-result CALL and ownership transfer.
The parent constructor remains pending until every field has evaluated, and the
child result is copied into scalar staging and dropped before later fields run.

```brownie
module main;
struct P { i32 x; }
struct R { P p; i32 tail; }

fn P make() {
    return P { .x = 42 };
}

fn i32 main() {
    let R r = R { .p = make(), .tail = 0 };
    return r.p.x;
}
```


The [returned-subrecord constructor-field successor](m2-struct-child-call-paths.md)
now accepts `Box { .child = make().child }` and deeper exact-nominal paths,
including declaration, replacement and constructor-return contexts. Its focused
receipt is separate; counts in this document remain historical for their
original inputs. Parenthesized/general aggregate operands remain unavailable.

## Accepted form

For an exact-nominal record child field, the value may be a bare function name
followed by `(`. The callee must resolve through the existing function and
result catalogs and must return the child field's exact nominal type. A visible
local with the callee's spelling is rejected. Calls with scalar and existing
supported aggregate arguments still use `call_value`'s normal argument rules. A
bare exact-nominal record call can now supply a record formal; that argument
exception is owned by the [call-argument successor](m2-struct-result-arguments.md).

The same lowering is reached from all declaration and replacement contexts that
share `record_constructor`: `let`/`var` declarations, root replacement, child
replacement, and a direct constructor-return operand. Nested constructors may
place the call at any supported child depth. The existing constructor path may
also select a whole visible child binding or a dotted exact-nominal path.

Parenthesized child calls remain unsupported. A wrong result type, unknown or
locally shadowed callee, or parenthesized/general aggregate operand for a record
formal is rejected. A bare exact-shape array-call argument now has its own
[successor](m2-array-result-arguments.md).
Those forms fail during compilation. Bare exact-nominal child-path arguments
now have a separate [successor](m2-struct-path-arguments.md).

## Evaluation and publication

The compiler first recognizes the child field and reserves one dead,
immutable, function-owned anonymous destination site through
`record_results::destination`. The destination is absent from the local name
table. Arguments are then evaluated from left to right by the existing
`call_value` path, including mutable aggregate captures and argument effects.
Only the callee's exact-nominal result is accepted for the destination site.

After CALL, `struct_value_source::stage_part` emits one `SREAD` (43) and one
`STORE` (18) for every depth-first scalar leaf of the returned child. The
temporary is then released with `SDROP` (45). This happens before the
constructor evaluates any later scalar sibling or child field. The pending
child destination is absent from the local name table during argument
evaluation. A new parent binding is also absent; an existing replacement parent
remains visible and live.

For a one-leaf child, the relevant order is:

```text
CALL -> SREAD -> STORE -> SDROP -> later fields -> LOAD -> parent SINIT
```

Root replacement uses the same staging followed by `SREPLACE`; child replacement
uses `SSUBREPLACE`. A direct constructor return reaches `SINIT` and then `SRET`.
The shared constructor path emits consecutive `LOAD` (17) operations only after
all fields and the closing punctuation have finished.

Early `return`, `?`, `break`, and `continue` during argument evaluation use the
existing cleanup machinery. They can release already visible bindings and
captures, including an old replacement parent when the exit leaves its scope.
They cannot drop the pending child destination or a new parent owner that has
not been published. Scalar calls and existing whole-binding/child-path staging
are unchanged; `stage_child` now
delegates its owner-free leaf staging to `stage_part`.

## Ownership and quota

Each syntactic child call consumes one static record site for its anonymous
return. The temporary needs the returned record's payload extent until its
scalar leaves have been staged and `SDROP` runs. The parent owner is allocated
only when `SINIT` executes, so a pending parent does not contribute payload
bytes while a later sibling is being evaluated.

`struct R { P p; }` with a four-byte `P` therefore needs only four payload bytes
when `R` is newly constructed from `R { .p = make() }`: the four-byte child
and four-byte parent extents do not overlap. A three-byte arena reports the
existing `array_limit` failure. The old-parent case differs: an eight-byte live
replacement parent and a four-byte returned child need twelve bytes before
captures, formals, or other locals are counted. Early-exit cleanup may release
the old parent instead of reaching replacement.

No opcode, verifier rule, VM behavior, Fuel charge, profile string, or version
field changes. Existing bounds still apply: sixteen static record sites and
sixteen shared owners, sixteen scalar leaves and 128 planned bytes per root,
a 65,536-byte payload arena, 128 registers, 256 instructions, 32 VM frames,
eight call arguments, and 32 call sites.

## Verification

The focused fixture has six native groups, fifteen successful programs, and
twelve type-rejection programs. It covers forward declarations, nested fields,
all six scalar kinds at their extrema, declaration-order field evaluation,
mutable argument effects, declaration and replacement contexts, direct
constructor returns, early returns, `?`, outer loop transfers, repeated child
calls, and the four-versus-three-byte payload boundary.

The native fixture checks `CALL`, `SREAD`, `STORE`, `SDROP`, `LOAD`, and
`SINIT` order and verifies that removing `SDROP` leaves invalid IR. The CLI
matrix also exercises the static-site limit with repeated constructor
replacement. Its 154 cases come from the 27 fixture programs,
48 scalar-boundary programs, and two
repeated-assignment boundary programs, each run through `check` and `run`.

The harness selects 23 native groups per profile: six new `struct_child_calls`
groups and seventeen regressions from `struct_child_path_source` (5),
`struct_return_constructors` (6), and `struct_child_call_assignment` (6). The
regression phase selects 529 CLI cases per profile: 154 new child-call, 83 child
path, 144 constructor-return, and 148 child-call-assignment cases. The recorded
input set has 211 verified identities; all four phase invocations rechecked
identical raw inputs before final formatting.

Development and release each passed 23 native groups (6 core, 17 regressions)
and 529 CLI cases (154 + 83 + 144 + 148) in four separate phase invocations.
Development core ran before implementation commit `c4cd6ab` with the same
implementation files uncommitted; development regressions, release core, and
release regressions ran after it. Compiler and SDK identities matched across
all four phases, and both retained executable hashes were confirmed.

After all four phases, removing sixteen spaces from otherwise empty checker
line 63 was validated as an exact reversible byte change with an identical
Python AST, recorded in `postVerificationFormatting` with verified/current
hashes; product tests were not rerun.

The focused selection does not cover full native or CLI suites, M0, Linux,
isolation, DLL embedding, packaging, allocation instrumentation, or performance.
The later call-argument successor has its own fixture, harness, and focused
verification; it is not included in the 23-group and 529-case totals above.

Bare exact-nominal constructor arguments now have their own
[successor](m2-struct-constructor-arguments.md), which also reruns the child-call
fixture through the shared constructor staging path.
