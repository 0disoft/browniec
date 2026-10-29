# Named-array UTF-8 ranges (frontend slice)

`text::valid_utf8(a[START..END])` now passes a byte range of a named `u8` array
to the existing private opcode 52. The frontend admits only statically known
slices; the scan and Fuel rules are those of [opcode 52](m2-array-range-utf8.md).
This slice adds no new IR opcode and no new runtime path. A later
[temporary-range successor](m2-array-utf8-temporary-ranges.md) applies the same
suffix to direct call results and repeated-byte literals; statements below about
unavailable temporary ranges describe this checkpoint. The [open-range
successor](m2-array-utf8-open-ranges.md) accepts omitted endpoints; the
rejection list below describes this checkpoint.

## Syntax and static admission

The accepted form is the qualified predicate call with one bracketed range on a
named array. Supported sources are locals, parameters and named array results
that are live `u8` bindings; `text_source::named` resolves the name through the
local table, requires an array binding, and checks the catalog entry's element
type and owning function.

Both endpoints must be explicit non-negative integer literals in 0..4096, and the
builder enforces `start <= end <= length`. Wrapped unsigned scanner values,
negative values, dynamic bounds, omitted endpoints such as `a[0..]` or `a[..1]`,
extra arguments and reusable `ref` slices are compile errors. Rejects also
cover `a[0...1]`, `a[0..=1]`, `a[0+0..1]`, `a[(0)..1]`, `a[0..a.len]` and
nested `a[0..1][0..1]`.

The lexer reuses its ordinary punctuation token for `.`, consumed twice, so
`a[0 . . 2]` with whitespace between the dots is accepted. No new global lexer
token or keyword was introduced, and scans for other constructs behave as before.

## Lowering and ownership

A successful parse and name check emits opcode 52 with the catalog ID, the two
static endpoints, `b = 0` and a fresh bool destination. Endpoints are encoded
into the instruction rather than evaluated: the new test pins six instructions,
one catalog entry and three registers for a four-byte local, with no endpoint
registers and no source copy. The ordinary whole-array call, call-result and
literal paths keep their previous lowering.

The predicate neither mints an owner nor copies the payload and keeps no
persistent borrow; the source owner and its bytes remain live and the bool is a
plain scalar result. The CLI corpus deliberately fills all sixteen owner slots
and still runs a range predicate, and a separate case proves the guest surface
still lacks borrow syntax.

## Runtime and Fuel

Execution is the synchronous scan in `array_range_vm::step`: prepaid
**65 + 4 * K** work, where `K = end - start`, charged before any byte is read;
empty ranges are valid at 65. The VM supplies its own matching owner table and
backing buffer, pairing them stays a trusted native caller obligation, and the
instruction leaves no borrow behind.

The native test pins the whole-program budget for a four-byte array, `start = 1`,
`end = 3`, at **192** Fuel, with one unit short failing. The CLI fixture
`let bool b = text::valid_utf8(a[start..N])` runs at exactly
**65712 + N + 4 * K** for N in 1, 4 and 4096; `exact - 1` fails at that final
instruction, while only a 52-unit-short pre-scan budget reports the intrinsic
offset.

## Deferred general views

Dynamic or computed endpoints, nested range expressions and persistent borrows
remain unavailable, so general view expressions are still pending work. Temporary
sources are handled by the successor above. Named array-result bindings stay
supported as ordinary named arrays. Caller-side host limits are unchanged:
table-to-backing association stays a trusted native obligation. Version JSON now
reports `"array_utf8_ranges": true` beside `array_utf8_predicate`,
`array_utf8_call_results` and `array_utf8_literals`.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --ranges`
and repeat with `--profile release`. Each profile selects **15 native groups**:
four new range groups, five existing source groups and six range-VM groups. It
then builds the CLI once and runs **582 cases**: 202 new range cases, 142 source
cases, 100 call cases, 130 literal cases and eight sentinel invocations covering
scalar, array and struct programs plus rejection of guest Buffer syntax.

The four new native groups cover the lowering shape, selected boundaries across
calls, scopes, loops and recursion plus the 4096-byte case, the rejection matrix
for wrong types, ranges and expression forms, and exact Fuel. The CLI checker
mirrors those sources through `check` and `run`, adds the valid/invalid UTF-8
corpus with invalid flanking bytes, and asserts the version flags.

Development and release each passed all 15 native groups and 582 CLI cases.
The implementation is committed at `92feb5e`. The [Windows receipt](../evidence/m2-array-utf8-ranges-windows-20261030.json)
records both profiles, matching source/tool hashes, compiler/SDK identities,
all CLI matrix receipt hashes and retained executable hashes. Earlier receipts
remain historical for their exact inputs.

Full native and CLI suites, Linux, M0, DLL embedding, isolation, packaging,
allocation instrumentation and elapsed-time performance were not run for this
slice.
