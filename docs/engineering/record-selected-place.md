# Native owned-record scalar locations

Date: 2026-11-06. L04 successor to [array locations](array-selected-place.md)
and [exclusive-slice source assignment](slice-place-assignment.md).

## Implemented boundary

`src/record_places.fy` captures a scalar leaf of a live owned plain record,
including nested records. Its private `Place` retains the original owner
token/generation, nominal root, root byte length/alignment, reservation
mark/base/end, depth-first scalar ordinal, scalar tag and checked byte offset.
Ordinals match existing record IR. A snapshot does not copy a sixteen-word
field path, own payload, allocate a root or introduce a guest value/pointer.

`array_owners::resolve_record` now exposes the existing complete native
token/ledger/catalog authentication. Its returned metadata copy grants no
authority. `struct_nested_storage::scalar_location` reuses the existing
validated layout and iterative leaf cursor, returning metadata without reading
payload. Both APIs remain native implementation helpers.

Selection authenticates the whole owner ledger and record layout before
selecting the leaf. Read and store re-resolve the captured root and ordinal,
then compare nominal type, exact scalar tag and reservation/offset. A later
descriptor/ordinal change cannot redirect the captured location. In-place
replacement may alter bytes while preserving the original target. Compound
lowering must explicitly read and retain the old scalar before RHS execution;
a later read deliberately observes the current payload.

Selection does not inspect bool bytes. Plain store can therefore repair an
invalid old bool; reading that bool or encoding an invalid replacement fails.
The scalar codec validates/stages at most eight bytes before publication.
Failed validation or encoding changes neither payload nor owner metadata.

Each successful select/read/store performs two complete layout plans, one
complete owner authentication (at most sixteen order entries plus sixteen
slots) and an iterative scalar-ordinal walk. Root size is at most 128 bytes,
with at most 128 scalar leaves and sixteen nesting levels; the walk is bounded
by fewer than 4096 cursor iterations. Missing or host-maximum ordinals, short
backing, cyclic/too-deep catalogs, malformed ledgers and array tokens fail.
Full sixteen-owner and backing capacity needs no additional reservation.

## Remaining integration

Snapshots are trusted native metadata, bound to one immutable catalog and one
owner-table/backing lifetime. They are not unforgeable guest capabilities and
do not pin roots or enforce single use. Release, reuse and clear invalidate the
captured generation. Source binding mutability and identity/phase/lifetime
obligations still require independent record-place IR admission.

The [independent IR successor](record-place-ir.md) now proves exact record/field
identity, scalar types, phases and root/CFG lifetimes in a separate analysis
entry. Existing executable admission remains gated. Metered invocation storage,
both VM drivers and source early selection/compounds remain next. Scalar-local/grouped places, generic
aggregate overlap and complete L04/C05/Instance/host/delivery remain open.
This prerequisite changes no guest opcode, source syntax, capability flag,
instruction price, CLI default or ceiling.

## Verification

Run `python -B tools/verify-static-execution.py --profile development
--selection record-places`, repeated for release. The selection contains eight
new record-place groups, six existing record-owner groups, six nested-storage
groups and eight array-place regressions.

It covers stable original locations after descriptor changes/allocation/root
replacement, separately captured old values, all six scalar domains and codec
edges, metadata-only bool selection, atomic encoding failure, stale/reused/
cleared owners, malformed snapshots and full-ledger corruption, exact capacity,
array/record separation, sixteen-level nesting and the last of 128 leaves.
See [Windows evidence](../evidence/record-selected-place-windows-20261106.json).

Public CLI/full language/Fuel matrices, Linux, OOM injection, general stack or
performance characterization, worker isolation and delivery are outside this
native prerequisite. Its tests do not establish guest record-place execution
or its future Fuel accounting.

Windows development/release each passed **28 native groups**, using 176
identical checkout-matching input hashes, 168 LF production modules and common
290-file discovery. All 176 input hashes match staged Git raw bytes.
The 40 unselected discovery-only CRLF/LF differences are recorded separately,
with both raw hashes for each fixture.
Both locked LF mirrors pass. No historical native results or stack/compiler
overrides were reused; skipped scopes above remain unverified by this selection.
