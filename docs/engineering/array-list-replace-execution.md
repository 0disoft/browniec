# Native scalar-list replacement IR and execution

Date: 2026-11-06. Successor to [replacement storage](array-list-replace-storage.md)
and [list execution](array-list-execution.md). This is a native prerequisite for
whole-array element-list assignment; it does not expose new source syntax.

## Encoding and independent admission

Opcode 81 uses the same bytes as list creation (80): destination array ID,
little-endian operand-pool start, and four reserved zero bytes. Both operations
share the dense 4096-entry pool; each instruction consumes exactly the canonical
destination length. No separate payload, arity or unchecked register array enters
the VM. The builder validates the complete candidate before appending anything.

Complete admission independently reconstructs pool spans and exact scalar types,
function-local definitions on every incoming CFG path, canonical reserved bytes,
and owner liveness. Replacement requires an already-live mutable destination,
rejects shared/exclusive loans and preserves the owner live set. Returned-view
lifetime analysis rejects replacement while any returned alias protects that
owner, including after the original loan closes. Last-alias closure restores
the usual mutation permission. Recipe read analysis includes every pool operand.

All six scalar domains, 4096 cells, 32768 encoded bytes, 16 sites, 128 registers,
256 instructions and 32 frames retain their existing bounds. This is private
copyable IR, with no external bytecode loader or stable bytecode ABI.

## Execution and transaction boundary

Ordinary and retained dispatch reach the same replacement routine. It checks
Fuel and live token/scratch bounds, gathers cells from the current frame, and
uses complete codec staging before the first destination write. A late invalid
cell, stale or borrowed token, or insufficient budget preserves backing and
every owner/token/order/epoch/arena field. Discardable scratch may change after
successful Fuel preflight. Successful replacement preserves those same metadata
fields and the exact existing extent.

The retained route supplies read-only owner and token bindings directly. It
does not materialize or publish a 512-token compatibility plan for replacement.
Creation keeps its existing unpublished metadata plan and publication rules.
Both operations reuse the two invocation-local scratch owners across loops and
CALLs. No replacement allocation or additional owner/extent is required, even
when all sixteen owners and the backing quota are full.

## Fuel and limits

| Work | Exact charge |
| --- | ---: |
| Invocation setup without lists | 0 |
| Setup with creation and/or replacement | `257 + 2*M + S` |
| List creation | `56 + N + 3*B` |
| Existing-extent list replacement | `49 + N + 3*B` |

M and S are the maximum list length and encoded byte count across all bodies;
N and B describe the current operation. Setup runs once, including programs
whose pool contains only replacement operands. Replacement removes creation's
seven-unit worst-case allocation padding reserve. Its linear gathering, codec
staging and final copy remain O(N+B), plus bounded O(16) owner validation.

Ordinary prices include dispatch. The retained coordinator adds its existing
separate dispatch unit and entry/leave reserves exactly once; no budget retry or
alternate schedule is selected. Existing operation prices, public default 256
and ceiling 16000000 are unchanged. Native host budgets remain independent.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-replace-execution
python -B tools/verify-static-execution.py --profile release --selection array-list-replace-execution
```

The focused selection contains six new execution groups, two replacement-storage
regressions, three existing creation/Fuel/rollback regressions and two returned
owner-lifetime regressions. Independent numeric oracles cover exact, one-short
and one-more budgets for ordinary and retained execution. Cases also cover six
domains and full-width edges, the full 4096-entry pool, a 32768-byte payload,
16 occupied owners with exactly 23 backing bytes, late bad cells, stale/locked
tokens, metadata preservation, scratch capacity reuse, forged operands/CFG/
mutability/liveness/borrows, and owned CALL results through loops.

Implementation `7a4688d` passed all thirteen groups in each Windows profile on
164 identical input paths, all matching checkout and Git raw bytes. Both locked
LF mirrors pass with 156 LF production modules; the common test-discovery
identity covers 266 files. Final runs use no compiler/stack overrides or
historical-result reuse. Initial test-only borrow-check failures and a stale-lock
discovery attempt are excluded. See the
[focused Windows evidence](../evidence/array-list-replace-execution-windows-20261106.json).

## Remaining source integration

Lower `a=[x,y];` only after ordered, one-time cell evaluation and exact existing
type/arity validation. Emit replacement after the complete RHS and terminator
validate; keep names/ownership unchanged and preserve existing repeated fills.
Earlier RHS guest effects are not rolled back if later evaluation exits.

No replacement source/version capability is enabled by this native increment.
General list expressions/projections, nested/resource elements, full L03/C05,
Instance capacity/accounting/resumability, host/project CLI, worker, ABI and
delivery remain open. Public CLI/full native matrices, Linux, allocator fault
injection and general stack/timing measurements are outside this selection.
