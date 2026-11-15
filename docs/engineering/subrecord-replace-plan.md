# Plan nominal subrecord replacement once

`array_owners::replace_subrecord` implements scalar-value constructor replacement
for captured whole-record and nominal child destinations. Previously it planned
the same immutable catalog in `resolve_record`, in `struct_range::offset`, and
again in storage `replace_values`. These three plans authenticate the owner
shape, select the subtree and encode into the existing destination, respectively.

The wrapper now uses checked `inspect_record_owner` for token, full table and
record kind, then passes expected size/alignment to checked storage
`replace_subrecord_bound`. Storage builds one fresh full plan, checks the expected
shape and nominal ID, resolves the nominal range with that same plan, proves the
whole root extent, and stages the selected record through a private helper.
Only a locally calculated plan enters the private writer; no caller-supplied
Plan, unchecked public writer, cross-call proof or persistent cache is added.
Binding is expected metadata, never ownership or write authority.

## Bounds, ordering and publication

The owner path retains token, full table, record kind, full catalog/owner shape,
nominal range, storage extent and scalar encoding order. A missing root or
changed owner shape still returns Metadata. A missing nominal node, scalar
lookalike, invalid ordinal or oversized nominal range still returns Type.
Catalog/shape faults precede range faults, which precede field-count/codec faults.

The new checked storage entry also proves the entire root before adding the
relative selected offset to its base. This bounds that addition by the initialized
arena extent, including near-maximum bases. A child that fits a truncated root
does not authorize access through an invalid whole root. For owner callers the
unchanged full-table preflight has already proved this; the independent check
keeps direct storage callers safe. Selected extent checks remain in the writer.

Raw `replace_values` still builds its own plan and uses the same private staged
writer. All fields encode into the existing zeroed 128-byte scratch before any
backing byte is published. Invalid late values preserve the whole backing; valid
replacement normalizes selected padding and does not inspect old bool payload.
Owner state, tokens, generations, reservation, quotas and Fuel prices persist.
Selection and saved-place revalidation remain independent of this operation.
See [aggregate destinations](aggregate-selected-place.md) and their
[source assignment contract](aggregate-place-assignment.md).

## Structural cost

One successful owner-bound replacement now builds one complete plan instead of
three, removing two thirds of full-catalog planning. Each plan validates 32 record
rows and 512 field slots before dependency/offset calculation. Fixed field-slot
inspections fall from 1536 to 512; record-row inspections fall from 96 to 32.
For 4096 replacements this removes 4194304 field-slot inspections
(6291456 to 2097152), plus 8192 dependency/offset planning passes.

The bound applies to `array_owners::replace_subrecord`, not the whole compiler or
aggregate assignment sequence. Earlier SELECT and saved-place validation keep
their independent plans. Overall complexity remains O(T+S+R+F+V+B), where T is
owner-table validation, S=512 catalog slots, R<=32 records, F<=512 active fields,
V is the bounded nominal-range walk and B<=128 staged bytes. The independent
whole-root extent check adds constant arithmetic. Payload work and 128-byte
scratch are unchanged; no heap allocation or persistent state is added. These
are source-level counts, not measured native throughput or physical stack peaks.

## Focused verification

`tools/verify-subrecord-replace-plan.py` selects six native groups per profile.
The frozen 05a0a02 three-plan wrapper remains the oracle; it uses unchanged checked
owner resolution and raw range/storage boundaries. There are 1671 differential
inputs, comparing result lengths/error codes and every backing byte. Failed
operations must preserve all 256 original bytes.

- 1024 field-slot and 32 record-row corruptions, 36 catalog/diagnostic contexts.
- 192 owner mutations across all sixteen slots and four invalid/array tokens.
- 49 nominal/ordinal combinations, six field counts and four capacities.
- Four old bool encodings, three competing failures and two valid-table shape faults.
- 48 scalar codec edges, 265 wide-root/subtree bool cases and depths 16/17.

Eighteen direct storage cases cover forged shape, missing IDs, error order,
alignment, maximum-base addition, a partial root with an otherwise fitting
child, short backing, invalid field count/late bool and oversized root admission.
Existing regressions cover raw and bound atomic staging, destination identity,
exact Fuel and one-unit-short rejection, frame 31, 128 leaves at depth sixteen
and sixteen owners with full backing usage. Receipts are recorded under
`build/subrecord-replace-plan/<profile>` in byte-identical locked mirrors,
using the pinned compiler and default native stacks.

Full Engine, public CLI, standalone memory and full release gates are outside
this focused change; public admission remains unchanged. The previously recorded
legacy source failure in [subrecord assignment](subrecord-assign-plan.md) was not
rerun or claimed fixed. See the
[evidence](../evidence/subrecord-replace-plan-windows-20261115.json) for final
profile results, tested input identity and implementation commit.

Development and O2 each passed all six native groups. All 376 inputs match
tested working bytes and implementation 4c77778: 376 raw Git matches and
0 line-ending-only differences. The guidance body after its heading is
byte-identical to the previous checkpoint.
