# M2 Direct Array-Return Calls

- Status: implemented; focused Windows development/release verification is recorded in the receipt
- Scope: `return FUNCTION(arguments);` in exact-shape scalar-array functions
- Evidence: [Windows receipt](../evidence/m2-array-return-calls-windows-20261025.json)
- Example: [`array-return-calls.brc`](../../examples/array-return-calls.brc)

```c
fn i32[2] forward(i32 value) {
    return make(value);
}
```

This extends [source array results](m2-array-result-source.md). The callee must
return the enclosing function's exact element type and length. All six scalar
elements and lengths 1–4096 are supported. Forward, recursive and mutual calls
retain their rules. Local bindings shadow functions. Scalar results, `main`,
unknown targets, wrong arities and incompatible shapes fail compilation.

The compiler reserves one fresh immutable caller catalog site for the anonymous
result and reuses the call parser. Arguments evaluate left to right, capturing
mutable arrays before later effects. The destination remains absent from visible
bindings: returns, breaks and continues during argument evaluation never drop a
pending result. Nested early returns release pending outer captures normally.

After CALL and its capture cleanup, the shared return finisher drops every other
visible array in reverse order and emits terminal ARET for the anonymous result.
The independent verifier requires that result to be the sole remaining live array.
Locals, parameters and pending enclosing argument captures participate in cleanup.

Owner transfer copies zero payload bytes and requires no extra live owner or
payload reservation. Parameter entry copies, mutable captures and deferred dead
extents keep their existing costs. The anonymous site shares the 16-site cap;
ordinary CALL/ARET retain the 32-frame, 16-owner and 65,536-byte arena ceilings.
Recursive direct returns consume frames. One zero-argument numeric forwarding
layer adds 66 Fuel: total 65,826 with the normal arena, or 294 with four native
arena bytes. One less fails as `fuel`; bool returns retain per-element validation.

Both profiles pass 12 native groups (four new and eight source-result groups)
and 509 CLI cases (117 direct-return, 119 source-result, 80 parameter, 96 signature,
97 helper-local). Tool-free CLI runs cover all elements, signed/unsigned edges,
maximum lengths, destination mutability, parameter independence, capture order,
repeated cleanup, nested early exits, exact Fuel and all four shared quota caps.
The receipt records individual commands, input hashes and binary identities.
The expanded `result-source` aggregate harness was syntax-checked, not invoked.
Unchanged backend inputs are compared with the previous source receipt. Full
native suites, other array/scalar CLI matrices, M0, allocator instrumentation,
Linux, isolation, DLL, clean-machine packaging and performance are not rerun.

[Repeated return literals](m2-array-return-literals.md) have subsequent focused evidence.
Parenthesized/indexed results, aggregate scalar expressions,
array-result call arguments, literal assignment RHS, for headers, slices, borrows and
wrapper elements remain unsupported. General aggregate expressions and frame
elision have no new contract in this increment.
