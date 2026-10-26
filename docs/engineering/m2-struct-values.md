# M2 Bounded Source Struct Values

- Status: historical read baseline; construction and one-level reads were verified in development/release before field writes, record copies, and nested source records were added.
- Scope: entry-only scalar-field record construction and one-level scalar field reads.
- Implementation: `src/struct_value_source.fy`, `src/compiler.fy`, `src/array_source.fy`,
  `src/struct_source.fy`, and the existing private struct IR and VM.
- Evidence: [Windows native and CLI receipt](../evidence/m2-struct-values-windows-20261026.json).
- Successor: [bounded source struct field writes](m2-struct-write.md); later,
  [source struct copy initialization and assignment](m2-struct-source-copy.md)
  and [source nested structs](m2-struct-source-nested.md).

This historical slice admits initialized scalar-field records in the entry
function. It is a bounded source adapter over the existing `SINIT` and `SREAD`
path. It does not claim full source struct support or full-profile conformance.
The [write successor](m2-struct-write.md) adds mutable one-level field
assignment and passed focused native and CLI checks in development and release.
The later [source-copy successor](m2-struct-source-copy.md) adds bare-name copies
and whole-record assignment, verified stepwise in development and release. The
[nested successor](m2-struct-source-nested.md) adds inline child constructors,
multi-segment scalar paths, and whole-root copies for nested records.

## Accepted source

```brownie
module main;
struct Point { i32 x; i32 y; }
fn i32 main() {
    let Point p = Point { .x = 20, .y = 22 };
    return p.x + p.y;
}
```

`let` and `var` are accepted. The field list must contain every field of the
selected scalar-only record exactly once, in declaration order. A comma may
follow the final field.

```text
let|var TYPE NAME = TYPE { .FIELD = EXPR, ... [,] };
```

Each `EXPR` is a normal typed scalar expression for that field. Field
expressions evaluate from left to right. Each result is stored in its typed
staging slot before the next field expression is evaluated. All staging slots
are then loaded into consecutive scalar registers for `SINIT`. The compiler
declares the new name only after emitting the complete initializer and `SINIT`;
runtime initialization failure aborts the invocation.

Construction is a declaration statement in the entry function's admitted
lexical scopes. It is not a general expression and is unavailable in parameters,
results, borrows, or `for` headers. `NAME.FIELD` reads one scalar leaf through
`SREAD`; the record is not copied or materialized as a scalar binding.

Run the example with `browniec run point.brc --fuel 1000000`. The CLI default
Fuel of 256 does not cover aggregate arena preparation and struct operations.

`var` is accepted and marks the binding mutable. This read baseline did not lower
field writes; the [write successor](m2-struct-write.md) now does.

## Lowering and metadata

`struct_value_source` resolves a type or field name by lexing the bounded
source to locate its declaration, then scanning its field names on demand. It does not add persistent source-name arrays to the
recursive lowering stack. For this flat baseline, scalar fields are flattened in
declaration order, so their source field ordinals coincide with their scalar
leaf ordinals. Nested roots use depth-first leaf ordinals through the
[nested successor](m2-struct-source-nested.md).

The compiler checks the complete field list and stages every typed value before
allocating the record descriptor. It emits consecutive loads followed by one
`SINIT`, then declares the binding at site `144 + binding_id`. The nominal
record type ID and the binding site ID are independent. For F fields, staging
adds exactly 2F scalar register cells and 2F store/load instructions beyond the
field expressions, plus one `SINIT`; the existing 128-register and 256-instruction
limits still apply. Constructor type/label validation performs F+2 bounded declaration lookups;
this is compile-time work, not VM dispatch or a measured performance result.

Record bindings use sites 144..159, separate from array sites 128..143 and scalar
registers 0..127. The array binding predicate has an exclusive upper bound of
144. Blocks, loop transfers, and returns release arrays and records in reverse
lexical order. A loop transfer drops only the suffix whose scopes it exits;
other visible arrays and records remain live.

## Bounds and runtime

Construction is limited to records whose planned byte size, including alignment
padding, is at most 128 bytes. A selected record has 1..16 fields; entry record
sites are limited to 16. The existing shared 16-entry owner table, 65,536-byte
payload cap, and Fuel accounting govern allocation and execution.

The accepted declaration catalog retains its existing limits. Struct declaration
graphs may contain nested named types and unselected valid records may exceed
128 bytes. This historical baseline cannot construct or access a nested record
value; the [nested successor](m2-struct-source-nested.md) does, within its
16-leaf source staging bound.

In this read baseline, a record-binding program without `SWRITE` reports
`brownie.m2-struct-read/1`. The write successor selects
`brownie.m2-struct-write/1` when a record binding catalog and opcode 44 are present. A
bound record with a nested field selects `brownie.m2-struct-nested/1` before
those checks. A program with struct declarations but no record binding keeps the
scalar or array profile selected by its existing object operations.

## Unsupported forms

The following remain outside this historical read baseline:

- Subrecord values such as `p.inner`; nested construction and scalar paths are
  handled by the [nested successor](m2-struct-source-nested.md)
- Struct parameters, results, and borrows
- General constructors outside a record declaration initializer
- Struct fields with wrapper, array, or borrowed types

`p.x` in scalar expressions and arithmetic is supported.
One-level field writes are handled by the [write successor](m2-struct-write.md).
Record copy initialization and whole-record assignment are handled by the later
[source-copy successor](m2-struct-source-copy.md).

## Validation

These results belong to the historical read baseline.
`python -B tools/verify-m2-struct-values.py` completed successfully. Each
profile passed 28 native groups: values (5), declarations (5), struct VM (8),
functions (4), and loops (6). Each also passed 2,352 CLI cases: 144 new struct
values, 124 declarations, 115 array-literal assignments, and 1,969 scalar cases.
Three additional cases per profile check early return/continue before object
publication and a type declared after `main`; their artifact hashes match the
aggregate invocation.

The Pair example returns 42 with exactly 128,789 Fuel using the private 8-byte
arena, or 194,317 Fuel with the CLI's 65,536-byte capacity. One fewer unit fails.
Other cases cover all six scalar widths and extreme values, left-to-right
snapshots, mixed cleanup, 16 shared owners, 16 record sites, complete ordered
initializers, and nested expression depth 7 success/depth 8 compile-limit.
These are native execution and algorithmic bounds, not performance measurements.

The receipt records the pinned Fairy C compiler `4ce1264273be`, SDK, source
hashes, both native CLI artifacts, commands, and outcomes. These results are
historical for the nested-source compiler inputs. Full native suites,
full array CLI matrices, M0, Linux, isolation, DLL, packaging, allocation
instrumentation, and performance measurements were not run.

The earlier declaration-only contract and its 23 native groups and 2,208 CLI
cases remain historical evidence for declarations that create no record
binding. That evidence does not cover `SINIT`, `SREAD`, lexical binding declaration, or
the read profile. The source has since changed for field writes, source record
copies, and nested records; the [write successor](m2-struct-write.md) has its own historical
[receipt](../evidence/m2-struct-write-windows-20261026.json), while the later
[source-copy successor](m2-struct-source-copy.md) has stepwise development/release
verification. The [nested successor](m2-struct-source-nested.md) has a
complete development/release pass on corrected inputs. Full source struct support, borrows, and
full-profile conformance remain open.
