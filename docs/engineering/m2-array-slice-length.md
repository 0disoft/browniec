# Checked lexical slice length

Implementation: `f56e4aa`.

Lexical `ref u8[]` bindings now expose `.len` as an ordinary usize value. This
extends the [source slice contract](m2-array-utf8-slices.md) using private opcode
57 and the existing checked registry. Version JSON adds `array_slice_length: true`.

```c
let u8[4] bytes = [65; 4];
let ref u8[] part = ref bytes[1..];
let usize count = part.len; // 3 bytes
```

## Source behavior

The length is the selected byte count, including zero for empty ranges. It is
not a UTF-8 scalar/character count: a range containing one four-byte scalar has
length four. Whole/open/computed selections, named array parameters/results,
and existing lexical scopes work as before. The result participates in ordinary
usize arithmetic, comparisons, calls, record constructors and subsequent range
endpoints. A scalar snapshot may outlive the slice; no handle or loan escapes.

The getter does not evaluate the original endpoints again. It reads the retained
range after validating that the root and session are still live. Changing an
unrelated variable previously used as a bound cannot change the selected length.
It does not end a borrow; root writes remain blocked until lexical cleanup.
Existing scope, return/question/break/continue cleanup is unchanged.

The [indexing successor](m2-array-slice-index.md) adds checked scalar reads.
The [subslice successor](m2-array-slice-sub.md) adds parent-relative ranges.
The [alias successor](m2-array-slice-alias.md) adds whole-parent reborrows.
Parameters/results as slices, mutable slices
and borrowing temporaries remain unavailable. Unknown members are type errors.
Calling `.len()` or appending another suffix is rejected by the existing grammar.
There is no implicit narrowing from usize to u32/i32. Ordinary array `.len` still
uses its original fixed-shape constant lowering and exact Fuel price.

## IR, verification and execution

Opcode 57 is eight bytes: `op,dst,a,0,0,0,0,0`, where a is a declared live slice
site and dst is a fresh usize register. The existing slice verifier requires a
live function-owned origin and slice, correct result type, unused nonslot result
register, canonical operands and function-local register partition. Origin and
borrow live sets are unchanged. No new per-PC state table is added.

Runtime execution checks frame/site bounds, Program origin shape, current owner
token, ticket generation, active session, retained range and current backing
capacity before publishing the result. This includes empty ranges: stale empty
handles cannot return zero without lifetime validation. Missing backing,
frame-mismatched tickets and malformed state fail before result publication.

The instruction prepays 4097 Fuel before semantic ticket reads and reuses
`array_slices.length`, then packs the bounded result in the ordinary usize cell.
It reads no payload bytes, copies no payload and adds no owner, registry entry or
heap allocation path. Each emitted getter consumes one ordinary scalar register;
the existing 128-register program ceiling still applies. Fixed metadata work is
O(D*O) with D=O=16, independent of the selected length. This is structural
accounting, not allocator/process-memory or timing measurement.

Insufficient Fuel leaves the output cell and handle state unchanged. Native
stale/malformed state uses existing kind 5; Fuel uses kind 8. Normal and error
cleanup retain their existing behavior. The four-byte source length-comparison
fixture needs exactly 73855 Fuel with a four-byte arena, or 139387 with the CLI's
default 65536-byte arena. Existing scan/open/close prices are unchanged.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-length`
and repeat with `--profile release`. Each profile passed 21 native groups: four
new length groups, eight private slice VM, six source slice and three ordinary
array length groups. Each passed 360 tool-free CLI invocations: 104 new length,
248 source slice and eight scalar/array/record/unsupported-Buffer sentinels.

Coverage includes empty/whole/open/computed/4096-byte selections, UTF-8 byte
counts, scalar snapshots, function-local results, record fields and range bounds,
question/continue cleanup, root mutation conflicts, invalid scalar uses,
independent malformed-type/operand/result-reuse/use-after-close rejection,
short Fuel/backing, stale/frame-mismatched tickets, unchanged output/lease state,
exact Fuel and builder register/origin limits. Old unsupported-length checks now
reject unknown `capacity` members instead; no successful case was removed.

The [Windows evidence](../evidence/m2-array-slice-length-windows-20261031.json)
records matching profile inputs, compiler/SDK identities, native reports,
original/matrix receipt hashes and retained executable hashes. Full suites,
other CLI matrices, M0, Linux, DLL, isolation, packaging, allocator instrumentation
and timing benchmarks were not rerun.
