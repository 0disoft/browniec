# Plan an owner-bound record field access once

`array_owners::read_record` and `write_record` are used by scalar field VM
instructions. They previously called `resolve_record`, which authenticated the
owner table and built a complete `struct_layout::Plan` to compare the owner's
nominal ID, size and alignment. They then called nested storage `read`/`write`,
whose address resolver built the same plan again before checking the extent
and field path. The catalog and table are immutable throughout this call.

The owner entry points now authenticate token/table and record kind, then pass
the expected size/alignment to checked `read_bound`/`write_bound` storage entry
points. Their local plan authenticates the entire catalog, checks the nominal
ID and expected shape, checks the whole root extent, and resolves the scalar
path. A `Binding` is merely expected metadata, never a proof: each value is
compared with that freshly calculated plan. No supplied Plan, retained location,
cache or unchecked storage API is introduced. Existing raw storage entry points
still calculate their own plan; `resolve_record` is unchanged for other callers.

Error order remains token, table, record kind, catalog/owner shape, extent, path
and scalar codec. Missing nominal IDs and binding mismatches return storage
Layout, which maps to owner Metadata as before. Raw storage still returns Bounds
for a missing record ID. Whole-root alignment/extent, path length/field/scalar
endpoint, bool decoding and scalar range checks stay in place. Writes encode
only after all metadata/path checks; failed writes preserve the backing bytes.

## Structural cost

One successful owner-bound field read/write now calls `struct_layout::plan` once
instead of twice. Each plan validates all 32 record rows and 512 field slots,
then resolves dependencies and calculates offsets over all active records.
Per access, fixed field-slot inspections fall from 1024 to 512; record-row
inspections fall from 64 to 32. One full dependency/offset planning pass is also
removed. A 4096-access loop eliminates 2097152 fixed field-slot inspections
(4194304 to 2097152), plus the repeated planning work.

The overall complexity stays O(S+R+F+P), where S=512 fixed field metadata slots,
R<=32 records, F<=512 active fields and P<=16 selected path components. The
constant factor in full-catalog planning is halved, not the entire VM operation.
Owner-table validation, scalar bytes, copies, Fuel, quotas and conservative
reservations are unchanged. No heap allocation or persistent state field is
added. Binding is ephemeral expected metadata. These counts describe source
structure, not elapsed throughput, compiled instructions or physical memory.

## Focused verification

`tools/verify-record-access-plan.py` runs six selected native groups. Original
b992a2d owner wrappers still call unchanged `resolve_record` then raw storage;
the replacement is compared for read values/errors, write lengths/errors and
every backing byte. Failed writes must preserve the original bytes. There are
1257 read/write comparisons: two corruptions at every field metadata slot
(1024), malformed field count at every record row (32), twelve catalog changes
combined with valid/empty paths and invalid tokens (36), eight owner changes
across all sixteen slots (128), six path/backing faults, all six scalar tags
with five candidate write values (30), and a corrupt bool payload (1).

Direct checked-storage tests reject forged expected size/alignment, a missing
record ID and short initialized extent, preserving all bytes. Existing tests
cover a 128-leaf root, depth sixteen, raw storage path/extent/codec errors, exact
prepaid VM Fuel and actual read/write dispatch at depth/leaf boundaries.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are under `build/record-access-plan/<profile>`. The first
fixture failed parsing because its error match used unsupported `default`
syntax; it was changed to explicit enum cases before final verification. That
attempt is incomplete evidence. Full Engine, standalone memory, public CLI and
release gates are outside this focused change. Public admission is unchanged.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All 377 receipt input hashes match the tested working tree. At
implementation e3eec80, 376 inputs also match Git objects byte-for-byte; the
existing `tests/m2/struct_vm.fy` checkout uses CRLF while Git stores LF. That
file is identical after repository LF normalization and its tested bytes were
not changed. Both hashes are recorded in the
[evidence](../evidence/record-access-plan-windows-20261115.json).
