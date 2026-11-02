# Private owned record arguments in canonical CALLs

Canonical CALLs now admit immutable nominal record values alongside arrays,
scalars, shared slices and exclusive formals. This extends the
[owned array coordinator](m2-slice-owned-call-authority.md); aggregate results,
suspended/derived exclusive CALL sources and guest/public reborrow promotion
remain gated. Source syntax, opcodes, public capabilities and prices are unchanged.

## Exact signatures and copying

CALL inspection validates unique formal record destinations, zero scalar type,
nonoverlapping parameter kinds, caller/target partitions, immutable descriptors
and exact nominal identity. Equal-sized records of another nominal type cannot
cross this boundary. Existing constructor, child-path and mutable-source capture
lowering produces ordinary immutable owned argument descriptors; it is unchanged.
Repeated owned sources are legal and receive independent copies.

Complete Fuel remains `1 + arity + struct_call_vm::cost`, plus
`65537*(1 + readers + 2*writers)` when any slice is passed. The existing owned
cost is array work alone without records, or `2048 + 43008*records + array_work`
when records are present. The immutable coordinator and existing copier preflight
read the same sufficient original budget; the VM publishes only the coordinator's
complete remaining Fuel. No copy or reserve is charged twice.

Existing scalar/control preflight and unpublished loan/authority preparation run
first. `enter_owned` now passes mutable record state to unchanged
`struct_call_vm::step`, which dispatches the existing array-only or mixed copier.
It is the last fallible transaction. The mixed copier resolves every original
owner, validates all nested bool values, exact layouts, quotas and descriptors,
and stages normalized records before any backing write or owner publication.
Only infallible authority/pool/binding and scalar/control publication follows.
Preparation cannot change canonical state, including on a late record failure.

The mixed copier already owns fixed 1,024-byte record snapshot scratch (eight
128-byte records) and normalizes padding. This change adds no additional payload
snapshot, authority clone, persistent field or receipt collection. CALL/Admission
and authority layouts are unchanged. Existing root sessions remain valid between
preparation and publication; plans retain the prior trusted native single-use
contract. They must not cross unrelated state mutation, callbacks or invocations.
Native size/stack, allocator and timing remain unmeasured.

## Return, abort and execution

Existing body operations and source cleanup release copied record/array parameters
before canonical return. Dirty child tokens are rejected before restoring callers.
Loan cleanup, detached writers, generation reserves and combined depth keep their
prior behavior. Owned-only calls use an empty Batch. The shared execution loop
changes only its canonical CALL argument from readonly to mutable record state;
scalar/control algorithms and public execution branches are unchanged.

Abort retains prior payload writes and copied owners after successful loan drain,
preserving the original result/error. Failed drain keeps diagnostic CALL/maps.
Native callers still dispose owned storage/backing; abort does not roll back copies
or external effects. Existing fixed limits remain eight arguments, 16 owner and
pool slots, 32 VM frames, 31 pending events and 128 bytes per record value.

## Verification and remaining work

```text
python -B tools/verify-m2-slice-elements.py --profile development --record-call-authority
python -B tools/verify-m2-slice-elements.py --profile release --record-call-authority
```

The selection covers six new record-CALL, six owned-array, six shared, six scalar
and eight existing public/legacy record-CALL groups. New cases cover all scalar
field tags/wide edges, eight repeated records, recursion/frame reuse, mixed arrays
and loans, nested padding normalization, actual independent copies, exact/short
Fuel, late quota/nested-bool/stale-token/nominal failures, owner/pool exhaustion,
writer generation limits, dirty child slots, short control spans, constructor and
child-path arguments, mutable captures, tagged scalar returns, and abort write/
copy/error retention. Public regression selects 74 mutable-parameter, 222 owned
mutable, 192 readonly and 2,007 M1 CLI cases per profile.

Next is canonical scalar-array result coordination as a separate delivery, then
record results and suspended CALL proof. Full native, other M2, Linux, M0,
isolation, packaging, native size/stack, allocator and timing are outside this
selection. Local commits only; no push, publication, release or deployment.
