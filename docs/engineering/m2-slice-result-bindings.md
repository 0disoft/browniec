# Retained returned-view bindings in native frames

Date: 2026-11-04. Scope: native frame/coordinator integration toward B04.
This does not enable returned-result source bindings, a new executable IR recipe,
public compilation or a capability flag. Independent source/CFG admission is
still required before guest code can create these destinations.

## Ownership and capacity

`slice_result_bindings` stores linear Held receipts keyed by `frame * 16 + site`,
with each receipt's original caller binding. `slice_result_frames::pop` can now
publish a handed-off result into a caller slice site and leave the caller
unprepared so it can continue. Existing terminal forwarding keeps its behavior.

The sparse map has 47 entries. Sixteen physical view slots do not bound the
number of returned exclusive receipts: exclusive descendants reuse the same
physical slot with new generations. Native tests retain seventeen such receipts
across two caller frames while using one physical writer slot.

Shared Held receipts occupy distinct physical slots, at most sixteen. Each
exclusive Held owns a canonical child entry, at most thirty-one. If any exclusive
receipt exists it also occupies a physical slot, leaving at most fifteen shared
ones: at most 46 canonical live receipts. One additional registry entry permits
publication of the incoming result before clearing a callee's consumed receipts.
The conservative capacity is therefore 47. This changes no owner, pool, authority,
static-site or frame limit. It is a bounded metadata argument, not a measured
memory/stack/performance result.

Locations are unique. An exact issued ticket cannot be registered twice, while
exclusive descendants with the same physical slot and different generations are
distinct receipts. Native callers must still preserve linear receipts and the
single canonical runtime; this module is not a hardened C ABI.

## Closing and forwarding

The existing private loan adapter recognizes a retained result on CLOSE/END.
Canonical `runtime::close` authenticates the current generation, selected view,
descendant stack and root ownership before publication. Successful exclusive
close writes its fresh parent ticket into the saved caller site. Shared close
leaves the original parent binding alone. The result site and receipt are then
cleared. Descendant use and ordinary CALLs can rotate the ticket; close must use
the caller site's current ticket rather than the originally issued generation.

A failed close, wrong generation, out-of-order descendant or final root release
keeps the binding and canonical runtime intact. A successful handoff already
prepaid its finalizer; result close preserves the supplied Fuel, including zero.
Existing unretained slice closes retain their usual schedule.

Terminal forwarding first commits the canonical handoff, then clears the
callee's consumed Held records. It does not close those records a second time.
An ordinary scalar/array/record return instead rejects any still-live Held in
its frame; its source cleanup must have closed them. Invocation failure still
uses the existing abort reserve and drains native metadata; invocation-private
frame bindings do not escape that failure.

## Verification and remaining B04 work

Five native groups cover shared continuation, mutable writes/fresh parent
restoration, terminal forwarding, seventeen simultaneous same-slot generations,
duplicate/stale receipt rejection and transactional failure of the final root
drop. The tests exercise the native APIs directly. They are not evidence that
source result bindings or new guest instructions are admitted.

Next connect source CALL results to these destinations with independently proved
exact types, selected input origins, whole-root exclusion, CFG joins, backedges
and lexical cleanup. Selected anonymous captures need owner/parent retention
until result close; unselected argument captures still clean up after the CALL.
Only then admit the new execution recipe and demonstrate public source behavior.
Argument/projection use, Static backing and broader reference types remain open.

Final Windows development passed **43 native groups and 217 tool-free CLI cases**;
release passed the five new binding groups. The development selection also covers
frames, scalar entry, existing scalar/owned-array/record execution and Fuel. All
509 captured input hashes match, all 114 production files are LF, and a separate
LF source/manifest/lock mirror passed `check --locked`. No native result reuse or
stack/compiler overrides were used. See the
[retained evidence](../evidence/m2-slice-result-bindings-windows-20261104.json).
Full M1/other M2, Linux, restricted delivery, DLL/ABI, packaging, allocator and
size/stack/performance checks were not run. The release selection is smaller than
development; do not report 43 groups for release. Local only; no remote delivery.
