# Atomic caller capture END chains

Date: 2026-11-04. This is a B04 native/IR prerequisite for direct returned CALL
arguments and reference-valued range projections. Source syntax for those forms
is still pending; the full [completion objective](completion-plan.md) stays open.

## Why the one-END restriction was insufficient

A returned exclusive slice can itself become another call's actual. Its hidden
ancestors can contain several returned Held receipts and ordinary reborrows.
After a reference-returning call, unselected actuals must be restored before the
new selected child is installed. Closing them afterwards can conflict with that
new top loan. Retaining every unselected temporary would incorrectly extend its
borrow and reject valid subsequent access to an independent root.

The existing private CALL_BIND recipe now supports a complete caller END chain
per masked actual. No new opcode, serialized format or public capability exists.

## Independent proof

CALL_BIND byte4 still indexes formal argument positions. END_CAPTURE (68) keeps
its existing child/parent/zero operands. An END may refer to a preexisting BEGIN
(61) or exclusive BIND_RESULT (67). Every link must follow that actual's unique
real definition and exact parent. The complete END list is in reverse acquisition
order; independent normalized CFG/loan proof checks the logical closes before
BIND_RESULT installs the new child.

`slice_result_call_ir::chain` reconstructs each actual's count and surviving
anchor from those markers. Every set mask bit must have a nonempty chain; every
marker must belong exactly once to a marked actual; no extra/missing/reordered
link is accepted. The selected anchor is the endpoint of the selected chain.
Opaque CALL result IDs, exact type/access, origins, recipes and CFG-entry gates
retain their prior independent checks. Helper count/map/argument bounds are
checked before table indexing.

## Native transaction and linear receipts

Private Capture metadata adds `ends`. The existing `capture(ticket,close,drop)`
constructor retains zero/one-END behavior. The VM uses `chain_capture` only after
independent recipe admission. Multi-END captures are bounded by sixteen, exclusive,
reference-returning and non-dropping; malformed combinations reject in entry.
Guest code never provides an unchecked numeric close count.

The VM authenticates any caller Held records named by END markers before entry.
Native handoff stages restoration and all exact ENDs in reverse actual order,
then installs the new selected view under its surviving anchor. Any missing,
wrong-frame, wrong-slot or non-top child fails without committing that staged
handoff. Real returned bounds survive chain collapse.

After successful native handoff, frame publication clears each consumed child
site, retires its already-consumed Held receipt, and publishes fresh resumed
parents at the final anchors. Retirement does not call Held.close again.
END_CAPTURE remains a one-dispatch committed marker, and later result cleanup
uses its ordinary prepaid close. Selected and unselected anonymous chains are
both consumed; no obsolete Held may block an ordinary frame return.

## Bounded work and Fuel

Operation prices and CLI limits are unchanged. Each extra END marker consumes
its normal dispatch unit. Caller and callee children share one 31-entry canonical
authority stack, including the active CALL: callee child unwind plus caller END
unwind is at most 30 total, replacing the earlier independent 30+8 estimate.
The existing 96 pool-primitive handoff allowance therefore still covers the chain
work; Held finalization and failure abort remain prepaid.

Across eight actuals, at most sixteen distinct source sites can end. Reconstructing
all chains visits at most 8*256 recipe records, 8*16 markers and 16*256 definition
records (6272 visits). Entry's receipt preflight adds at most 16*256 definition
and 16*47 sparse-receipt visits (4848). Frame publication adds at most 16*47
retirement visits plus the chain reconstruction and bounded direct updates.
These additions fit the existing 32768 fixed staging/publication allowance.
They are algorithmic allowances, not native time or stack-size measurements.

## Verification and next source bridge

The [Windows record](../evidence/m2-slice-result-capture-chains-windows-20261104.json)
retains final inputs, test-discovery identity, compiler, commands and outcomes.
Windows development passed 15 native groups (three new, nine independent IR
and three affected native CALL regressions); release passed five (three new and
two affected CALL regressions). All 123 final inputs and the 213-file discovery
identity match. All 117 production files are LF; an LF mirror passed
`check --locked`. No stack/compiler overrides or historical-result reuse. Final
selections ran after the snapshot; exploratory results are excluded.

Direct IR fixtures move four existing canonical ENDs into one recipe: two nested
Helds for each actual, both selected positions, a real returned subrange, fresh
parent reads, ordinary frame return, exact/one-short Fuel, preserved writes and
complete invocation drain. Mutation cases reject wrong masks, parents, duplicate
links and helper argument overflow. Existing single-END, recursive, native owned
entry and independent recipe cases are selected for regression.

The [direct-argument successor](m2-slice-result-arguments.md) connects nested
returned actuals and argument ranges to this prerequisite. The bridge requirements
below record that original next step; declaration/return range projections remain
open:


- Evaluate a nested returned actual with CALL_BIND, then publish its hidden owner/
  parent ancestry in acquisition order before later argument/endpoint expressions.
- For exclusive temporary chains, emit their ENDs in reverse acquisition order
  and bind under the final surviving named/root-view anchor. Preserve the selected
  owner through the outer result lifetime; release unselected captures promptly.
- Preserve the selected shared ancestry transitively. Ordinary scalar/aggregate
  CALLs can use existing reverse capture cleanup after they return.
- Follow selected nested actuals recursively in advisory source-origin inference;
  independent definition/CFG proof must continue to establish authority.
- Parse range endpoints fully before acquisition, keeping hidden dependencies
  visible to exits. Publish a user binding only after its delimiter; do not create
  duplicate cleanup bindings for one anonymous site.
- Connect direct return/nested/ranged forms and immediate scalar projections to
  these same recipes, then verify source-to-execution cases before promotion.

Static backing, other B04/B05 forms, ordinary public Program/CLI admission and all
remaining language/runtime/delivery features remain in the accepted inventory.
Standalone CLI, full M1/M2, Linux, restricted/ABI/packaging, allocator instrumentation
and timing/stack-size benchmarks are outside this increment.
