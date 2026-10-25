# M2 Private By-Value Array Calls

- Status: private IR, verifier, and VM implemented and focused-harness verified; source lowering pending
- Scope: mixed scalar and immutable scalar-array parameters in private CALLs
- Evidence: [Windows receipt](../evidence/m2-array-calls-windows-20261025.json)

This increment connects [atomic argument copies](m2-array-arguments.md) to private
VM calls. Source declarations with array parameters remain rejected by the
[signature gate](m2-array-signatures.md). No source execution claim follows from
the private IR tests, and no new opcode or bytecode loading interface is added.

## Metadata and independent verification

`Program.array_parameters` adds 128 bytes indexed by register position. Zero
denotes a scalar parameter or an ordinary register; a nonzero byte denotes an
array catalog ID plus one. An array parameter reserves one of the existing
parameter register positions for argument ordering, but that position never
contains a guest scalar value.

`ir::array_parameter` declares an immutable function-owned array catalog entry
and reserves that position. The verifier separately requires each nonzero map
entry to lie in its owning function's parameter prefix, to have the matching
element tag, and to refer to a unique immutable catalog entry. Unused and
nonparameter positions must be zero. Entry-function parameters remain forbidden.

The function's initial live-array set contains its array parameters. Array
parameter positions are never readable as scalars. Parameters may be read and
copied into separate local arrays, but cannot be written, assigned, or initialized
again after release. All live parameter and local arrays must be dropped before
return; the existing CFG merge and loop checks preserve exact live sets.

The existing call argument bytes encode scalar register indices as 0..127 and
array catalog IDs as 128..143. The verifier ties every argument to its callee
parameter, including mixed argument order, and checks exact element type and
length. An array source must be live, owned by the caller, and immutable. Invalid
encodings, unused nonzero argument entries, foreign owners, mutable sources,
dead sources, and shape mismatches are rejected independently of the builder.

## Snapshot semantics and frame entry

An immutable caller binding is already a stable snapshot. A mutable source must
first be copied with the existing `ACOPY` instruction to a separate immutable
catalog entry. That instruction precedes any later argument effects in the
private fixtures. Writing the original after capture cannot change the argument.
The verifier enforces snapshot immutability and liveness; source lowering is
still responsible for creating and cleaning captures at the proper evaluation
points, including early `?` failures.

CALL precharges its complete Fuel cost and checks the 32-frame limit before
copying. The VM gathers array tokens from the caller frame and exact shapes from
the verified callee parameter map, then invokes the atomic batch copy helper.
Every parameter gets a fresh owner and independent payload. Sources are not
transferred or aliased, including when the same source appears several times.

Only successful copies publish child-frame tokens. Scalar arguments, return
metadata, and the current frame are updated afterward. Copy failures leave
payload, owner state, and frame-token bindings unchanged; consumed Fuel is not
refunded. Existing guest argument evaluation is not rolled back. Runtime checks
also reject occupied child destination slots before copying.

Recursive invocations use distinct token slots at `frame * 16 + catalog_id`.
All invocations continue to share 16 live owners and one arena capped at 65,536
bytes. A caller snapshot remains live while the child owns its copy, so both
extents count toward the peak. An explicit mutable-source capture adds another
extent; it is not silently elided. No owner or arena limit is multiplied by frame.

## Fuel

Scalar-only CALLs retain their existing `1 + arity` charge and skip the array
entry helper. For a CALL with array parameters, add:

`128 + sum(128 + payload_bytes + 7 + bool_validation_bytes)`

The fixed terms cover staging/committing bounded metadata, parameter binding,
and descriptor scans. Each parameter allows worst-case alignment padding of
seven bytes; bool payload validation is charged once per copied source byte.
The payload charge covers the independent copy. These are conservative work
charges, not benchmark measurements.

The mixed i32 fixture retains an eight-byte mutable source, its eight-byte
immutable capture, and an eight-byte callee parameter. It succeeds with a
24-byte arena and exactly 670 Fuel; 23 bytes or 669 Fuel fail. The CALL itself
costs 274 Fuel (`1 + 2 + 271`), and 478 total Fuel fails before its copy begins.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice calls
```

The focused selection contains nine new call groups, four scalar-function
groups, five array IR groups, six array VM groups, and five recursive-frame
groups. The harness builds both CLI profiles and runs the existing array and
scalar CLI matrices on those same binaries.
Development and release each passed all 29 native groups and 2,395 CLI cases
(426 array and 1,969 scalar). The receipt identifies Fairy C revision
`4ce1264273be`, Windows x64, Python 3.14.6, both retained CLI hashes, and fresh
input identities. Twenty-five unchanged source hashes match the previous
argument-copy receipt; this does not rerun its complete owner/batch-copy suites.

New native checks cover all six element types, mixed scalar/array ordering,
immutable snapshots after original writes, eight repeated array arguments,
late batch quota failure without token publication, exact Fuel, 24 sequential
calls with parameter reclamation, recursive parent preservation, and shared
owner/payload exhaustion. Malformed metadata and call operands are rejected;
missing cleanup, scalar reads of array positions, reinitialization, and parameter
writes are also rejected. The full owner/batch-copy native suites retain their
earlier evidence; they are not rerun by this slice.

The full scalar native suite, other private-array/M0 native suites, allocator
instrumentation, Linux execution, isolation, DLL, clean-machine packaging, and
performance measurement remain outside this increment.

## Next source increment

Predeclare callee array catalog entries before forward-call lowering, bind
immutable parameter names, and capture source array arguments exactly once from
left to right. Track temporary captures through nested argument evaluation and
drop them on normal completion and every early return, including `?` failures.
Keep for-header restrictions and exact-shape checks. Remove the signature gate
only after source execution and negative checks cover those paths.
