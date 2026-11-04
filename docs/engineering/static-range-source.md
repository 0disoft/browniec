# Computed Static byte ranges from source

Date: 2026-11-05. This connects the private retained-image source compiler to
[frame-local RANGE execution](static-range-execution.md). It advances B04/D05;
Static CALL/return lifetime receipts, dynamic runtime/Buffer/input views and
ordinary public admission remain open.

## Grammar and evaluation

```brownie
let ref u8[] all = b"x*y";
let ref u8[] selected = all[low()..high()];
let ref u8[] suffix = text::bytes("x*")[1..];
if (text::equal(selected, suffix)) { return selected[0] as i32; }
```

Views can be byte literals, named immutable views with optional explicit `ref`,
parenthesized views, text literals/locals passed through `text::bytes`, and
chained byte ranges. Scalar projections support an additional index or `.len`,
including `(view[lo..hi])[index]`. A missing lower endpoint is usize zero; a
missing upper endpoint reads the actual parent's length. `[..]`, empty ranges
and function/ordinary expression endpoints use the existing private VM path.

Source expressions evaluate the parent, lower endpoint and upper endpoint in
that order. Both endpoints must have exact usize type. A malformed guest range
traps only after both endpoint expressions have completed: an error while
computing the upper endpoint takes precedence over an out-of-range lower value.
RANGE itself precharges Fuel before guest endpoint checking. Nested ranges use
the parent's actual current span, including after temporary-parent closure.

Text ranges are rejected; callers must explicitly project text into immutable
bytes first. Bytes cannot coerce back to text. Existing readonly/mutation,
source/token/depth/register/instruction/Program-wide sixteen-site limits remain.
A full-range source expression still emits its own RANGE definition. Ranges introduce no payload
copy or guest backing allocation.

`static_source` owns atoms, bounded lookahead and declaration headers. The
compiler owns recursive view/range parsing because endpoints reuse its full
ordinary scalar expression and control-flow context. Lookahead examines tokens
without evaluating guest code. Member dots and dots in nested reads/parentheses/
blocks do not count as top-level `..` delimiters. Ordinary scalar grouping and
existing immediate literal projections retain their paths.

## Exit cleanup and argument lifetime

Before parsing either endpoint of an owned parent, the compiler registers that
parent under an unfindable zero-length hidden lexical name. The existing return,
propagation, break, continue and aggregate-return finalizers can therefore close
it on every exited path. A successful RANGE publishes a child first, then closes
only its temporary parent. Named parents remain visible/live. The pending result
binding is introduced only after its initializer and terminator complete.

Equality arguments now admit these effectful range expressions. An owned left
argument enters a separate hidden lexical snapshot before the right argument is
parsed. Right-argument exits close the pending left argument too; right-parent
snapshots retain it as an outer binding. Normal comparison closes owned right
and then owned left temporaries, preserving named arguments. No separate runtime
owner/loan system or unmetered interpreter is introduced.

## Fuel and verification

Existing operation prices and native entry/leave reserves are unchanged. New
independent source-work oracles are 170 for `b"x*"[1..2][0] as i32`, 187 for
branching on an empty `b""[..].len`, and 189 for comparing a selected one-byte
range against a one-byte literal and returning 42. EQUAL uses actual selected
lengths, not maximum proof windows. Each oracle checks one-short/exact/one-more
whole-invocation budgets, with zero guest backing and zero Fuel left at exact.

Run `python -B tools/verify-literal-compiler.py --profile development --selection
ranges --phase native` and repeat for release. The selection includes eleven new
range groups and 21 existing equality/binding/literal/text-dispatch groups.
Serialize `--phase cli` builds for the same two profiles; they run the existing
88 tool-free literal/lexical CLI gates and retain separate artifact hashes.

Windows development and release each passed all 32 native groups and 88
tool-free CLI cases. All four phase snapshots match on 140 input hashes and the
same 227-file test-discovery identity. All 126 production modules are LF and
locked LF mirrors pass. There are no compiler/stack overrides or historical
result reuse. See [focused Windows evidence](../evidence/static-ranges-source-windows-20261105.json).
Implementation is committed as `9b97263`; the evidence records the preceding
starting head and exact final code/input hashes. Early development probes are
excluded; one corrected an invalid usize-to-i32 narrowing in the empty-length
Fuel fixture. Focused checks do not establish full-profile,
general stack/RAM/allocator/timing, Linux, restricted Windows or C ABI/package
conformance. Public compile and returned-reference capability promotion still
require the remaining admission and lifetime work.

Next connect image-backed Static CALL actuals/returns to retained Program origin
and lifetime receipts, then validate public end-to-end admission. The full
accepted implementation objective remains active.
