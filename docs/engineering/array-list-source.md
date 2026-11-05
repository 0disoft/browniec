# Scalar element-list declarations

Date: 2026-11-06. Implementation: `3340b24`.
Successor to [list IR and execution](array-list-execution.md).

The source compiler accepts inferred and annotated local declarations:

```brownie
let a = [20, 22];
var i32[2] b = [a[0], a[1]];
let single = [42];
let trailing = [20, 22,];
```

These are owned, independent fixed arrays. The first inferred cell establishes
the exact scalar element type; uncontextualized integers retain the existing i32
default. Subsequent literals use that type as their context, while typed values
must match exactly. An annotation supplies both element type and arity. Empty
lists, mixed types and incorrect arity fail before a Program is published. All
six existing scalar domains are supported; nested/resource-bearing element types
remain outside this increment.

## Evaluation, admission and cleanup

A non-evaluating lexer snapshot identifies the first outer comma, semicolon or
closing bracket. Parentheses, brackets and braces hide their inner separators;
comments and escaped byte/text literals use the canonical lexer. The active lexer,
IR and guest state are unchanged by classification. Repeated `[filler; N]`
initializers retain their existing lowering and prices.

The ordinary expression parser evaluates cells once, left to right, into immutable
scalar register values. A mutable local is read immediately, so later writes do
not change an earlier cell's value. Existing CALL/index/switch lowering manages
temporary roots and loans, including return, propagation, break and continue.
No destination array or lexical binding is created during those expressions.
Only after the closing bracket, statement terminator, exact type and arity checks
does lowering emit one complete `ir::array_values` operation and publish the name.
Independent CFG/type/owner verification remains mandatory.

Compiler operand scratch is a locally owned `Vec<usize>`, destroyed on all exits.
It grows with the current list, bounded by the whole-Program 4096-entry operand
budget; no 4096-usize array is added to recursive expression/CALL parser frames.
This is compiler scratch, separate from the VM's invocation scratch and future
Instance accounting. Source, token, register, instruction, function/CALL, array-
site and live-owner limits still apply. Native support for 4096 values does not
promise that every 4096-element source expression fits the experimental frontend.

## Public scope and Fuel

`array_element_list_declarations` is the declaration-specific version capability.
Direct element-list CALL arguments, returned literals, borrowed temporaries and
whole-array list replacement require their own source integration. Existing
named-array copy, CALL, return, borrowing and mutation work with initialized lists.
This increment does not complete L03 or C05.

Public default 256, ceiling 16000000 and existing operation prices remain
unchanged. Lists use the already admitted setup `257 + 2*M + S` and instruction
price `56 + N + 3*B`. For `let a=[20,22];return a[0]+a[1];`, an independent numeric
oracle requires 489 Fuel with eight backing bytes, or 66017 with the public
65536-byte backing. One less fails with Fuel; exact and one more succeed.

## Focused verification

```text
python -B tools/verify-static-execution.py --profile development --selection array-list-source
python -B tools/verify-static-execution.py --profile release --selection array-list-source
python -B tools/verify-local-inference-cli.py --profile development --array-lists
python -B tools/verify-local-inference-cli.py --profile release --array-lists
```

Development and release each passed thirteen native groups and 34 standalone CLI
cases, including the declaration-specific version flag, source/admission/run
results, exact Fuel boundaries and rejection diagnostics with no runtime tools.
The native selection includes nine new groups, two repeated-array/aggregate-exit
regressions, the six-domain native Fuel oracle and the original combined
module-compiler depth-32/depth-33 fixture. The new combined source boundary group
also retains both ordinary and retained routes at depths 32 and 33, 256 references
to a repeated scalar register, the source-byte limit and the exact 128-register
boundary. Its original depth inputs were not reduced or split for final runs.

All 165 input paths in the native/CLI union match the checkout and `3340b24` Git
raw bytes; there are 156 LF production modules and a 263-file discovery identity.
Both locked LF mirrors pass. See the
[Windows evidence](../evidence/array-list-source-windows-20261106.json).
Final runs use no compiler/stack overrides or historical-result reuse. The
preliminary native helper retained an additional owning Program local and
overflowed on the retained depth boundary; the final helper consumes the Result
directly in its arm, preserving the original combined boundary group. Temporary
subgroup/generated-C probes and the initial CLI version probe without `--json`
are excluded from final evidence. No general stack-size claim follows from this
focused boundary check.

Full profiles, Linux, allocator fault injection, general stack/accounting/timing
and delivery verification are separate obligations.
