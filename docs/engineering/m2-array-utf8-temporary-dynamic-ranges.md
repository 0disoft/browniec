# UTF-8 temporary-array ranges with local endpoints

The [computed-endpoint successor](m2-array-utf8-computed-ranges.md) now accepts
ordinary usize expressions on named arrays. Restrictions below describe this
checkpoint; temporary computed bounds and persistent views remain unavailable.

`text::valid_utf8(make()[lo..hi])` and
`text::valid_utf8([value; N][lo..hi])` accept existing scalar `usize` bindings
as endpoints. Mixed literal/name endpoints and omitted bounds work as on
[named arrays](m2-array-utf8-dynamic-ranges.md). This extends the frontend;
the IR, verifier, VM dispatch and backend Fuel prices are unchanged.

## Evaluation and lifetime

Call arguments and repeated-literal fillers finish before a temporary owner is
published. A filler evaluates exactly once, including for an empty selected
range. After CALL/ARET or AINIT, the shared suffix parser emits only scalar
loads/constants and the scan; no endpoint can execute guest code. Mutable names
therefore observe changes made by the preceding arguments or filler. Immutable
names reuse existing value registers. The temporary remains absent from names.

Opcode 53 consumes the resulting endpoint registers and produces a bool. ADROP
immediately follows the scan for the same catalog ID. Nested predicates finish
and drop before the outer call or literal publishes its result, so sequential
one-byte temporaries work in a one-byte arena. No additional owner, payload
copy or retained lease is introduced beyond ordinary temporary construction.

A pending `return`, `?`, `continue` or `break` in an argument or filler occurs
before publication. Existing argument/capture cleanup stays responsible for
earlier values. Short-circuit branches skip construction and scanning together.
The verifier tracks owner liveness rather than requiring adjacency; deleting
the drop and returning with the anonymous owner still live fails verification.

## Bounds and Fuel

With a name endpoint, the frontend uses existing opcode 53 and materializes
literal/default operands as `usize` constants. Runtime bounds require
`start <= end <= length`; invalid bounds report kind 14 (`bounds`, CLI exit 5)
at `text::valid_utf8`, including full unsigned values such as 2^63 and MAX.
Opcode 53 prepays **65 + 4*N** against the entire root length before reading its
endpoint registers. Loads executed before the scan keep their ordinary cost.
The scan remains synchronous. Runtime failure aborts through the existing VM
error path; this extension adds no error recovery or retained scan state.

All-static ranges retain opcode 52 and **65 + 4*K** for K selected bytes; bare
temporary predicates retain opcode 51. For the four-byte, two-immutable-bound
fixtures with an unused bool, literal execution costs **202** Fuel with a
four-byte arena, and a direct zero-argument call costs **268**. Default-arena
CLI totals are **65,734** and **65,800** respectively. Full, partial and empty
ranges have the same dynamic price; exact-minus-one fails. These totals describe
those fixtures, not arbitrary call arguments, fillers or mutable bounds.

## Admission and capability

The shared parser accepts one in-scope scalar `usize` name or a literal per
endpoint. `[..hi]` supplies zero; `[lo..]` supplies the temporary's catalog
length. Wrong scalar/sum types and array/record bindings are rejected. Endpoint
calls, arithmetic, casts, field/index expressions, repeated slicing and escaping
views remain unavailable. Compute an endpoint in an earlier binding instead.
Array lengths remain bounded to 1..4096.

Version JSON adds `array_utf8_temporary_dynamic_ranges: true`, alongside the
existing named-array dynamic capability. General slices, persistent borrows and
Buffer/text ownership remain separate work.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --temporary-dynamic-ranges`
and repeat with `--profile release`. Each profile selects **23 native groups**:
five new temporary-dynamic groups, five named-dynamic groups, four static
temporary groups, four open-range groups and five dynamic VM groups. The CLI
selection contains **1,646 invocations**: 484 new temporary-dynamic cases,
634 named-dynamic cases, 250 static temporary cases, 270 open-range cases and
eight sentinels. Runtime PATH contains no build tools.

Checks cover post-argument/filler mutable reads, counted evaluation, nested and
loop capacity reuse, immediate drop plus verifier rejection of its removal,
pending exits, earlier record captures, short circuiting, full/partial/empty
Fuel, multibyte boundaries, maximum-length roots and unsigned bounds failures.

Development and release each passed all 23 native groups and 1,646 CLI
invocations for implementation `bb7476a`. The [Windows receipt](../evidence/m2-array-utf8-temporary-dynamic-ranges-windows-20261030.json)
records matching source/tool inputs, compiler/SDK identities, original and CLI
matrix receipt hashes, and retained executable hashes. Earlier receipts remain
historical for their exact inputs.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation,
packaging, allocator instrumentation and timing benchmarks are not included.
