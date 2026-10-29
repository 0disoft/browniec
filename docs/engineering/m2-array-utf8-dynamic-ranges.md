# Named-array UTF-8 ranges with local endpoints

`text::valid_utf8(a[lo..hi])` accepts existing scalar `usize` bindings as
endpoints on a named live `u8` array. Local `let` and `var` bindings and scalar
function parameters are supported. Bindings may hold values computed by earlier
statements, including an array length. An endpoint inside the brackets is still
one name or a literal, rather than an arbitrary expression.

```c
let u8[4] bytes = [65; 4];
var usize start = 1;
let usize end = bytes.len;
if (text::valid_utf8(bytes[start..end])) { return 42; }
```

## Parsing and lowering

The named-array parser accepts `[lo..hi]`, `[lo..3]`, `[1..hi]`, `[..hi]` and
`[lo..]`. Omitted bounds become 0 or the catalog length. A scalar name must be
in scope, have tag 12 (`usize`), and refer to a scalar register rather than an
array or record binding, including aggregate parameters. There is no implicit
conversion from another integer or sum type. A mutable binding emits a `LOAD`
at each use, so later assignments and loop iterations observe its current value.

If neither endpoint is a name, lowering retains opcode 52 with immediate bounds
and the existing compile-time bounds check. This also preserves its code,
register count and Fuel behavior for open ranges. If either endpoint is a name,
the compiler materializes any literal/default endpoint as a `usize` constant and
emits the existing opcode 53. An immutable endpoint reuses its value register;
a mutable endpoint uses one fresh loaded register. The bool destination is fresh.

No owner, payload copy or retained read session is added. Named array locals,
parameters and named call results remain live after the predicate. The
independent verifier and runtime retain the checks of the
[register-bounded VM foundation](m2-array-dynamic-utf8.md).

## Runtime bounds and Fuel

Opcode 53 prepays **65 + 4*N** for the entire root length N before reading the
endpoint cells. This is deliberate even for a small or empty selected range;
opcode 52 still costs **65 + 4*K** for K selected bytes. The source extension
changes neither backend price. Loads and materialized constants have their
ordinary instruction cost.

Dynamic endpoints require `start <= end <= length` at runtime. A reversed or
out-of-bounds range reports `bounds` (kind 14, CLI exit 5) at `text::valid_utf8`.
Full unsigned decoding rejects 2^63 and `usize` MAX without truncation. A short
scan budget reports `fuel` before inspecting the endpoint cells. An empty valid
range returns true; malformed UTF-8 within a valid range returns false.

For the four-byte fixtures with two immutable endpoint bindings and an unused
bool result, total native execution using a four-byte arena costs **202** Fuel.
The corresponding default-arena CLI programs cost **65,734**. Full, partial and
empty ranges have that same total; one unit less fails. These are fixture totals,
not a general program pricing formula.

## Unsupported forms

At this checkpoint, dynamic endpoints on direct temporary calls or repeated-byte
literals were rejected. The [temporary dynamic successor](m2-array-utf8-temporary-dynamic-ranges.md)
now supports them with the same name/literal admission and immediate drop. Endpoint calls,
arithmetic, casts, parentheses, field/index expressions, general slices and
persistent borrows remain unavailable. Compute a scalar value in an earlier
binding to use it as a bound. The CLI version adds
`array_utf8_dynamic_ranges: true`, scoped to named arrays and scalar names.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --dynamic-ranges`
and repeat with `--profile release`. Each profile selects **24 native groups**:
five new source groups, five dynamic VM groups, six static VM groups, four
named-range groups and four open-range groups. The CLI selection comprises
**1,114 invocations**: 634 new dynamic cases, 270 open-range cases, 202 static
named-range cases and eight sentinels, all with a tool-free runtime PATH.

The source tests cover mutable reloads, loops, recursion, scalar/array parameters,
named array results, omitted/mixed endpoints, preservation of the source owner,
short-circuit skipping of invalid bounds, bounds failures, full unsigned values,
exact Fuel and rejected types, scopes, computed endpoints and temporary forms.
The CLI matrix exhausts endpoint pairs on short arrays, probes the 4,096-byte
limit and unsigned edges, and selects every range boundary around a four-byte
UTF-8 scalar surrounded by invalid bytes.

Development and release each passed all 24 native groups and 1,114 CLI
invocations for implementation `9bb31ed`. The [Windows receipt](../evidence/m2-array-utf8-dynamic-ranges-windows-20261030.json)
records matching source/tool inputs, compiler/SDK identities, original and CLI
matrix receipt hashes, and retained executable hashes. Earlier receipts remain
historical for their exact inputs.

Full suites, other CLI matrices, M0, Linux, DLL embedding,
isolation, packaging, allocation instrumentation and timing benchmarks are
outside this selection. Scans remain synchronous and non-interruptible.
