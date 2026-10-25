# M2 Array Call-Result Assignment

- Status: implemented; focused Windows development/release evidence is in the receipt
- Scope: `DESTINATION = FUNCTION(arguments);` for exact-shape mutable scalar arrays
- Evidence: [Windows receipt](../evidence/m2-array-call-assignment-windows-20261025.json)
- Example: [`array-call-assignment.brc`](../../examples/array-call-assignment.brc)

```c
var i32[2] result = [0; 2];
result = make(21);
```

This extends [whole-array assignment](m2-array-assignment.md) with a direct
array-result call RHS. The destination must be a visible `var` array; immutable
locals and parameters cannot be assigned. The function must return the exact
element type and length. All six scalar elements and lengths 1–4096 retain their
contracts. Unknown or scalar targets, shadowed functions, wrong arities and
shapes, parenthesized call results, and classic `for`-header assignments are rejected.
[Repeated literal RHS](m2-array-literal-assignment.md) has a subsequent in-place
fill implementation that does not need this call-result temporary.

The destination remains live throughout argument evaluation and CALL. Arguments
retain left-to-right evaluation and mutable snapshot rules, so `a = identity(a);`
reads the original array independently. A fresh immutable anonymous catalog site
receives the returned owner. It stays absent from visible bindings; early returns,
question-mark failures and loop exits cannot drop a pending result. Existing
scope cleanup releases old arrays and any pending captures on those exits.

After CALL and capture cleanup, the compiler emits AASSIGN into the existing
destination and ADROP for the temporary. Destination catalog, token, generation,
extent and length are preserved. The independent verifier requires live,
exact-shape owners and rejects an omitted temporary drop before scalar return.

The RHS must complete before assignment writes occur. Argument-side writes and
external effects retain their ordinary ordering and are not rolled back by later
failure. Runtime failure ends the run; this increment adds no transaction/replay.

Result transfer itself still copies zero payload bytes. Assignment then copies
B result bytes once into existing storage, taking O(B) work and O(1) copy scratch;
bool validation also scans N elements. There is no third extent allocated by
AASSIGN, but the old destination and returned extent coexist. Parameter copies,
mutable snapshots and deferred holes may increase peak payload/owner usage.
All sites share 16 catalogs, 16 occupied owners, 32 frames and a 65,536-byte arena.
The zero-argument maximum-width example needs two 32KiB extents; another live byte
exceeds quota. Mutable self-input needs its additional snapshot and callee copy.

The minimal i32 example needs exactly 65,963 Fuel with the normal arena, or 435
with eight native arena bytes. One less fails as `fuel`; seven arena bytes fail
as `array_limit`. These are work/quota checks, not performance measurements.
Successful call assignments use the existing `brownie.m2-array-copy/1` profile.

Both profiles pass 15 native groups: four new, three whole-array assignment and
eight source-result groups. Each profile passes 609 CLI cases: 115 new,
59 assignment, 119 source-result, 117 direct-return, 119 literal-return and
80 parameter cases. Cases cover all elements, numeric edges, maximum lengths,
helper scopes, self-input, capture order, early exits, repeated cleanup, Fuel,
all quota ceilings and verifier rejection of a leaked temporary. CLI subprocesses
use a cleared environment and a tool-free PATH.

The receipt records individual commands, fixture hashes and binary identities.
The initial native attempt failed one incorrectly calculated Fuel boundary; all
15 groups were rerun successfully after correction. No partial failed selection
is reused. The expanded aggregate harness was syntax-checked, not invoked.
Unchanged backend inputs are compared with the previous receipt. Full native
suites, other array/scalar CLI matrices, M0, allocator instrumentation, Linux,
isolation, DLL, clean-machine packaging and performance checks are not rerun.
