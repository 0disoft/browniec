# Private typed conditional values

Private `value_source::compile` admits `if` and exhaustive Option/Result `switch`
as operands, including Buffer and nested wide-tag results. Every continuing arm
ends with a value without a semicolon. Statements may precede it. If requires
else; terminal return arms do not constrain the result type, but at least one arm
must yield. An else-if suffix may consist entirely of terminal paths.

All yielding arms have the identical canonical type. Enclosing annotations supply
constructor context; otherwise the first yield supplies subsequent context.
Bare `.ok`, `.err` and `.none` retain their existing inference restrictions.
Read-only lexical lookahead distinguishes final control values from earlier
control statements and keeps preceding void calls outside the result type
context. Actual parsing still validates and emits each expression.

## Ownership and independent admission

One lazy destination belongs to all yielding paths. Scalar paths store/load an
ordinary exact-type slot; typed paths initialize one initially Dead value slot.
Named subjects use whole-type COPY/MOVE. Anonymous values always MOVE88 into the
join, even when copyable, so temporary direct Result obligations transfer once.
The value is published before reverse arm-scope cleanup, preserving returned
local resources. Other local pending Results still reject. Terminal paths neither
initialize nor read the destination. A joined Result is a fresh pending value.

Continuing paths use the existing compiler snapshot pool and real cleanup to
intersect initialized sets and union pending obligations. Moves on only one path
cannot revive the original name. Independent value IR admission proves exact
initialized/Dead state, operand types and complete scalar definitions before
native execution. No runtime conditional-drop flags or allocator rewind are added.

The small `value_source_context` module holds value/capture and lexical helpers
outside the recursive parser. Compiler-only snapshots remain scoped pool indices.
The existing statement-depth fixture remains byte-identical; no native stack
adjustment is permitted. Existing capacities and opcode prices, Fuel default 256
and ceiling 16000000 remain. Public source/CLI routes and capability flags are
unchanged.

## Verification and remaining work

Run `python -B tools/verify-value-joins.py --batch source --profile development`
and `--batch native --profile development`, with release counterparts. The disjoint selections contain seven source groups (three new groups with 55
guest programs and four unchanged regressions) and three native helper groups.
Windows development/release each passed all ten groups on `7a7ff8f` after helper
`f06cc54`. All 210 inputs match checkout/Git raw bytes; all 199 production modules
are LF. The unchanged admitted 32/rejected 33 fixture passed in both profiles.
See the [Windows evidence](../evidence/value-joins-windows-20261107.json) and
[input manifest](../evidence/value-joins-inputs-windows-20261107.json).
Public CLI/full language/native Fuel matrices, Linux, OOM injection, general
stack/performance and clean-machine delivery were not rerun.
Public admission, typed loops/break/continue, useful Buffer operations, general
aggregate/reference/module composition and full language/runtime/Engine/Instance/
host/isolation/embed/platform/delivery validation remain open.
