# M2 Subrecord Assignment

- Status: historical per-leaf implementation, verified on its recorded inputs.
- Successor: [atomic subrecord assignment](m2-struct-subassign-atomic.md).
- Implementation commit: `666da70`.
- Evidence: [Windows receipt](../evidence/m2-struct-subassign-windows-20261027.json).
- Predecessor: [subrecord declaration initializers](m2-struct-extract.md).
- Tests: [struct_subassign_source.fy](../../tests/m2/struct_subassign_source.fy).
- Combined selection: `python -B tools/verify-m2-struct-values.py --subassign`.
- CLI selection: `tools/check-m2-struct-subassign.py`.

## Source forms

```brownie
module main;
struct I { i32 x; }
struct R { I i; }
fn i32 main() {
    let R q = R { .i = I { .x = 42 } };
    var R p = R { .i = I { .x = 0 } };
    p.i = q.i;
    return p.i.x;
}
```

The example returns 42 with `--fuel 1000000`. A destination must belong to a
visible mutable record binding. Its endpoint may be a nested record; the RHS may
be an exact-nominal record path or a whole visible binding. This admits
`p.i = q.i`, `p.i = i`, and `i = p.i`. Immutable sources are accepted. Whole
binding-to-binding assignment keeps the existing `SASSIGN` lowering.

Fields with identical shapes but different nominal types remain incompatible.
Scalar endpoints retain their existing typed expression assignment. Constructors,
calls, parentheses, and general aggregate expressions are not record assignment
operands. Record statements in helpers and `for` initializer/post clauses,
struct parameters/results, borrows, and subrecord paths as constructor child
values remain unsupported.

The atomic successor replaces the per-leaf lowering and Fuel limit described
below. This receipt is historical for changed verifier, VM, and compiler inputs.

## Historical snapshot and lifetime

The compiler resolves the mutable destination before parsing the RHS. It checks
the complete source path and nominal type, then emits all source `SREAD`s before
any destination `SWRITE`. This gives self-assignment and sibling copies the same
snapshot semantics. Changing either independent value afterward does not change
the other.

For a selected record with k scalar leaves, lowering adds k consecutive read
registers and emits k reads followed by k writes. There are no `STORE`, `LOAD`,
`SCOPY`, `SINIT`, or `SASSIGN` instructions for this operation. The destination
retains its existing site, owner, and extent; the source stays live. No temporary
owner or payload is reserved, so assignment works with a full 16-owner table or
16-site record catalog. Neighbors and existing padding are preserved.

No user expression runs between the reads and writes. A fatal runtime error,
including Fuel exhaustion, aborts the invocation. Earlier scalar writes within
that failed invocation are not transactionally rolled back. Invocation-local
storage is not exposed by this CLI, and no automatic replay or external-effect
rollback is introduced.

## Historical per-leaf limits and Fuel

Each read and write pays the existing 41,281 Fuel charge. Copying k scalar leaves
therefore requires 82,562*k Fuel for the assignment instructions, plus the other
program work. These are abstract work charges, not elapsed times. Sixteen-leaf
assignment is statically admitted but its read/write charges alone exceed the
CLI's 1,000,000 Fuel cap; that case returns `fuel` at runtime.

Existing source bounds remain: 16 scalar leaves, depth 16, a selected root of
128 bytes, 16 record sites, the shared 16-owner table, a 65,536-byte arena,
128 registers, and 256 instructions. No opcode, verifier, or VM rules change.
Programs retain `brownie.m2-struct-nested/1`; version JSON adds
`"struct_subrecord_assignment": true`.

## Verification

The complete combined invocation passed in development and release without
reusing prior results. Each profile passed 15 native groups (5 assignment,
5 extraction, 5 write) and 3,044 CLI cases: 129 assignment, 117 extraction,
88 child, 128 nested, 110 copy, 120 write, 144 values, 124 declarations, 115
array-literal assignment, and 1,969 scalar. The receipt records 91 harness input
hashes plus four CLI generator fixture hashes, compiler/artifact hashes, commands,
and outcomes. All input and compiler hashes were rechecked before archival;
the added fixture snapshots match the implementation-commit Git blobs. The final
release binary matches its recorded CLI hash. Both profiles select the same
15 native identities.

The native selection covers assignment, extraction, and field writes. CLI selections also cover child construction, nested paths,
whole-root copies, values, declarations, array-literal assignment, and scalar
regressions. Cases include all six scalar types, differing parent types, nested
and nonzero-offset endpoints, self/sibling copies, source independence, owner
and static-site saturation, loop cleanup, immutable and nominal rejection,
depth 2/8/16, and the sixteen-leaf Fuel limit.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation, and performance are outside this selection.
