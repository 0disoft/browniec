# M2 Private By-Value Array Results

- Status: private result IR, independent verification, and VM transfer implemented and native-verified
- Scope: exact-shape scalar arrays returned between verified VM frames
- Source boundary: [result signature gate](m2-array-result-signatures.md) remains enabled
- Evidence: [Windows receipt](../evidence/m2-array-results-windows-20261025.json)

This increment connects private array-return IR to the native VM. It does not
enable source array-result programs or external bytecode loading. Caller and
callee values remain independent: returning a callee-owned value transfers its
unique owner, while array parameter entry still makes the existing independent
by-value copy.

## Private metadata and verification

`Program.array_results` has 16 byte entries, one per function. Zero means a
scalar/wrapper result; a nonzero entry is a callee catalog ID plus one anchoring
the exact result shape. The anchor need not be the particular owner returned by
every branch. Its element matches `return_types[f]`, and its catalog belongs to
that function. Unused function slots must be zero; the entry function cannot
have an array result. This adds 16 metadata bytes, not a new payload arena.

An array-result `CALL` uses the existing opcode 9 with destination byte
`128 + caller_catalog_id`. It defines that array's lifetime without allocating
a scalar placeholder register. The destination must belong to the caller,
have the exact result shape, be dead at the call, and not be a parameter site.
Existing mixed scalar/array argument checks still apply before the destination
becomes live. Array and scalar call destinations cannot be interchanged.

Private opcode 39 (`ARET`) has `dst=0`, `a=source_catalog_id`, and `b=0`.
The source must be live, belong to the callee, and have the declared shape.
It must be the callee's **only** live array: parameters and other locals must
already be cleaned. `ARET` is terminal; scalar `RET` is rejected in array-result
functions. Result lifetimes participate in branch joins and backedge invariants
like other arrays, and a scalar return must still leave no arrays live.

## Ownership transfer and failure

Before changing a token, the native helper checks frame/index bounds, source and
destination shapes, an empty parent destination, all other child token slots,
the live source generation and owner metadata, and every bool payload byte.
It then clears the child binding and publishes that same token in the parent.
No recoverable check follows the two assignments.

The owner descriptor, generation, arena mark, and bytes remain unchanged.
Transfer allocates zero additional owners, reserves zero payload bytes, and
copies zero payload bytes. Numeric result transfer has O(16) bounded metadata
work; bool transfer adds O(N) validation. This is an implementation work count,
not a measured latency or memory benchmark. No token or native pointer is
guest-visible, and the callee cannot execute after `ARET`.

Returning a parameter transfers the independently copied callee value; changing
the returned array cannot change the original caller argument. Deferred dead
extents below the result remain accounted until the caller drops the result,
at which point existing suffix reclamation releases them. Transfer does not
compact the arena or bypass its owner/payload limits.

Failed preflight leaves every frame token, owner field, and payload byte intact.
Exhausted Fuel stops before transfer. Runtime failure terminates the run and the
existing owned payload buffer is dropped; no argument or external effect is
replayed. Scalar calls and array-argument entry retain their existing prices.

## Fuel and limits

`ARET` prepays 65 Fuel for bounded frame/descriptor work, plus the result length
for bool validation. There is no byte-copy or allocation charge because transfer
performs neither. This price does not replace preparation, initialization,
argument copying, reads, writes, or drops.

All functions still share 16 static array sites, 16 occupied owner descriptors,
32 VM frames and an arena capped at 65,536 bytes. Existing eight-argument,
128-register, 256-instruction, and 32-static-call-site limits remain in force.
Source result lowering, borrows, slices, and wrapper-element arrays remain open.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice results
```

The new aggregate selection is available for future reruns. This increment's
evidence was completed as individual native/build/CLI commands; the aggregate
script was syntax-checked, not rerun over already completed native selections.

The result verifier fixtures cover all six element types, exact shapes, invalid
anchors, cross-function/dangling/live destinations, scalar/result confusion,
unclean returns, branch joins, and backedges. Native VM fixtures cover scalar
edges, 4096-element results, repeated calls, recursive frame limits, malformed
tokens/metadata, canonical bool validation, exact Fuel and failed preflight.
Separate edge fixtures cover parameter independence and deferred callee holes.

The four-byte i32 factory completes with 232 total Fuel; 231 fails. Fuel 141
stops at the annotated `ARET` before its token assignments. Thirty-one helper
invocations plus the entry frame return one owner through all 32 VM frames using
four payload bytes. One more invocation fails with the existing frame limit.
Returning a copied parameter succeeds with the original plus one callee extent
(eight bytes), and changing the result preserves the original caller value.
The deferred-hole fixture repeats 24 calls within eight bytes. These are native
quota/Fuel cases, not measured startup, latency, allocation, or throughput results.

Executed counts, commands, binary hashes, fixture identities, comparisons with
the prior receipt, and skipped checks belong to the linked evidence file.
Each development/release profile passed 43 native groups and 2,571 CLI cases:
426 existing array, 80 parameter, 96 result-signature, and 1,969 scalar cases.
Development combines a 41-group run with two disjoint edge groups; release runs
the identical 43 identities together. No broader native suite is inferred.
The implementation commits are `04a4387` (IR/verifier) and `056897c` (VM).
The receipt anchors the final verification-tool commit and records Fairy C
revision `4ce1264273be`, compiler SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`,
Python 3.14.6 and Windows x64. All 20 CLI receipts match the retained binaries;
generated fixture hashes and 92 current input hashes are checked. Twenty-nine
earlier source inputs and the standard-library lock entry are unchanged.

| Profile | Native CLI SHA-256 |
| --- | --- |
| development | `3347ffa4a6626a3eb6a0af084c6b3c1edc55f48c66e291cac3bf2380166f5312` |
| release | `42caece882767ea49ac0615f50afc4f8185b78b931db5361b23c917662486641` |

No source array-return, Linux, worker isolation, DLL, clean-machine packaging,
allocator instrumentation, or performance claim follows from these private tests.

## Next source increment

Connect source result shape catalogs, caller destination initialization, and
return cleanup that retains the selected result until `ARET`. Preserve ordered
captures during nested result calls and early exits. Remove the source gate only
after those paths have direct CLI and negative compilation evidence.
