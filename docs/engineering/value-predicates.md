# Private non-consuming typed tag predicates

The private typed-source compiler accepts Option `.is_some`/`.is_none` and Result
`.is_ok`/`.is_err` properties. Each returns an ordinary bool. Inspection preserves
the entire receiver, including move-only wrappers with active or inactive Buffer
alternatives. It neither extracts a payload nor creates a typed destination.
Public compiler selection, capability flags and Fuel default/ceiling are unchanged.

## Source evaluation and ownership

Named typed receivers retain a compiler-only delayed capture through parentheses.
A postfix predicate reads that live slot directly; it emits no MOVE or COPY for
the receiver. Repeated tests therefore need no additional typed slots. All ordinary
value consumers still capture with the existing whole-type COPY/MOVE before a
later argument or operand evaluates. Assignment, return, constructor payloads and
explicit discard keep their previous move rules. These compiler references do not
become guest aliases or native owner authority.

A computed receiver, including a typed CALL result or inferred `.some(...)`,
evaluates once. Its test runs before the anonymous receiver is explicitly dropped.
The bool survives independently of that cleanup. Grouping and unary `!` preserve
normal postfix precedence. Wrong-wrapper members, method-call spelling, chained
members on bools and tests of moved values reject. A bool result context does not
supply a wrapper type: unconstrained Result constructors still require enough
information to determine both alternatives.

## Independent instruction admission

Private TAG_TEST98 has bool register `dst`, typed receiver `a`, variant `b` (1
some/ok, 0 none/err), and zero reserved bytes4..7. Complete admission reconstructs
exact wrapper kinds, function-local operands, live initialized receiver state and
a fresh ordinary bool definition. It preserves the typed live set on every edge.
Ordinary/image/reference routes continue to reject private typed instructions.
The source helper preflights budgets and operands before publishing code or
register metadata; failures leave the candidate unchanged.

Native execution authenticates frame generation, canonical wrapper bytes and
any active root binding, and pays its complete inspection price before publishing
the bool. It leaves native payload bytes, owners and liveness unchanged.
TAG_TEST98 costs `8192 + 4 * wrapper_width` abstract Fuel units, including
dispatch, bounded frame/root authentication and two canonical wrapper scans. The
wrapper width is independently bounded before pricing; no typed payload allocation,
copy, transfer or new cleanup reserve is added. Existing instruction prices remain
unchanged. Normal and failure cleanup still use the same prepaid native ledgers.

## Verification and remaining scope

Run `python -B tools/verify-value-predicates.py --batch source --profile development`
and `--batch native --profile development`, with release counterparts. Final
Windows development/release each passed 26 native groups in disjoint source 22/
instruction 4 selections on `5a02886`. All 210 inputs match checkout and Git raw
bytes; all 197 production modules are LF. The prior admitted 32/rejected 33 fixture
is byte-identical and passes in both source selections without stack overrides.
See the [Windows evidence](../evidence/value-predicates-windows-20261107.json) and
[input manifest](../evidence/value-predicates-inputs-windows-20261107.json).

Coverage includes both polarities, move-only/copyable/nested wrappers, 17 repeated
named inspections with no typed-slot growth, grouping, one-time CALL receivers
and immediate temporary DROP, malformed/dead/foreign operands, unchanged source
bytes/root bindings/liveness on rejection, exact/one-under/one-over native prices
and final independent public-route rejection. An empty-image negative admission
fixture initially lacked its required metadata quota; final runs use the same
four-group fixture with the correct quota. Production code was unchanged between
these batches; no historical/native-override result is reused.

The [propagation successor](value-propagation.md) now connects wide/resource `?`
and early anonymous capture cleanup. Must-use Result diagnostics, typed value-expression joins, loops,
useful Buffer operations and general aggregate/reference/module/public composition
remain open. Full CLI/language/native Fuel matrices, Linux, OOM/general stack/
performance and clean-machine delivery are separate obligations.
