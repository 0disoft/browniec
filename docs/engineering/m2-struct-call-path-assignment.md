# M2 Returned-Subrecord Assignment Values

- Status: implemented at `297116966cfedd0ed2eed8c93c0ef522da0ed1fd`; verified in development and release.
- Evidence: [Windows receipt](../evidence/m2-struct-call-path-assignment-windows-20261028.json).
- Scope: `p = make().child;` and deep forms such as
  `s.child.right = make().child.right;` for existing mutable records.
- Implementation: [`compiler::record_call_assignment`](../../src/compiler.fy) and [`struct_value_source::assign_call_part`](../../src/struct_value_source.fy).
- Fixture: [returned-subrecord assignment cases](../../tests/m2/struct_call_path_assignment.fy).
- Harness: [focused verifier](../../tools/verify-m2-struct-call-path-assignment.py).
- Predecessors: [root call-result assignment](m2-struct-call-assignment.md) and [child call-result assignment](m2-struct-child-call-assignment.md).
- Commit: `2971169`.

This slice assigns an exact-nominal child selected from a record call result into an existing mutable record endpoint.
The destination can be the root or a child at any supported depth; matching layout alone is insufficient.

```brownie
module main;
struct P { i32 x; i32 y; }
struct R { P child; }
fn R make() { return R { .child = P { .x = 20, .y = 22 } }; }
fn i32 main() { var P p = P { .x = 0, .y = 0 }; p = make().child; return p.x + p.y; } // 42
```

## Accepted form

The shared assignment helper recognises a visible function name followed by `(` after `=`.
The callee must return an actual nominal record, and the destination root must be mutable; a shadowing local rejects.

After CALL, a trailing `.` starts returned-path resolution. Every segment must name a record field.
The endpoints must have the same exact nominal record identity. Only the destination root must be mutable.

A bare whole returned root assigned into a root keeps `SASSIGN`; assigning one into a child keeps `SSUBASSIGN`.
Bare whole-call assignments therefore retain their previous lowering and do not use the helper below.

Parenthesized or general aggregate operands are unsupported. Constructor-field and return call-child paths,
such as `R { .child = make().child }` and `return make().child;`, remain unsupported. Immutable destinations,
wrong nominal types, scalar endpoints, and for-header assignments reject compilation.

## Evaluation and limits

The compiler reserves one unnamed returned root at the callee's actual nominal identity before arguments.
The destination remains live and visible throughout argument evaluation. Existing left-to-right order,
snapshots, capture cleanup, early `return`/`?`/`break`/`continue`, and nonrollback effects apply.

`assign_call_part` parses and validates the path and semicolon, emits `SSUBASSIGN` (47) with destination and
source leaf ordinals, then `SDROP` (45) for the returned root. The atomic overwrite retains the destination
owner and neighboring bytes. No independent source child, scalar staging register, child `SINIT`, or child site is created.

Each call uses one temporary site from the existing record catalog. No opcode, VM, Fuel, profile, or version
field changes. A four-byte destination plus an eight-byte returned parent requires twelve payload bytes; eleven fails.

The native fixture checks CALL/`SSUBASSIGN`/`SDROP` order, a nonzero source leaf ordinal, and verifier rejection
for a missing drop or invalid source ordinal. It covers deep paths, scalar neighbors, argument effects, early
exits, loops, and exact-nominal rejection.

## Focused verification

Each profile passed 16 native groups and 440 CLI cases per development and release profile: four new
assignment groups, six root-assignment regressions, and six child-assignment regressions. The new 144 CLI
cases are 10 success and 10 type-failure programs through `check`/`run` (40); six scalar tags, two extrema,
two destination forms, and two depths (96); 13/14-call boundaries (4); and two malformed delimiters (4).

- At thirteen assignments, the three-site baseline reaches all sixteen sites: `check` accepts and `run`
  exhausts the CLI Fuel allowance. Fourteen reports `compile_limit`.
- The 148-case root and child regressions add 296 cases, for the verified 440 total.

```sh
python -B tools/verify-m2-struct-call-path-assignment.py --profile development
python -B tools/verify-m2-struct-call-path-assignment.py --profile release
```

Earlier root, child,
and declaration receipts are historical for their original inputs. Full suites, M0, Linux, isolation, DLL,
packaging, allocation instrumentation, and performance are outside this slice.

## Archived verification

Development and release each passed 16 native groups and 440 CLI cases.
Both invocations rechecked 241 identical input hashes and matching compiler/SDK
identities; both retained executable hashes matched their CLI receipts. Development
ran from `a291d77` with implementation files uncommitted; release ran after
`2971169`. The selection above is now verified for these archived inputs.
