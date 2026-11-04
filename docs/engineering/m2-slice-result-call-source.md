# Source lowering for returned CALL bindings

Date: 2026-11-04. Scope: typed lexical borrowed-result initializers in the private
returned-view dialect. This connects source lowering to the independently proved
[CALL-binding IR](m2-slice-result-call-ir.md). Public syntax remains gated;
[private native binding dispatch](m2-slice-result-call-execution.md) is connected
by the successor. The [full completion objective](completion-plan.md) remains active.

## Source and construction

The private compiler now lowers both access modes for all six scalar elements:

```brownie
let ref i32[] r = select(ref p, ref q);
let ref mut i32[] w = change(ref mut p[1..]);
```

The initializer's callee must have the exact element/access result signature.
The binding remains absent from lexical lookup until the complete initializer
and semicolon finish. Existing `= ref [mut] name[range]` initializers retain their
syntax and cleanup. The public compiler still rejects every returned-reference
function declaration, including unreachable functions, before body lowering.

The private lowering pass invokes `slice_result_source_origins::infer` once on
fresh scanned signatures before lowering bodies. These advisory hints select a
candidate actual; independent recipe/CFG/definition-origin proof must agree.
They are never copied into the unit's claimed origins as admission facts.
`inspect_slice_results` now also uses private unit construction and independent
recipe proof, rather than attempting to verify extended opcodes as ordinary IR.

Arguments and endpoints still evaluate once, left to right, through the existing
captured CALL path. A zero witness register is defined before them. The separate
`slice_result_call_source` module constructs CALL_BIND/END_CAPTURE/BIND_RESULT;
it does not widen the recursive scalar CALL's shared lexical-table contract.
No new Program field, instruction kind, public capability or Fuel price is added.

## Captures and lifetime

- Existing named input: bind under its exact caller site.
- Anonymous exclusive named range: emit the existing END in reverse capture
  order, annotate it as END_CAPTURE, and bind under the surviving lexical parent.
  Mask bits retain formal argument positions, including mixed scalar arguments.
- Selected anonymous shared range or owned-array view: retain the anonymous
  parent. If its owner is temporary, retain that owner as well.
- Unselected array/record/view captures: use the same canonical lexical release
  operation as ordinary CALL cleanup. They are not retained with the result.

After finalization, hidden retained names are published in owner-then-parent
acquisition order, followed by the user's result name. Reverse lexical exits
therefore close the returned result, then its anonymous parent, then its owner.
The selected original literal/owned CALL result is not recreated or copied.
The result's actual range remains supplied by the callee, not by the zero IR
witness. A returned binding can itself back aliases and returned-reference
functions; origin tracing follows the real CALL and alias definitions.

`array_source::release_at` centralizes one lexical finalizer so selective capture
retention does not duplicate DROP/CLOSE logic. Slice cleanup recognizes exclusive
BIND_RESULT definitions and emits the matching END, preserving ordinary CFG and
loan-stack checks through scopes, returns, loops and branches.

Compile-time source/token/site/local limits remain unchanged. Temporary retention
can consume bounded owner/site/local capacity until the lexical result closes;
exhaustion still rejects or traps under the owning limit. This is not a heap,
allocator, native stack-size or performance claim.

## Execution and evidence

This source increment constructs independently admitted IR. The
[execution successor](m2-slice-result-call-execution.md) now routes native
destinations, consumes END_CAPTURE exactly once, publishes fresh resumed tickets
and retains selected parents/owners through actual cleanup. Ordinary public
admission/dispatch, arguments/projections and Static backing remain open.

The [Windows evidence](../evidence/m2-slice-result-call-source-windows-20261104.json)
records 18 development native groups (six new source, eight existing origin and
four existing return-range groups), plus the six new source groups in release.
All 123 captured raw inputs and the aggregate identity of all 209 test-discovery
files match. All 117 production files use LF; an LF mirror passed `check --locked`.
Standalone CLI and broader/full-profile/platform/delivery/performance checks were
not run. The semantic interpreter cannot execute the compiler's reachable
UTF-8 byte-slice operations; no semantic execution pass is claimed. Exploratory
runs are excluded. Final native runs use default compiler/stack settings.

## Runtime connection (implemented by successor)

CALL_BIND must pass its result site as the frame destination and mark only its
END-mask captures for native handoff cleanup. Returned resumed tickets for these
captures belong to the original surviving parents, not the dead anonymous child
sites. Retain Held under the proved parent (byte6); END_CAPTURE and BIND_RESULT
then account for the already committed transfer without acquiring/closing twice.
Ordinary later CLOSE/END must consume the prepaid Held receipt and publish the
fresh parent ticket. Selected anonymous parents/owners stay alive through their
existing lexical cleanup, while unselected captures keep immediate cleanup.
Verify nested/forwarded results, selected temporaries, failure draining, initial
failure preservation and exact/one-short Fuel before lifting the native gate.
