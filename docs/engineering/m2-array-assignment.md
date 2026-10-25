# M2 Whole-Array Assignment

- Status: implemented and focused-harness verified in development and release
- Evidence: [Windows assignment receipt](../evidence/m2-array-assignment-windows-20261025.json)
- Scope: exact-shape copies into existing mutable scalar arrays in `main`

## Source contract

```text
DESTINATION '=' SOURCE ';'
```

Both names must resolve to visible arrays. The destination must be `var`; source
and destination element types and literal lengths must match exactly. Sources may
be `let` or `var`. Self-assignment is admitted. The source remains live and later
writes to either distinct binding do not affect the other.

Assignment is a statement in ordinary `main` scopes, including loop bodies,
branches, switch-statement arms, and switch-expression arms. The existing
[lexical lifetimes](m2-array-scopes.md) apply. A destination can outlive a source
in an inner scope because its bytes are copied, not borrowed. Its `.len`, catalog
entry, owner token, and generation are unchanged.

The RHS is a bare array name. Parenthesized arrays, array literals, indexed or
member expressions, calls, resizing, conversion, and chained assignment are not
admitted. Array assignment remains excluded from classic `for` init/post statements.
Array parameters/results, helper-function arrays, borrows, slices, and aggregate
wrappers remain unavailable.

[The example](../../examples/array-assignment.brc) assigns from a nested two-element
array, leaves its scope, and returns 42 from the destination.

## Storage and private IR

The owner primitive resolves both tokens and validates the complete owner table,
element type, and length before writing. It scans the entire bool source for
canonical 0/1 bytes before the first destination write, including on self-assignment.
Failed preflight leaves all payload bytes unchanged. Valid owner extents are
disjoint unless the two tokens identify the same owner.

Copying overwrites the destination extent directly. It reserves no additional
array payload or descriptor and changes no owner metadata. It takes O(B) time
and O(1) auxiliary space for B source bytes, plus bounded metadata validation;
bool validation also scans N elements. It works when all 16 owners and the payload
quota are already occupied. This is distinct from declaration-time `ACOPY`, which
creates an independent new owner and extent.

Private opcode 38, `AASSIGN`, is encoded as `38,dst_array,source_array,0,0,0,0,0`.
The independent verifier requires both arrays to be live in the entry function,
an exact shape match, a mutable destination, and zero reserved operands. Assignment
does not change the live-array set or scalar register definitions.

The VM charges `81 + B + (N if bool, otherwise 0)` Fuel before dispatch, covering
two bounded owner resolutions, preflight, byte copying, and optional bool scanning.
The one-element i32 fixture uses exactly 369 Fuel with an eight-byte arena; 368
fails. With the standard 65,536-byte CLI arena, the thresholds are 65,897 and 65,896.
No third array extent is needed. These are payload/Fuel contract checks, not
process-memory or throughput measurements.

A program with `ACOPY` or `AASSIGN` selects the existing
`brownie.m2-array-copy/1` profile ahead of mutable-write and read profiles. The JSON
result schema and version fields are unchanged. No external bytecode loading is added.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice assignment
python -B tools/record-m2-array-write-evidence.py --slice assignment --scalar-regression
```

Per development/release profile, the harness runs 16 native groups: five existing
private-array IR groups, six existing array VM groups, two new owner-assignment
groups, and three new assignment source/verifier groups. The 329 array CLI cases
comprise 67 reads, 61 writes, 58 copies, 40 lengths, 44 scopes, and 59 assignments.
The recorder also executes 1,969 scalar CLI cases per profile on the same binaries.
CLI subprocesses use a tool-free `PATH`.

Coverage includes all six scalar types and boundary values, self-assignment,
independent mutations, nested-scope source release, repeated loop assignment,
maximum-size arrays, full descriptor/payload quotas, exact Fuel, and rejected
immutable, mismatched, dead, or out-of-scope operands. Native malformed IR checks
require rejection at `AASSIGN` for wrong shapes, dead operands, immutable targets,
and reserved bytes. Primitive tests corrupt the final bool byte and verify that
the entire payload remains unchanged on failure.

The scalar instruction implementations, codecs, layout rules, and compiler identity
match the prior scope receipt. Owner assignment, private IR construction/admission,
array verification, and array dispatch change and receive fresh native checks.
The full 84-group scalar native suite, M0 rerun, allocator instrumentation, Linux,
isolation, DLL, and performance checks are skipped.
