# Private typed postfix propagation

The private typed-source compiler extends the accepted postfix `?` rules to
canonical Option/Result values with wide scalars, nested wrappers and Buffer
payloads. The operand evaluates once. Option success types may differ from the
enclosing Option success type; Result success types may differ but error types
must match exactly. The two wrapper families do not mix. Scalar/void enclosing
functions, including the i32 entry, reject propagation.

## Ownership and continuation

The parser captures a named receiver through the existing whole-type COPY/MOVE
rules before selecting its payload. Postfix binds before unary and binary work;
grouped and computed receivers retain their own type rather than inheriting the
surrounding payload expectation. Propagation adds no Result error-type inference.
Nested wrapper payloads may themselves propagate in the same expression.

`value_source_propagation::lower` emits existing CASE92 and forward jumps. The
success edge retains its exact payload and explicitly drops a surviving copyable
anonymous receiver. A mismatch reaches the failure case, which constructs the
enclosing function's failure wrapper. Current-function values other than that
return value are cleaned in reverse allocation order, including earlier anonymous
CALL captures and constructor children, before RETURN94. Later operands, arguments
and statements on that failing execution do not run. CASE's impossible second
mismatch reaches the existing failure terminal.

The tested sources include a failing later argument with an earlier captured
Buffer and a distinct active Buffer error payload. A first positive fixture used
more than the private sixteen-slot static ledger; diagnostic execution reported
`compile_limit`. Its final form keeps the same pending-capture/error ownership
path with a void helper and scalar success wrapper. The production slot bound and
existing combined depth regression remain unchanged.

Compiler snapshots remain in the invocation-local bounded path vector; recursive
parser frames retain indices rather than copying full lexical states. Selecting
the independently reached success edge restores its compiler names/live set while
preserving the global allocation high-water mark. Scoped snapshots release on
both success and failure. They confer no native ownership authority.

Ordinary source returns share the same terminal cleanup helper. Independent
canonical admission still reconstructs exact operand types, scalar definitions,
CFG initialized/Dead sets and return compatibility before private execution.
No opcode, existing instruction price, Fuel default/ceiling, public source route
or capability flag changes.

## Verification and remaining work

Run `python -B tools/verify-value-propagation.py --batch source --profile development`
and `--batch native --profile development`, with release counterparts. Windows
final development/release each passed 11 native groups (source 8/helper 3) on
`78cde1f`. All 208 inputs match checkout and Git raw bytes; all 198 production modules
are LF. The existing admitted 32/rejected 33 combined depth fixture is byte-identical
and passes in both profiles without stack overrides. See the
[Windows evidence](../evidence/value-propagation-windows-20261107.json) and
[input manifest](../evidence/value-propagation-inputs-windows-20261107.json).

Coverage includes both wrapper families/variants; wide and nested exact types;
active/inactive Buffer errors and success payloads; differing success types;
grouping and unary/binary precedence; declaration/assignment/constructor/CALL/
return/condition/switch contexts; skipped later failing work; fresh invocation
recovery after Fuel/quota rejection; real return-anchor validation; partial-error
snapshot release; malformed CFG and missing anonymous cleanup rejection.
Public CLI/full language/native Fuel matrices, Linux, OOM injection, general
stack/performance and clean-machine delivery remain separate obligations.

The [must-use successor](value-must-use.md) diagnoses pending direct Results at
normal/early exits, overwrite and continuing joins. The
[typed-join successor](value-joins.md) now adds scalar/Buffer/nested-tag values.
The [loop successor](value-loops.md) now connects while/for/break/continue and
cyclic Result checking. Useful Buffer operations, aggregate/reference/module/public
composition and the wider Engine/Instance/host/isolation/embed/delivery work remain
open. This private path does not complete the full language profile.
