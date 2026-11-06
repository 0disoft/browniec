# Compiler selection and cleanup for aggregate places

Date: 2026-11-07. Implemented at `ecf9cbb` after
[aggregate-place VM execution](aggregate-place-execution.md).

`place_source` allocates all five place kinds from the same sixteen-bit mask.
Whole-array and exact nominal record-subtree selections reserve no lexical name,
scalar register or owner site. The mask is changed only after SELECT emission
succeeds; exhaustion rejects without emitting another instruction.

`aggregate_place_source` emits all five final store forms. Parser callers must
select into their lexical snapshot before evaluating the RHS. Successful stores
emit END before dropping an anonymous array or record result. Constructors load
their already evaluated staging slots into consecutive values before REPLACE87;
no temporary aggregate owner or payload extent is introduced.

Existing normal-return, propagation and loop-transfer cleanup consumes this
same mask. It ends exited selections in reverse ID order before owner drops and
loan closes. Exit emission does not mutate the lexical construction snapshot;
another branch can still compile from the same state. Runtime abort remains the
separate, prepaid failure path.

Development and release each passed two native groups on this helper checkpoint.
All five store forms execute through both VM coordinators. Mixed scalar-array,
exclusive-slice, scalar-record and aggregate selections preserve sixty-four
names, reject a seventeenth ID without emission, reuse an ended ID and drain all
sixteen selections before native owner/loan cleanup. See the scoped
[Windows evidence](../evidence/aggregate-place-cleanup-windows-20261107.json).

This checkpoint did not change guest source lowering or prices. The
[source successor](aggregate-place-assignment.md) connects the parser and records
the resulting source Fuel changes. Full language/native matrices, Linux,
OOM/general stack/performance and complete L04/C05/Engine/Instance/host/isolation/
platform/delivery were outside this helper selection.
