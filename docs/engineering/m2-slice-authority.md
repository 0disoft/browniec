# Private combined CALL and reborrow authority stack

`slice_authority` owns the pending native receipts for exclusive CALL transfers
and lexical subrange suspension in one invocation. It joins the existing
[CALL handoff](m2-slice-exclusive-call-handoff.md) and
[subrange transaction](m2-slice-exclusive-reborrow.md) without exposing receipts
to guest code or requiring the caller to guess their combined reserve depth.

This is native transaction coordination. Source grammar, Program fields, private
op61/62 execution gates, public capabilities and existing Fuel prices remain
unchanged. Existing mutable CALL execution still uses its current frame adapter.

## Admission and frame ownership

The stack admits at most 31 pending restoration events. A CALL batch is one event
even with eight exclusive arguments; a child subrange is one event. A CALL with
no exclusive arguments still consumes an event and advances the frame counter.
The root runs at frame0 and CALLs may advance through frame31. Reborrow does not
advance the frame counter. Every entry records the frame that created it.

`enter_call` and `enter_child` validate bounded entry occupancy, frame ownership,
receipt kinds and reserve depths before touching the pool. The actual combined
stack depth goes to the existing primitive's generation-headroom check. Thus a
CALL at VM frame0 with six pending subrange restorations reserves for depth6,
rather than merely reserving its own return. In this stack, the legacy
`handoff::Batch.frame` field denotes combined reserve depth; its meaning on the
existing public mutable CALL path remains unchanged. Empty CALL batches retain
the primitive's canonical zero reserve while the stack counts their frame/event.

Only child tickets escape from entry. The stack retains canonical receipts and
owns their lifetime. Callers must keep the invocation state unique, must not
clone or mutate receipts, and must not perform unrelated pool rotations or owner
session changes. The host supplies the latest tickets after nested returns.
Frame arguments must match the stack's current frame.

## Return, failures and abort

`leave_child` restores only a child at the top of the stack, in its creating
frame. `leave_call` restores only a CALL at the top, from the corresponding child
frame. It cannot skip outstanding lexical children. Successful restores replace
stale tickets with fresh generations, clear the consumed entry and update the
combined depth; CALL return also decrements the frame counter.

The protocol is deliberately strict reverse order across independent roots too.
The current IR inspector permits some independent-root lifetimes that this
native protocol does not execute. A future VM adapter must align its independent
root lifetime policy with receipt ownership before admitting op61/62. Existing
IR remains inspection-only and public/internal execution continues rejecting it.

The existing native primitives stage/validate every input before pool publication.
The stack stages its receipt locally and publishes/clears entries only after the
primitive succeeds. Capacity, generation, stale-ticket, wrong-frame, wrong-order,
duplicate-source and late multi-argument return errors preserve both canonical
stack and pool. Payload writes made before a later failure remain visible.

`finish` is invocation abort, not lexical close. It atomically drains the pool
before clearing all fixed receipt cells. Failed drain retains all metadata.
Successful drain retains owned payload and prior writes. Corrupt receipt-stack
metadata does not block authentic pool cleanup. External VM binding tables and
the original execution result are the future adapter's responsibility.

## Bounded storage and remaining integration

Native private storage uses 31 logical entries in fixed columns: 248 CALL ticket
and lease cells, 31 child receipts, kind/frame/count/reserve columns and two
counters. This avoids unsupported nested array mutation in the pinned compiler.
CALL and child backing are both reserved; this is not a compact tagged union or
a measured memory optimization. Validation visits 31 entries and publication
copies at most eight CALL ticket/lease pairs. No owner, pool slot, Program,
signature-table or shared CALL-frame field grows, and no payload extent or copy
is added by the transfer/reborrow transaction. Native size, stack, allocation
and timing measurements were not performed.

A future metered VM adapter must authenticate Program site/frame bindings,
account for shared arguments and owned copies, publish scalar/control state,
route every CALL (including one with no writers) through combined admission,
coordinate normal aggregate returns and preserve the original outcome on abort.
It must reconcile the existing mutable frame adapter with this canonical stack,
rather than keeping duplicate live receipts. Metering and independent-root
lifetime policy precede private executable dispatch; guest/public promotion
remains separate.

## Verification selection

```text
python -B tools/verify-m2-slice-elements.py --profile development --authority
python -B tools/verify-m2-slice-elements.py --profile release --authority
```

Six new native groups exercise all six scalar tags and relative writes across
alternating CALL/child returns, 31 mixed events, exact/one-short combined
generation reserves, stale/duplicate inputs, wrong frames/kinds, atomic late
multi-argument failure, full sixteen-slot abort and empty-CALL frame counting.
They run with six native subrange groups, six CALL-handoff groups and six IR
proof/public/internal-gate groups. Public CLI regression includes 74 mutable
parameter, 222 owned mutable, 192 readonly scalar and 2007 M1 cases on Windows.
New combined execution evidence is native coordination, not guest VM execution.

Implemented at `d0567c6`. Development and release each passed all 24 selected
native groups and 2,495 CLI cases, with 378 matching current inputs. Compiler,
retained CLI and all matrix/M1 receipt identities were rechecked. Program and
signature declarations, owner/pool/native handoff/reborrow, existing frame
helpers, verifier, execution core and CLI/compiler entries match `bc44a1f`.
Both profiles accept parser depth32 in check/run and reject depths33/64 with
`compile_limit`. See the
[Windows evidence](../evidence/m2-slice-authority-windows-20261102.json).

Full native, other M2, Linux, M0, isolation, packaging and performance are outside
this selection. Local commits only; no push, publication, release or deployment.
