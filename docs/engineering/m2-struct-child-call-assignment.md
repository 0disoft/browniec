# M2 Child Record Assignment from Call Results

- Status: implemented at `63be9e5`; verified in development and release.
- Scope: `outer.child = make(args);` for a mutable, exact-nominal child
  record, including deep paths such as `outer.middle.child = make(args);`.
- Implementation: [shared assignment helper](../../src/compiler.fy),
  [result helper](../../src/struct_result_source.fy).
- Fixture: [child call-assignment cases](../../tests/m2/struct_child_call_assignment.fy).
- Harness: [verify-m2-struct-child-call-assignment.py](../../tools/verify-m2-struct-child-call-assignment.py).
- Predecessors: [root record call-result assignment](m2-struct-call-assignment.md)
  and [atomic subrecord assignment](m2-struct-subassign-atomic.md).
- Evidence: [Windows receipt](../evidence/m2-struct-child-call-assignment-windows-20261028.json).

This slice extends record-result assignment from an existing mutable root to an
exact-nominal child endpoint. The source is the returned record root. The
destination can select a child at any supported path depth.

```brownie
module main;
struct Pair { i32 x; i32 y; }
struct Bundle { u8 tag; Pair pair; }

fn Pair make() {
    return Pair { .x = 20, .y = 22 };
}

fn i32 main() {
    var Bundle bundle = Bundle {
        .tag = 255,
        .pair = Pair { .x = 0, .y = 0 }
    };
    bundle.pair = make();
    return bundle.pair.x + bundle.pair.y; // 42
}
```

## Accepted form

For an assignment whose destination starts with a visible mutable record, the
compiler first tries the shared `record_call_assignment` helper. It accepts a
bare identifier followed by `(` after `=`. The callee must resolve to a
function whose record result has the destination's exact nominal identity. A
visible local with the callee's spelling rejects the call.

The destination path may contain any number of field segments supported by the
existing path resolver. Every segment must name a record field, and the endpoint
must be an exact-nominal record leaf. The destination root must be mutable.

The same helper handles a root destination and a child destination. A root
continues through `record_results::assigned` and `SASSIGN`; a child continues
through `struct_result_source::subassigned` and the existing `SSUBASSIGN`
(47) instruction.

The form is accepted as an ordinary function statement and in the same
statement-bearing contexts as root call-result assignment. A parenthesized call,
general aggregate expression, scalar endpoint, or for-header assignment remains
unsupported and fails during compilation. A trailing field selection such as
`outer.child = make().field;` enters the call helper, but the unexpected
field selector fails the required terminator check. It is rejected as a syntax
error before execution.

This document owns a call assigned into an existing child destination. The later
[constructor child-call slice](m2-struct-child-calls.md) separately admits an
exact-nominal record call as a value inside `R { .child = make() }`; it does not
make parenthesized calls or call-result field selection valid.

## Evaluation and publication

Before evaluating arguments, `record_results::destination` reserves one dead,
immutable, function-owned anonymous result site. The site is absent from the
local name table, so an early `return`, `?`, `break`, or `continue` can
drop only bindings that already exist.

The existing `call_value` path evaluates arguments from left to right. Scalar
arguments are evaluated in place. Mutable record and array arguments receive
their anonymous captures before later arguments evaluate. The shared call
lowering emits capture cleanup after a successful CALL and before the assignment
instruction executes. CALL writes the anonymous result site in the caller;
capture cleanup then releases the argument captures.

`subassigned` requires a destination and temporary in the same function,
a mutable destination, an exact-nominal child endpoint, and a temporary whose
record identity matches that endpoint. It emits `SSUBASSIGN` with source leaf
zero, selecting the complete returned root, then emits `SDROP` for the
temporary.

The destination root remains live throughout argument evaluation, CALL, capture
cleanup, and `SSUBASSIGN`. Only the selected child range is overwritten. The
destination owner slot, owner order, generation, and extent stay unchanged;
neighboring bytes in the parent remain at their current values. The anonymous
result owner is released after its payload has been copied into the child.

Arguments can mutate the destination root before the normal assignment. Those
changes remain in effect outside the selected child range. The compiler and VM
do not roll back argument effects, external effects, or earlier statements when
the later child assignment succeeds or fails.

## Limits and compatibility

`SSUBASSIGN` already performs its complete owner and range validation before a
single staged commit. This slice reuses that verifier, VM dispatch, and existing
131,072-Fuel charge. It adds no opcode, VM rule, Fuel price, profile string, or
version field.

Each syntactic call-result assignment consumes one static record site from the
existing 16-site catalog. A loop reuses that site; recursive frames retain
frame-local owner tokens for it. The anonymous result needs its normal record
extent. For example, a four-byte returned record assigned into a four-byte child
of an eight-byte parent requires twelve payload bytes before captures and callee
formal copies are considered. The focused eight-versus-seven boundary uses a
four-byte parent `struct R { P p; }` and a four-byte returned `P`; together
they require eight bytes.

Existing limits remain unchanged: sixteen static record sites and shared
owners, a 65,536-byte payload arena, 128 registers, 256 instructions, 32 VM
frames, eight call arguments, and 32 call sites.

## Verification

The focused fixture has six native `@test` groups. Together they exercise
twelve successful programs and twelve negative programs. The negatives comprise
eleven type rejections and one syntax rejection for the trailing
`make().field` form.

The groups cover deep child paths, scalar neighbors before and after the target,
all six scalar kinds at their extrema, argument snapshots, mutations of the
destination during argument evaluation, early returns, `?`, outer
`break`/`continue`, inner-loop capture preservation, repeated assignment, and
rejected destination types.

One group compares `bundle.pair = make();` with the explicit scoped form
`{ let Pair temporary = make(); bundle.pair = temporary; }`. Both programs
must have the same instruction stream and record-site count. The test also
observes `SSUBASSIGN` followed by `SDROP`, reuses the result site across a
runtime loop, and exercises the eight-versus-seven payload boundary for
`struct R { P p; }` plus a returned `P`.

The verifier corruption checks independently reject a mutated stream that
removes the `SDROP` and a stream whose `SSUBASSIGN` target leaf is invalid.

Run the focused harness in separate phase and profile invocations:

```sh
python -B tools/verify-m2-struct-child-call-assignment.py --phase core --profile development
python -B tools/verify-m2-struct-child-call-assignment.py --phase regressions --profile development
python -B tools/verify-m2-struct-child-call-assignment.py --phase core --profile release
python -B tools/verify-m2-struct-child-call-assignment.py --phase regressions --profile release
```

`core` selects six new `struct_child_call_assignment` groups. `regressions`
selects twenty groups: six root `struct_call_assignment`, five
`struct_subassign_source`, six `struct_return_paths`, and three
`struct_subassign_owners`. Each profile therefore covers 26 native groups.

The regression phase also builds the CLI and runs 575 cases per profile: 148 new
child-call-assignment, 148 root call-assignment, 131 atomic subassignment, and
148 subrecord return-path cases. The new checker generates 148 cases from twelve
successful programs, twelve negative programs, 48 scalar-boundary programs that
also vary direct and forwarding callees and declaration order, and two repeated
assignment boundary cases for Fuel exhaustion and the static-site compile limit.
It runs each source through both `check` and `run`.

The development core phase passed all six native groups on a full rerun. Its
first attempt passed five and failed one because the fixture expected a type
error for `make().p`, while the compiler reported syntax. The fixture-only
repair changed that expectation and added a syntax rejection helper; no
production code changed. The six-group core was then rerun without reusing the
partial result.

Development then passed all 26 native groups (six core and twenty regressions)
and all 575 CLI cases (148 new child-call-assignment, 148 root call-assignment,
131 atomic subassignment, and 148 subrecord return-path cases). The development
artifact was retained, and 208 input hashes remained unchanged across the
development phases. The new 148-case CLI selection had also passed on the
diagnostic build before the full regression invocation.

Development and release each passed 26 native groups and 575 CLI cases in four
separate phase invocations. All 208 input hashes matched across the phases;
compiler and SDK identities matched, and the retained development and release
executable hashes were confirmed. Development core ran before `63be9e5` with
the implementation files uncommitted; the other three phases ran after it. The
[archived Windows receipt](../evidence/m2-struct-child-call-assignment-windows-20261028.json)
records the provenance, commands, identities, and outcomes. The initial failed
fixture attempt remains diagnostic rather than part of the passing totals.

Earlier receipts remain historical for their original inputs. This focused
selection does not cover full native or CLI suites, M0, Linux, isolation, DLL
embedding, packaging, allocation instrumentation, or performance.
