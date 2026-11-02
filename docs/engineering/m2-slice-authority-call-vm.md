# Private canonical exclusive CALL argument binding

`slice_authority_call_vm` connects scalar/exclusive-formal CALL binding, formal
release, return and abort to the [canonical authority stack](m2-slice-authority.md).
The stack is the only persistent owner of Batch/Loan receipts. The adapter keeps
31 immutable CALL-PC cells and 248 detached-ticket cells; it derives caller,
target, formal positions and caller source sites from inspected immutable IR.
It does not persist a second copy of those maps or any handoff receipt.

This is a direct native frame transaction, not shared-core dispatch or guest
reborrow support. The existing public mutable CALL adapter is unchanged. This
private bridge rejects shared/owned arguments, aggregate results and derived
reborrow CALL sources. Scalar/control copying and all unrelated callee value/loan
cleanup remain the VM coordinator's responsibility. There must be at least one
exclusive formal. An independently inspected immutable Program and its matching
Sites are required throughout the invocation.

## Admission, origins and price

For the admitted scalar/exclusive subset, the logical CALL price matches the
existing mutable CALL price:

```text
1 + arity + 65537 * (1 + 2 * exclusive_formals)
```

It prepays bounded entry/return/abort metadata work. Release costs 4,097; normal
return uses its prepaid reserve. These are logical Fuel costs, not native timing
claims. Static unsupported shapes fail before admission. A short budget fails
before runtime maps, source tickets, frame state or generation lookup. The next
event beyond the combined31 bound returns kind12 before publication.

Entry validates all original source capabilities and an unused child frame.
The formal tag/mode must match exactly. Shared origin cells and caller tokens
must agree with canonical lease roots and immutable argument positions. Only a
successful canonical handoff publishes the CALL PC, clears writer source
bindings and publishes child tickets/origins. There is no fallible owned copier
in this subset, and no fallible work follows pool/receipt publication.

Generation headroom uses the combined pending restoration depth, including
native subranges of unrelated roots. VM frame depth alone is not sufficient.
The PC map is indexed by authority-event position, so intervening child receipts
do not collide with CALL records. Zero-writer native CALL events can remain
unmapped and still count toward frame/depth limits; this adapter does not itself
admit such calls. Native callers must keep the complete canonical state unique.

`origin` resolves an owned source or an exact mutable formal anchor through its
canonical CALL entry. Formal origins survive release and nested forwarding;
this does not make a suspended/detached ticket accessible. `view` additionally
requires the current frame, an available formal binding, the exact issued pool
slot, a current generation, the original selected range and the same write
session. Parent origin records cannot authorize data access while a child frame
is active. All mapped CALLs are validated before public adapter operations;
origin resolution alone is not an alternative to invocation-state validation.

## Release, return and failure publication

Release authenticates a live formal and moves its current ticket into one
private detached cell, preserving the root write session. Duplicate release,
read through a detached binding and simultaneous live/detached binding fail.
Nested returns may advance generations; callers must use the latest ticket.

Return requires the top authority event to be the corresponding CALL. Every
exclusive formal must have exactly one live or detached current ticket. Extra
child loans and owned array/record values must already be cleaned by the VM
coordinator; this adapter rejects them rather than silently dropping them.
All inputs, origins and sessions validate before the native batch restoration.
Only success publishes fresh caller tickets and clears child bindings, origins,
PC and detached cells. A late error in a second argument cannot publish the
first argument's rotation. Scalar return/control publication is still external.

Abort drains the authentic pool before clearing canonical receipts, CALL maps,
all512 ticket cells and all256 shared origins. Cleanup failure retains metadata
and overrides the original outcome. Success retains prior payload writes and
the original success/error. Owned roots are not destroyed. Other private child
site maps owned by a future outer coordinator must be cleared only after a
successful drain; this module does not duplicate their ownership.

## Scope, verification and next step

No Program, signature, owner, pool-slot, shared-frame, opcode, public capability,
existing public price or payload extent changes. Private metadata adds PC and
detached-ticket cells; native size, stack, allocator and timing are unmeasured.
The new module has no dependency on the owned reborrow adapter, allowing that
adapter to reuse canonical formal-origin authentication in a later integration
without a module cycle.

```text
python -B tools/verify-m2-slice-elements.py --profile development --authority-call-vm
python -B tools/verify-m2-slice-elements.py --profile release --authority-call-vm
```

Six new native groups cover six scalar writes, exact/one-short prices, live and
detached return, 31 recursive handoffs, surviving origins after forwarding,
interleaved scalar/two-writer positions, late multi-argument failure, corrupt
origins/PC maps, combined-depth generation exhaustion after30 unrelated native
subranges, empty ranges, abort preservation and explicit unsupported-mode gates.
Each native transition receives its own sufficient Fuel; this is not evidence
that the public CLI's unchanged one-million invocation budget executes31 calls.
The selection also runs six legacy mutable CALL, six authority and six owned
reborrow adapter groups, plus74 mutable parameter,222 owned mutable,192 readonly
scalar and2007 M1 CLI cases on Windows.

Next, reuse these canonical origin/argument bindings for rootless mutable-formal
reborrow transitions and data dispatch, then integrate CALL/scalar/control and
normal/abort lifecycle into the shared execution core without duplicate receipts.
Suspended CALL inspection, reborrow execution and guest/public promotion remain
separate and gated. Full native, other M2, Linux, M0, isolation, packaging and
performance are outside the selection. No push, publication, release or deployment.
