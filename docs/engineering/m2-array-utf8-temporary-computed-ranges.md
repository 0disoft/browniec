# Computed UTF-8 endpoints on temporary arrays

`text::valid_utf8(make()[start + 1..end()])` and
`text::valid_utf8([value; N][start + 1..end()])` accept ordinary scalar `usize`
endpoint expressions. They reuse the [named-array expression parser](m2-array-utf8-computed-ranges.md),
including arithmetic, calls, casts, scalar fields, array reads, switches and
omitted bounds. Version JSON adds `array_utf8_temporary_computed_ranges: true`.

## Publication and cleanup

Arguments or the repeated literal filler evaluate before the array is published,
as before. When the suffix contains computed bounds, `utf8_temporary_range`
adds the published owner to a snapshot of the current lexical binding table.
Its empty name span cannot match a guest identifier. Existing `return`, `?`,
`continue` and `break` lowering now sees that owner and emits ordinary cleanup
in reverse order with any earlier captures. The binding snapshot is discarded
when lowering finishes; it neither creates another owner nor copies payload.

On normal completion, opcode 53 scans and one ADROP immediately follows for
the same catalog ID. An early exit drops the owner and skips the scan and its
normal drop. Independent owner-liveness verification rejects a path that returns
with the temporary still live. The mechanism matches existing temporary-array
index-expression cleanup and adds no opcode, runtime dispatch or VM state.

Simple name/literal/omitted-bound suffixes keep their previous fast path,
instruction/register counts, Fuel and binding-table requirements. Computed
suffixes require one anonymous entry in the existing 64-binding table; a full
table produces `compile_limit`, while the old simple forms still fit. The
capture is compiler metadata and does not consume a guest scalar register.

## Evaluation and capacity

Construction precedes start evaluation, which precedes end evaluation. Each
evaluates once, even for an empty selected range. The start is materialized
before end effects can change its mutable source binding. Short-circuiting skips
construction, endpoint expressions and scanning together.

An outer temporary stays live throughout endpoint evaluation. If a bound creates
another temporary, both must fit at once: the nested one-byte fixture requires
two bytes and fails with `array_limit` at one byte. This is required live storage,
not a payload copy added by the range operation. Once each predicate finishes,
its storage is released, so the same capacity can be reused across loop iterations.
Nested early exits also release both captures, including earlier record arguments.

## Fuel and failures

Endpoint expressions consume ordinary Fuel before the scan. Their overflow and
division errors keep their existing categories; final reversed or oversized
endpoints report `bounds` at `text::valid_utf8`, including full unsigned values.
After evaluation, opcode 53 prepays **65 + 4*N** for root length N. Original
literal-only ranges retain opcode 52 and **65 + 4*K** for selected length K.
No backend price changes, retries, retained leases or rollback are introduced.
Effects before an error or early exit are not rolled back. Runtime failures use
the existing VM abort path; this extension adds no guest recovery mechanism.

The four-byte fixture with `0+0..4`, an unused bool and return 42 costs **204**
Fuel for a repeated literal and **270** for a zero-argument call using a
four-byte arena. Default CLI totals are **65,736** and **65,802**. The empty
`4+0..4` fixtures cost the same; exact-minus-one fails. These totals exclude
arbitrary extra calls/effects in fillers, arguments or endpoints.

All source forms now use the expression parser for malformed complex ranges;
inclusive `..=` remains unsupported and reports `syntax`. General slices,
persistent borrows and Buffer/text ownership remain unavailable.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --temporary-computed-ranges`
and repeat with `--profile release`. Each profile selects **23 native groups**:
five new temporary-computed groups, five named-computed groups, five temporary
name-bound groups, four static temporary groups and four open-range groups.
The tool-free CLI selection contains **1,518 invocations**: 310 new,
196 named-computed, 484 temporary name-bound, 250 static temporary, 270 open-range
and eight sentinels.

The new groups cover expression forms and defaults, construction/start/end
ordering, once-only effects, start snapshots, loop capacity reuse, overlapping
nested storage, all four endpoint exits, nested and record captures,
short-circuiting, exact Fuel, drop-removal rejection and existing runtime errors.
CLI cases additionally cover maximum-length arrays, full unsigned endpoints,
UTF-8 boundaries and the 63/64-binding admission edge.

Development and release each passed all 23 native groups and 1,518 CLI
invocations for implementation `62ad15f`. The [Windows receipt](../evidence/m2-array-utf8-temporary-computed-ranges-windows-20261030.json)
records matching source/tool inputs, compiler/SDK identities, native reports,
original and CLI matrix receipt hashes, and retained executable hashes. Earlier
receipts remain historical for their exact inputs.

Full suites, other CLI matrices, M0, Linux, DLL, isolation, packaging,
allocation instrumentation and timing benchmarks are outside this selection.
