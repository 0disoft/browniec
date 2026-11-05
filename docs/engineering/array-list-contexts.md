# Element-list arguments, returns and temporary borrows

Date: 2026-11-06. Implementation: `6fea8e4`.
Successor to [scalar list declarations](array-list-source.md).

The same complete scalar-list evaluator now serves declarations, by-value CALL
arguments, fixed-array return expressions and call-scoped temporary borrows:

```brownie
let result = take([20, 22]);
return [20, 22];
let item = read(ref [20, 22][1..]);
let changed = write(ref mut [20, 20]);
```

CALL/result signatures provide the exact element type and fixed arity. Borrow
signatures provide the exact scalar type and access mode; the list determines
the temporary array's length. Contextual integer literals support all six
existing scalar domains. Trailing commas and single-cell lists are accepted;
empty lists, mixed types, mismatched fixed arities and malformed delimiters fail
before an executable Program is published. Missing `mut` remains the existing
syntax error. There is no fallback to another compiler or Fuel schedule.

## Publication and cleanup

`array_list_value` evaluates cells once, left to right, into immutable scalar
registers, using one local compiler-owned vector. Type/arity validation and the
closing bracket precede one `ir::array_values`; no pending destination exists
during cell evaluation. Each caller then validates its own delimiter and decides
whether to bind, capture or return that complete owner. Declaration names still
appear only after the statement terminator. A compiler error discards candidate
IR and cannot publish partial guest state.

By-value arguments join the existing hidden capture suffix only when complete.
They remain live through later argument evaluation, are copied into the callee
through the existing ownership transaction, and close in the established reverse
order. Direct array returns use `array_result_source::finish`, which drops other
lexical resources and transfers the unique result token through ARET without a
payload copy. Repeated `[filler; N]` paths and their prices remain unchanged.

A borrowed list creates its hidden owner only after every cell finishes and
before computed range endpoints. The existing temporary-borrow path opens the
view, captures CALL authority, and closes the view before dropping its owner.
Return, propagation, break and continue during cells, endpoints or later
arguments see exactly the completed capture suffix. Shared-byte returned views
retain selected temporary owners and close unselected captures through the
existing independently verified origin/receipt machinery. Lists add no new
origin class, reference type, ownership token or cleanup protocol.

The independent type/CFG/owner/operand-pool proof remains mandatory. Source,
token, register, instruction, function, CALL, frame, array-site and live-owner
bounds are unchanged; full-profile capacities remain separate work. The original
combined depth-32 success/depth-33 rejection groups remain intact on both compiler
routes. Full Instance accounting and general native stack containment are not
established by these focused cases.

## Public discovery and exact Fuel

Version JSON adds these scope-specific booleans:

- `array_element_list_arguments`
- `array_element_list_returns`
- `array_element_list_temporary_borrows`

`array_element_list_declarations` remains true. The current source profile strings,
default 256, ceiling 16000000 and all operation prices remain unchanged. Invocation
scratch and list initialization use the existing [list schedule](array-list-execution.md).
CALL copying, returned-owner transfer and borrow retention keep their existing
additive charges.

| Ordinary fixture | Native backing | Exact native Fuel | Exact public Fuel |
| --- | ---: | ---: | ---: |
| `take([20,22])`, callee sums both cells | 16 bytes | 820 | 66340 |
| `return [20,22]`, caller sums both cells | 8 bytes | 555 | 66083 |

The independent numeric oracles cover exact, one-short and one-more budgets.
Direct and named-list variants also produce identical instruction bytes and
operand pools. Public totals use the unchanged 65536-byte backing. Retained
whole-invocation pricing remains distinct; no ordinary total is claimed for that
driver.

## Focused verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-contexts
python -B tools/verify-static-execution.py --profile release --selection array-list-contexts
python -B tools/verify-local-inference-cli.py --profile development --array-lists
python -B tools/verify-local-inference-cli.py --profile release --array-lists
```

The native selection covers new contextual types, effects, returned values,
cleanup/propagation/loop transfers, temporary-borrow endpoints, selected owners,
negative admission and exact IR/Fuel. It also includes original declaration Fuel
and combined source limits, repeated-argument/return/borrow regressions, and real
qualified module CALLs/results on ordinary and retained routes. The CLI selection
retains every earlier declaration fixture and adds direct argument, result,
temporary-borrow and capability discovery cases with no runtime tools.

Development and release each passed all fourteen native groups and 54 standalone
CLI cases. The 167-path input union matches the executed checkout snapshots.
All 156 LF production modules and all new/changed test inputs match `6fea8e4`
Git raw bytes. Of the full union, 166 paths match Git raw bytes; the one existing,
unmodified `slice_temporary_arguments.fy` checkout fixture has 141 CRLF line ends
while its Git blob uses LF. Exact executed and Git blob hashes are both retained,
and only CRLF normalization is needed to make those bytes equal. No execution
result is reused after a file mutation. Both locked LF production mirrors pass,
and both native selections share the final 264-file discovery identity. See
[Windows evidence](../evidence/array-list-contexts-windows-20261106.json).
Final runs use no compiler/stack overrides or historical-result reuse. Initial
compiler-borrow and missing-mut diagnostic-expectation drafts are excluded.

Full profiles and CLI/native matrices, Linux, allocator fault injection, general
native stack/timing, Instance accounting/resumability and restricted/ABI/package
delivery remain outside this evidence. The [assignment successor](array-list-assignment.md)
now supplies whole-array scalar list replacement. The [scalar projection successor](array-literal-projections.md)
adds immediate index/length expressions, grouping and UTF-8 lists. Broader
aggregate expressions/projections and nested/resource-bearing elements remain
language work; this increment does not complete L03/C05 or the full objective.
