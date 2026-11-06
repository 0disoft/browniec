# Private typed Result handling obligations

The private typed-source compiler diagnoses an unhandled Result independently of
native ownership and copyability. Each top-level Result evaluation carries a
compiler-only pending obligation. A Result parameter starts pending; construction,
storage and by-value CALL move obligations to the produced value, destination or
callee. A fresh owned read is another Result evaluation even if a copyable source
was handled earlier. Its source remains live under ordinary COPY rules.

The existing non-consuming `.is_ok`/`.is_err` properties acknowledge a Result while
preserving its owner. Exhaustive switch, return, postfix propagation and explicit
`_ = EXPR;` also handle or transfer it. An ignored selected payload `_` explicitly
handles a nested Result. Construction transfers a Result child into its container;
the pending rule applies to a direct Result type, not every enclosing Option.

## Compiler state and rejected exits

The source compiler opts into `bindings::State` obligation checking before its
first function. Its sixteen-bit pending plane is distinct from the initialized/
Dead plane and may name only live direct-Result slots in the current function.
Trusted low-level IR construction helpers default to explicit instruction semantics;
that default does not select source admission or bypass source policy. Snapshots
retain both planes and their mode; continuing joins union pending obligations.
Terminal paths do not erase obligations on a different continuing path.

Pending values reject normal scope/function exit, implicit path cleanup and
replacement of an old mutable destination. Return checks every other live Result
before emitting terminal cleanup. The operand of `?` is handled first, but any
other pending Result must already have been handled or transferred on its early
failure edge; handling it only later on success is too late.

Typed CALL arguments remain pending captures until CALL publication. A later
argument that propagates failure cannot pretend the earlier Result reached its
callee. Earlier Buffer arguments still use the existing owner cleanup. Parameter
obligations are checked independently in the callee, including unused helpers.

`must_use_result` is distinct diagnostic kind 18 and renders with compile exit 3.
Ordinary type errors retain their existing kind. These are compiler metadata
changes, not new guest values, flags, VM operations or Fuel prices. The public
compiler's existing `must_use_result` capability remains false until its own
source/CFG diagnostics and broader composition are complete.

## Verification and remaining work

Run `python -B tools/verify-value-must-use.py --batch source --profile development`
and `--batch native --profile development`, with release counterparts. The
selections are disjoint: source has three new groups (80 independent guest
programs) and four unchanged regressions; native has three obligation/atomicity
helper groups. Preserve the unchanged admitted 32/rejected 33 combined source-depth
fixture and use no native stack overrides. Windows development/release each
passed all ten groups on `b6e18b2`. All 209 inputs match checkout/Git raw bytes;
all 198 production modules are LF. See the
[Windows evidence](../evidence/value-must-use-windows-20261107.json) and
[input manifest](../evidence/value-must-use-inputs-windows-20261107.json).
Full CLI/language/native Fuel matrices, Linux, OOM/general stack/performance and
clean-machine delivery remain separate obligations.

Public Result diagnostics, typed value-expression joins, loops/break/continue,
useful Buffer operations, general aggregate/reference/module/public composition
and the wider Engine/Instance/host/isolation/embed/delivery work remain open.
