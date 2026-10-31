# Private borrowed slice instruction builders

Admission update: the [public successor](m2-array-slice-parameters-public.md)
now enables verified readonly u8 slice calls. Gate-rejection statements below
refer to the original private checkpoint and its historical receipts.

Implementation: `d001a75`. This checkpoint extends the existing
slice instruction builders to rootless u8 formal and derived sites declared by
the [borrow-aware IR builders](m2-array-slice-builders.md). The independent core
verifier still rejects borrowed parameter metadata before runtime admission.
No guest syntax, runtime borrow instruction support or version capability is
enabled by this construction-only change. The [source successor](m2-array-slice-parameter-source.md)
adds gated signature and explicit reference argument lowering.

## Construction contract

The private `ir.slice_element` helper distinguishes an owned-array site from
a rootless borrowed site. Owned sites require an in-range array root and zero
borrowed origin/function markers. Borrowed sites require a bounded origin and
function, a self-anchored formal in that function and exactly one matching
formal position without a scalar type, mutable slot or owned aggregate shape.
Function/arity/register indices are checked before table access. The formal
positions must already be constructed; final register partitions may still be
open during lowering. Derived origins are already flattened to the formal.

The helper returns the owned array element tag or u8 for a borrowed site. This
is construction-time shape validation, not a whole-Program metadata check,
per-PC ownership/liveness proof or runtime ticket/session check. Builders
operate on coherent in-progress declarations. Foreign scalar-register use and
other whole-Program constraints remain independent verifier obligations.

Existing public IR helpers now construct these same instructions for borrowed
formals and derived sites:

- `slice_utf8`: opcode 55 with a fresh bool register.
- `slice_close`: opcode 56 with no new scalar register.
- `slice_length`: opcode 57 with a fresh usize register.
- `slice_read`: opcode 58 with a fresh u8 register and an ordinary usize index.
- `slice_sub`: opcode 59 with a distinct derived destination, a same-origin,
  same-function parent, ordinary usize bounds and the existing byte-4 endpoint.

A borrowed formal cannot be the destination of a subslice initialization.
Owned and borrowed sites cannot be mixed by subslicing. A derived parent is
checked directly against its formal origin; no traversal or still-live anchor
ticket is required by the builder. Actual liveness remains unproven here.
`slice_open` remains owned-root-only: CALL admission must supply formal runtime
tickets in a later checkpoint. Borrowed scalar positions are explicitly rejected
as indices/endpoints even if malformed metadata supplies a usize tag.

All validation precedes instruction/register publication. Invalid shapes and
operands return kind 3; code/register capacity returns kind 4, with the supplied
offset. Existing bounds remain sixteen sites, 128 registers and 256 instructions.
Failed operations preserve instruction bytes, source offsets, type metadata and
counts. Close and subslice emission need no fresh register and still work when
all 128 positions have been reserved, if code capacity remains.

## Execution boundary and remaining work

This change constructs prospective private IR; it does not certify that IR as
executable. The core verifier gate remains unchanged, as do the VM dispatch,
Fuel schedule and source parser. Existing owned-array slices retain their opcode
encoding and scalar result types. No Program field, payload copy, array owner
or runtime allocation is added.

Source parameter declaration/binding and borrowed call argument parsing are
covered by the gated source successor. Independent borrowed control-flow
verification, dynamic runtime origins, mixed
owned/borrowed frame admission, forwarding/recursion execution and metered normal
and error cleanup remain pending. Slice results remain unavailable. The gate
must remain until runtime and verifier integration are implemented and verified.

## Focused verification

Shape validation uses O(A) lookups for a borrowed site, A<=8, and O(1) for an
owned site. Subslice construction checks two sites, at most sixteen formal
positions in total, with no origin-chain traversal or per-PC state allocation.
Timing and allocator/process-memory behavior were not measured.

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-borrow-ir`
and repeat with `--profile release`. Each profile selects nineteen native groups:
four borrowed-instruction groups, five declaration-builder groups, four parameter
metadata groups, three subslice VM groups and three slice-index VM groups.
CLI regression selects 252 tool-free invocations: 120 aliases, 124 subslices
and eight scalar/array/record/unsupported-Buffer sentinels. Both profiles passed
with 327 matching input hashes. Checkout bytes match both receipts; committed
text content matches after CRLF-to-LF normalization.

Coverage includes typed opcode bytes for rootless formal/derived reads,
retained-child instruction construction after parent close, flattened origins,
sixteen malformed-origin variants, foreign/mixed origin rejection, formal
destination rejection, invalid scalar operand kinds, code/register exhaustion,
failure preservation, legacy non-u8 owned result tags and execution rejection
before backing/Fuel admission. Source slice signatures remain rejected.
See the [Windows evidence](../evidence/m2-array-slice-borrow-ir-windows-20261031.json).

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.
