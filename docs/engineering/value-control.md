# Private typed-source mutation and control flow

The [typed body compiler](value-body.md) now admits mutable scalar/owning locals,
ordinary `if`/`else if`/`else` statements and exhaustive Option/Result `switch`
statements through the same independently verified native value dialect. This
increment does not select that dialect in the public compiler/CLI or change
existing opcode prices, Fuel limits or capability metadata.

## Mutable destinations

`var` retains a fixed source binding. Scalar variables use the existing ordinary
STORE18/LOAD17 slots, with checked compound arithmetic and bitwise assignments.
Typed bindings retain one exact-type value slot through whole-value assignment.
RHS expressions evaluate once before the old destination is replaced. This
includes `a = identity(a)` and `a = a`: an earlier move may leave the destination
Dead, and a successful assignment reinitializes it.

`value_source_bindings::assign` preflights exact source/destination types, source
liveness, mutable permission, name metadata and the complete instruction budget.
It emits DROP90 only for an old live destination, then MOVE88 from the captured
RHS. That MOVE consumes an anonymous RHS even for a copyable type. Self-source
helper calls can be no-ops, while source expressions still have ordinary capture
and evaluation behavior. Rejections publish no partial instruction/state change.

## Independent paths and joins

Snapshots are compiler data. `select_path` selects a separately reached CFG entry
or cleanup block, including alternatives after another path returned and removed
all its names. It validates the rebased snapshot and preserves the global static
allocation high-water mark. It neither rewinds code nor restores runtime owners.
The independently reconstructed value CFG is still required before execution.

Path snapshots live in a bounded, invocation-local vector rather than recursively
copied parser frames. Parser frames retain small scoped indices; saved metadata
is released after its control construct and storage is reused by later constructs.
The pool grows on demand and guards 128 live entries, above the requirement of the
existing 32 source-depth bound. Allocation failures return the existing allocation
error. These indices are never guest values, native owner handles or a disk cache.
Development execution reproduced a stack overflow in the unchanged admitted
32-level conditional test even after moving snapshots. Generated-C inspection
then found whole-IR/name-table temporaries caused by direct nested value field
reads. Explicitly borrowing the nested metadata before scalar reads removes those
copies from recursive frames. Diagnostic MSVC 19.51 `/Od` listings show conditional
reservation 16904 -> 4104 bytes, block 6488 -> 4664 and switch selection
18520 -> 5800.
These are emitted frame reservations, not total process-stack or RAM measurements.
Final native execution, rather than an optimized-only pass, validates the fix.

Each continuing arm records a forward jump and exact exit state. Terminal edges
do not participate in a later join. Equal continuing live sets merge directly.
For unequal sets, `value_source_control::join` emits real DROP90 cleanup blocks
and converges to the live-set intersection. A name moved on either continuing edge
is therefore Dead afterward; reading it rejects, while a mutable destination may
be reinitialized. No owner is revived and no runtime conditional-drop flags are
introduced. Surviving lexical names/types/mutability must still match exactly.

## Exhaustive tag statements

`switch` evaluates and captures its subject once, admits exactly the two distinct
variants and lowers them through CASE92. Matching move-only wrappers are consumed
as whole types, including inactive Buffer alternatives. Copyable subjects remain
live until their explicit anonymous-value drop. None has no child slot; guarded
payload slots are initialized only on a matching edge.

Scalar payloads are read through SCALAR_READ96 into ordinary capture registers.
Buffer/nested payloads become lexical typed bindings, or are dropped immediately
for `_`. Arm-local declarations and payload names leave scope together. Mismatch
edges select the original subject state; final mismatch reaches the existing
failure terminal, whose native ledger cleanup remains prepaid. Duplicate/missing
variants, leaking capture names and reads of moved subjects reject.

## Verification and remaining work

`python -B tools/verify-value-control.py --profile development` and its release
counterpart use fresh locked production/selected-test mirrors. The selection has
29 native groups: six source control, six mutation, three CASE, four source-body,
five existing lexical ownership, three construction/conversion and two existing
typed VM regressions. It includes 32 admitted conditional levels and rejection
of level 33 without native stack overrides, as well as unselected failing arms,
active/inactive resource extraction, mutable reinitialization and atomic errors.
Windows development/release each passed all 29 native groups on `dbda356` after
helper `a95eb11`. All 209 final inputs match checkout and Git raw bytes; all 197
production modules are LF. The admitted 32/rejected 33 fixture module remained
byte-identical across the reproduced failures and final passes. See the
[Windows evidence](../evidence/value-control-windows-20261107.json) and
[input manifest](../evidence/value-control-inputs-windows-20261107.json).

The [predicate successor](value-predicates.md) now adds non-consuming wide/resource
Option/Result inspection; [typed propagation](value-propagation.md) connects `?`
and early anonymous capture cleanup. This checkpoint is statement control flow. Typed value
`if`/`switch` joins, loops and break/continue, must-use diagnostics,
general aggregate/reference/module/public composition and useful Buffer byte/text/
input/output operations remain open. Engine/Instance/host/isolation/embedding/
delivery and complete language/platform validation also remain open. No public
CLI/full matrices, Linux, OOM injection, general stack/performance or clean-machine
delivery pass is implied by this focused selection.
