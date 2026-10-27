# M2 Private Scalar-Value Record Replacement

- Status: implemented and verified in development and release.
- Implementation commit: `6509e27`.
- VM successor: [metered atomic root replacement](m2-struct-replace-vm.md).
- Evidence: [Windows receipt](../evidence/m2-struct-replace-values-windows-20261027.json).
- Implementation: [nested storage](../../src/struct_nested_storage.fy),
  [shared owners](../../src/array_owners.fy).
- Tests: [replacement cases](../../tests/m2/struct_replace_values.fy).
- Combined selection: `python -B tools/verify-m2-struct-values.py --replace-values`.

## Contract

`struct_nested_storage::replace_values(catalog, record, destination, fields,
storage, arena)` replaces an existing complete record from depth-first scalar
leaf cells. It replans the whole catalog and validates the selected extent,
alignment, arena state and capacity. The selected record remains at most 128
bytes, with 1..128 exact scalar inputs and depth at most 16.

`array_owners::replace_record(catalog, destination, nominal, fields, bytes,
table)` first resolves the live generation-checked record token, validates its
descriptor against the current catalog and requires the exact nominal record
identity. Matching physical layouts do not substitute for nominal identity.
Array tokens, stale or released generations and forged descriptors fail.
This private owner layer does not establish source-level write authority;
the [VM successor](m2-struct-replace-vm.md) checks mutability before dispatch.

The initializer and replacement share one private `encode_fields` traversal.
It encodes every scalar into zero-initialized local scratch before publication,
including canonical bools and checked u8/i32/u32 ranges. Nested and tail padding
become zero. Replacement then copies the complete staged record without another
fallible operation. Bytes outside that extent are untouched. Invalid fields,
metadata, layouts, bounds or values leave all backing bytes unchanged.

The owner table and arena are read-only inputs to replacement. Successful and
failed operations preserve generations, live state, order, owner count, arena
cursor and limit. No owner, site or payload extent is reserved. This works when
all 16 shared owner slots and all payload bytes are occupied. A future constructor
assignment can therefore avoid a temporary root owner and its payload extent.
The record buffer has a fixed 128-byte bound; this is not a measured stack/RAM
or execution-speed claim. The owner entry point performs two bounded catalog
plans, one extent preflight and one scalar encoding pass.

## Integration boundary

This foundation added no source syntax, opcode, verifier rule, VM dispatch or Fuel charge.
In particular, `p = P { ... }` is still rejected. Version JSON and existing
source profiles are unchanged. The native tests exercise the new functions
directly; CLI regressions exercise their shared initialization path and existing
record operations.

The [metered VM successor](m2-struct-replace-vm.md) now supplies those checks and
prepayment through private `SREPLACE` (48). Source lowering must still evaluate
and stage every RHS field before this final write.
Failure atomicity applies to this storage operation; earlier statements and
external effects are not rolled back.

## Verification

The initial six native development groups cover mixed scalar extremes, padding
and neighboring owners, invalid late values and field counts, all 128 leaves at
full owner/payload capacity, nominal and token rejection, malformed metadata,
storage extent/alignment/state checks, depth 16 and generation reuse.

The combined development/release selection adds six existing nested-storage,
six owner-copy and three subrecord-owner groups, plus the child-path and
subrecord-assignment CLI matrices. The complete invocation passed
in development and release without reusing earlier results: 21 native groups and
214 CLI cases per profile. The receipt records 102 input hashes, compiler and
artifact identities, commands and outcomes. Input and compiler hashes, the final
release binary hash and identical native identities across profiles were rechecked
before archival. The SDK lock identity is unchanged.
Full native suites, scalar/array and other struct CLI matrices, M0, Linux,
isolation, DLL, packaging, allocation instrumentation and performance are outside
this selection. Earlier receipts are historical for changed shared storage,
owner, root-lock and harness inputs.
