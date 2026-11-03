# Private returned-view handoff and capture lifetime

Introduced after `ba1a62a`. This is a real native ownership transaction over the
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
unchanged. Remaining integration includes private result destination bindings,
verified preparation-site selection, frame registers, routing capture and callee-
local cleanup through these transactions, opcode dispatch and final metering.
General borrowed-result expressions/locals/arguments, Static and public promotion
remain separately gated. No Engine lifecycle, isolation or packaging is implied.

## Verification

The first development native checkpoint passed six groups: shared owner pinning,
mutable returned descendants/parent suspension, selected versus unselected temporary
owners, nested forwarding, late-failure rollback preserving payload writes, and
in-place full-pool transfer/zero-Fuel abort. Follow-up verification covers remaining
type/alias/generation boundaries, anonymous mutable argument restoration in both
selection orders, rollback after caller-restoration/result-installation, and the
unchanged public CLI gate. These are native
component checks, not guest returned-reference execution or Python model checks.
