# M2 Source Array Length

- Status: implemented; development/release verification is recorded in the linked receipt
- Scope: fixed scalar-array bindings in outermost `main`
- Evidence: [Windows length receipt](../evidence/m2-array-length-windows-20261025.json)

## Grammar and types

```text
ARRAY_NAME '.' 'len'
```

The named binding must be a visible `let` or `var` array declared under the
[read](m2-array-source.md), [write](m2-array-write.md), or
[copy-initializer](m2-array-copy-source.md) contract. The result is an exact
64-bit guest `usize`, containing the declared element count, from 1 through 4096.
It is independent of element type, mutability, contents, and later element writes.
Copies have the same length as their source.

Length is an operand in scalar expressions, including nested blocks, conditions,
function arguments, switch-expression arms, and the pure scalar parts of classic
`for` headers. For example, `i < values.len` can bound a `usize` index.
[The example](../../examples/array-length.brc) sums three elements and returns 42.
Array declarations remain restricted to the outermost `main` body.

There is no implicit conversion: returning `values.len` from `fn i32 main()` or
binding it to an `i32` local is a type error. This slice adds no `len` keyword or
function. Existing scalar locals and functions named `len` remain valid.
Scalar `.len`, unknown members, `values.len()`, indexing the result, assigning to
the property, and array-valued or parenthesized receivers are unsupported.

## Lowering and resources

The compiler resolves the array catalog entry and emits the ordinary `usize`
constant instruction. Each source occurrence consumes one constant, register,
and IR instruction under the existing 128/128/256 limits. Executing that
instruction costs one Fuel unit, including each iteration of a loop condition.
It reads no runtime array payload and allocates no additional array storage.
Array initialization, fill evaluation, arena preparation, quotas, and reverse
drops retain their existing behavior. There is no new verifier rule or VM opcode.

The existing JSON profiles remain unchanged: copied arrays select
`brownie.m2-array-copy/1`, otherwise mutable arrays select
`brownie.m2-array-write/1`, otherwise arrays select `brownie.m2-array-read/1`.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice length
python -B tools/record-m2-array-write-evidence.py --slice length --scalar-regression
```

The focused harness runs 15 native groups and 226 array CLI cases per profile:
67 reads, 61 writes, 58 copies, and 40 length cases. The length cases cover all
six scalar element types, lengths 1/4096, copies, mutable bindings, lexical
blocks, loops, function arguments, switch expressions, errors, Fuel boundaries,
and fresh invocations after failure. CLI subprocesses use a tool-free `PATH`.
The recorder separately runs 1,969 scalar CLI regression cases per profile.

The one-element native fixture passes with a four-byte arena and 163 Fuel and
fails with 162. With the standard 65,536-byte CLI arena it passes at 65,695 Fuel
and fails at 65,694. These are resource-contract checks, not speed measurements.

Full scalar native, allocator instrumentation, Linux, isolation, DLL, and
performance checks are skipped. Array parameters/results, borrows, slices,
whole-array reassignment, and the complete source profile remain unavailable.
