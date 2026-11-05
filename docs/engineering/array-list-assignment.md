# Scalar element-list assignment

Date: 2026-11-06. Source successor to [native replacement execution](array-list-replace-execution.md)
and [list declarations and contexts](array-list-contexts.md).

## Source behavior

Mutable existing scalar arrays now accept `a=[x,y];`, including one cell and a
trailing comma. The destination fixes the exact element type and length for all
six supported scalar domains. There is no implicit widening, length change,
nested/resource element or assignment expression. Immutable destinations,
active lexical loans and scalar-only for headers retain their existing errors;
complete admission independently rejects outstanding returned-owner aliases.

The lexer distinguishes repeated fills from lists using the first outer
separator, ignoring nested expressions, comments and literals. Existing
`a=[value;N];` still evaluates its filler once and emits its original fill.

One shared scalar-list evaluator now serves declarations, arguments, returns,
temporary borrows and replacement. Cells evaluate once from left to right and
keep immutable scalar snapshots. The existing destination remains visible and
live throughout evaluation: `a=[a[1],a[0]];` reads both original cells, while a
later cell observes actual earlier RHS guest writes. Compiler-side register-ID
scratch is heap-owned and separate from recursive expression/CALL frames.

Replacement checks complete arity and the statement terminator before emitting
one opcode 81 into the original destination. No temporary array, binding, owner
or backing extent is added by replacement itself. Ordinary RHS expressions keep
their own existing temporary-owner requirements. Complete canonical proof and
the native atomic encoder still precede any destination replacement.

## Exits and effects

Return, Option propagation, break and continue in a cell use existing lexical
and capture cleanup. A pending replacement never partially overwrites its
destination. Outer owners remain live across a loop-local exit; owners whose
scope is left are finalized normally. Only completed RHS owners/captures are
released, including temporary returned views and array CALL results.

RHS guest effects happen when evaluated and are not rolled back. For example,
an earlier `change(ref mut a)` may change a cell even when a later cell returns
from the function before replacement. Fuel/runtime failure also does not undo
earlier statements or external effects. This is atomic destination publication,
not an invocation-wide transaction or replay mechanism.

## Fuel, limits and discovery

Existing scratch setup is `257+2*M+S` once per invocation, or zero without lists.
Replacement is `49+N+3*B`, using the same preallocated typed/encoded scratch and
read-only owner/token bindings in both VM drivers. The retained coordinator
keeps its extra dispatch unit and entry/leave reserves. Existing prices, public
default 256 and ceiling 16000000 remain unchanged.

For `var a=[0;2];a=[20,22];return a[0]+a[1];`, an independent native oracle
requires 555 Fuel with eight backing bytes. Public backing requires 66083:
66082 fails, and 66083/66084 succeed. The same source IR in the native retained
coordinator needs 410152 (one-short fails and one-more succeeds).

`--version --json` adds `array_element_list_replacement: true`; existing profile
names and declaration/argument/return/borrow flags remain. Original source,
token, instruction, register, site, frame, backing and operand-pool limits are
unchanged. The 4096-entry pool is a whole-Program compile budget; replacement
does not remove independent source/register/IR constraints or adopt full C05.

## Verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-assignment
python -B tools/verify-static-execution.py --profile release --selection array-list-assignment
python -B tools/verify-local-inference-cli.py --profile development --array-list-assignment
python -B tools/verify-local-inference-cli.py --profile release --array-list-assignment
```

Native selection covers new source groups, both real qualified-module compiler
routes, original declaration/lookahead/32-depth boundaries, direct list CALL/
result exact Fuel, borrowed temporary cleanup and the retained replacement
oracle. Source cases include six scalar domains, ordered one-time snapshots,
self-reads and RHS writes, copies/CALLs/results, last-alias closure, nonlocal exits,
all sixteen sites with exactly 23 backing bytes, and a pool start above 255.
CLI selection includes every earlier scalar/list case plus assignment and
capability discovery, with no runtime tools on PATH. CLI builds are serialized.

Implementation `bd34554` passed fourteen native groups and 79 CLI cases in each
Windows development/release profile. All 166 input paths in the native/CLI union
match the checkout and implementation Git raw bytes. Both locked LF mirrors pass
with 156 LF production modules; the common discovery identity covers 267 test
files. Both CLI artifact hashes and all native reports/receipts are recorded in
[Windows evidence](../evidence/array-list-assignment-windows-20261106.json).
Final runs use no compiler/stack overrides or historical-result reuse. Initial
u32/usize test fixtures used unsupported narrowing casts; corrected comparisons
are used in every final run. The earlier native result/snapshot is excluded and
both complete native selections reran on final inputs.

The [scalar literal projection successor](array-literal-projections.md) now adds
immediate index/length expressions, grouping and UTF-8 lists. Broader aggregate
expressions/projections, nested/resource elements and full L03/C05
remain open. Full native/CLI matrices, Linux, allocator fault injection, general
stack/timing benchmarks, complete Instance accounting/resumability, host/project
CLI, restricted worker, ABI and package delivery are separate obligations.
