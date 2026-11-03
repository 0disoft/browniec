# Call-scoped temporary-array borrow arguments

Implemented at `8983737`, following named-slice ranges at `b8ab0eb`.

Array literals and owned array CALL results may supply an explicit `ref` or
`ref mut` argument: `read(ref [42; 3])`, `update(ref mut make())`, or a single
relative range such as `update(ref mut make()[1..])`. This extends
[named-slice range arguments](m2-named-slice-range-arguments.md).
See the [example](../../examples/temporary-array-borrow-arguments.brc).

## Ownership and evaluation

The formal determines the exact scalar element type and access mode. Repeated
literals retain the existing static length of 1 through 4096 and evaluate their
filler once. Owned CALL results must have an array result of the exact scalar
type; their fixed length comes from the signature. A fresh temporary may be
borrowed exclusively even when the producing function returned an immutable
local: ownership has transferred to the caller. Existing named immutable arrays
still cannot be borrowed mutably.

Each temporary has one hidden owner in the enclosing CALL's capture suffix.
Literal initialization or the producer CALL completes before owner publication.
An exit from a filler or producer argument does not drop an uninitialized owner.
The owner is published before parsing/evaluating any range endpoints, so endpoint
exits release that owner. Both endpoints complete, once and in order, before OPEN.
All open-ended and empty ranges use the same bounds rules as existing arrays.

After OPEN, later arguments see the active view. Normal CALL return and lexical
argument exits close views and drop their owners in reverse capture order.
Nested calls preserve the enclosing capture suffix. Scalar, array and record
results use existing result lowering. A temporary owner or view cannot escape
through a name, returned borrow, or retained callee reference.

Runtime failure uses existing canonical invocation drain, preserving the error
and earlier writes. All borrowed sessions must be closed; native failure contexts
may still retain initialized payload/owners until their caller disposes the
invocation. This is not rollback of array allocation or external effects.

## Costs and boundaries

A literal creates one array owner and extent through the existing INIT. A CALL
result uses its existing destination and ownership transfer. No second owner or
array copy is introduced to borrow either kind. Each borrow also uses one static
slice site, one hidden view local, OPEN and CLOSE; DROP follows view closure.
The hidden owner adds one local, so each temporary argument consumes two hidden
locals. Explicit endpoints use their normal scalar instructions and registers.

Prefix decoding and temporary lowering stay outside the recursive scalar CALL
frame. VM dispatch, authority, allocator, persistent layouts, instruction prices,
Fuel, profiles and all existing depth/site/local/register/quota limits remain
unchanged. Version JSON adds `array_slice_temporary_arguments: true`.

Implicit access-mode or scalar coercions, parenthesized temporary roots,
repeated slicing, borrowed CALL results and escaping/returned borrows remain
unsupported. Mutable views still exclude the entire owned root.

## Verification

Development and release each passed **16 native groups and 812 CLI cases**.
Nine new native groups cover six scalar types in both modes, literals and owned
CALL results, relative/open/empty ranges, independent writers, nested calls,
aggregate results, single evaluation and early exits. They check CLOSE followed
by DROP after CALL without array copy, normal zero-owner cleanup, canonical
failure drain, prior writes and a 3-byte quota rejecting a 4-byte literal owner.
Seven existing admission groups exercise the six updated historical test modules.

CLI coverage is 120 temporary-array borrow, 102 named-range, 108 owned-array range,
82 whole-array, 74 mutable-parameter, 74 readonly-parameter and 252 scalar slice
source cases per profile. It uses a cleared environment and tool-free PATH at
1M Fuel/64KiB backing; native fixtures use 16M Fuel/256-byte backing. The fixture
with 15 temporary roots reaches the CLI Fuel cap; 16 roots plus the formal exceed
the static 16-site limit and reject during compilation.

All 457 final input hashes match across profiles and the implementation commit
under Git LF normalization. Compiler, native report, retained CLI artifact and
receipt identities were rechecked. Only compiler lowering, capture prefix
handling and version JSON differ in production; 97 other sources match `cbb9c41`.
Development started before the implementation commit, using the same final
inputs as release. See the
[Windows evidence](../evidence/m2-temporary-array-borrow-arguments-windows-20261103.json).

Full native/full M1/other M2/Linux/isolation/packaging/allocator/
native size-stack/timing are outside this slice. No performance claim is made.
Local only; no push, release or deployment.
