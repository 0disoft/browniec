# M2 Array Parameter Signature Foundation

- Status: signature metadata implemented and focused-harness verified; array parameter execution not implemented
- Scope: bounded function signature scanning and an explicit compiler gate
- Evidence: [Windows receipt](../evidence/m2-array-signatures-windows-20261025.json)

The signature pass recognizes `ELEMENT[LENGTH] NAME` in a function parameter
list. Elements are `bool`, `u8`, `i32`, `i64`, `u32`, and `usize`; lengths are
literal integers from 1 through 4096. It reuses the local-array length parser.
Scalar and shallow wrapper parameters keep their existing grammar.

`functions::Table.param_types` retains the scalar element tag for an array.
The parallel `param_lengths` table uses zero for scalar/wrapper parameters and
1..4096 for arrays. Both use `function * 8 + parameter` indexing. The existing
16-function and eight-parameter limits therefore bound all 128 metadata slots.
Unused length slots are initialized to zero. On the current 64-bit target this
adds 1,024 bytes to the bounded signature table, with no payload allocation.

The scanner still records parameter names and body boundaries, checks duplicate
and reserved names, and requires a zero-parameter `i32 main`. It rejects wrapper
arrays, multidimensional arrays, slices, `ref` parameters, expression lengths,
and array results. This increment does not add modifiers for parameter mutation.

Before lowering any function body, the compiler rejects every array parameter
with a `type` error at its name. This includes unused helpers and forward
declarations. A scalar value cannot accidentally satisfy an array parameter by
matching its element tag. No array parameter program produces executable IR.
The gate costs O(P) time for at most 128 declared parameters.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-array-signatures.ps1
```

The focused harness passed six signature groups, four existing function groups,
and six helper-array groups per development/release profile. Each CLI passed
1,969 scalar, 67 array-read, and 97 helper-local CLI cases on those same
binaries. The helper CLI case for a valid array parameter declaration now
expects `type` rather than `syntax`; the declaration remains unavailable.
Input and binary hashes are recorded by the harness. The source-only signature
tests exercise the last metadata slot, mixed shapes, integer range edges,
malformed forms, duplicate names, and compiler rejection before body lowering.
The receipt identifies Fairy C revision `4ce1264273be`, Windows x64, Python
3.14.6, and both CLI hashes. Runtime/verifier source hashes match the previous
helper receipt; this comparison does not rerun their private native suites.

The complete scalar native suite, other private-array/M0 native suites,
allocator instrumentation, Linux execution, isolation, DLL delivery, and
performance checks are skipped. No runtime array-call evidence is claimed.

## Next implementation slice

The [private call increment](m2-array-calls.md) adds independent call verification
and transactional VM copies with frame-specific owners. Source lowering must
still bind immutable array parameters and capture each argument once from left
to right before later argument effects. Temporary captures need cleanup on every
exit. Remove the compiler gate only after those source paths are implemented
and checked; caller tokens must not become callee aliases.
