# M2 Source Nested Struct Constructors, Paths, and Root Copies

- Status: implemented; its recorded development/release result is historical for
  the current child-binding compiler inputs. The child-binding successor is
  implemented and its combined run passed in development and release.
- Scope: entry-owned nested record constructors, multi-segment scalar read/write
  paths, and whole-root copy initialization/assignment.
- Predecessor: [source struct copy initialization and assignment](m2-struct-source-copy.md).
- Implementation: `src/struct_value_source.fy`, `src/compiler.fy`,
  `src/array_source.fy`, `src/render.fy`, and `src/main.fy`.
- Implementation commits: `576d062` and `716c14b`.
- Tests: [tests/m2/struct_source_nested.fy](../../tests/m2/struct_source_nested.fy).
- Native harness: `python -B tools/verify-m2-struct-values.py --nested`.
- CLI harness: `tools/check-m2-struct-source-nested.py`.
- Historical evidence:
  [m2-struct-source-nested-windows-20261027.json](../evidence/m2-struct-source-nested-windows-20261027.json).
- Successor: [whole visible child bindings](m2-struct-child.md).

This slice extends the entry-only record adapter through the existing private
struct instructions. It adds no opcode, VM owner pool, arena, or source access to
subrecord values. A nested root is one record binding: one static site, one owner
token, and one payload extent. Its child constructors are syntax inside the root
initializer and allocate none of their own.

Whole visible bindings are also admitted as child values by the
[child-binding successor](m2-struct-child.md). That form copies scalar leaves
into the parent's staging and does not allocate a separate child owner or extent.

## Accepted source

```brownie
module main;
struct I { i32 x; }
struct R { I i; }
fn i32 main() {
    var R p = R { .i = I { .x = 42 } };
    return p.i.x;
}
```

The example returns 42. Run it with an explicit aggregate Fuel allowance:

```powershell
browniec run nested.brc --fuel 1000000
```

The default Fuel of 256 does not cover arena preparation and struct operations.

The admitted constructor form remains a declaration initializer:

```text
let|var TYPE NAME = TYPE { .FIELD = SCALAR_EXPR | CHILD_TYPE { ... } | CHILD_BINDING, ... [,] };
```

Each field appears exactly once in declaration order. A comma separates members,
and an optional comma may precede each closing `}`. A child field may be an
inline constructor of the declared type or a whole visible binding of that exact
nominal type. The inline-constructor rules are owned here; binding capture is
owned by the [child-binding successor](m2-struct-child.md). The fields of every
inline constructor are checked the same way. A root may mix scalar and nested
fields in any declaration order.

Scalar endpoints use the existing read and write forms, now with more segments:

```text
NAME(.FIELD)+                  // read a scalar leaf
NAME(.FIELD)*.FIELD = EXPR;    // write a scalar leaf
```

A path resolves through named fields only and must end at a scalar leaf. Its
length is at most 16 segments. The root binding must be visible; a write needs a
mutable `var` root. Reads may appear in ordinary scalar expressions and loop
conditions. Writes follow normal statement handling, except that both `for`
header clauses remain scalar-only.

## Initialization

The constructor cursor is an iterative depth-first walk. When it returns a scalar
leaf, the compiler takes that leaf's scalar tag directly from the cursor and
allocates one staging slot immediately before parsing the expression. It does not
preallocate the whole slot set or return a tag array. Each exact-typed expression
is parsed into its allocated slot. For an inline child field, the compiler checks
the nominal name and `{`, then descends without allocating a binding, site, owner,
or extent. Closing a child resumes the enclosing record. Verifier and VM rules are
unchanged.

Leaves are still parsed and staged left to right in depth-first source order.
After the complete root initializer and its terminator, the compiler emits
consecutive `LOAD`s for the staging slots and one `SINIT` for the root. The
compiler adds the root name to the lexical scope only after emitting that
complete initializer.
This is compile-time visibility; a runtime `SINIT` failure aborts the invocation.
An early `return`, `continue`, `break`, or other transfer inside a leaf expression
or child constructor therefore sees no pending root binding to drop. Cleanup
still drops every owner that was visible before the declaration and whose scope
the transfer exits.

The source record tree must have at most 16 scalar leaves in total. This is a
source staging bound checked by a scalar leaf-count preflight; the private VM
continues to accept up to 128 leaves for programs built directly. A selected root
is also limited to 128 planned bytes and 16 fields per record, within a catalog
of at most 32 definitions. The 17th leaf,
17th nested level, oversized selected root, or exhausted site reports
`compile_limit`. The record tree walk is iterative and bounded at 4,096 visits;
native recursion is not used for type-tree traversal. Scalar expression depth
limits are unchanged, including the existing composed depth-7 success and
depth-8 `compile_limit` boundary.

## Paths and leaf ordinals

`SREAD` and `SWRITE` address a flattened scalar leaf ordinal, not a source field
index or byte offset. The path compiler starts at the root and counts the leaves
of every preceding field before descending:

```brownie
struct I { bool a; u8 b; i64 c; }
struct R { u8 head; I inner; i32 tail; }
```

For `R`, `head` is ordinal 0, `inner.a..inner.c` are 1..3, and `tail` is 4. Thus
`p.inner.b` resolves to ordinal 2. A nested sibling's leaves are included even
when the selected path starts in a later field. A write uses the exact scalar tag
at the endpoint, so `p.inner.b = true` is rejected as a type error.

The binding and complete path resolve before a write RHS. The RHS is one normal
typed scalar expression, evaluated once; `SWRITE` follows the expression and the
statement terminator. Reads and writes reuse the existing root extent and create
no copy, owner, site, or payload allocation. A non-scalar endpoint, unknown field,
extra segment after a scalar, or immutable destination is rejected.

A switch arm whose value begins with a dotted chain is treated as a write only
when `=` follows the complete chain. The lookahead accepts up to 16 segments;
longer chains report `compile_limit`. A final `p.inner.x` without `=` remains a
scalar value expression.

## Copies and lifetimes

Whole-root copies now accept nested record types through the existing
`SCOPY`/`SASSIGN` path. `let|var R q=p;` requires an exact nominal `R` source and
creates an independent owner and extent. `q=p;` requires a visible mutable `q`,
reuses its existing extent, and accepts self-assignment. Immutable sources are
accepted. Nested children are copied as part of the root; they never receive
separate owners.

Mixed lexical exits, switch arms, loop transfers, and returns release arrays and
records in reverse order. Loop transfers drop only the suffix whose scopes they
exit. A whole-root copy keeps the source live and pays the peak quota for both
roots; assignment adds no owner or extent.

## Profile and version

Profile selection considers the layouts of bound records. If any selected record
has a nested field, the program selects `brownie.m2-struct-nested/1` before the
copy, write, and read checks:

```json
{"struct_nested_profile":"brownie.m2-struct-nested/1"}
```

A flat record binding keeps the existing order: `SCOPY`/`SASSIGN` select
`brownie.m2-struct-copy/1`, otherwise `SWRITE` selects
`brownie.m2-struct-write/1`, otherwise record bindings select
`brownie.m2-struct-read/1`. Nested declarations that never produce a record
binding do not promote a flat, array, or scalar program. The plain `--version`
output also lists the nested profile.

## Bounds, ownership, and Fuel

- Selected roots: at most 128 planned bytes, with 1..16 fields per record.
- Source staging: at most 16 scalar leaves across the complete root tree.
- Record nesting depth: 16 levels; path length: 16 segments.
- Catalog: at most 32 definitions, 16 fields each.
- Record sites: 16 per entry function; children consume none.
- Shared owner table: 16 entries, shared with arrays; 65,536-byte payload arena.
- Scalar registers and instructions: the existing 128-register and 256-instruction limits.

No new VM charges are added. `SINIT` (46,145), `SREAD`/`SWRITE` (41,281),
`SCOPY` (42,049), `SASSIGN` (60,545), and `SDROP` (65) retain their existing
prepaid prices and checks. The VM's leaf, depth, traversal, owner, codec, and Fuel
bounds remain those of the [private struct VM](m2-struct-vm.md).

## Unsupported forms

- Subrecord values or movement: `let I i=p.i`, `p.i=q.i`, or assignment to a
  non-scalar path endpoint.
- Subrecord paths, calls, parentheses, and aggregate expressions as child
  values. Whole visible bindings such as `R { .i = someI }` are covered by the
  [child-binding successor](m2-struct-child.md).
- Constructor RHS assignment such as `p = R { .i = I { .x = 42 } };`.
- Record statements in helpers or in `for` initializer/post clauses.
- Struct parameters, results, borrows, arrays, and wrapper-typed fields.
- Dynamic or computed field paths, general aggregate expressions, and slices.
- More than 16 total source scalar leaves, even though the private VM supports 128.

These are bounded-slice limits, not a claim of full source struct conformance.

## Verification status

The nested slice's receipt records a complete run on its corrected inputs:

```powershell
python -B tools/verify-m2-struct-values.py --nested
```

Each profile passed 36 native groups: 6 nested, 6 source-copy, 5 write, 5 values,
8 struct VM and 6 switch-arm groups. Each passed 2,710 CLI cases: 128 nested,
110 copy, 120 write, 144 values, 124 declarations, 115 array-literal assignment
and 1,969 scalar cases. The
[historical receipt](../evidence/m2-struct-source-nested-windows-20261027.json)
records 91 source/tool hashes, compiler and artifact identities, commands and
outcomes. The child-binding source change makes those input hashes historical;
use the [child contract](m2-struct-child.md) for the current combined run and do
not present the nested receipt as validation of the successor.

The first release selection failed 18 of 36 groups at `576d062`: staging/load
register types read as zero and the verifier rejected record programs. `716c14b`
creates each staging slot from its directly resolved scalar tag instead of a
returned tag array. The corrected nested aggregate reran both profiles without
reusing old results. Verifier and VM rules remain unchanged.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance were not run. Full-profile
conformance remains incomplete.
