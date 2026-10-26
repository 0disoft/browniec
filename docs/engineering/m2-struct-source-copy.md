# M2 Source Struct Copy Initialization and Assignment

- Status: implemented and verified stepwise in development and release.
- Scope: entry-only bare-name copy initialization and whole-record assignment for scalar-field record bindings.
- Predecessor: [bounded source struct field writes](m2-struct-write.md).
- Implementation: `src/struct_value_source.fy`, `src/compiler.fy`, `src/array_source.fy`,
  `src/render.fy`, `src/main.fy`, and the existing private struct IR and VM.
- Implementation commit: `f9cf654`.
- Tests: [tests/m2/struct_source_copy.fy](../../tests/m2/struct_source_copy.fy).
- Native harness: `python -B tools/verify-m2-struct-values.py --copy`.
- CLI harness: `tools/check-m2-struct-source-copy.py`.
- Evidence: [Windows stepwise native and CLI receipt](../evidence/m2-struct-source-copy-windows-20261026.json).

This slice connects visible record bindings to the private struct VM's existing
`SCOPY` (42) and `SASSIGN` (46) instructions. It keeps the current entry-only,
scalar-field, caller-backed storage model. An initializer creates an independent
record; assignment overwrites an existing mutable destination without creating
another extent or owner.

## Accepted source

```brownie
module main;
struct P { i32 x; }
fn i32 main() {
    let P p = P { .x = 42 };
    var P q = p;
    q = p;
    return q.x;
}
```

The example returns 42. It uses the existing constructor for `p`, a copy
initializer for `q`, and whole-record assignment back into `q`.

The added forms are:

```text
let|var TYPE DEST = SOURCE;
DEST = SOURCE;
```

`SOURCE` and `DEST` are visible bare record binding names. The source must have
the destination's exact nominal record ID; matching field shapes under different
type names are not compatible. A copy initializer accepts either an immutable
`let` or mutable `var` source. The new destination may be `let` or `var`.
Assignment requires a visible mutable `var` destination; its source may be either
`let` or `var`. Self-assignment such as `p = p;` is accepted. A copy initializer
cannot see the name it is declaring, so `let P p = p;` is rejected.

Initialization in a `for` initializer or post clause remains rejected because
those headers are scalar-only. Record reads may still appear in a loop condition,
and record statements in the body follow normal lexical handling.

## Initializer disambiguation

After the destination name and `=`, the compiler snapshot-checks the next token.
If a nominal name is followed by `{`, it parses the existing constructor form.
Otherwise it parses a bare-name copy. This separates the two forms without
requiring a lookahead over the complete expression and permits a local to share
its type's name:

```brownie
let P P = P { .x = 42 };
let P q = P;
```

The destination named `P` in the first declaration remains a local; the `P`
after `=` is the nominal constructor name. In the second declaration, the `P`
after `=` is the visible source binding.

## Lowering and lifetimes

Copy initialization resolves the visible source binding and checks its exact
nominal ID before reserving a new record site. It emits one `SCOPY`, then publishes
the destination name after parsing/emitting its complete initializer. Runtime
instruction failure aborts the invocation. The copy has an independent owner
token and payload extent. Later mutation or release of the source does not alias
or invalidate the copy.

Whole-record assignment resolves the mutable destination and then a visible
source of the same nominal type. It emits one `SASSIGN` against the existing
destination extent. The destination keeps its binding site, owner identity, and
generation; the source keeps its own extent and owner. Self-assignment therefore
reuses one extent and does not allocate another record.

Both forms participate in the same reverse lexical cleanup as record fields.
Blocks, loop transfers, switch arms, and returns drop only record bindings whose
scopes end on that path. A loop transfer that remains inside a record's scope
keeps the record live.

## Bounds, ownership, and Fuel

The existing aggregate limits remain unchanged:

- selected roots are at most 128 planned bytes with 1..16 fields;
- at most 16 static record sites and 16 entry record bindings are available;
- records share the existing 16-entry owner table with arrays;
- the single payload arena remains capped at 65,536 bytes;
- full catalogs are replanned at struct boundaries and existing traversal bounds remain in force.

A copy initializer needs one free static record site, one runtime owner slot, and
enough payload capacity for another extent. The source stays live, so the copy's
peak quota includes both records. An assignment needs no new site, owner, or
payload extent and remains available when the shared owner table is full. It
still requires both records to be live at runtime.

The existing VM charges are used: `SCOPY` costs 42,049 Fuel and `SASSIGN` costs
60,545 Fuel. Their owner, generation, nominal-ID, catalog, codec, bounds, and
canonical-bool checks are unchanged. Aggregate arena preparation and the existing
65,536-byte capacity limit still apply, so CLI examples need an explicit Fuel
allowance such as `--fuel 1000000`.

## Profile and version

For a program with a nonempty record binding catalog (`p.records.count != 0`),
profile selection checks emitted object operations in this order:

1. Any `SCOPY` (42) or `SASSIGN` (46) selects `brownie.m2-struct-copy/1`.
2. Otherwise, any `SWRITE` (44) selects `brownie.m2-struct-write/1`.
3. Otherwise, record bindings select `brownie.m2-struct-read/1`.

Type declarations alone do not select or upgrade to a record profile; programs
without record bindings retain the profile selected by their existing objects.
`--version --json` adds the supported profile:

```json
{"struct_copy_profile":"brownie.m2-struct-copy/1"}
```

The plain `--version` output also lists `brownie.m2-struct-copy/1`.

## Unsupported forms

- Records or record copy/assignment statements in helper functions
- Copy initialization or assignment in a `for` initializer or post clause
- Assignment from a constructor, such as `p = P { .x = 42 };`
- General aggregate expressions, calls, parentheses, or field chains in either side
- Records whose values require nested construction or nested field chains
- Struct parameters, results, and borrows
- Copying from an array, scalar, or a different nominal record type
- Assigning to an immutable `let` record

The declaration catalog still accepts named-field struct declarations within its
existing limits; those declarations do not make nested record values copyable in
this slice.

## Testing

Development and release each passed 39 native groups: 6 source-copy, 5
struct-write, 5 struct-values, 8 struct-VM, 9 struct-IR, and 6 switch-arm groups.
Each profile passed 2,582 CLI cases: 110 copy, 120 write, 144 values, 124
declarations, 115 array-literal assignment, and 1,969 scalar cases.

To rerun the complete selection:

```powershell
python -B tools/verify-m2-struct-values.py --copy
```

The [receipt](../evidence/m2-struct-source-copy-windows-20261026.json) records
stepwise completion. The initial aggregate run completed development native/build
and stopped at a CLI fixture profile mismatch. Only Python fixtures changed
afterward: profile expectation, CLI Fuel cap, and obsolete copy-rejection cases.
All development CLI suites then passed individually. Unchanged native inputs and
the build were reused, with native input hashes and provenance recorded. Release
ran the complete native selection, build and six CLI suites. The complete
aggregate harness was not rerun.

Cases cover scalar extrema, independence after mutation and source-scope exit,
self-assignment, exact nominal identity, immutable rejection, lexical cleanup,
for-header rejection, constructor/name disambiguation, full 128-byte records,
static-site exhaustion and shared owner pressure. Assignment succeeds at sixteen
live owners; another copy fails with `array_limit`.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance were not run.

The earlier [read-baseline receipt](../evidence/m2-struct-values-windows-20261026.json)
and [field-write receipt](../evidence/m2-struct-write-windows-20261026.json)
remain historical evidence for their recorded inputs.
