# Open-ended UTF-8 ranges

`text::valid_utf8(a[..])`, `a[..END]` and `a[START..]` now accept an omitted
endpoint on any supported source: a named live `u8` array, a direct call result
and a repeated-byte literal. The frontend fills the missing bound at compile
time, so the backend sees an explicit range and nothing else.

The [named-array dynamic successor](m2-array-utf8-dynamic-ranges.md) now accepts
scalar usize endpoint bindings on named arrays. Statements below about dynamic
rejection describe the static checkpoint. The [temporary dynamic successor](m2-array-utf8-temporary-dynamic-ranges.md)
now extends the same scalar-name bounds to direct calls and literals.

## Parsing and defaults

At this checkpoint, the shared `text_source::predicate` parser owned every range
suffix. The named dynamic successor briefly split endpoint parsing; the
temporary dynamic successor reunifies all three forms with scalar-name support.
After `[` it treats a leading `.` as `START = 0`, and after the second `.` it
treats `]` as `END = length` for the selected catalog entry. Both defaults are
resolved before the instruction is built, which is why no new token, opcode or
runtime flag is needed.

Explicit endpoints keep the previous rules: non-negative integer literals in
0..4096 with `start <= end <= length`. `a[..2]` past the length, `[2..]` beyond
it, `a[...]`, `a[..-1]`, a computed bound such as `a[..n]` and a nested
`[..][..]` are all rejected at compile time. A leading `.` supplies
`START = 0` and the closing `]` supplies `END = length`; no other token stands
in for a bound.

## Lowering equivalence

Defaults compile to the same bytes as the explicit form. Three new checks compare
code, register types and slots, constant pools and catalog entries for `a[..]`
against `a[0..4]`, `[65;4][..2]` against `[65;4][0..2]`, and `make()[2..]`
against `make()[2..4]`; source offsets differ naturally, the emitted program does
not.

The instruction remains opcode 52 with a prepaid `65 + 4 * K` scan, so inferred
bounds inherit the existing prices: the four-byte `a[..]` fixture totals **200**
Fuel, `[255;4][4..]` is an empty range at **184**, and `make()[..2]` totals
**258** on the call path.

An open range is not the bare argument. `text::valid_utf8(a)` still lowers to
opcode 51 at `33 + 4 * N`, while `a[..]` builds opcode 52 at `65 + 4 * N`; for
N=4 that is 49 against 81 Fuel. The 32-unit difference is the intentional
difference between the whole-array predicate and the range instruction, and
neither backend price changed here.

## Temporary behavior

Open ranges reuse the temporary path unchanged. A call result is published, scanned
and dropped; a literal filler is evaluated once before AINIT; an empty range such
as `[4..]` still constructs and evaluates its source. Pending `return`, `?`
propagation and short-circuit evaluation behave exactly as with closed temporary
ranges, and no register, owner slot or heap copy is added.

## Unsupported forms

General slices, dynamic or computed bounds, and persistent borrows remain
unavailable. No verifier rule changed: it continues to track array ownership
across control flow rather than requiring any particular adjacent cleanup
instruction. Backend pricing, dispatch and IR metadata are unchanged; the CLI
version capability `array_utf8_open_ranges` is new.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --open-ranges`
and repeat with `--profile release`. Each profile selects **12 native groups**:
four new open-range groups, four temporary-range groups and four named-range
groups. It also runs **1102 CLI cases**: 270 new cases, 250 temporary-range
cases, 202 named-range cases, 142 named whole-array cases, 100 call cases,
130 literal cases and eight sentinels.

The four new groups cover `[..]`, suffix and prefix defaults on all three source
forms including an empty and a 4096-byte case, default-versus-explicit lowering
equivalence, temporary evaluation, cleanup and short-circuit behavior, and exact
Fuel with rejected reversed, oversized, malformed and computed bounds.

Development and release each passed all 12 native groups and 1102 CLI cases.
The implementation is committed at `c7830fc`. The [Windows receipt](../evidence/m2-array-utf8-open-ranges-windows-20261030.json)
records matching source/tool hashes, compiler/SDK identities, all CLI matrix
receipt hashes and retained executable hashes. Earlier receipts remain historical
for their exact inputs.

Full native and CLI suites, Linux, M0, DLL embedding, isolation, packaging,
allocation instrumentation and elapsed-time performance were not run for this
slice.
