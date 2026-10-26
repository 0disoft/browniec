# M2 Source Struct Field Writes

- Status: implemented and verified in development and release.
- Scope: entry-only one-level scalar-field assignment through the existing `SWRITE` (44) instruction.
- Predecessor: [bounded source struct values](m2-struct-values.md), the historical read baseline.
- Implementation: `src/struct_value_source.fy`, `src/compiler.fy`, `src/array_source.fy`,
  `src/render.fy`, `src/main.fy`, and the existing private struct IR and VM.
- Evidence: [Windows native and CLI receipt](../evidence/m2-struct-write-windows-20261026.json).

This slice makes a field of a mutable `var` record assignable. Construction,
record ownership, and one-level reads retain the [read baseline](m2-struct-values.md).
The slice remains entry-only and scalar-only. Nested paths, record copies,
whole-record assignment, struct parameters/results, and borrows remain
unimplemented.

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

The destination is `NAME.FIELD = EXPR;`, with exactly one field after `NAME`.
`NAME` must be a visible mutable record binding created in `main`; the record
catalog must be nonempty and contain the selected record. `FIELD` must be a
scalar leaf of that record, and `EXPR` must produce the field's exact scalar
type. Immutable `let` records, unknown fields or types, duplicate or partial
construction, and helper-local construction retain the read baseline's rejection
rules.

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

A switch arm beginning with `NAME.FIELD` is a write statement only when the
lookahead after the field sees `=`. A final `p.x` without `=` remains a scalar
value expression. This keeps an arm's final `p.x` expression distinct from a
preceding `p.x = ...;` statement.

## For headers

Classic `for` headers retain the scalar-only restriction used by arrays. A field
write in either the initializer or the post clause is rejected. Existing field
reads may appear in the condition, and writes in the loop body follow the normal
statement path.

## Runtime and profile

The fixed `SWRITE` charge is 41,281 Fuel. The VM reuses the existing owner
checks and codec; the shared 16-owner table and 65,536-byte payload cap are
unchanged. The write does not reserve a second extent.

Compilation selects `brownie.m2-struct-write/1` when the record catalog is
nonempty and opcode 44 is present. Record programs without a field write keep
`brownie.m2-struct-read/1`; declaration-only programs keep the profile selected by
their existing objects. `--version --json` adds
```json
{"struct_write_profile":"brownie.m2-struct-write/1"}
```
The plain version output also lists the profile.

## Unsupported forms

- Field writes on `let` bindings
- Writes in `for` initializer or post clauses
- Nested field chains and writes below one field
- Record copy initialization and whole-record assignment such as `p = q;`
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
