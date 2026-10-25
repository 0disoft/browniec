# M2 In-Place Repeated-Literal Assignment

- Status: implemented and focused-harness verified in development and release
- Implementation: `d7aa34e`; parser boundary fix: `9522e0e`
- Scope: `ARRAY = [value; N];` for existing mutable scalar arrays
- Evidence: [Windows receipt](../evidence/m2-array-literal-assignment-windows-20261025.json)
- Example: [`array-literal-assignment.brc`](../../examples/array-literal-assignment.brc)

```c
var i32[2] result = [20; 2];
result = [result[0] + 1; 2];
```

The visible destination must be a `var` array. The fill expression is evaluated
once in its element type context before any fill writes occur. Its type and the
literal count must match the destination exactly. All six scalar element types
and lengths 1–4096 are supported; computed counts, element lists, implicit
conversions, immutable destinations, and classic `for`-header array assignments
remain rejected.

The destination remains visible and live while the fill evaluates. Reads such
as `result[0]` therefore use its old value. Nested returns, `break`, `continue`,
and question-mark failures run normal scope cleanup and skip the fill. Argument
captures retain their earlier snapshots when a later argument fills the original.
Effects already produced while evaluating the fill are not rolled back if owner
preflight or scalar encoding later rejects it.

## Owner primitive, verifier and VM

Private opcode 40, `AFILL`, is encoded as `40,destination,value_register,0,0,0,0,0`.
The independent verifier requires a live, function-owned, mutable destination;
a defined immutable scalar register of the exact element type; and canonical
reserved operands. It preserves the live-array set and register definitions.

The owner primitive resolves the live token, validates the complete owner table
and extent, then encodes the scalar into eight scratch bytes. Every fallible check
precedes the first destination write. It fills only the existing extent; tokens,
generations, allocation order, arena usage, and neighboring bytes remain unchanged.
Invalid bool values, stale tokens, corrupt metadata, and truncated backing storage
are rejected without changing any destination payload byte.

AFILL writes all B payload bytes once through the encoded element, taking O(B)
work and eight fixed scratch bytes. It allocates no owner, payload extent, or
catalog site. All 16 owners and the entire 65,536-byte arena can already be
occupied. A maximum-width `i64` or `usize` array needs only its existing 32KiB
extent; no temporary array or copy-back pass is introduced. These are work and
space bounds, not benchmark results.

VM admission prepays `49 + 2 * stride + B` Fuel before dispatch. The minimal i32
source needs exactly 65,756 Fuel with the normal arena, or 224 with four arena
bytes. One less fails as `fuel`; three arena bytes fail as `array_limit` during
the original declaration. Fill selects the existing array-write profile unless
another operation already selects the array-copy profile.

## Verification

The final selection contains 36 unique native groups per profile: 17 reused
backend identities plus 19 fresh frontend groups. Development reuses the backend
groups from `b5e0c98`; release reuses the same identities from its earlier
36-group selection. Reuse validation matched 28 unchanged source and test files to
their `b5e0c98` Git blobs and confirmed matching SDK and compiler identities. Each
profile runs the 19 frontend groups fresh. The aggregate harness was syntax-checked
but not invoked, so no aggregate rerun is claimed.

Each profile passes 2,693 CLI cases: 724 array cases and 1,969 scalar cases. The
array total comprises 115 new, 59 assignment, 115 call-assignment, 119
source-result, 117 direct-return, 119 literal-return, and 80 parameter cases.
Fixtures cover all element types, numeric extremes, maximum lengths, exact Fuel,
full catalog/owner/arena occupancy, early exits, fill-once ordering, rejected
preflight, and independent verifier mutations. The example returns 42 in both
profiles.

The final lowering separates array statement handling and copy/index operations
into distinct helpers, so a recursive fill path retains no unrelated lowering
locals. Scalar and composed-fill cases return 42 at depth 10; depth 11 remains the
`compile_limit` boundary. Two permanent fill CLI cases exercise that composed
boundary. The pre-fix binary reproduces `0xC00000FD` at depth 10. These are
correctness checks, not stack-byte or performance measurements. CLI runs use a
cleared environment and a tool-free PATH.

The receipt records commands, input and fixture hashes, and binary identities
individually. Other native suites, other array CLI matrices, M0, allocator
instrumentation, Linux, isolation, DLL, clean-machine packaging, and performance
checks remain outside this run. Arbitrary aggregate expressions, parenthesized or
indexed array RHS forms, slices, borrows, and wrapper elements remain outside this
increment.
