# M2 Declaration-Only Source Structs

- Status: implemented declaration parsing and immutable layout attachment; development and release checks passed stepwise.
- Scope: top-level source struct declarations, field-type resolution, layout planning, and function/type name collision checks.
- Implementation: [src/struct_source.fy](../../src/struct_source.fy), [src/struct_layout.fy](../../src/struct_layout.fy), [src/compiler.fy](../../src/compiler.fy), and [src/functions.fy](../../src/functions.fy).
- Tests: [tests/m2/struct_source.fy](../../tests/m2/struct_source.fy).
- Harness: [tools/verify-m2-struct-source.py](../../tools/verify-m2-struct-source.py) and [tools/check-m2-struct-source.py](../../tools/check-m2-struct-source.py).
- Evidence: [Windows native and CLI receipt](../evidence/m2-struct-source-windows-20261026.json).

This slice admits struct type declarations and their immutable layout catalog.
It does not admit struct values, bindings, field operations, or source-level
record calls. A declaration-only program therefore keeps the existing scalar
source behavior while making validated record metadata available to later
lowering work.

## Accepted source

Struct declarations are top-level declarations and may appear before, between,
or after function declarations. The file must begin with `module main;`.

```brownie
module main;
struct Point { i32 x; i32 y; }
fn i32 main(){return 42;}
```

```text
FIELD ::= SCALAR NAME ';' | TYPE_NAME NAME ';'
SCALAR ::= bool | u8 | i32 | i64 | u32 | usize
```

Each struct has one through sixteen fields and no trailing semicolon after the
closing brace. A field either stores one of the six admitted scalar types or
stores another declared struct by value. Named fields may refer forward, so a
declaration order that mentions `Inner` before `Inner` is declared is valid.
The full declaration graph is resolved before layouts are attached.

Only bare scalar or named-type fields are admitted. Wrapper fields such as
`Option<i32>` or `Result<i32, bool>`, array fields, borrowed fields, pointers,
and other aggregate syntax are rejected. Struct declarations and fields use the
existing reserved-word set. Duplicate struct names, duplicate field names,
unknown type names, dependency cycles, and collisions between a struct name and
a function name are rejected. Function and struct names share one top-level
namespace; local variable names remain independent.

## Layout metadata

`struct_source::Table` stores a `struct_layout::Catalog` plus zero-based source
byte spans for each struct name and an offset for each body. Identifiers are compared through the
immutable source slices rather than copied into a separate name table. The
catalog stores each field as either a scalar tag or a nominal record ID.

`struct_layout::plan` resolves the acyclic graph and computes declaration-order
offsets with natural alignment, nested alignment propagation, and tail padding.
Field order and padding are part of the compiled layout; source field names are
compile-time metadata. A planner error is returned before any layout is attached
to a program.

| Resource | Bound |
| --- | ---: |
| UTF-8 source | 4,096 bytes |
| Lexer tokens | 1,024 |
| Struct declarations per program | 32 |
| Fields per struct | 1 through 16 |
| Struct nesting depth | 16 |

Overflow while computing offsets, byte sizes, or encoded metadata is rejected as
a compile limit. The declaration catalog itself is not capped at 128 bytes per
record. The existing private runtime contract's 128-byte cap applies only when a
record is selected for materialization, which this slice does not implement.

## Compiler and runtime behavior

The compiler prepares array and record metadata through one aggregate-preparation
step before recursive function-body lowering, releasing the source-name/catalog
scratch before expression compilation. It checks every function name against the
struct catalog and then attaches the immutable layouts to `ir::Program`.

Declaration-only structs set `p.records.layouts`; they leave
`p.records.count == 0`. No `SINIT`, `SCOPY`, `SREAD`, `SWRITE`, `SDROP`, or
`SASSIGN` opcode is emitted and no record owner or payload extent is created. The
runtime's aggregate-preparation gate uses the binding count, so this slice adds
no payload allocation or Fuel charge. Layout validation remains compile and
verification work over immutable metadata.

The following source forms remain rejected because their lowering is not part of
this slice:

```brownie
Point { .x = 1, .y = 2 }  // construction
let Point p = value;      // record binding
p.x                       // field read
p.x = 3;                  // field write
fn i32 use(Point p)       // record parameter
fn Point make()           // record result
ref Point p               // record borrow
```

Record copies, assignment, drops, parameters, results, and borrows also remain
unimplemented at source level. The next slice is struct construction and field
lowering onto the existing private struct IR and VM.

## Verification

Run:

```powershell
python -B tools/verify-m2-struct-source.py
```

Both profile selections passed 23 native groups:
five new `struct_source` groups, four `functions` groups covering name
collisions, eight struct-layout groups, and six array-layout regressions. The
black-box CLI leg covers 124 new source struct cases per profile, including the
permanent depth-10 success and depth-11 compile-limit pair with a struct
declaration, plus the existing 115 array-literal-assignment and 1,969 scalar
cases, for 2,208 cases per profile. The harness also builds both profiles and
binds the native CLI artifact hashes to the recorded outcomes.

Both profiles passed all 23 native groups and all 2,208 CLI cases. Aggregate
preparation combines existing array-parameter/result setup and struct catalog
preparation before body lowering; the permanent depth cases pin the composed
array-expression stack boundary. The initial aggregate invocation completed
all development checks and release native checks/build, then referenced an
incorrect release artifact path. Both profiles emit `build/browniec.exe`.
Release CLI checks then completed directly against that release artifact.
The corrected aggregate harness passed a Python AST syntax check and was not
rerun; the receipt records the stepwise execution and both harness identities.

Full native suites, full array CLI matrices, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance measurements are outside this
selection.
