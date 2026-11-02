# Owned arguments in derived slice CALLs

Array-result successor: [derived array results](m2-slice-reborrow-array-results.md).
The result restrictions below describe the `c9f2294` checkpoint.

Implemented at `c9f2294`, following lexical reborrow source at `3a07820`.
Windows development and release verification passed with matching inputs.

## Supported calls

A live mutable child may now share a CALL with immutable owned scalar arrays and
records, readonly slices, other independent mutable children and scalar values.
The caller retains its original owned values. Each aggregate formal receives a
distinct owned copy through the existing array/record copier, including repeated
uses of the same immutable record argument. All six scalar array types work.

```text
let ref mut i32[] child = ref mut parent[1..];
let i32 answer = update(ref mut child, input_array, adjustment_record);
```

Source syntax and lowering are unchanged. Public verifier admission, checked
native execution and the canonical VM share the extended argument boundary.
Version JSON adds `array_slice_reborrow_owned_arguments: true`. See the
[runnable example](../../examples/mutable-slice-owned-call.brc).

## Transaction order

1. Prepay the existing complete CALL charge and preflight scalar registers and
   return-control destinations.
2. Authenticate the original child/CALL maps, authority, shared readers, mutable
   tickets, selected ranges, frame/depth reserves and empty callee cells.
3. Stage reader retention and writer rotation in the existing private loan plan.
4. Run `struct_call_vm::step` as the final fallible operation. Its existing atomic
   array/record copier validates every source and reservation before payload writes.
   Copying allocates only new owner descriptors and preserves existing sessions.
5. Publish authority, pool, tickets, origins and CALL metadata, followed by scalar
   arguments and return-control cells. These operations are infallible.

`slice_reborrow_call_vm::enter_owned` owns this synchronous sequence. The existing
readonly-backing `enter` adapter still rejects owned arguments. Preparation itself
publishes no owned copy or loan, and its plan must not be activated separately.

Owned copying is included once in the existing complete CALL charge; the nested
copier's remaining Fuel is not substituted for that charge. Return and abort use
the existing canonical cleanup. Callee copies are dropped before normal return
restores the child's selected view. Runtime failure preserves earlier guest writes
and does not replay a call.

No Program, owner, pool, receipt or persistent frame layout changes. The record
copier retains its existing fixed scratch; this path adds no payload snapshot or
authority clone. Prices, quota rules, frame/depth limits and profiles are unchanged.

## Remaining boundaries

Derived CALLs returning arrays or records still reject during verification before
Fuel, quota or guest effects, including unreachable functions. Duplicate mutable
arguments and suspended-parent access remain invalid. Ordinary CALLs retain their
existing aggregate results. Inline temporary borrows, escaping borrows, external
bytecode, runtime code caching, JIT and guest GC are not added.

## Verification

Each profile passed 16 native groups: five new source groups, two new atomicity
groups, eight existing derived-execution groups and one existing source-admission
group. Each also passed 188 tool-free CLI cases: 46 new owned-argument cases,
68 lexical reborrow cases and 74 mutable-parameter cases. They cover six scalar
types, record/array/shared/scalar mixtures, repeated records, multiple writers,
formal descendants, recursion, caller resumption and error paths.

All 441 input hashes match across profiles; compiler, retained CLI artifacts and
receipt hashes were rechecked. Five production paths differ from `80c5b9e`; 95
other sources match under Git LF normalization. The evidence also records the
test-only removal of three unused import/helper lines after `c9f2294`; both final
profiles use that corrected fixture. See the
[Windows evidence](../evidence/m2-derived-owned-call-windows-20261103.json).

Atomicity cases check one-short Fuel, an invalid late bool payload, copy quota,
a stale owned token, a dirty callee cell and insufficient register capacity.
Failure preserves payload bytes, owners, receipts, tickets, maps, scalar registers
and return-control cells. Exact-charge success publishes distinct copies and
restores the original child view after normal return.

The CLI keeps its 1M Fuel cap and 64KiB backing; native source tests use 16M Fuel
and 256-byte backing. Expected Fuel/quota outcomes therefore differ for explicit
boundary fixtures. Full native suites, full M1, other M2 matrices, Linux,
isolation, packaging, allocator, native size/stack and timing are outside this
verification. Local commits only; no push, release or deployment.
