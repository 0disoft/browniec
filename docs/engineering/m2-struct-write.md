# M2 Source Struct Field Writes

- Status: historical field-write baseline; focused checks passed in development and release before source record copies and nested source records were added.
- Scope: entry-only one-level scalar-field assignment through the existing `SWRITE` (44) instruction.
- Predecessor: [bounded source struct values](m2-struct-values.md), the historical read baseline.
- Successor: [source struct copy initialization and assignment](m2-struct-source-copy.md);
  later, [source nested structs](m2-struct-source-nested.md).
- Implementation: `src/struct_value_source.fy`, `src/compiler.fy`, `src/array_source.fy`,
  `src/render.fy`, `src/main.fy`, and the existing private struct IR and VM.
- Evidence: [Windows native and CLI receipt](../evidence/m2-struct-write-windows-20261026.json).

This slice makes a field of a mutable `var` record assignable. Construction,
record ownership, and one-level reads retain the [read baseline](m2-struct-values.md).
The slice remains entry-only and scalar-only. The later [source-copy
successor](m2-struct-source-copy.md) lowers bare-name copies and whole-record
assignment through the same private struct VM. The [nested
successor](m2-struct-source-nested.md) extends the endpoint to multi-segment
scalar paths and adds inline child constructors.

## Accepted source

```brownie
module main;
struct P { i32 x; }
fn i32 main() {
    var P p = P { .x = 0 };
    p.x = 42;
    return p.x;
}
```

Run the example with `browniec run point.brc --fuel 1000000`. The CLI default
Fuel of 256 does not cover aggregate arena preparation and struct operations.

The destination is `NAME.FIELD = EXPR;`, with exactly one field after `NAME` in
this historical slice. `NAME` must be a visible mutable record binding created in
`main`; the record catalog must be nonempty and contain the selected record.
`FIELD` must be a scalar leaf of that record, and `EXPR` must produce the field's
exact scalar type. Immutable `let` records, unknown fields or types, duplicate or
partial construction, and helper-local construction retain the read baseline's
rejection rules. The nested successor accepts `NAME.FIELD.FIELD = EXPR;` when
every intermediate field is a record and the endpoint is a scalar leaf.

## Evaluation and lowering

The compiler resolves the target binding, nominal record ID, and field leaf
before parsing the RHS. A target error therefore occurs before any RHS effect.
The RHS is one normal typed scalar expression for the field's exact type and is
evaluated once. The compiler emits `SWRITE` only after the expression and the
statement terminator have been consumed; the runtime write follows successful
expression completion. An RHS error or control transfer that leaves the statement skips the pending
outer write. Earlier RHS changes are subject to normal owner cleanup, and runtime
failures still abort the invocation. No automatic replay or rollback is added.

The RHS may read the same record, mutate it through nested statements such as
switch arms, call scalar functions, and transfer control. It does not gain
record-valued parameters or expression assignment.

`SWRITE` mutates the existing record extent in place. It allocates no new record,
copy, owner, or payload extent. Owner generations, liveness, mutability, catalog
layout, codec, and canonical bool checks remain the struct VM's existing checks.

## Statement classification

A switch arm beginning with a dotted chain is a write statement only when the
lookahead after the complete chain sees `=`. A final `p.x` or `p.i.x` without
`=` remains a scalar value expression. This keeps an arm's final value distinct
from a preceding write statement.

## For headers

Classic `for` headers retain the scalar-only restriction used by arrays. A field
write, including a nested path, in either the initializer or the post clause is
rejected. Existing scalar field reads may appear in the condition, and writes in
the loop body follow the normal statement path.

## Runtime and profile

The fixed `SWRITE` charge is 41,281 Fuel. The VM reuses the existing owner
checks and codec; the shared 16-owner table and 65,536-byte payload cap are
unchanged. The write does not reserve a second extent.

Compilation selects `brownie.m2-struct-write/1` when the record binding catalog
is nonempty and opcode 44 is present. A bound record with a nested field selects
`brownie.m2-struct-nested/1` before this check. Record-binding programs without a
field write keep `brownie.m2-struct-read/1`; declaration-only programs keep the
profile selected by their existing objects. `--version --json` adds
```json
{"struct_write_profile":"brownie.m2-struct-write/1"}
```
The plain version output also lists the profile.

## Unsupported forms

- Field writes on `let` bindings
- Writes in `for` initializer or post clauses
- Subrecord field writes whose endpoint is a record rather than a scalar leaf;
  multi-segment scalar writes are handled by the [nested successor](m2-struct-source-nested.md)
- Struct parameters, results, and borrows
- Construction outside `main`, including helper-local construction
- General constructor expressions outside record declaration initializers

## Validation

The existing value harness is extended with `--write`; no separate harness is
added:

```powershell
python -B tools/verify-m2-struct-values.py --write
```

Each profile passed 24 native groups: 5 struct-write, 5 struct-values,
8 struct VM, and 6 switch-arm-statement groups. Each profile also passed 2,472 CLI
cases: 120 write, 144 constructor/read, 124 declaration, 115 array-literal, and
1,969 scalar cases.

Those results belong to the earlier field-write inputs. The subsequent source-copy
and nested-source compiler changes make this receipt historical for modified
inputs. The [source-copy contract](m2-struct-source-copy.md) records its stepwise
development/release checks; the [nested contract](m2-struct-source-nested.md)
records the complete development/release pass on corrected inputs.

Nested field-write RHS depth 10 succeeds; depth 11 reports `compile_limit`.

The basic example returns 42 after 128,782 Fuel with the private 4-byte arena, or
194,314 Fuel with the CLI's 65,536-byte capacity. One Fuel unit less fails.

The [receipt](../evidence/m2-struct-write-windows-20261026.json) records matching
source/tool hashes and both native CLI artifact identities. Native owner/table
quotas are unchanged. Full native suites, full array CLI matrices, Linux,
isolation, DLL, packaging, and performance were not run.

The [read-baseline receipt](../evidence/m2-struct-values-windows-20261026.json)
remains historical evidence for construction and reads; it does not cover
`SWRITE`.
