# Retain value layouts with one record plan

`value_codec::retain` previously called `value_properties::inspect`, which
planned the complete record catalog, discarded that record plan, then planned
the same immutable catalog again to retain offsets and alignments. Every
successful native value/frame layout retention paid for both plans, including
empty record catalogs.

`value_properties::inspect_described` now returns both the checked value shapes
and the record plan used to derive them. Retention consumes those two products
of the same inspection. Both checked inspection entries derive properties in
one private scalar-result helper; no caller-supplied plan is accepted.

## Validation and representation

Both entries preserve count, whole record catalog, then value-node validation
order. Count >64 remains Metadata even when records are invalid; a bad record
catalog still returns Type before an invalid value node. All 32 record rows,
512 field slots and 64 value rows remain authenticated, including unused rows
and unrelated layouts. Raw `inspect` retains its signature and error types.

The property-derivation loop is extracted without changing its body. Fallible
row operations still return scalar-sized results, avoiding a large result
temporary on every row error edge. Type-equivalence classification, nominal
identity, the retained Layout fields and ownership, byte validation, copy/move
behavior, memory quota and Fuel prices are unchanged. No additional plan is
cached across operations; the Layout remains an immutable snapshot. No
executable authority or public Brownie CLI feature is added.

## Structural cost

Each successful `value_codec::retain` now plans records once instead of twice.
Fixed record field-slot inspections fall from 1024 to 512 and record-row
inspections from 64 to 32, with one dependency/offset planning pass removed.
Across 4096 successful retentions, this removes 4096 plans and 2097152 fixed
field-slot inspections (4194304 to 2097152).

Asymptotic complexity is unchanged: catalog planning remains linear in its
bounded rows/fields, while type-equivalence classification retains its existing
quadratic upper bound over at most 64 value nodes. The 50% reduction applies
to record planning only. Counts are source-level work; throughput, CPU
instructions and physical stack peaks were not measured. The joint inspection
result is transient; the retained Layout representation and heap allocations
are unchanged.

## Focused verification

Run `python -B tools/verify-value-retain-plan.py --profile all`. Seventeen native
groups use locked, byte-identical production mirrors and default native stacks
without compiler overrides. Two new groups compare the raw and joint inspection
results, every property field in all 64 slots, and all record sizes, alignments,
depths and 512 offsets against independently planned records.

Negative comparisons cover 1024 record-slot mutations, 32 record-row mutations,
256 value-node mutations, empty catalogs, cycles and diagnostic precedence.
Valid limits include a full 64-node DAG, six scalar tags, 4096-element arrays,
record depths 1..16 combined with four wrappers, nominal identity and a
4096-byte record under four wrappers. Depth 17, wrapper depth 5 and a 6144-byte
record are rejected. Existing codec and frame checks cover canonical padding,
inactive Buffer alternatives, alias-safe copies and immutable retained inputs.

Full Engine, public CLI, standalone memory, Linux and full release gates were
not rerun. The known legacy source-test failure was not retested or claimed
fixed. Changes are local commits; no push, release, deployment or version bump.

Development and O2 each passed seventeen groups. All 378 input hashes match working bytes and implementation 9c77ad4 exactly, including Git blobs.
Root check: 375 sources / 4099 MIR. Property derivation, type equivalence,
the retained Layout fields and the guidance body match baseline.
See [evidence](../evidence/value-retain-plan-windows-20261115.json).
