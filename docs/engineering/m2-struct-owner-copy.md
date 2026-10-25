# M2 Private Struct Owner Copy and Assignment

- Status: verified private owner copy/assignment primitives; historical for current IR, harness, and root-lock inputs.
- Scope: record-owner copy and assignment over the shared 16-slot table.
- Implementation: [src/array_owners.fy](../../src/array_owners.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--owner-copy`.
- Evidence: [Windows receipt](../evidence/m2-struct-owner-copy-windows-20261026.json).

`copy_record(catalog, source, bytes, table)` resolves a live, generation-checked
record token, preflights one free shared slot, and calls nested record copy.
Nested copy charges old-plus-new bytes and alignment before advancing the cursor;
after success, the shared `publish_record` helper installs one new record owner.
The copy has independent metadata and payload and survives source release.
`publish_record` is shared with `create_record`.

`assign_record(catalog, destination, source, bytes, table)` resolves both live
record tokens against the current immutable catalog and requires the exact same
record id, even when two records have identical layout. It delegates to nested
snapshot assignment, which updates destination bytes with prewrite snapshot
values and canonical bool checks, including self-assignment. Assignment reserves
no descriptor or extent and changes no token, generation, or cursor. Every
returned failure preserves payload bytes and all table metadata.

## Bounds and trust

Each record consumes one shared descriptor and one arena extent; no per-field
descriptors are created. Retained dead extents still count toward shared byte
and descriptor limits until suffix reclamation. The existing 128 record-byte, 128-leaf, depth-16, and
16-owner limits still apply. The trusted caller must bind one immutable catalog
and stable backing region to the table lifetime. There is no catalog-identity
hash, cross-Instance token, borrow, or mutability capability; same-id same-size
schema substitution remains outside this private contract. Tokens establish
liveness inside that table lifetime only.

Mixed array copies and argument batches continue to work while record owners are
live because all kinds share slots, order, and arena. This slice adds no source
grammar, struct IR/VM/Fuel, or borrows. The [private struct IR
successor](m2-struct-ir.md) now defines bindings and verifier rules; struct VM
dispatch and Fuel remain pending.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --owner-copy` selects 17 native groups
per profile: six new struct-owner-copy, six struct-owner, and five array-owner
groups. Development and release each passed all 17 groups. The
[tests/m2/struct_owner_copy.fy](../../tests/m2/struct_owner_copy.fy) cases cover
mixed array copy and argument batches with live records, source independence
across release, padding, exact-id rejection for identical layouts, full 128-byte
capacity and 16-owner pressure, quota and alignment, late bad bools, stale
tokens, corrupt metadata, and depth 16. The
[receipt](../evidence/m2-struct-owner-copy-windows-20261026.json) records both profiles.
Existing other 38 source files and old test fixtures are unchanged. Full CLI,
other native suites including array VM and call/result VM, M0, Linux, isolation,
DLL, packaging, performance, and allocator instrumentation were not rerun.

The 17-group result remains evidence for the unchanged primitive owner-copy path.
Its receipt is historical for the later IR, harness, and root-lock changes; those
changes do not invalidate unrelated primitive source results.

Next: struct VM dispatch and Fuel.
