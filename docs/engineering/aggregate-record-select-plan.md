# Plan captured aggregate record destinations once

Whole-record and nominal-subrecord assignments capture their destination before
evaluating the RHS, then independently revalidate that captured identity before
publication. In each capture or revalidation, aggregate_places::select_record
previously built the same immutable catalog twice: once inside resolve_record
to authenticate the owner shape, then again to locate the selected subtree.
This repeats even for an unchanged catalog on each loop iteration.

The selector now calls checked inspect_record_owner for token, complete owner
table and record kind, computes one fresh catalog plan, and checks the owner's
record ID, byte length and alignment against that plan. Only then does it resolve
the nominal range with offset_prepared and check the selected size against the
owner length. Public signatures, saved Place representation and storage
transactions are unchanged. There is no new Plan input, retained proof, cache,
heap allocation or persistent field.

## Authentication and ordering

Validation keeps token, complete table, record kind, full catalog, owner shape,
nominal range and selected bounds in that order. Catalog and owner-shape faults
still return Metadata before a conflicting bad nominal/ordinal returns Type.
The owner ID is checked before indexing the plan; the range resolver proves the
nominal ID before selected-size indexing. The offset check precedes the
owner.length-offset subtraction, preserving underflow-safe selected bounds.

Saved-place validation still reselects through the captured token using a fresh
plan on every use and compares the complete shape and reservation. Old payload
bytes are not read during selection; corrupt old bools may still be replaced.
Storage independently validates sources and finishes staging before publishing.
Mismatched snapshot shapes/reservations are rejected; RHS descriptor changes
cannot redirect the captured token. The coordinator must still bind a Place to
one catalog/table/backing lifetime; native metadata grants no IR write authority.
See [captured destinations](aggregate-selected-place.md) and
[assignment lowering](aggregate-place-assignment.md).

## Structural cost

For a valid catalog, one successful selector now builds one full plan instead of
two. Its fixed catalog-validation field visits fall from 1024 to 512 and record
rows from 64 to 32, removing 50 percent of that catalog work plus one complete
dependency/offset planning pass. N successful selections save 512*N fixed
field-slot inspections and N dependency/offset passes. At N=4096 this is
4194304 to 2097152 field-slot inspections, saving 2097152 inspections.

The same reduction applies to saved-place revalidation because it calls the
selector again. With unchanged raw storage boundaries, capture plus constructor
store falls from five plans to three (2560 to 1536 fixed field-slot visits), and
capture plus record-copy store falls from six to four (3072 to 2048). These
counts cover destination capture, revalidation and the existing owner/storage
transaction, excluding RHS evaluation and compiler/Engine work.

Asymptotic complexity remains O(T+S+R+F+V): T is complete-table validation,
S=512 catalog slots, R<=32 records, F<=512 active fields and V the bounded
nominal-range walk. The duplicate full-plan factor is removed. Table and payload
validation, copy/constructor staging, payload scratch and VM Fuel prices remain
unchanged. Counts describe source work, not measured native throughput,
instructions, physical stack or memory peaks.

## Focused verification

Run python -B tools/verify-aggregate-record-select-plan.py --profile all.
The verifier selects six native groups in each of development and release/O2,
using the pinned compiler, locked byte-identical production mirrors and default
native stacks. Five frozen d944ec5 boundaries retain the previous selection,
snapshot comparison, validation, copy store and constructor store. The frozen
functions were compared with the baseline bodies, allowing only names and the
qualified Place type to change.

There are 1651 differential inputs, each comparing selection metadata/error,
validation length/error and both stores' length/error and all 256 backing bytes.
Failed stores must leave the original backing unchanged.

- 1024 corrupt field slots, 32 corrupt record rows and 36 diagnostic contexts.
- 192 owner mutations, four invalid/array tokens and 49 nominal/ordinal pairs.
- Six field counts, four capacities, four old bool encodings, three competing
  failures, two otherwise valid-table shape faults and 13 snapshot mutations.
- Nine valid wide root/subtree cases and 256 invalid-bool root/subtree cases,
  covering every one of 128 leaves, plus all 16 admitted nominal depths and a
  depth-17 rejection.

Four existing groups additionally exercise stale/reused/cleared generations,
malformed snapshots/owner ledgers, original destination identity, both record
stores, exact and one-less Fuel, frame 31 and maximum record/owner/backing limits.
Receipts are under build/aggregate-record-select-plan/<profile>.

Full Engine, public CLI, standalone memory and full release gates are outside
this focused change; public admission remains unchanged. The prior legacy
source failure recorded in [subrecord assignment](subrecord-assign-plan.md) was
not rerun or claimed fixed. Final results and tested input/commit identity are
recorded in the [evidence](../evidence/aggregate-record-select-plan-windows-20261115.json).

Development and O2 each passed all six native groups. All 376 inputs match
both tested working bytes and implementation dcdcb23: 376 raw Git matches and
0 line-ending-only differences. The root check passed with 375 sources and
4092 MIR functions; its lock update is included in the implementation commit.
The guidance body after its heading is byte-identical to the prior checkpoint.
