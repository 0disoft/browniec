# Plan whole-record constructor replacement once

array_owners::replace_record implements in-place whole-record constructor
replacement for struct_vm opcode 48. Previously resolve_record planned the
catalog to authenticate the owner, then replace_values independently planned
the same immutable catalog before staging. This repeated work occurs even for
a one-byte replacement and requires no new owner or arena reservation.

The owner wrapper now uses inspect_record_owner for token, complete table and
record-kind authentication. It passes the expected byte length and alignment
to checked storage replace_record_bound. Storage builds one fresh full plan,
authenticates that expected shape and exact nominal identity, then delegates
to the existing private replace_values_prepared writer with that local plan.

## Validation and publication

Diagnostic order remains token, complete table, record kind, full catalog and
owner shape, nominal identity, storage extent, then field encoding. An absent
owner record or changed shape still returns Metadata; a different nominal ID
still returns Type before field/extent errors. Corrupt unused catalog slots
remain errors, including when a competing nominal/field error exists.

Binding is expected metadata, not authority. Every checked storage call plans
the current full catalog; callers cannot provide a Plan. The existing writer
checks selected quota, arena state, base alignment and the complete initialized
root extent before encoding. It stages all fields into the unchanged zeroed
128-byte scratch before publishing any byte, so late invalid scalar values
leave backing unchanged. Old bool payload is not read; valid replacement can
overwrite invalid old bools and normalizes record padding.

Raw replace_values, owner resolution, the staged writer and Fuel prices are
unchanged. No heap allocation, persistent proof or cross-call cache is added.
The new checked native storage entry does not change public Brownie admission.

## Structural cost

For successful calls to this owner wrapper, complete plans fall from two to
one. Fixed catalog field-slot inspections fall from 1024 to 512 and record-row
inspections from 64 to 32: half the fixed validation work. One dependency/offset
planning pass is also removed. Across 4096 replacements, fixed slot inspections
fall from 4194304 to 2097152, removing 2097152 inspections and 4096 planning passes.

Asymptotic cost remains O(T+S+R+F+B), with full-table validation T, fixed slots
S=512, records R<=32, active fields F<=512 and staged bytes B<=128. The repeated
catalog factor is reduced. Full-table validation, field encoding, backing writes
and 128-byte payload scratch are unchanged. Counts describe source operations;
native elapsed throughput, CPU instructions and physical peaks were not measured.

## Focused verification

Run python -B tools/verify-record-replace-plan.py --profile all.
Six native groups per profile use locked byte-identical production mirrors,
the pinned compiler and default native stacks. Two new groups include 1344
differential inputs against the frozen 1279629 owner wrapper: 1024 slot faults,
32 row faults, 36 catalog/error contexts, 192 owner mutations, token/nominal/
field-count/capacity combinations, old bool replacement, competing errors,
ledger/shape faults and depth 1..16 plus depth-17 rejection. Each compares exact
lengths/errors and all 256 backing bytes; failed writes preserve original bytes.

Seventeen direct checked-storage cases cover forged bindings, absent roots,
catalog and nominal precedence, misalignment, near-maximum bases, partial roots,
short backing, empty fields, late invalid bools and oversized selected records.
Four existing groups cover all scalar encodings/padding, sixteen owners with
full 2048-byte backing and 128-leaf replacement, raw storage compatibility,
and direct opcode-48 Fuel 46145 with one-unit-short rejection before mutation.

Receipts are under build/record-replace-plan/<profile>. Full Engine, standalone
memory, public CLI, Linux and full release gates are outside this change.
The prior legacy source failure was not rerun or claimed fixed; broader
completion remains paused. Final results and tested input/commit identity are
in the [evidence](../evidence/record-replace-plan-windows-20261115.json).

Development and O2 each passed all six selected native groups. All 376
receipt inputs match tested working bytes. Implementation acf190e:
All input bytes match implementation Git blobs.
The root check passed with 375 sources and 4094 MIR functions; its lock update
is included in the implementation. Four owner functions and both raw/private
storage replacement functions match the baseline exactly. The guidance body
below its heading remains byte-identical.
