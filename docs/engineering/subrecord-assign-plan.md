# Share subrecord assignment layout planning

`array_owners::assign_subrecord`, used by private nominal subrecord assignment,
previously built the same complete catalog layout five times: once for each
owner, once for each nominal range, and once in raw storage assignment. Catalog,
owner table and arena metadata remain immutable until the final staged copy.

The owner wrapper now authenticates the destination token/table and record kind,
then calculates one local plan. A private `record_metadata_prepared` helper checks
each owner's nominal ID, size and alignment against that plan. Source token/table
authentication still occurs after destination catalog/shape checks. Both nominal
ranges use existing `struct_range::offset_prepared` with this exact catalog/plan.
The raw storage assignment retains its independently calculated second plan.
No public unchecked API, supplied-plan boundary or cross-call cache is added.
The same private shape helper also backs existing independently checked owner
resolution and the existing prepared-record owner lookup.

## Preserved checks

Diagnostic order stays destination token/table/kind, whole catalog/destination
shape, source token/table/kind/shape, destination range, source range, selected
extent checks and storage snapshot/codec. A bad catalog still wins over a stale
source token; a nonrecord destination still fails Type before catalog planning.
Missing nominal nodes, scalar lookalikes and bad ordinals still fail Type.
Owner shape mismatches still fail Metadata. Full owner-table validation remains
independent for both identities. Raw range and storage entry points still
validate their own catalogs, extents and selected scalar payloads.

Raw assignment stages at most 128 canonical bytes before the first write. Bool
errors, including exact self-assignment, preserve all bytes. Selected padding
is normalized, neighboring bytes are preserved, and no owner, token, generation,
reservation, arena usage, quota or Fuel price changes.

## Structural cost

For one successful subrecord assignment, full layout planning drops from five
calls to two (60 percent fewer). Each plan validates all 32 record rows and
512 field slots, then resolves dependencies and computes offsets. Fixed field
slot inspections fall from 2560 to 1024, and row inspections from 160 to 64.
Across 4096 successful assignments this removes 6291456 field-slot inspections
(10485760 to 4194304), plus three dependency/offset planning passes per call.

Asymptotic complexity stays O(T+S+R+F+V+B): T is owner-table work, S=512 fixed
catalog slots, R<=32 records, F<=512 active fields, V is the two bounded nominal
range walks and B<=128 staged bytes. No heap allocation is added. These are
source-level operation counts, not measured throughput, machine instructions
or physical peak memory. Other record copy/replacement operations are outside
this change.

## Focused verification

`tools/verify-subrecord-assign-plan.py` selects six native groups per profile:
two new differential groups, three existing subrecord owner groups and one
direct VM group covering exact Fuel and preservation of owners/backing when
Fuel is one unit short.
The new fixture retains the ef0a258 five-plan wrapper as a comparison oracle;
it uses unchanged raw range/storage APIs and independent owner resolution.
Successful lengths, error codes and all 256 backing bytes must match, and every
failed operation must preserve the original bytes.

The first group compares 1299 inputs: 1024 field-slot corruptions, 32 invalid
record rows, 36 catalog/diagnostic combinations, 192 owner mutations, eight
invalid-token/array-owner contexts and seven competing-error/backing/bool cases.
The second compares 26 boundary inputs: eight 128-leaf/ordinal/bool cases, all
16 nominal nodes of a depth-16 chain, and two directions between different
root layouts containing all six scalar types and their integer boundaries.
Existing groups also exercise sibling/self copying, full 16-owner pressure and
padding normalization without allocating another extent.

Run development and release separately with the pinned compiler and default
native stacks. Receipts are under `build/subrecord-assign-plan/<profile>`. The
first development attempt stopped at fixture compilation: inline inversion of
an indexed mutable field also read that field, triggering E2101. The fixture now
reads a copied owner descriptor before mutation. That failed attempt is not a
verification pass; its receipt/logs remain under `initial-fixture-loan-error`.
The next development run passed five groups but the initially selected legacy
`struct_subassign_source::writes_reuse_sites_owners_and_payload_without_copy_or_init`
failed an assertion. The same test also fails with original ef0a258 production
sources and lock, under the same pinned compiler and development native profile
(exit 5, assertion-failed). This pre-existing failure is not counted as a pass
or repaired here. Its attempt and baseline report remain in this build folder;
the final selection instead exercises subassignment directly at the VM boundary.
Full Engine, standalone memory, public CLI and release gates are outside this
focused change. Public admission is unchanged.

Development and O2 each passed the final six native groups in byte-identical
locked mirrors. All 376 receipt inputs match tested working bytes and the
implementation commit f3bc2ec: 376 raw Git byte matches, 0 line-ending-only differences.
The baseline failure, input identity checks and structural counts are recorded
in the [evidence](../evidence/subrecord-assign-plan-windows-20261115.json).
