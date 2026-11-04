# Direct returned slice CALL arguments

Date: 2026-11-04. This B04 increment connects nested returned actuals to the
existing private CALL-binding VM. The full [completion objective](completion-plan.md)
remains open; ordinary public admission and capability metadata stay gated.

## Source and lifetime

A slice actual can now use an exact-mode reference-returning CALL, including
nested CALLs, selected temporary literals and owned array CALL results:

```brownie
let ref i32[] result = select(ref id(ref [42; 2]), ref id(ref other));
let i32 value = read(ref mut id(ref mut writer));
let ref mut i32[] part = id(ref mut tail(ref mut writer)[..1]);
```

The inner CALL finishes before its selected hidden owner and parent chain are
published in acquisition order, followed by its anonymous returned result. These
cleanup bindings have empty source spans and cannot resolve as guest identifiers.
Argument ranges keep the returned result visible while both endpoints complete;
the new range child is acquired afterwards. Every later argument sees the
dependencies for normal reverse lexical cleanup on return,
propagation, break and continue. The outer CALL has not happened on these exits;
its END_CAPTURE markers therefore do not appear on those paths.

For a reference-returning outer CALL, selection follows the callee's advisory
input hint. Shared selection retains every anonymous definition ancestor and its
owned backing transitively, rather than inferring lifetime from flattened root
metadata. Exclusive anonymous BEGIN/BIND_RESULT links collapse to the first
existing lexical binding or root OPEN. A retained anonymous root view keeps its
owner. Unselected captures close in reverse acquisition order before installation
of the outer result; an unselected exclusive ancestor's END belongs to its actual's
formal mask even when its site differs from the immediate actual.

Scalar, owned-array and owned-record outer CALLs use their existing reverse
capture cleanup after return. No new opcode, native authority, operation price,
CLI limit or public capability is introduced.

## Origin and admission

Advisory source-origin inference recursively follows selected returned actuals,
including reordered inputs and grounded recursive forwarding. The parser walk is
bounded independently at 32 expression steps. Hints do not grant authority:
independent definition, CFG, exact access/type, origin and loan proof still checks
the final recipes. Temporary-owner escapes, ungrounded cycles and conflicting
exclusive aliases remain invalid.

## Verification

The [Windows evidence](../evidence/m2-slice-result-arguments-windows-20261104.json)
records 37 development and 15 release native groups on 126 matching final inputs
and a 214-file test-discovery identity. Nine groups cover the new source forms;
development also covers all origin-hint, immediate-projection, independent
CALL-binding IR, CALL-execution and END-chain groups. Release covers the nine
new groups, four origin-hint groups and two affected CALL regressions. All 117
production files are LF and a separate LF mirror passed `check --locked`. Final
selections ran after input capture, with no native overrides or historical result
reuse. The earlier exploratory seven-group pass is excluded.

Tests cover all six scalar types in both access modes, selected and
unselected temporary backing, both selected positions, ordinary CALL result kinds,
recursive forwarding, later-argument exits, access conflicts, exact/one-short
Fuel, bounds traps, preserved writes and complete invocation cleanup.

Reference-valued declaration/return range projections, Static backing, general
references and ordinary public Program/CLI result admission remain open. Full
M1/M2, standalone CLI, Linux, restricted delivery, ABI, packages, allocator
instrumentation and timing/stack-size measurements are outside this increment.
