# Array results from derived slice CALLs

Implemented at `56842b9`, following owned argument support at `c9f2294`.
Windows development and release verification passed with matching inputs.

## Source contract

An exclusive reborrow child may now be passed to a function returning a fixed
scalar array. All six scalar element types work. Calls may also carry existing
owned array/record arguments, readonly slices, scalar values and independent
mutable children. Named array arguments can be returned as owned results.

```text
let ref mut i32[] child = ref mut parent[1..];
let i32[2] result = update(ref mut child, input);
```

The caller can use both the returned array and the resumed child after the CALL.
Lexical child cleanup later restores its parent. Formal descendants, forwarding,
recursion and array-result assignment use existing source lowering. Version JSON
adds `array_slice_reborrow_array_results: true`; grammar, profiles and instruction
formats are unchanged. See the [example](../../examples/mutable-slice-array-result.brc).

## Admission and return

Public and checked native admission now permit array results for derived CALLs.
Record results still reject before guest effects, including unreachable functions.

After the complete existing CALL charge is prepaid, preparation checks that the
caller's result destination has both slot and generation zero. A live owner or
malformed empty token fails before loan staging, owned copying or publication.
Scalar/control preflight, source authentication, depth reservation and atomic
argument copying retain their existing order.

The shared VM already dispatches ARET through `slice_authority_call_vm::return_array`.
It authenticates the actual mapped CALL and prepares the unique array result,
including shape, live destination, other callee owners and bool payload checks.
Canonical return restores the caller's child ticket/view before the existing
infallible transfer clears the callee token and installs it in the caller.
There is no second result extent or payload copy during this transfer. This slice
does not change the return helper, owner allocator or shared VM dispatch bodies.

ARET retains its existing `65 + length` charge for bool arrays and `65` for other
scalar arrays. CALL prices, quota/Fuel/frame/site limits, runtime layouts and
cleanup ordering are unchanged. Runtime failure preserves earlier guest writes;
there is no automatic call replay or external-effect rollback.

## Remaining boundaries

Derived record results, escaping borrows and inline temporary CALL borrows remain
outside this slice. Ordinary record results are unchanged. No external bytecode
loader, runtime code cache, JIT, guest GC or host capability is added.

## Verification

Each profile passed 13 native groups: five new array-result source groups, three
admission/atomicity groups, three existing result authentication/restoration/gate
groups and two updated source-admission groups. Each profile also passed 232
tool-free CLI cases: 44 new array-result, 46 owned-argument, 68 lexical reborrow
and 74 mutable-parameter cases.

All 443 current input hashes match across profiles. Compiler, retained CLI and
receipt hashes were rechecked. Only the shared derived admission guard, derived
CALL preparation and CLI version flag change production; 97 other source files
match baseline `7980328` under Git LF normalization. Existing array transfer,
canonical return and shared VM dispatch bodies are unchanged. See the
[Windows evidence](../evidence/m2-derived-array-result-windows-20261103.json).

Coverage includes scalar types, owned/shared/multiple-writer arguments, formal
forwarding, recursion, repeated assignment, callee arithmetic/bounds errors and
result-allocation quota. Admission cases preserve payload, owners, receipts, maps,
tickets, scalar cells and return controls when the result destination is live or
malformed. Existing result tests also cover invalid result/CALL authentication,
late restoration failure with retry, and Fuel/control/live-destination gates.

Native source tests use 16M Fuel and 256-byte backing. CLI cases retain 1M Fuel
and 64KiB backing; explicit recursive and allocation-boundary outcomes reflect
those different budgets. Full native suites, full M1, other M2 matrices, Linux,
isolation, packaging, allocator, native size/stack and timing are outside this
verification. Local commits only; no push, release or deployment.
