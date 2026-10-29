# Computed UTF-8 range endpoints on named arrays

The [temporary-computed successor](m2-array-utf8-temporary-computed-ranges.md)
now accepts endpoint expressions on direct call results and repeated literals,
with anonymous lexical capture for early-exit cleanup. Restrictions and the
older temporary-parser diagnostic distinction below describe this checkpoint.

`text::valid_utf8(a[lo + 1..a.len])` accepts ordinary scalar `usize`
expressions as endpoints when `a` is a named live u8 array. Arithmetic, calls,
parentheses, supported widening casts, array reads, scalar record fields and
switch expressions reuse the existing expression parser and its limits.
The CLI version adds `array_utf8_computed_ranges: true` for named arrays only.

```c
let u8[4] bytes = [65; 4];
let usize start = 1;
if (text::valid_utf8(bytes[start + 1..bytes.len])) { return 42; }
```

## Parsing and lowering

`text_source::argument` resolves the live array and consumes its name. A bounded
lookahead reads at most five tokens to recognize the original name/literal/
omitted-bound grammar. That path keeps the existing code and Fuel costs: all
literal bounds use opcode 52; name bounds use opcode 53. The preview neither
emits instructions nor advances the actual lexer state.

Other named-array suffixes use `compiler::utf8_computed_range`, which parses
ordinary expressions with expected type `usize`. Both resulting registers must
have tag 12; implicit integer coercion is not added. Omitted bounds become zero
or the catalog length. Every computed form emits existing opcode 53, including
constant arithmetic or parenthesized constants. It is not constant-folded into
the static path. A scalar record field can end at the two-dot separator, while
a further member after a scalar field remains invalid. Inclusive `..=` ranges
stay unsupported: malformed named `[..=1]`/`[0..=1]` now report `syntax` through
the expression path, while the unchanged temporary parser still reports `type`.

The existing independent verifier checks readable, defined, same-function
endpoint registers, fresh bool destination and live function-owned u8 root.
This extension changes no opcode, instruction encoding, runtime dispatch or
backend scan price. General slices and persistent borrows are not introduced.

## Evaluation and exits

Start and end evaluate once, from left to right, before scanning. A mutable start
is loaded before any end-expression effects, so changing that variable later
does not change the captured start. Changes to array contents during endpoint
evaluation are visible to the scan. Nested temporary predicates use their
existing immediate cleanup before the outer scan; this path adds no root owner
or payload copy. Endpoint calls may create their own ordinary arguments/results.

Named roots remain in the lexical binding table during evaluation. Existing
cleanup therefore handles `return`, `?`, `continue` and `break` inside endpoint
switch arms. Short-circuit branches skip endpoint expressions and the scan.
Earlier effects are not rolled back if evaluation or scanning later fails.

## Bounds and Fuel

Arithmetic, calls and control flow consume ordinary Fuel before the scan. An
overflow or division by zero reports its existing runtime error before scanning;
a final `start > end` or `end > length` reports `bounds` at `text::valid_utf8`.
Full unsigned endpoint values are not truncated.

After endpoint evaluation, opcode 53 prepays **65 + 4*N** for root length N
before reading its endpoint registers. This does not prepay the endpoint
expressions themselves. The scan remains synchronous; even an empty computed
range prepays the root cost. Original literal opcode 52 retains **65 + 4*K**.
The four-byte fixture `a[0+0..4]` with an unused bool and return 42 costs **204**
Fuel with a four-byte arena, or **65,736** with the default CLI arena. A budget one unit below that total fails; a short scan budget preserves the
intrinsic offset.

## Scope and verification

Computed bounds on direct temporary calls and repeated-byte literals remain
unavailable. Those forms still accept scalar names, literals and omitted bounds
without executing guest expressions after temporary publication. Buffer/text
ownership, general views and persistent borrows remain separate work.

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --computed-ranges`
and repeat with `--profile release`. Each profile selects **23 native groups**:
five computed-source groups, five name-bound groups, five temporary dynamic
groups, four static range groups and four open-range groups. The tool-free CLI
selection contains **1,794 invocations**: 196 new, 634 name-bound, 484 temporary
dynamic, 202 static range, 270 open-range and eight sentinels.

The new checks cover scalar expression forms, field separators, once-only
evaluation and start snapshots, array mutation, nested temporary capacity,
endpoint exits, short circuiting, exact Fuel, overflow/division/bounds errors,
unsigned edges, maximum-length arrays and expression depth limits.
Development and release each passed all 23 native groups and 1,794 CLI
invocations for implementation `b2ce341`. The [Windows receipt](../evidence/m2-array-utf8-computed-ranges-windows-20261030.json)
records matching source/tool inputs, compiler/SDK identities, native reports,
original and CLI matrix receipt hashes, and retained executable hashes. Earlier
receipts remain historical for their exact inputs.

Full suites, other CLI matrices, M0, Linux, DLL, isolation, packaging,
allocation instrumentation and timing benchmarks are outside this selection.
