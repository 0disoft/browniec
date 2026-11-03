# Call-scoped owned-array range arguments

Implemented at `749f9bf`, following whole-array arguments at `528934b`.

An existing owned array may supply a selected range directly to an exact slice
formal: `ref array[lo..hi]` or `ref mut array[lo..hi]`. Whole-array arguments retain
their existing behavior. This extends the
[whole-array argument contract](m2-array-borrow-arguments.md).
See the [example](../../examples/array-range-borrow-arguments.brc).

## Source and evaluation

Supported forms are `[lo..hi]`, `[lo..]`, `[..hi]` and `[..]`, including empty
ranges. Explicit endpoints must have exact `usize` type. Lower and upper
expressions each execute once, in source order; omitted endpoints use zero and
the fixed root array length. Calls, arithmetic, casts, fields and existing switch
value arms keep their existing expression and depth rules. Mutable access still
requires a mutable binding and mutable descriptor; six scalar element types and
explicit access modes match exactly.

A source-only capture descriptor either carries a ready argument or a validated
owned root whose endpoints remain to be evaluated. It has no runtime handle.
The range endpoint parser lives outside the recursive scalar CALL frame. Both
endpoints complete before the new OPEN and anonymous local are emitted. Endpoint
expressions may therefore access or mutate the root before acquisition, subject
to any earlier captures that are already active.

Nested endpoint calls retain their own argument cleanup. A return, propagation,
break or continue from an endpoint closes only already-live captures, not the
pending range. After OPEN, later arguments see the active borrow; reverse mixed
capture cleanup closes it after CALL or on a later argument exit. Runtime failures
reuse the existing invocation drain, preserving the original error and earlier
writes. There is no automatic replay or external-effect rollback.

## Runtime boundaries

The existing view OPEN validates bounds, including reversed intervals and
full-width usize endpoints. Callee indexes are relative to the selected range.
Normal cleanup restores direct array access after scalar, array or record
results. Exact source/type/lifetime proof runs before Fuel and guest effects,
including unreachable functions.

Exclusion remains per owned root. Two mutable ranges of one array conflict even
when disjoint or empty; this adds no borrow splitting. Readonly duplicates remain
legal. Named slice range arguments, repeated slicing, literal/call-result roots,
implicit mode conversions and escaping or returned borrows remain unsupported.

Each range uses one existing static slice site and anonymous local plus OPEN and
CLOSE. Explicit endpoints use their existing expression instructions/registers;
omitted endpoints emit usize constants. No array owner, result extent, payload
copy, opcode, persistent runtime field or instruction price is added. Existing
source, site/local/register, argument, depth, quota and Fuel limits remain. The
CLI still caps Fuel at 1M. Version JSON adds
`array_slice_array_range_arguments: true`.

## Verification

Development and release each passed **11 native groups and 752 CLI cases**.
Eight new native groups exercise range source behavior and cleanup; three
existing whole-array groups cover updated admission, lowering and error cleanup.
CLI coverage is 108 range-argument, 82 whole-array, 74 mutable-parameter, 74
readonly-parameter, 252 scalar slice source, 50 derived record-result, 44 derived
array-result and 68 lexical reborrow cases. All 451 final input hashes match
across profiles; compiler, native-report, retained CLI and receipt hashes were
rechecked. Three production paths change: source capture, endpoint lowering in
the compiler and CLI version JSON. The other 97 sources match `e51b0ed` under
Git LF normalization. See the
[Windows evidence](../evidence/m2-array-borrow-range-arguments-windows-20261103.json).

Both profiles ran native and CLI checks with the final inputs. Development
started with uncommitted implementation inputs; every input is also checked
against the implementation commit under Git LF normalization.

Coverage includes six scalar types, open/empty
ranges, one-time endpoint evaluation, root mutation before acquisition, nested
endpoint calls, aggregate results, endpoint and later-argument exits, whole-root
conflicts, malformed syntax/types, arithmetic and runtime bounds failures.
Native cleanup checks inspect maps, owner sessions and surviving root payloads
after invalid OPEN, endpoint arithmetic failure and callee bounds failure. A
nested endpoint call writes before an invalid outer OPEN; the write survives.

Native source fixtures use 16M Fuel and 256-byte backing. CLI matrices run with a
cleared environment and tool-free PATH at 1M Fuel and 64KiB backing. Sixteen total
sites compile and reach the CLI Fuel cap; seventeen sites reject at compilation.
A four-level parenthesized endpoint succeeds; forty levels reject under the
existing depth guard. Full native suites, full M1, other M2, Linux, isolation,
packaging, allocator, native size/stack and timing are not covered. No performance
claim is made. Local work only; no push, release or deployment.
