# Plan scalar record places once per checked operation

`record_places::select` authenticates the destination of record scalar assignment.
Its `read` and `store` operations select again to reject stale or forged saved
places. Previously each selection called `array_owners::resolve_record`, which
planned the entire catalog to authenticate the owner shape, then called storage
`scalar_location`, which planned it again to resolve the leaf ordinal. A compound
assignment selects, reads and stores, so this path calculated six plans.

Selection now calls checked `inspect_record_owner` to authenticate token, full
table and record kind, then passes the expected owner size/alignment to checked
`scalar_location_bound`. That entry point builds its own fresh plan, compares the
nominal ID and expected shape, checks the ordinal and whole initialized extent,
and walks to the scalar leaf. Only the private iterator receives this local plan.
No caller-supplied Plan, saved proof, unchecked byte access or cache is added.
`Binding` remains expected metadata and grants no ownership or write authority.
The original `resolve_record` is unchanged for other callers.

## Validation and errors

Error precedence remains token, full table, record kind, whole catalog and owner
shape, ordinal, extent, saved-place equality and scalar codec. Missing nominal IDs
and mismatched expected sizes/alignments produce storage Layout and owner
Metadata. An invalid ordinal must not hide catalog/shape faults in the bound
path. The raw `scalar_location` boundary still rejects ordinals >=128 before
planning, including when the catalog is corrupt. Both entry points share the
unchanged private extent and iterative leaf walk. Selection reads no payload.

Each read/store still reauthenticates the current token/table/catalog and compares
every saved place field at the original point. No validation is reused across
RHS evaluation, owner mutation or a separate instruction. Bool decoding, staged
scalar encoding, byte-exact failure atomicity, owner tokens, generations,
reservations, quotas and VM Fuel prices are unchanged. Public admission remains
unchanged; these checks exercise the private retained-value path.

## Structural cost

One successful selection, read or store calculates one plan instead of two. Each
plan checks 32 record rows and 512 field slots before calculating dependencies
and offsets. Fixed field-slot inspections fall from 1024 to 512 per operation,
and row inspections from 64 to 32. A compound assignment uses three plans instead
of six: 3072 to 1536 field-slot inspections, a 50% reduction in this component.
Across 4096 compound assignments this removes 6291456 field-slot inspections
(12582912 to 6291456), plus half the dependency/offset planning passes.

Overall complexity remains O(S+R+F+T), where S=512 metadata slots, R<=32 record
rows, F<=512 active fields and T is the traversal to the selected ordinal. Root
table validation, leaf traversal, codec work, payload bytes and conservative
Fuel charges are unchanged. There is no new heap allocation or persistent state.
These are source-level structural counts, not measured native throughput,
machine instructions, stack peaks or physical memory claims.

## Focused verification

`tools/verify-record-place-plan.py` selects six native groups per profile. A frozen
06d6683 implementation provides independent selection/read/store wrappers that
retain the two checked plans. There are 1480 differential scenarios; each compares
all selected-place fields, read values/errors, write lengths/errors and every
backing byte, with failed writes preserving the original input.

- 1024 field-slot corruptions and 32 record-row corruptions.
- 32 competing catalog/ordinal/token/capacity diagnostic contexts.
- 192 owner mutations across all sixteen slots.
- 13 forged saved places, four backing capacities and one array-token case.
- 48 writes across six scalar domains and eight codec boundary values.
- Four bool payload encodings, depths 16/17 and all 128 leaf ordinals.

Thirteen direct storage cases check forged bindings, missing nominal ID, catalog
versus ordinal precedence, alignment, initialized extent and short backing.
Existing regressions check bool repair/failure atomicity, exact prepaid Fuel
across all scalar domains, maximum depth/leaves and sixteen-owner/backing pressure.
Run development and release separately, using the pinned compiler, byte-identical
locked mirrors and default native stacks. Receipts are under
`build/record-place-plan/<profile>`.

Full Engine, public CLI, standalone memory and full release gates are outside this
focused change. The previously recorded legacy source failure in
[subrecord assignment](subrecord-assign-plan.md) was not rerun or claimed fixed.
See the [evidence](../evidence/record-place-plan-windows-20261115.json) for final
profile results, exact input identity and implementation commit.

Development and O2 each passed all six native groups. All 376 inputs match tested
working bytes and implementation b307617: 376 raw Git matches and 0 line-ending-only
differences. The guidance body after its heading is byte-identical to the previous
checkpoint.
