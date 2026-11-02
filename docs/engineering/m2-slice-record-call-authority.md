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

Implemented at `b35b867`, with the release field-path repair at `518a9cb`.
Development and release each passed 32 canonical CALL native groups and 2,495
CLI cases, with 393 matching current input hashes. Separate record VM/path checks
passed 10 native groups and one public wide-record CLI regression per profile.
See the [Windows evidence](../evidence/m2-slice-record-call-authority-windows-20261102.json)
for compiler/artifact identities, original receipt hashes, parser boundaries and
the additional field-path reports.
Nineteen core/public/native modules match `02e0140`, including IR, signatures,
verifier, compiler, public VM, native authority, both copy adapters, owner/pool
primitives, formal reborrow and invocation admission/cleanup. Existing
scalar/control and canonical release/return/abort bodies and authority/CALL
declarations also match. The shared core differs only in the mutability of the
record-state argument passed to canonical CALL. The remaining struct VM change
is limited to its field selector.

## Release field-path repair

The original release build returned path `[0]` for scalar ordinal 2 in a record
containing all six scalar tags. The `i64` minimum comparison consequently read
the leading `i32` field. The same guest IR succeeded in development; direct
codec and owner reads retained the minimum in release. Both canonical and public
execution reproduced the incorrect result before the repair.

The selector now stages the path array and leaf counter as separate locals and
constructs `Selection` at return. Depth 16, 128 leaves, the 4,096-visit ceiling,
error handling, payload quotas and logical Fuel prices are unchanged. The rest
of `struct_vm` matches the baseline. No Fairy C checkout or compiler binary was
modified; the underlying compiler cause has not been established.

Separate native checks exercise every mixed-width flat/nested ordinal, verify
all neighbors after each write, release storage, and rerun all eight existing
record VM groups, including maximum depth/leaves and exact Fuel/quota tests.

All ten record VM/path groups passed in both profiles. The original six-tag
source also returned 42 through each retained public CLI using a tool-free PATH.
The canonical CALL batch retains its original six record groups and assertions.
