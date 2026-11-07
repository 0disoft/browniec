# Terminal Buffer and view operands

Private retained-value source now propagates a terminal expression through final
Buffer/view operands. The actual return, break or continue edge performs its
existing checked cleanup. The enclosing byte operation is not emitted, and no
consumer tries to read or capture an absent value afterward.

```c
module main;
fn i32 main() {
    var b = bytes::empty();
    _ = bytes::push(ref mut b,
        if (true) { return 42; } else { return 0; });
}
```

## Admitted positions

Both `bytes::` and `brownie::bytes::` retain the existing explicit prefixes and
exact types on every continuing operand.

| Position | Terminal behavior |
| --- | --- |
| Sole `ref` receiver of len/copy/view | Require `)`; do not begin a receiver loan or allocate a result/view. |
| Final read index, push byte or reserve count | Require `)`; retain prior receiver evaluation, omit the operation. |
| Final write byte | Preserve receiver/index evaluation; require `)`, omit WRITE. |
| Final append `ref` source | Preserve the destination loan/effects; require `)`, do not begin another loan or APPEND. |
| View index or range upper endpoint | Preserve receiver capture and any lower endpoint; require `]`, omit READ/RANGE. |

Prior receivers, captures, scalar work and effects are real and evaluate once.
Their function/loop cleanup already knows the active values and views. A terminal
path must not subsequently call the ordinary operation's loan-end, publication,
result capture or receiver-drop helpers. No pinned root is moved and no owner is
fabricated. Declared/contextual type nodes may already be interned; they are not
runtime values or result destinations.

Owning, tagged, shared-view and void returns keep their original rules. Result
failure propagation inside an operand still abandons and cleans the pending
receiver. Break/continue restore the target loop's loan masks and close departed
captures; classic-for continues still execute the real post step. Later legal
Buffer mutation observes that those transient loans/views have ended.

## Grammar and rejection

Nonfinal receivers, a write index and a slice lower endpoint still reject when
terminal: later syntax/arguments need the remaining unreachable-source checker.
Early bottom cannot repair a missing argument, wrong arity or closing delimiter.
Ordinary void CALLs remain distinct from bottom. Missing reference prefixes,
immutable mutation, pins, overlapping loans and unhandled Results still reject.
Trailing invalid or unreachable statements are not silently skipped.

There are no new instructions, runtime fields, existing prices, public gates,
source/operand/depth capacities or Fuel changes (default256/ceiling16000000).

## Verification

Five new groups contain 41 successful guest compilations/executions and 44
rejections. Every successful guest independently verifies before the VM returns
42. Compact per-function opcode histograms check omitted byte/view operations,
return/read/capture/drop counts and real nonzero cleanup. Runtime sentinels check
both branch choices, a real receiver CALL, once-only index/lower-endpoint effects,
temporary owners, selected shared returns, Result failures and loop transfers.

Development evidence reuses four passing groups from an initial frozen module
and one corrected group from a second frozen module. The sole correction gives
an ambiguous `.none` its required `Option<i32>` annotation in the fixture. All
production/config bytes, helpers and the four retained group bodies are identical
across the snapshots. No production code or limit changed to accommodate it.
There was no second all-five development run on the final complete module.

Integration runs seven existing development regressions and all twelve release
groups in disjoint locked mirrors through `tools/verify-value-terminal-operands.py`.
The existing checks cover ordinary Buffer operations/loans, ordered view endpoints,
return/propagation, deferred loop-header owners and the unchanged 32/33 fixture.
Unfiltered invocation runs all twelve groups in both profiles.

Implementation `093475d` passed seven integrated development regressions and all
twelve final release groups, complementing the five current worker development
passes described above. All 227 union inputs match checkout and Git raw bytes;
all 216 production modules retain LF. All 220 final worker inputs match the
checkout. The complete combined admitted32/rejected33 fixture is byte-identical
to `edf6d76` and ran in both root profiles. See
[focused evidence](../evidence/value-terminal-operands-windows-20261107.json).

## Remaining work

This extends [terminal expressions](value-bottom.md), not general unreachable
checking, bottom conditions/subjects/receivers, nonfinal CALL arguments or arbitrary
reference composition. Fresh loop-carried owners, general aggregates/modules/public
admission, methods/public AllocError and the runtime/host/isolation/embed/platform
inventory remain open. No public CLI, cross-platform, allocation-failure or full
accounting/leak evidence is claimed by this source increment.
