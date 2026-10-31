# Gated borrowed slice source parameters

Implementation: `8278682`. Source lowering now accepts read-only
`ref u8[]` parameters and explicit `ref name` arguments naming existing lexical
slices. It produces prospective private IR using the existing
[borrowed instruction builders](m2-array-slice-borrow-ir.md).
The initial source-only checkpoint retained an execution gate. The later
[public parameter promotion](m2-array-slice-parameters-public.md) removes that
temporary rejection after metered CALL, dynamic roots and cleanup integration.
Version JSON now reports `array_slice_parameters: true`.

## Source forms and limits

The compiler and public VM now admit this example with an explicit Fuel budget:

```c
module main;
fn i32 first(ref u8[] bytes) {
    let ref u8[] view = ref bytes[..];
    return view[0] as i32;
}
fn i32 main() {
    let u8[1] bytes = [42; 1];
    let ref u8[] part = ref bytes;
    return first(ref part);
}
```

Borrowed parameters may appear alongside scalar/wrapper, fixed-array and record
parameters within the existing eight-argument limit. Formal names remain
immutable and use the existing duplicate/reserved-name rules. Entry parameters,
mutable or non-u8 slices, sized reference parameters, slice results and implicit
conversions remain rejected.

An argument must be `ref` followed by one visible slice name. It can name an
owned-array slice, a borrowed formal or a formal-derived alias/subslice. Repeated
arguments may name the same slice. Bare slice values, direct arrays, literals,
temporary results, inline subslicing, computed slice expressions and names whose
lexical scope ended are rejected. Callers can explicitly bind a slice first.
No temporary borrow or caller-side close is synthesized for a reference argument.

## Signature and body lowering

`functions.Table.param_slices[128]` adds one bounded boolean entry per possible
formal position. A borrowed signature has no scalar type, fixed length or record
shape. Signature scanning knows these kinds before any body is lowered, allowing
forward, duplicate and recursive call forms to be constructed without inventing
future tickets or needing a later function's register/site IDs.

`slice_call_source.bind` uses the existing formal builder to reserve one
non-scalar register position and one self-anchored slice site. It publishes an
immutable lexical binding encoded as `160 + site`. Body order assigns site IDs
from the shared sixteen-site namespace; forward calls consult the signature
kind and encode their caller's existing site.

`slice_call_source.capture` checks explicit reference syntax, lexical visibility,
u8 array/function provenance for owned sites, and same-function formal origin
metadata for borrowed sites. This lowering helper assumes compiler-built
declarations. It does not replace independent whole-Program metadata/liveness
checks or runtime retained-ticket/session validation.

Formal `.len`, indexing and `text::valid_utf8` reuse existing instruction
builders. Aliases and subslices of borrowed formals reserve flattened derived
origins instead of subtracting one from an absent owned-array root. Local owned
slices retain their previous lowering. The existing reverse lexical cleanup
emits closes for derived bindings before formals at function exits, including
question propagation and returns; block/break/continue cleanup preserves outer
formals. Passing a reference does not remove the caller binding or emit a close
at the call site. Existing argument evaluation/capture order is unchanged.

## Execution boundary and remaining work

The initial `8278682` checkpoint produced prospective IR and rejected execution.
The [public successor](m2-array-slice-parameters-public.md) now admits it after the
same full metadata and control-flow proof used by inspection. Well-formed unused
helper signatures are allowed. Invalid IR still fails before Fuel or backing
admission; valid programs reach their actual runtime outcome.

The historical source-only receipt below remains unchanged. Its gate-specific
expectations are historical; current verification uses the promoted CLI matrix.

No opcode, Fuel price, Program/frame field, runtime owner or payload-copy path
is added. The signature scratch table gains 128 boolean entries; native layout,
process memory, allocator usage and timing have not been measured.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-parameter-source`
and repeat with `--profile release`. Each profile selects nineteen native groups:
five source-parameter groups, four parameter-metadata groups, four native argument
batch groups and six existing array-signature groups. CLI selects the gated
source matrix plus 120 alias, 124 subslice and eight ordinary/unsupported-Buffer
sentinel invocations, with runtime tool paths cleared. The gated source matrix
contains 74 invocations, for 326 CLI invocations in total per profile. Both
profiles passed with 330 matching input hashes. Exact checkout bytes match both
receipts; committed text matches after CRLF-to-LF normalization.

Coverage includes mixed signature kinds, main-first forward declarations,
recursive/duplicate reference encoding, formal-derived aliases and nested ranges,
UTF-8/length/index operations, reverse closes, caller-handle preservation,
question/loop/aggregate exits, seventeen unsupported source forms, eight-argument
and sixteen-site boundaries, and verification before Fuel/runtime failure.
See the [Windows evidence](../evidence/m2-array-slice-parameter-source-windows-20261031.json).

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.
