# Grouped record values and scalar projections

Date: 2026-11-06. This increment extends the bounded plain-record source profile
within L02/L03. Full language, C05, Instance and delivery work remain open.

## Supported forms

Plain-record constructors, named owners and record-returning CALLs now preserve
their exact nominal type through parentheses, including nested grouping around
child paths. They compose with inferred/annotated locals, by-value arguments,
record returns, and whole/child assignment right-hand sides. Constructors also
support immediate scalar field projections, with or without parentheses:

```brownie
struct Point { i32 x; i32 y; }
fn Point make() { return (Point{.x=20,.y=22}); }
fn Point same(Point p) { return ((p)); }
fn i32 main() {
    var p=(same((make())));
    p=(Point{.x=(p).x,.y=22});
    return (p).x+Point{.x=0,.y=22}.y;
}
```

Grouping performs no conversion. The six scalar domains retain exact types;
unknown fields, wrong nominal records and scalar/record shape mismatches fail.
Qualified calls and constructors use the existing scoped resolution. Version
JSON exposes `record_expression_projections` and `record_grouped_values` for
this scope only; no profile identifier or opcode changes.

## Evaluation and ownership

Read-only lookahead classifies an atom and its path without emitting IR or
running guest expressions. Actual lowering validates the same source and nominal
type. Constructor fields use the existing ordered scalar staging, evaluating all
fields once, including unselected fields and their effects. A scalar projection
loads the staged leaf without creating an owner or allocating record backing.
A grouped constructor child can feed its parent's staging directly.

Named initializers copy the complete selected value. Mutable by-value arguments
snapshot before later arguments can change the original. Immutable complete
owners retain the existing capture-free argument-prefix path, including grouped
names; the large lexical snapshot stays outside recursive CALL frames.

A record CALL runs once. Its completed root transfers into a whole value context,
or drops promptly after a scalar read or child extraction/staging. Constructor
replacement uses existing in-place root/child replacement. Assignment keeps the
destination live through RHS effects; returned temporary roots drop afterwards.
Existing reverse-order capture cleanup handles return, `?`, break and continue.
Earlier guest effects are never rolled back.

Four grouped/ungrouped source pairs compare exact instruction bytes, register and
record-site counts, then execute with four/eight backing bytes, including
replacement at full quota. Immediate constructor projection executes with zero
record sites and zero backing bytes. Grouping shares the existing expression
depth budget; 32 groups around a named field projection pass and 33 fail. Both
positions of grouped immutable arguments preserve the original 32/33 CALL
boundary through ordinary and retained execution. No stack override is used.

## Verification

Windows development and release each passed **17 native groups and 178 tool-free
CLI cases**, including earlier scalar, array and aggregate regressions. The
170 input paths match checkout and verification-commit Git raw bytes; all 158
production modules are LF. Both locked LF mirrors and the common 270-file test
discovery pass. The discovery additionally preserves 41 unselected legacy test
files whose checkout/Git difference is CRLF versus LF only; both hashes are
recorded. Implementation is `7e26edd`, with focused verification at `7b9a9de`.
See the captured input/compiler/artifact identities and exact selected results in
the [Windows receipt](../evidence/record-expression-projections-windows-20261106.json).
Obsolete aggregate rejection fixtures were removed for newly accepted grouping.
The focused native selection covers seven new execution groups and ten original
lifecycle, module and depth groups. Unselected historical suites were not rerun.

```text
python -B tools/verify-static-execution.py --profile development --selection record-expression-projections
python -B tools/verify-static-execution.py --profile release --selection record-expression-projections
python -B tools/verify-local-inference-cli.py --profile development --record-expression-projections
python -B tools/verify-local-inference-cli.py --profile release --record-expression-projections
```

CLI builds share their output and must be serialized. The native runner checks a
locked LF production mirror, exact selected identities, unchanged input hashes
and common test discovery. This source increment uses existing IR operations and
their Fuel prices; default 256 and explicit ceiling 16000000 remain unchanged.

Aggregate-valued control-flow expressions, grouped lvalues/borrows,
nested/resource-bearing array elements, general returned views, full C05 and
Instance accounting/stepping, host APIs, Linux and restricted/embed delivery
remain outside this increment. No whole-project performance or general native
stack-size guarantee is established.
