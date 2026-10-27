# M2 Entry-Only Root Constructor Assignment

- Status: implemented and verified for `1627ee4`; historical after later backend inputs.
- Implementation commit: `1627ee4`.
- Predecessor: [metered atomic root replacement](m2-struct-replace-vm.md).
- Successor: [entry-only child constructor assignment](m2-struct-subreplace-source.md), now implemented.
- Historical evidence: [Windows receipt](../evidence/m2-struct-replace-source-windows-20261027.json),
  retained for `1627ee4` and historical for changed backend inputs.
- Implementation: [source lowering](../../src/compiler.fy), [constructor walker and staging](../../src/struct_value_source.fy),
  [IR builder](../../src/ir.fy), [verifier](../../src/struct_verifier.fy), [VM dispatch](../../src/struct_vm.fy),
  and [version JSON](../../src/main.fy).
- Tests: [native source replacement cases](../../tests/m2/struct_replace_source.fy) and
  [CLI harness](../../tools/check-m2-struct-replace-source.py).
- Combined selection: `python -B tools/verify-m2-struct-values.py --replace-source`.

## Source contract

An entry function may replace an existing mutable record root with a complete
constructor:

```text
var P p = P { .x = 0, .y = 0 };
p = P { .x = 20, .y = 22 };
```

The destination is an existing `var` binding with the exact nominal type. The
right-hand constructor names that same type and supplies every field exactly
once in declaration order. Missing, duplicate, reordered, or extra fields are
rejected, as are wrong nominal types and immutable destinations. The form is a
statement in the entry function; helper functions and `for` initializer/post
clauses continue to reject record constructor assignment.

Scalar fields may use scalar expressions. Child fields may use inline nested
constructors, an exact-type whole binding, or an exact-type record path. The
accepted `p = P { ... }` form is an assignment to the root binding. Child-target
constructor assignment such as `p.i = I { ... }` was outside this slice; the
[child successor](m2-struct-subreplace-source.md) now implements it. General
aggregate expressions, record parameters/results, and borrows remain unsupported.

## Lowering and visibility

`record_constructor` is shared by declaration and replacement. It walks the
record tree in declaration order and allocates one staging slot immediately
before each scalar leaf expression. Scalar and inline nested-constructor
expressions are evaluated and stored left to right. Binding and path children
are snapshotted left to right at their field position with one `SREAD` and one
`STORE` per source leaf. Inline children create no owner, site, or extent.

Only after the complete constructor and its terminator are parsed does the
compiler emit consecutive `LOAD` instructions into adjacent registers. Root
replacement then emits one `SREPLACE` (opcode 48) naming the live mutable
destination binding, first scalar input register, and exact nominal root record
ID. The verifier requires a complete consecutive input range with the exact
scalar leaf types. The existing VM instruction stages canonical bytes and
overwrites only the destination's existing extent.

The old root stays visible and live while every right-hand expression runs.
Consequently, `p = P { .x = p.y, .y = p.x }` swaps values from the old root.
Right-hand mutations and nested root replacements happen immediately and are
not rolled back. Their final effects on `p` can still be overwritten when the
outer replacement commits.

If a right-hand expression faults, the outer `SREPLACE` is skipped. Every
right-hand mutation completed before the fault remains, including a mutation of
the destination itself. `return`, `break`, and `continue` bypass the outer
replacement through the existing control-transfer paths. Existing reverse-order
cleanup releases the visible arrays and records; the pending replacement has no
owner or extent to drop.

## Bounds and profiles

Replacement reuses the destination owner, record site, and payload extent. It
allocates no temporary owner, site, or extent, including when all 16 owners
and the payload arena are full. Staging consumes bounded scalar registers.
Source constructors remain limited to 16 total scalar leaves, record depth 16,
and a selected root of at most 128 bytes. Existing limits of 16 record sites,
16 shared owners, a 65,536-byte payload arena, 128 registers, and 256
instructions remain unchanged. `SREPLACE` retains its existing 46,145 Fuel
charge.

No new program profile is introduced. Flat record replacement continues to use
`brownie.m2-struct-copy/1`; nested records use
`brownie.m2-struct-nested/1`. `--version --json` reports
`"struct_constructor_assignment":true`.

## Verification

The complete `python -B tools/verify-m2-struct-values.py --replace-source`
invocation passed in development and release without reusing earlier results.
Each profile passed 28 unique native groups: six new source replacement, five
struct-value, five child-path, six source-copy, and six replacement-VM groups.
The 2,390 CLI cases per profile comprise 97 new replacement, 83 child-path,
110 source-copy, 131 subrecord-assignment, and 1,969 M1 regression cases.
An obsolete source-copy rejection fixture now accepts root constructors.
Child-target constructor assignment was outside this slice; the
[child successor](m2-struct-subreplace-source.md) now implements it.

The simple one-field CLI replacement succeeds at exactly 199,180 Fuel and
fails at 199,179. Native execution with a four-byte payload succeeds at
133,648 Fuel and fails with one less; a three-byte payload is rejected.
One native group fills the shared table with 15 arrays plus one record in a
64-byte arena and separately runs 16 live record sites under the same limit.
CLI cases cover all six scalar tags, self-read order, RHS side effects,
nested replacements, child binding/path snapshots, name ambiguity, early
transfers, malformed fields, nominal identity, full owners/sites, 16-leaf and
128-byte roots, depth 16 versus 17, overflow and division by zero.
Pure switch nesting runs at 15 and is rejected at 16; nested constructor
assignment runs at seven and is rejected at eight with `compile_limit`.

The [receipt](../evidence/m2-struct-replace-source-windows-20261027.json)
records toolchain and SDK identities, commands, input hashes, native results,
CLI cases and executable hashes. Source/tool/compiler hashes and identical
native identities across profiles were rechecked before archival. The SDK lock
identity is unchanged. Earlier receipts are historical for changed frontend,
version JSON, root-lock, fixture and harness inputs. Full native suites, other
CLI matrices, M0, Linux, packaging, isolation, DLL, allocation instrumentation
and performance were not run.

These 28-group and 2,390-CLI results remain historical for `1627ee4` after the
later backend inputs; they remain recorded for that commit.
