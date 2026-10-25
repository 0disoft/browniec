# M2 Repeated Array-Return Literals

- Status: implemented; focused Windows development/release evidence is recorded in the receipt
- Scope: `return [value; N];` in exact-shape scalar-array functions
- Evidence: [Windows receipt](../evidence/m2-array-return-literals-windows-20261025.json)
- Example: [`array-return-literals.brc`](../../examples/array-return-literals.brc)

```c
fn i32[2] make(i32 value) {
    return [value; 2];
}
```

This extends [named array results](m2-array-result-source.md) and
[direct return calls](m2-array-return-calls.md). The function's declared return
element type supplies the fill expression's context, including signed minimums
and unsigned maximums. The fill's resulting type and the literal's count must
exactly match the signature. Counts are integer literals from 1 through 4096;
computed counts, element lists and implicit shape/type conversions remain rejected.

The compiler evaluates the fill expression once, then validates the count and
closing syntax before emitting a fresh immutable array site and initialization.
The anonymous result never enters the visible binding table. A nested return,
break or continue during fill evaluation does not initialize or drop that result.
Ordinary arithmetic overflow, division by zero, bounds and Fuel errors propagate.

After initialization, the shared return finisher drops every other visible local,
parameter and pending capture in reverse order, then emits ARET. The independent
verifier requires the returned owner to be the only remaining live array. Returned
values can be bound to `let` or `var` in the caller under the existing rules.

Initialization needs one live owner and one payload extent; transfer introduces
no second owner, reservation or payload copy. Other arrays remain live until
return cleanup, so their extents and parameter copies still contribute to peak
quota usage. The literal site shares the existing 16-site cap, 16 occupied owners,
32 frames and 65,536-byte arena. This is not a performance benchmark.

The minimal one-element i32 literal-return program has the same emitted runtime
work as its named-local equivalent: 65,760 Fuel with the normal arena, or 228
with four native arena bytes. One less fails as `fuel`. Maximum bool literals
retain the existing per-element return validation charge.

Both profiles pass 16 native groups: four new, four direct-return and eight
source-result groups. Each profile passes 628 CLI cases: 119 literal-return,
117 direct-return, 119 source-result, 80 parameter, 96 signature and 97 helper-local.
The new cases cover all six elements, signed/unsigned edges, lengths 1 and 4096,
both destination mutabilities, fill-once behavior, captures, repeated cleanup,
nested returns/loop exits, Fuel and all four quota caps. CLI runs use a cleared
environment and tool-free PATH. Commands, fixtures and binary hashes are recorded.

The expanded `result-source` aggregate harness was syntax-checked, not invoked.
Unchanged backend inputs are compared with the prior receipt. Full native suites,
other array/scalar CLI matrices, M0, allocator instrumentation, Linux, isolation,
DLL, clean-machine packaging and performance checks are not rerun. Parenthesized
or indexed array returns, general aggregate expressions/arguments, assignment RHS,
for-header arrays, slices, borrows and wrapper elements remain unsupported.
