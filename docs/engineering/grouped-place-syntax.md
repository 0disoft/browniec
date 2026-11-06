# Read-only grouped assignment location plans

Date: 2026-11-06. Private prerequisite for grouped assignment, following
[scalar-local assignment](scalar-assignment.md). Public source lowering is now
covered by the [assignment successor](grouped-assignment.md). This private
prerequisite itself added no capability flag or executable syntax.

## Grammar and retained source state

`place_syntax::inspect` recognizes a name followed by field/index selectors,
with grouping before the root and around any completed prefix. For example,
`((p).inner).x += value`, `(a)[index] = value`, `((a[index])) += value` and
`(((slice))[index]) ^= value` produce the same selector sequence as their
ungrouped forms. All eleven existing assignment tokens are recognized.

A plan retains the root's original name span, each field's original name span,
each index's initial lexer state and closing-bracket offset, the group count,
and a lexer snapshot at the pending operator. Index expressions are not
evaluated. The input lexer is borrowed read-only and source bytes are never
rewritten, so original diagnostic offsets, source fences and token budgets
remain available to the eventual typed lowering.

The index scanner matches parentheses, brackets and braces with one explicit
stack. String literal contents and comments remain lexer tokens rather than
delimiter input. Nested calls, arrays and control-expression blocks therefore
cannot prematurely close the outer index. Empty, crossed and unfinished index
delimiters produce original-offset syntax errors.

Ordinary final values, arithmetic, CALL results, constructors, comparisons and
borrows are not assignment locations. The probe returns an invalid plan for
these forms so value-arm classification can defer to the expression parser.
An incomplete outer group also cannot become a valid assignment plan.

## Bounds and authority

Source length remains at most4096 bytes, token count at most1024, root grouping
at most32, and selectors at most16. Index delimiter storage has32 entries,
including its outer bracket. Each scan advances a bounded lexer copy; no native
recursion, heap allocation, guest owner, payload extent, register or pending
place ID is introduced. Planning is linear in scanned source bytes plus bounded
selector/stack initialization. Excess depth/selectors return compile-limit
errors. Invalid native cursor/span/budget state and malformed scoped contexts
retain checked errors.

These are syntax plans, not executable authority. The future lowering must
resolve the exact visible mutable binding, check selector kinds/types and
existing source/struct/expression limits, evaluate each actual index once, and
use the existing array/slice/record selected-place or scalar-slot operations.
Complete IR/ownership admission remains mandatory. A syntactically plausible
mixed chain is not a claim that the current type profile supports that chain.

## Verification and frontier

Run `python -B tools/verify-static-execution.py --profile development
--selection place-syntax`, repeated for release. Six native groups check source
span/state preservation, every operator and nonplace disambiguation, nested
delimiter/literal/comment handling, original error offsets, exact32/33 grouping,
16/17 selectors and32/33 index-stack entries, scoped EOF, invalid native state,
token exhaustion and4097-byte source rejection. The oversized fixture uses a
Buffer because the pinned Fairy C compiler cannot type a4097-element fixed array.

The [assignment successor](grouped-assignment.md) now connects main/value-arm
dispatch to this plan and existing typed lowering. This checkpoint remains the
private syntax proof. Grouped borrows, generic aggregate overlap proof and full
L04/C05/Instance/host/delivery remain open. Public CLI, full language/native
Fuel matrices, Linux, OOM/general stack/performance, worker isolation and clean-
machine delivery are outside this private parser check. Existing source profiles,
capability metadata, operation prices, default256 and ceiling16000000 remain.

Windows development/release each passed **six native groups**. All 176
executed input hashes match checkout and staged Git raw bytes. Both locked LF
mirrors pass with 171 LF production modules and 296-file discovery.
The 40 unselected CRLF/LF-only discovery differences are recorded separately.
No native compiler/linker/stack overrides or historical results were used. See
[Windows evidence](../evidence/grouped-place-syntax-windows-20261106.json).
The skipped scopes above remain unverified here.
