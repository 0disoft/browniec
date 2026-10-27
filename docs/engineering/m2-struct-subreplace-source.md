# M2 Entry-Only Child Constructor Assignment

- Status: implemented and verified in development and release.
- Implementation commits: backend `9fa0180`; frontend `a24c0b1`.
- Predecessor: [entry-only root constructor assignment](m2-struct-replace-source.md).
- Evidence: [Windows receipt](../evidence/m2-struct-subreplace-source-windows-20261027.json).
- Implementation: [source lowering](../../src/compiler.fy),
  [constructor staging](../../src/struct_value_source.fy), [IR builder](../../src/ir.fy),
  [verifier](../../src/struct_verifier.fy), [VM dispatch](../../src/struct_vm.fy),
  [range resolution](../../src/struct_range.fy), [owner/storage helper](../../src/array_owners.fy),
  [top-level dispatch](../../src/vm.fy), and [version JSON](../../src/main.fy).
- Tests: [native backend cases](../../tests/m2/struct_subreplace_vm.fy) and
  [source cases](../../tests/m2/struct_subreplace_source.fy).
- CLI harness: [check-m2-struct-subreplace-source.py](../../tools/check-m2-struct-subreplace-source.py).
- Combined selection: `python -B tools/verify-m2-struct-values.py --subreplace-source`.

## Source contract

The source slice supports constructor replacement for an exact nominal child
of an entry-owned mutable record root:

```text
struct J { i32 x; }
struct I { J inner; }
struct P { I i; i32 tail; }

var P p = P { .i = I { .inner = J { .x = 0 } }, .tail = 0 };
p.i = I { .inner = J { .x = 42 } };
p.i.inner = J { .x = 7 };
```

The destination path must resolve to a complete record node of the constructor's
exact nominal type. Fields are supplied exactly once in declaration order.
Scalar fields accept scalar expressions. Child fields accept inline nested
constructors or exact-type whole bindings and paths.

Root assignment `p = P { ... }` continues to use `SREPLACE` (48). Child
assignment at `p.i` and deeper exact nominal endpoints uses the new private
`SSUBREPLACE` (49). General aggregate expressions, record parameters/results,
and borrows remain unsupported.

## Private instruction

`SSUBREPLACE` uses the existing eight-byte instruction width:

| Byte | Meaning |
| --- | --- |
| 0 | 49 (`SSUBREPLACE`) |
| 1 | Live mutable entry-owned root binding |
| 2 | First consecutive scalar input register |
| 3 | Exact nominal subtree record ID |
| 4 | First scalar leaf ordinal of the selected record node |
| 5..7 | Reserved zero |

The verifier resolves the selected nominal record node and its complete scalar
leaf count. It requires every consecutive input to be defined, scalar-typed, and
an exact match for the selected subtree's depth-first tags. The destination must
be a live mutable entry binding. Register definitions and owner live sets do not
change; existing joins and backedge invariants apply.

## Runtime and commit

`SSUBREPLACE` prepays 87,105 Fuel before traversal, authority checks, staging or
mutation: `4*18432 + 3*4096 + 1024 + 65`. The allowance covers four complete
layout plans for counting, owner resolution, child-range resolution, and
encoding, plus three bounded traversals. It is a bound on work, not a measured
execution-time claim.

The public `array_owners::replace_subrecord` helper accepts exact nominal root or
child targets. Runtime resolves the destination owner and selected child offset,
then encodes every scalar leaf into at most 128 canonical bytes. Encoding includes
padding inside the selected child. All fields, ranges, values, and metadata are
checked before one selected-range commit.

Only the selected child range is overwritten. Neighboring bytes retain their
latest values, and owner tokens, generations, order, arena cursor, and capacity
remain unchanged. The operation reserves no temporary owner, record site, or
payload extent, including with 16 occupied owners and a full payload arena.

## Staging and visibility

Source lowering reuses the shared constructor walker. Every RHS field expression
is staged left to right before consecutive scalar loads and one `SSUBREPLACE`.
Inline children, exact bindings, and paths use the existing bounded staging
rules. The source remains limited to 16 scalar leaves, record depth 16, and a
selected root of at most 128 bytes; existing register, instruction, site, owner,
and arena limits remain unchanged.

The old root remains visible while all RHS expressions run. Earlier RHS effects,
including writes to the selected target or sibling fields, are not rolled back.
The final selected-range commit uses the staged constructor values; neighboring
fields retain their latest RHS changes rather than an older snapshot.

An early `return`, `break`, or `continue` skips the outer `SSUBREPLACE` through
the existing control-transfer and cleanup paths. A fault before commit skips the
outer operation; completed RHS mutations and external effects remain. The pending
replacement has no temporary owner or extent to clean up.

## Profiles

No new program profile is introduced. Nested record programs retain
`brownie.m2-struct-nested/1`. The `--version --json` capability reports
`"struct_subrecord_constructor_assignment":true`.

## Verification

The complete `python -B tools/verify-m2-struct-values.py --subreplace-source`
invocation passed without reusing prior results in development and release.
Each profile passed 36 native groups: six new child-source, six new backend,
six root-source, five subrecord-assignment, four atomic-assignment and nine IR
groups. The 2,383 CLI cases per profile comprise 103 new child-constructor,
97 root-constructor, 83 child-path, 131 subrecord-assignment and 1,969 M1 cases.
The earlier subrecord-assignment rejection fixture now accepts exact-nominal
child constructors; other negative checks remain.

Backend tests cover exact nominal nodes and leaf ranges, scalar tags and
canonical values, malformed operands and reserved bytes, liveness and authority,
stale generations and invalid metadata, prepayment, and byte/owner preservation
on failure. All six scalar tags, selected-padding zeroing, untouched neighbors,
128-leaf children at 16 full owners in 2,048 payload bytes, and join/backedge
invariants are exercised. The private IR example succeeds at 174,620 Fuel with
16 payload bytes and fails at one less; 15 payload bytes fail.

Source cases cover staged self reads, child bindings/paths and inline children,
deep destinations, single evaluation, nested root replacement, latest sibling
writes, early return/break/continue cleanup, nominal and immutable rejection,
static sites and owner pressure. A full source owner table with 15 arrays plus
one record succeeds in 72 payload bytes. Sixteen-leaf and 128-byte children,
depth 16 versus 17, overflow and division by zero are tested. Nested child
assignment runs at seven and is rejected at eight with `compile_limit`.
The basic three-field source root succeeds with exactly 174,622 Fuel and 12
payload bytes, and fails at 174,621 Fuel or 11 bytes. The CLI counterpart
succeeds at 240,146 Fuel and fails at 240,145.

The [receipt](../evidence/m2-struct-subreplace-source-windows-20261027.json)
records input hashes, toolchain/SDK identities, commands, native results, CLI
cases and artifact hashes. All recorded input and compiler hashes, the release
binary hash and equal native identities across profiles were rechecked before
archival. SDK lock identity is unchanged. Earlier receipts remain historical
for changed backend, frontend, version JSON, root-lock, fixture and harness
inputs. Full native suites, other struct/array CLI matrices, M0, Linux,
packaging, DLL, isolation, allocation instrumentation and performance were not
run.
