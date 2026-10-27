# M2 Mixed Call-Argument Copies

- Status: implemented and verified in development and release.
- Scope: `array_owners::copy_call_arguments`, its `CallArgument` descriptor, and
  record snapshots through `struct_nested_storage::snapshot_into`.
- Implementation: [src/array_owners.fy](../../src/array_owners.fy) and
  [src/struct_nested_storage.fy](../../src/struct_nested_storage.fy).
- Related contracts: [array owner lifetimes](m2-array-owners.md),
  [atomic array argument copies](m2-array-arguments.md),
  [nested record storage](m2-struct-nested-storage.md), and
  [record-parameter IR](m2-struct-parameters-ir.md).

This foundation copies one dense batch of array and record arguments by value.
It adds no record-parameter VM execution, source form, Fuel charge, profile, or
version capability. Record-parameter IR remains unavailable in the VM, and source
record parameters remain gated before IR and body lowering.

## Inputs

`CallArgument` contains a source token, element tag, declared length, and nominal
record ID. The input slice is dense in source order and contains 0..8 aggregate
arguments; scalar arguments are omitted. An empty batch is valid.

- `element == 0` selects a record. The declared length must be zero, and the
  nominal record ID must match the live owner's record ID and resolve to the same
  entry in the caller-bound catalog. The owner's actual byte length and alignment
  must match that catalog plan; the helper stages exactly that many bytes.
- `element != 0` selects an array. The element tag and length must match the live
  owner's scalar tag and length. The argument's record field and the owner's
  record and alignment fields must be zero.
- Every source must be a live owner in the original table. Repeating a source
  creates separate owners and independent payload copies.

The catalog, owner table, and backing bytes are caller-bound for the table
lifetime. Record IDs are interpreted only against that stable catalog; replacing
it with a layout-equivalent catalog is not permitted. No guest input selects the
catalog, table, backing region, or scratch storage.

## Planning and quota

The helper first validates the original table's 16-slot allocation chain and
arena state, then copies the table into a provisional owner plan. Every source
is resolved against the original table, never against a provisional destination.
No argument can derive its bytes from another argument's new copy, including
repeated arguments or forged references to planned slots.

For each argument, the planner derives a reservation layout from the source
owner, obtains a free slot from the provisional table, and reserves an aligned
extent after the provisional used prefix. Existing extents, retained deferred
holes, and their alignment padding remain charged. Retired generation-zero slots
remain unavailable, and reused slots retain their current generation. The entire
batch must fit under the caller-supplied arena limit and backing capacity,
counting the original prefix plus every new payload and its padding.

Any metadata, token, table, type, length, alignment, value, overflow, or quota
failure returns before the first backing-byte or real-owner mutation. The actual
table's slots, order, depth, arena cursor, generations, and payload remain
unchanged; no partial destination becomes visible.

## Record and array staging

A record snapshot is prepared in a fixed 1024-byte scratch block divided into
eight 128-byte slices. Argument `i` uses the exact-size slice
`snapshots[i * 128 .. i * 128 + record_size]`. The full catalog is replanned for
each record's owner validation and again at the `snapshot_into` boundary, not
once per batch. The snapshot rechecks the complete source extent, zeroes the
slice, copies only scalar leaf bytes, preserves integer bit patterns, validates
every nested bool leaf, and leaves nested, interfield, and tail padding zero. A
late invalid bool may dirty scratch, but never publishes it.

The scratch is separate from the output backing and from every destination. The
`snapshot_into` boundary also requires an exact-size, disjoint scratch region.
It does not change storage or arena state.

An array argument is checked for an exact shape and its complete bool payload is
preflighted when the element tag is bool. Integers need no canonical-byte scan.
Record reservation is derived from record size and 1/4/8-byte alignment for arena
planning; it never creates a logical array view of a record token.

## Commit and result

After every argument passes metadata checks, boolean validation, record staging,
owner planning, and aligned quota reservation, the helper commits the batch. It
zeroes destination alignment padding, copies each record snapshot or array source
into its disjoint destination, then publishes the complete provisional slots,
order, depth, and arena cursor. No fallible allocation, callback, validation, or
recoverable failure follows the first output write.

Success returns one fresh token per input in input order. `Copies.count` equals
the argument count, and unused result tokens have generation zero. Source owners
and bytes remain live and unchanged. Argument evaluation, mutable-capture cleanup,
callee parameter mutability, and VM frame binding remain outside this storage
primitive. VM integration must prepay record planning, staging and copy work
before calling this helper, then bind parameter tokens only after success.

## Bounds

The batch is limited to eight aggregate arguments, the existing 16 owner slots,
selected records of 1..128 bytes with at most 128 scalar leaves and catalog depth
16, and the existing array shape limits. The 1024-byte record scratch is an
algorithmic bound. The helper's payload ceiling is the caller-supplied arena
limit, also bounded by backing capacity; the engine's 65,536-byte cap remains a
separate integration limit. Catalog replanning adds catalog-sized work for every
record validation and snapshot. Work and storage are bounded by these values;
this is a structural contract, not a latency or allocation measurement.

## Verification

Command: `python -B tools/verify-m2-struct-layout.py --call-copies`.
The complete default aggregate passed 70 native groups (9 new and 61 affected)
in each development/release profile without result reuse. Both profiles selected
the same 70 identities after correcting a layout-change fixture. The original
[Windows receipt](../evidence/m2-call-argument-copies-windows-20261027.json) records
62 input hashes, compiler identity, commands and complete native outcomes.
All input hashes, the current compiler hash and unchanged SDK identities were
rechecked before archival. Compiler revision: `4ce1264273be`. Native test images
are tool-managed; no new guest CLI artifact was built.

The nine new groups cover mixed nested copies, all scalar bit patterns, padding
normalization, source independence, late bool/nominal/token/catalog failures,
quota and alignment rollback, retired generations, deferred holes, provisional
sources, stale tokens, 0/8/9 arguments, 128-byte/128-leaf roots, depth 16 and a
65,536-byte payload peak. Regression groups cover record and array owners,
record snapshots, array argument copies, assignment/fill, and array VM calls/results.

No CLI build or matrix, full native suite, M0, Linux, packaging, DLL, isolation,
allocation instrumentation or performance measurement was run. Earlier receipts
remain historical for changed owner/storage, root-lock and harness inputs.
