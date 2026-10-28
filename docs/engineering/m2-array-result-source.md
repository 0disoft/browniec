# M2 Source Array Results

- Status: implemented; Windows development/release verification is recorded in the receipt
- Scope: named exact-shape scalar-array returns and typed call-result initializers; [direct return calls](m2-array-return-calls.md) have a subsequent focused increment
- Evidence: [Windows receipt](../evidence/m2-array-result-source-windows-20261025.json)
- Example: [`array-results.brc`](../../examples/array-results.brc)

```c
module main;
fn i32[2] make(i32 value) {
    let i32[2] result = [value; 2];
    return result;
}
fn i32 main() {
    let i32[2] result = make(21);
    return result[0] + result[1];
}
```

The compiler connects [signature metadata](m2-array-result-signatures.md) to the
[private result verifier and owner transfer](m2-array-results.md). The former
blanket source gate is removed. The six scalar element types and lengths 1–4096
retain exact shape matching; `main` remains zero-argument scalar `i32`.

## Lowering and cleanup

Before any body is lowered, each array-result function receives a shape anchor.
An exact-shape parameter catalog is reused where available. Otherwise one dead
catalog site is reserved, without allocating a live owner or payload. Anchors,
parameters, captures, locals and call destinations share the 16-site limit.
Declaration order does not affect forward, recursive or mutual calls.

`return NAME;` requires a visible array belonging to the current function with
the declared element type and length. The compiler emits reverse-order drops
for every other visible array, including parameters and anonymous argument
captures, followed by terminal `ARET`. The independent verifier requires the
returned owner to be the only live array. Returning a parameter transfers the
callee's independent by-value copy and preserves the original caller argument.

`let|var ELEMENT[LENGTH] NAME = FUNCTION(arguments);` reserves a dead,
exact-shape caller destination. Shared call parsing evaluates arguments left to
right and captures mutable arrays before later effects. The name becomes visible
only after the call and capture cleanup. Argument returns, `?` failures and loop
transfers therefore never drop an uninitialized destination. Existing immutable
callee bindings and mutable snapshot rules remain in force. A `var` destination
permits indexed writes and whole-array assignment regardless of callee mutability.

Returning transfers an existing owner without another owner allocation, payload
reservation or payload copy. This does not remove parameter copies, mutable
captures, initialization, bool validation or deferred dead extents below a result.
All 32 VM frames share 16 occupied owners and an arena capped at 65,536 bytes.

## Current boundary

Return operands can be bare array names or direct `return function(...);` calls.
The latter now has separate [lowering and verification](m2-array-return-calls.md).
[Repeated return literals](m2-array-return-literals.md) have a subsequent focused
increment. Parentheses, indexing, slices and borrows remain rejected.
Array-result calls are admitted in typed array declaration initializers, direct
returns, and mutable assignment. Repeated array literals are admitted in direct
returns and, through a separate [in-place fill](m2-array-literal-assignment.md),
mutable assignment. Scalar expressions, call arguments, and `for` headers do not
gain aggregate expression support. Wrapper elements and implicit shape
conversions remain unavailable. Unreachable source still has to satisfy static
typing.

## Original source increment verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice result-source
```

The aggregate selection is available for future runs. This increment used
individual native/build/CLI commands; it does not claim an aggregate invocation.
Development combines 18 unchanged passing groups from the first selection with
eight passing source-result groups after correcting a nonterminating mutual-call
fixture. Release selects all 26 identities together. No failed group is counted
as a pass. The native checks exercise small arena ceilings, cleanup omission
rejection and exact Fuel; CLI fixtures run with a cleared tool-free PATH.

Each profile runs 119 new result cases plus 96 signature, 80 parameter,
426 existing array and 1,969 scalar cases: 2,690 CLI cases per profile. The new
cases include all six elements, signed/unsigned edges, lengths 1 and 4096,
both destination mutabilities, recursion, capture ordering, early exits,
16-site/16-owner/32-frame limits, the full 64KiB arena and exact Fuel.
The minimal one-element numeric source program needs 65,760 Fuel with the normal
64KiB preparation, or 228 with a four-byte native arena; one less fails as `fuel`.

The unchanged runtime backend is compared with the prior private-result receipt.
Full scalar/private-array native suites, M0, allocator instrumentation, Linux,
Windows isolation, DLL, clean-machine packaging and performance are not rerun.
The receipt, rather than the presence of fixtures, establishes executed evidence.

## Array call results as arguments

The [argument successor](m2-array-result-arguments.md) now accepts a bare result
call as an exact-element, exact-length array argument, including nested calls.
The destination becomes an anonymous immutable capture only after CALL and
delimiter validation, then reuses mixed array/record cleanup. Parenthesized
calls and call-result indexing remain unsupported. Bare repeated literal
arguments now have a [successor](m2-array-literal-arguments.md).
Earlier counts above remain historical for their original inputs; the successor
reruns the focused source result and parameter selections.
