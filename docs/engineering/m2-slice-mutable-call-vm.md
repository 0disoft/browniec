# Private mutable slice CALL frame adapter

`slice_mutable_call_vm` now connects the [exact mutable argument proof](m2-slice-mutable-call-ir.md)
and [generation handoff protocol](m2-slice-exclusive-call-handoff.md) to native
frame admission and return. Mixed owned, shared and exclusive arguments publish
atomically. A private per-CALL receipt restores fresh caller tickets after the
child releases its mutable formals, without ending their root write sessions.

This is a native frame transaction, not executable mutable CALL dispatch. The
shared VM loop, scalar/control publication, mutable formal instruction adapter,
guest parameter grammar and public admission are still unconnected. Existing
public owned mutable slices and readonly CALLs retain their current paths.

Implementation: `6ea599c`.

## Entry transaction and cost

The caller supplies an immutable independently inspected Program, invocation-owned
state and one unique `Frame` receipt per active mutable CALL. Receipts must not
be cloned. The `shared::Frames` root bindings and existing sixteen-slot pool keep
their layouts; the new private receipt stores its batch, source/formal/argument
maps, detached tickets and parent/caller/target identities. No Program fields,
shared Frames fields, pool-slot fields or guest pointers are added.

Entry computes the complete private CALL cost before runtime source resolution:

```text
1 + arity + existing_owned_copy_cost
  + 65537 * (1 + shared_formals + 2 * exclusive_formals)
```

The final term prepays frame cleanup, shared retention, exclusive entry and
return restoration. It is a bounded logical Fuel reserve, not a native timing or
machine-instruction claim. Formal binding release costs 4,097, matching existing
close prices; return restoration consumes its prepaid reserve. Existing public
and readonly prices are unchanged. At least one mutable formal is required.

After Fuel admission, entry rejects frame depth31, an active receipt, occupied
child loan/root bindings and child array/record owners. Every original source
must resolve to the expected function/frame root, exact element and access mode.
Empty selected ranges remain valid, while the underlying array has length1..4096.
All sources are checked before any planned retention or generation rotation.

Shared handles are retained in a local pool copy. Exclusive handles rotate in
that same unpublished pool using absolute parent depth to reserve generation
headroom. Mutable sources must be unique by ticket/root; readonly duplicates
remain legal. The existing atomic array/record copier runs last. Any late codec,
owner, capacity or quota error discards the unpublished pool and receipt without
consuming caller generations, owner sessions or payload bytes.

Only after copies succeed does entry publish the pool, clear suspended caller
writer bindings, bind all child tickets/origins and activate the receipt. Scalar
registers, return registers and return-PC/destination publication belong to the
future VM coordinator; this adapter does not publish them. Slice transfer creates
no additional owner or payload extent. Owned value arguments still make their
normal independent array/record copies.

## Formal release and normal return

`release` prepays 4,097, authenticates the live exclusive formal against its exact
issued session/range and stores its latest ticket in the private receipt. It
clears the child binding while preserving the pool handle and write lock. Repeat
release, malformed issued generations and stale/mismatched tickets fail before
publication. Guest instructions cannot use the detached capability. The root is
still inaccessible until the restored caller eventually closes its own slice.

`leave` checks the receipt/function/frame, unique canonical maps, formal origins,
empty suspended caller bindings and exact original caller roots. Each writer
must have exactly one current capability: a live child binding or a detached
receipt entry. Nested returns may have advanced its generation. Missing,
duplicated, stale or changed-session tickets fail without publishing state.

Ordinary child loans are closed in staged pool/owner metadata. Exclusive restore
then validates all receipts and rotates fresh caller tickets against that staged
state. Only success publishes owner/pool metadata, caller tickets and cleared
child roots/bindings/receipt. Thus late restore failure cannot partially end the
child's readonly sessions. Existing owned aggregate cleanup and result transfer
remain the VM coordinator's responsibility; this adapter handles loans only.

Thirty-one nested handoffs fit the existing 32-frame bound without extra pool
slots or owners. Receipt reuse requires a successful return. A full sixteen-slot
pool can transfer eight writers when no new shared handles or owned copies are
needed. Shared retains and owned copies still require their normal capacities.

## Abort cleanup

`finish` accepts the invocation's complete receipt collection, at most32 entries.
A single atomic pool drain ends all live sessions, including detached formals;
suspended callers are not restored during invocation abort. Successful drain
clears receipts, roots and ticket bindings, preserving the original result/error
and prior payload writes. Failed drain surfaces cleanup failure and retains
metadata for diagnosis. Owned roots are not destroyed by this loan-only helper.

## Verification and next integration

```text
python -B tools/verify-m2-slice-elements.py --profile development --mutable-call-vm
python -B tools/verify-m2-slice-elements.py --profile release --mutable-call-vm
```

Six new native groups cover all scalar tags and actual relative writes, exact/
one-short Fuel, empty ranges, formal release, 31 nested frames, receipt reuse,
full-pool eight-writer transfer, mixed owned/shared copies, late codec/quota/token
failure, occupied child owners, corrupt return maps/origins/sessions and abort
success/failure. Five legacy mixed CALL groups and four readonly frame groups
cover unchanged existing paths. CLI regression covers 222 public owned mutable,
192 readonly scalar and 2,007 M1 cases. New mutable CALL evidence is native
adapter execution, not guest source or shared VM-loop execution.

Development and release each passed 15 selected native groups and 2,421 CLI
cases, with 366 identical current input hashes. The pinned compiler, retained
CLI and matrix/M1 receipt identities were rechecked, and the Program declaration
still matches `2135237`. Both profiles accept parser depth32 in check/run and
reject depths33/64 with `compile_limit`. Both complete selections ran all
15 groups without report reuse. See the
[Windows evidence](../evidence/m2-slice-mutable-call-vm-windows-20261101.json).

Next, publish scalar/control frames through the shared CALL coordinator, route
mutable formal instructions through authenticated root/binding resolution and
use binding release rather than session close. Connect normal scalar/aggregate
returns and invocation cleanup before enabling mutable source parameters or
public admission. The legacy mutable-signature gates remain intact in this slice.

Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks
are outside this selection. No native memory/stack/performance measurement is
claimed. Local commits only; no push, publication, packaged release or deployment.
