# Private returned-view handoff and capture lifetime

Implemented at `7f8f455`, with anonymous mutable capture restoration at
`b82500d`, following `ba1a62a`. This is a real native ownership transaction over the
existing array owners, slice pool and canonical CALL/reborrow stack. It does not
execute guest returned-view IR or enable public borrowed-result source.

## Ownership and admission

`slice_result_runtime::State` is one invocation-owned metadata coordinator. Its
Runtime contains the canonical authority, owner table and slice pool. Backing
payload bytes remain external and are never copied by these transactions.

`contract` independently checks a private returned-view IR unit and derives exact
formal scalar/access tags and the selected one-based input position. Scalars and
other nonborrow formals occupy absent capture positions. A Contract is a trusted
compile-derived native snapshot, not an untrusted serialized capability or C ABI.
The final VM adapter must bind it to its immutable Program/function.

`enter` authenticates all original tickets before any retain/rotation, then stages
canonical writer CALL transfer and independent readonly formal tickets. A Capture
states whether the caller owns an anonymous view and/or its temporary array root.
Owning a root requires owning an independently opened view/session. Anonymous
mutable reborrow captures instead own one caller-side restoration, never the
parent session or owner. Duplicate shared handles cannot claim
conflicting view ownership. Native Call and Held receipts are linear: do not clone,
forge, publish twice or mutate them. Callee readonly formal tickets stay live until
handoff; the eventual dispatcher must arrange cleanup accordingly.

## Atomic return

`handoff` authenticates the selected live ticket, exact root/generation/type/access
and contained range against the chosen actual. It stages all state in local metadata:

1. Unwind callee lexical mutable descendants in canonical reverse order.
2. Authenticate and restore the CALL's writers privately, then pop the callee frame.
3. End anonymous mutable argument reborrows in reverse capture order before
   installing the result. Restore their named parents privately; preserve the
   selected returned range separately. Independently opened anonymous views use
   CLOSE instead of END. Result depth is the resulting canonical depth, not the
   old CALL depth. Both earlier/later selected argument orders are supported.
4. For an exclusive result, install a caller-frame child before publication. The
   fresh parent ticket remains only in the canonical restoration receipt; caller
   bindings receive no selected parent ticket while the result is live.
5. For a shared result, rotate the selected live slot's generation in place. Keep
   its read session, including when all sixteen pool slots are occupied. The
   callee's old handle becomes stale without an allocation or payload copy.
6. Close callee-created readonly handles and unselected anonymous captures. Drop
   unselected temporary roots once per root; retain a selected temporary root until
   its result ends, even through aliased shared arguments.
7. Publish the complete Runtime, consume the Call receipt and return the held view
   plus fresh unselected named-parent tickets for caller binding updates. An
   anonymous reborrow capture may produce a resumed named-parent ticket even
   though its own capture has been consumed.

A selected mutable parent remains suspended through returned descendants. `close`
requires the canonical result child to be on top, restores its parent only after
all descendants end. A consumed anonymous reborrow restores its named parent;
an independently opened anonymous parent view closes instead. Then it drops a selected
temporary owner. Shared results close their own transferred ticket. Owner sessions
block mutation/move/drop while any appropriate result/peer view remains alive.

Nested forwarding consumes inner authority through the outer transaction. Old
inner handles/receipts cannot close the newly forwarded result. Native coordinators
must discard consumed inner receipts and update current writer tickets after nested
restorations, as with the existing CALL/reborrow APIs.

## Failure, generations and cost

Every fallible check, generation transition, owner release and cleanup occurs in
unpublished metadata. Fuel, wrong origin/access/range, stale state, capacity, late
owner-drop and generation failures preserve the live Runtime and active receipt.
Prior payload writes are neither replayed nor reverted. Result close failure also
preserves the result and its owner. No callback/allocation/payload operation occurs
between final admission and publication.

Each enter/handoff/close prepays the private conservative metadata charge
`80 * 65537` (5,242,960), with bounded 8-argument/16-slot/31-depth work and scratch.
This is not a public opcode price or a change to the CLI's 1M Fuel ceiling. It is
an internal admission/cleanup reserve, not a measured instruction count or latency.
The returned remaining Fuel is zero when admitted with that exact amount.
This deliberately exceeds the public 1M ceiling: derive/reconcile the eventual
verified VM charge before public source promotion, rather than wiring this private
reserve unchanged into public execution.

`abort` drains pool sessions, discards canonical receipts and clears invocation
owners, using the prepaid cleanup reserve even with zero execution Fuel. It
preserves generation retirement, invalidates stale handles and does not overwrite
an earlier execution error. The final dispatcher owns first-cause reporting.

## Integration boundary

The native component performs actual read/write-capable ticket transfer and owner
retention. It is not an interpreter for private opcodes 63/64/65. The existing
public compiler/VM, Program layout, prices, profiles and availability flags stay
unchanged. The [private VM dialect](m2-slice-result-vm.md) at `d468ca1` now connects
result destinations, checked preparation sites, frame registers, rootless loans
and private opcode dispatch. Its proved terminal CLOSE/END recipe routes through
these transactions. [Owned-array/ordinary CALL integration](m2-slice-result-owned-vm.md) now adds
owned roots and scalar/array CALLs through the same transaction. The
[record successor](m2-slice-result-record-vm.md) adds record locals and mixed CALL
batches. [Explicit native owned entry](m2-slice-result-entry.md) now uses the same
initial transaction. Final public metering remains pending.
General borrowed-result expressions/locals/arguments, Static and public promotion
remain separately gated. No Engine lifecycle, isolation or packaging is implied.

## Verification

Windows development and release each passed **12 native groups and 208 CLI cases**
in fresh final runs without result reuse. The native groups cover all six scalar
shared/exclusive modes, selected temporary roots, aliased shared ranges, nested
forwarding/descendants, full/exhausted slots, generation/frame errors, Fuel/late-
cleanup failure and zero-Fuel abort. Anonymous mutable argument cases cover both
selection orders and complete rollback after caller restoration/result installation.

CLI checks are 88 existing borrowed-result rejections plus 120 temporary-array
borrow regressions in cleared/tool-free environments. All 479 input hashes agree
across profiles and retained reports/artifacts were rechecked. All 103 prior
source files match `ba1a62a`; the only production addition is this native module.
Development started before `b82500d` was committed with the same final inputs;
its original recorded HEAD remains explicit in the
[Windows evidence](../evidence/m2-slice-result-runtime-windows-20261104.json).
Earlier 6+4/10-group checkpoints are historical and were not reused as final passes.

To reproduce:

```text
python3 tools/verify-m2-slice-result-runtime.py --profile development
python3 tools/verify-m2-slice-result-runtime.py --profile release
```

These are actual native component/payload checks, not guest returned-view execution
or Python model results. Full native/M1/other M2/Linux/isolation/ABI/packaging,
allocator instrumentation and native size/stack/timing were not verified. Local
only; no push, release or deployment.
