# Validate record results without discarded snapshots

Private record RET rehomes an existing unique owner; it does not publish a new
payload. `array_owners::validate_record_result` nevertheless used to allocate a
128-byte local scratch array and call `snapshot_into`, then discard the complete
normalized snapshot. Owner resolution and snapshotting also independently built
the same full catalog layout. Integer payload copies and padding initialization
could never affect the return value or the rehomed owner's backing bytes.

The owner entry point now authenticates token/table and record kind, then passes
expected size/alignment to checked `struct_nested_storage::validate_result`. Its
single fresh full plan checks the expected owner shape, requested nominal ID and
whole-root extent. The existing iterative scalar iterator then reads only bool
bytes for canonical 0/1 validation. Every bit pattern of each admitted integer
scalar is valid; padding was never part of snapshot payload validation.

Binding is expected metadata, never authority. The new public storage boundary
constructs its own plan and does not accept a caller-supplied plan or location.
Existing bound scalar access shares the private `binding_matches` predicate;
its diagnostic order is unchanged. Raw snapshots/copies remain independently
checked and still normalize padding when callers actually need a copy.

## Ordering and state

Checks retain token, table, record kind, whole catalog, bound nominal ID/size/
alignment, requested result nominal, root extent and bool order. Missing bound
record IDs and shape mismatches return storage Layout, mapped to owner Metadata.
A nominal mismatch still wins over malformed bool payload or root extent in
direct storage calls. Integer bytes do not need decoding or range checks because
the admitted widths accept all bit patterns, including packed upper-half usize.
No payload, arena, owner metadata, generation or reservation changes on success
or failure. RET token publication still happens only after validation succeeds.
The legacy conservative Fuel price 42113 and exact remaining Fuel are unchanged;
the cost comment now identifies the retained historical planning/snapshot budget.

## Structural cost

One successful owner result validation builds one plan instead of two. Fixed
catalog field-slot inspections fall from 1024 to 512, and record-row inspections
from 64 to 32, with one dependency/offset calculation removed. Metadata traversal
is still bounded by the validated catalog, 128 leaves and depth sixteen.

For B selected bytes, Q scalar payload bytes and N bool leaves, source payload
reads fall from Q+N to N. For sixteen i64 fields (B=Q=128, N=0), reads fall from
128 to zero; for 128 bool leaves, reads fall from 256 to 128. Snapshot-only local
scratch falls from 128 bytes to zero. Source-level scratch stores fall from
128+B+Q to zero: the local initializer, selected-size clearing and scalar copies
are all removed. For a full 128-byte integer record this is 384 eliminated byte
stores per return. Across 4096 such validations, 524288 payload byte reads and
2097152 fixed catalog-slot inspections are removed.

Payload work changes from O(Q+N) reads and O(128+B+Q) scratch stores to O(N) reads
and no scratch stores. Overall catalog/iterator complexity remains
O(T+S+R+F+V+N), where T is owner-table work, S=512 fixed slots, R<=32 records,
F<=512 fields and V is the iterative leaf traversal. No heap allocation is
added. These are source-level counts, not measured native throughput, compiler
dead-store behavior, machine instructions or physical peak-memory measurements.

## Focused verification

`tools/verify-record-result-validation.py` runs six native groups per profile:
two new differential groups, three existing direct RET groups and an existing
checked scalar-binding group. The comparison oracle retains the ab423bb owner
wrapper using unchanged independent owner resolution and raw snapshot APIs.
Return lengths/error codes must match and all 128 backing bytes must stay intact.

The first new group compares 1304 inputs: 1024 corrupt field slots, 32 bad record
rows, 36 catalog/error contexts, 192 owner mutations, four requested nominals,
three invalid tokens, four bool values, four capacities and five competing-error
contexts. The second compares 1541 more: 1280 integer patterns across all five
integer tags, 258 maximum-bool cases, two depth-sixteen bool cases and a rejected
depth-seventeen catalog. It also directly checks twelve storage validations,
including forged sizes/alignments, an unknown bound record ID, bad root extents,
arena metadata and nominal-before-extent precedence.

Existing direct RET tests cover eighteen failed-transfer scenarios, full sixteen
owner/128-byte pressure, frame 31, token and generation preservation, unchanged
padding, remaining Fuel and rejection of array tokens/nominal mismatch. Existing
scalar-binding tests exercise the shared private predicate at read/write entry
points. Run development and release separately with the pinned compiler, default
native stacks and byte-identical locked mirrors. Receipts are under
`build/record-result-validation/<profile>`. Full Engine, public CLI, standalone
memory and full release gates are outside this change. Public admission is
unchanged. The previously recorded legacy source failure in
[subrecord assignment](subrecord-assign-plan.md) was not rerun or claimed fixed.
The first development attempt stopped at fixture compilation because this
Fairy C subset does not admit a usize-to-u8 cast. The pattern generator now
increments a separate u8 value through 0..255 without a narrowing cast or
overflow. That attempt is not a pass; its receipt/logs remain in
`build/record-result-validation/initial-fixture-cast-error`.

Development and O2 each passed all six native groups in byte-identical locked
mirrors. All 376 inputs match tested working bytes and implementation
01d499e: 376 raw Git byte matches and 0 line-ending-only differences.
See the [evidence](../evidence/record-result-validation-windows-20261115.json)
for input identity checks, structural counts and verification limits.
