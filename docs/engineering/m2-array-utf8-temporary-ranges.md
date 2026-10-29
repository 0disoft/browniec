# UTF-8 ranges on temporary arrays

`text::valid_utf8(make()[S..E])` and `text::valid_utf8([value; N][S..E])` now
validate a byte range of a temporary array. The named-array slice in
[m2-array-utf8-ranges.md](m2-array-utf8-ranges.md) established the range syntax;
this successor applies the same suffix to direct call results and repeated-byte
literals without adding an opcode, a runtime path or a second owner. Version
JSON reports `array_utf8_temporary_ranges: true`.

## Shared suffix parsing

`compiler::utf8_value` classifies the argument by its first token: `[` starts a
literal, `name(` starts a call, and anything else goes to the named path. All
three converge on `text_source::predicate`, which consumes an optional
`[START..END]` and then the closing parenthesis. The suffix therefore has one
parser for every source form, and no new lexer token or keyword was introduced.

Endpoints must be explicit non-negative integer literals in 0..4096 with
`start <= end <= length`. `[0]`, `[-1..1]`, `[0..]`, `[0..4097]`, an
unterminated suffix and a nested `[0..1][0..1]` are rejected at compile time,
and a computed bound is rejected rather than deferred. Whichever form is used,
the endpoint check sees only the temporary's own length.

## Lowering and ownership

A call form reuses the ordinary CALL/ARET path into a fresh private destination,
emits opcode 52 on that catalog ID, then emits an ADROP for the same ID. A
literal form evaluates its filler once, then allocates the array and publishes
it through AINIT before the scan and the drop. The literal fixture again shows
six instructions, one catalog entry and three registers, matching the named-range
baseline, and the drop operand is asserted equal to the scan's catalog ID.

The filler is evaluated exactly once and ordinary argument order is preserved.
An empty range such as `[N..N]` does not skip construction or evaluation: a
counter incremented inside the filler and inside a call argument still reaches
its expected value, and the empty slice returns true at the minimum charge.

A pending `return` inside the filler or an argument, and a `?` propagation,
create no published temporary owner; loop `continue`
cleanup is exercised by the older whole-call and literal groups in the same
selection. No guest expression runs between publication, the scan and the drop,
and the temporary never appears under a name.

## Verifier and runtime

The frontend emits ADROP immediately after opcode 52 for the same catalog ID. The
verifier does not require that adjacency: it tracks array ownership, clears the
live bit on each drop and requires matching live state at control-flow joins, so
a scalar return that still owns a temporary is rejected. The new
negative case replaces the drop with a jump and fails verification. Opcode, Fuel
price, VM dispatch and IR metadata are unchanged; the CLI version capability is
new.

Scan cost stays `65 + 4 * K` for `K` selected bytes. For `N = 4`, `S = 1`,
`E = 3`, the call form needs exactly **258** Fuel, the literal form **192**, and
the named-array counterpart with its own `let` binding also **258**. One unit
short fails at the final instruction; only a 52-unit-short budget reports the
scan offset. The CLI fixtures follow `65778 + N + 4 * K` for the call form and
`65712 + N + 4 * K` for the literal form, with the same exact-1 and exact-52
behavior.

## Deferred forms

Dynamic, computed or omitted bounds, nested range expressions, general persistent
views and Buffer/text types remain unavailable. Caller-side limits are unchanged:
the owner table and its backing buffer stay a trusted native pairing.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --temporary-ranges`
and repeat with `--profile release`. Each profile selects **16 native groups**:
four new temporary-range groups, four named-range groups, four call groups and
four literal groups. It also runs **832 CLI cases**: 250 new cases, 202 range
cases, 142 named cases, 100 call cases, 130 literal cases and eight sentinels.

The four new groups cover selected bytes over call and literal temporaries
including a 4096-byte range, exact-capacity reuse in a loop with immediate drop
and Fuel parity against the named counterpart, empty ranges with counted
evaluation, pending return and `?` exits, and static admission rejections.

Development and release each passed all 16 native groups and 832 CLI cases.
The implementation is committed at `d70da59`. The [Windows receipt](../evidence/m2-array-utf8-temporary-ranges-windows-20261030.json)
records matching source/tool hashes, compiler/SDK identities, CLI matrix receipt
hashes and retained executable hashes. Earlier receipts remain historical for
their exact inputs.

Full native and CLI suites, Linux, M0, DLL embedding, isolation, packaging,
allocation instrumentation and elapsed-time performance were not run for this
slice.
