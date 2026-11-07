# Shared Buffer-view value joins

Private typed source lowering now carries shared `ref u8[]` values through
`if`/`else if` and exhaustive `Option`/`Result` switch expressions. All continuing
edges must have the same exact Buffer or formal origin. Windows may differ;
terminal return/break/continue edges contribute no continuing descriptor.

## Lowering and lifetime

The first yielding edge reserves one compiler-only view destination. Alternative
selection preserves active reservations, so a later RHS cannot allocate that
destination before publication. Each yielding edge captures a named source once
and emits existing MOVE108 into the Dead destination before arm cleanup. Nested
joins release their reservation after merging. Reservations create no runtime
descriptor, payload storage, Program field, instruction or executable authority.

Origin/name/liveness state must agree at the join. Temporary-retention hints
intersect across continuing edges: a CALL on only one edge cannot grant retention
on another. Lexical owners cannot escape their arms; surviving aliases pin outer
owners until their final close. The unchanged independent origin CFG proves both
the destination's prior Dead state and its exact origin on every executable edge.

Advisory return inference now walks mutable declarations/rebindings and structured
value/control paths. It preserves selected-formal summaries through forward and
grounded recursive calls; conflicting inputs, local roots and ungrounded cycles
remain errors. Hints never bypass the independent signature, value or view proof.

Existing opcode prices, no-view setup, public Fuel default 256/ceiling 16000000 and
ordinary/public admission remain unchanged. No payload copy or native escaped
view is introduced.

The ordinary scalar postfix parser also distinguishes a range delimiter `..`
from Result member access. This restores computed range endpoints used by
existing returned references. Read-only Result lookahead stops at that delimiter
so an upper endpoint cannot change the lower endpoint's expected type. Existing
returned-reference and Result handling tests are included in the final native
selection.

## Verification and remaining scope

`tools/verify-value-view-joins.py` runs disjoint `core`, `proof`, `regression` and
`origins` batches in locked native mirrors. Each defaults to Windows development
and release on the pinned compiler with default native stack limits. New source
cases run actual compiled programs; hand-authored CFGs test independent admission.
The original admitted32/rejected33 fixture is retained as a regression.
The 54 private source fixtures keep small helper scopes but run in six native images rather
than eighteen. Each guest retains fresh compilation, proof and invocation state;
the test driver does not hold a large Program across helper calls.

Different-origin joins (including independently created anonymous roots), general
mutable/non-byte/Buffer-object references, public admission, host/I/O, lifecycle,
isolation and platform/delivery obligations remain in the
[remaining-work inventory](../product/04-remaining-work.md). A value expression
with no yielding edge still needs general bottom-value lowering.

## Executed verification

Implementation `5555e4a` passed 68 groups in each Windows native profile:
core 9 (source 6/bindings 3), proof 16 (IR 8/origins 8), regression 25 and origins 18.
The source suite contains 54 private source fixtures and an additional
public compiler rejection; the new advisory inference suite adds 25
cases. The IR suite constructs and mutates independent CFGs. These are scoped
checks, not full-profile conformance or a public CLI run.

All 235 union inputs match both checkout bytes and Git raw objects;
all 216 production modules use LF. The unchanged admitted32/rejected33
fixture ran with default native stacks. See [focused evidence](../evidence/value-view-joins-windows-20261107.json).

General loop-backedge origin inference is not implemented by the new advisory
walker. Existing exact-origin loop verification and its tested view cleanup remain
mandatory; this increment does not claim general last-use or origin-set analysis.
