# M2 Source Child Binding Initializers

- Status: implemented and verified in development and release.
- Scope: whole visible record bindings used as child values in entry-owned
  record construction.
- Predecessor: [source nested struct constructors](m2-struct-source-nested.md).
- Implementation commit: `ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.
- Tests: [tests/m2/struct_child_source.fy](../../tests/m2/struct_child_source.fy).
- Native harness: `python -B tools/verify-m2-struct-values.py --child`.
- CLI harness: `tools/check-m2-struct-child.py`.
- Evidence:
  [m2-struct-child-windows-20261027.json](../evidence/m2-struct-child-windows-20261027.json).

This slice lets a record constructor copy an existing whole record binding into
a visible child field when both types have the same nominal identity. It extends
the nested constructor walk without changing opcodes, the private verifier, the
VM's owner model, or the payload arena.

## Accepted source

```brownie
module main;
struct I { i32 x; }
struct R { I i; }
fn i32 main() {
    let I i = I { .x = 42 };
    let R p = R { .i = i };
    return p.i.x;
}
```

The example returns 42. Use an explicit aggregate Fuel allowance:

```powershell
browniec run child-binding.brc --fuel 1000000
```

A child field may contain either an inline constructor of its declared type or
the bare name of a visible binding of that exact type:

```text
CHILD := TYPE { ... } | NAME
```

The parent and source binding may each be immutable or mutable. A mutable source
is accepted because construction takes a snapshot; the source binding is not
consumed. The source value may itself contain nested records, in which case all
of its scalar leaves are captured at the child field's position.

The source must be a whole visible binding. A subrecord path such as
`R { .i = other.i }`, a call, a parenthesized expression, or another aggregate
expression is not a child initializer. Declaration extraction is handled by the [successor](m2-struct-extract.md);
subrecord assignment is handled by its [successor](m2-struct-subassign.md).

## Lowering and order

When the constructor walk reaches a child binding, it traverses the source
record's scalar leaves in depth-first declaration order. For each leaf it emits
one `SREAD` from the source owner and one `STORE` into the parent's staging slot.
The capture is emitted before compiling any later sibling field expression, so a
later mutation of the original binding cannot change the parent snapshot.

After the complete parent constructor has been emitted and its `SINIT` succeeds,
the new parent name enters the visible scope. The source binding remains live and
owns its original site, owner token, and payload extent. Child capture creates no
`SCOPY`, temporary owner, record site, or payload extent. The new parent root is
the only new owner and extent.

An early exit in a later sibling expression sees only owners that were already
visible. Loop and return cleanup therefore drops the source through its normal
scope rule; it never treats the pending parent or the captured child as an
independent owner.

## Limits and Fuel

The source capture reuses the existing 16-record-site and 16-owner catalogs, the
16-scalar-leaf source staging bound, 16-level record and path bounds, 128-byte
selected-root cap, 65,536-byte payload arena, 128 registers, and 256 instructions.
The private VM's 128-leaf limit and verifier rules are unchanged. No new profile
or synthetic IR flag is introduced.

Each captured scalar leaf pays the existing `SREAD` charge of 41,281 Fuel, plus
the ordinary `STORE` and subsequent `LOAD` work. The parent root still performs
one existing `SINIT` (46,145 Fuel). For the i32 example above, a direct private
program with an eight-byte payload arena returns 42 at 174,997 Fuel and fails with
`fuel` at 174,996. With the CLI's 65,536-byte capacity, the exact boundary is
240,525 Fuel: 240,524 fails with `fuel`. The two roots need eight payload bytes;
a seven-byte arena fails with `array_limit`.

## Profile and discovery

Programs using child binding initializers continue to select
`brownie.m2-struct-nested/1`. Version JSON adds
`"struct_child_binding_initializers": true` so a caller can discover that whole
binding initializers are available for child fields:

```json
{
  "struct_nested_profile": "brownie.m2-struct-nested/1",
  "struct_child_binding_initializers": true
}
```

## Unsupported forms

Declaration extraction and subrecord assignment are covered by their
[extraction](m2-struct-extract.md) and [assignment](m2-struct-subassign.md) successors.

- Source subrecord paths, calls, parentheses, and aggregate expressions as child
  initializers.
- Constructor RHS assignment such as `p = R { .i = i };`.
- Record statements in helpers or in `for` initializer/post clauses.
- Struct parameters, results, borrows, arrays, or wrapper-typed fields.
- Dynamic or computed field paths, general aggregate expressions, and slices.
- More than 16 scalar leaves in the complete parent constructor tree.

## Verification status

The complete combined invocation passed in development and release:

```powershell
python -B tools/verify-m2-struct-values.py --child
```

The new CLI harness passed all 88 child cases in each profile. Those
cases cover immutable and mutable sources and targets, all six scalar types at
their extremes, snapshots taken before a later sibling mutation, nested child
bindings, whole-root copies and cleanup, the full owner table, and static depth
checks at 2, 8, and 16. The depth-16 program was check-only because the CLI's
1,000,000 Fuel cap is below its runtime cost. Source-tree leaf bounds were checked
at 16 (admitted) and 17 (`compile_limit`).

Each profile passed on the final source: 21 native
groups (5 child, 6 nested, 5 values, 5 write) and 2,798 CLI cases (88 child, 128
nested, 110 copy, 120 write, 144 values, 124 declarations, 115 array-literal
assignment, and 1,969 scalar). The
[receipt](../evidence/m2-struct-child-windows-20261027.json) records 90 input
hashes, compiler and CLI artifact hashes, commands, and outcomes. All input hashes
and the compiler hash were rechecked before archival, and the final release
binary matches its recorded CLI hash. Both profiles select the same 21 native
identities. No previous test results were reused for this invocation. The earlier
nested receipt is historical for the changed compiler, fixture, and tool inputs.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance were not run. Full-profile conformance
remains incomplete.

The source and fixture changes for [subrecord declaration extraction](m2-struct-extract.md)
make this receipt historical for the successor inputs.
