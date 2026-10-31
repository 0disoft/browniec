# Private borrowed slice parameter origins

Admission update: the [public successor](m2-array-slice-parameters-public.md)
now enables verified readonly u8 slice calls. Gate-rejection statements below
refer to the original private checkpoint and its historical receipts.

Implementation: `3f678ca`. This checkpoint prepares the IR and
independent verifier for readonly u8 slice parameters. Source syntax, VM CALL
execution, opcode/Fuel schedules and version capabilities are unchanged.
The core verifier explicitly rejects any declared borrowed parameter until the
runtime and metering contract is implemented.

## Representation

Three zero-initialized private Program fields share the existing sixteen-site
slice namespace with ordinary owned-array slices:

- `slice_parameters[128]`: a formal register position names its slice site + 1;
  zero means an existing scalar/array/record parameter kind. A borrowed position
  has type tag zero, is not a mutable slot and has no scalar cell or owned shape.
- `slice_origins[16]`: a rootless borrowed site names its formal anchor site + 1.
  Formal anchors point to themselves; derived sites point directly to that anchor.
- `slice_functions[16]`: a rootless borrowed site names its owning function + 1.
  Local owned-array slices retain zero here and their existing `slice_roots` entry.

A site cannot have both an owned-array root and a borrowed origin. The fields
add 160 fixed u8 entries to Program; no per-PC state or runtime frame table is
added. Native layout/process-memory changes have not been measured. Existing
Programs without borrowed signatures leave all new entries zero. The
[gated source successor](m2-array-slice-parameter-source.md) now constructs
prospective borrowed signatures while preserving the execution gate.

## Metadata and argument checks

`slice_parameters.metadata` checks bounded contiguous function/register
partitions, entry arity, formal positions, exclusive parameter kinds and unique
formal anchors. Borrowed sites must reference a declared self-anchored formal
in the same function. Cycles, orphan/foreign anchors, unused function markers,
owned/borrowed overlap, trailing parameter entries and out-of-range IDs fail
with verification kind 5. No recursion or cyclic worklist is used.

After successful metadata validation, `initial` computes only the formal slice
live bits for a proposed function entry. Borrowed parameters contribute bits
32..47 and no owned array bits. Derived views start inactive. The existing
eight-argument and sixteen-site ceilings remain in force.

The `argument` helper checks one proposed borrowed argument, encoded as
160..175 in the existing call-argument byte namespace. The destination must be
a formal borrowed position. The caller's source must be a live u8 slice owned
by that function. For local slices, both the slice and underlying array root
must be live and the array element must be u8. For borrowed/derived slices,
the site and formal origin must belong to the caller; no owned array root is
invented. A retained derived ticket need not keep its anchor ticket live.
Scalar, owned-array and record encodings are rejected as borrowed arguments.
Argument failures use verification kind 5 at the supplied call offset.

The entry-mask and argument helpers require prior successful metadata validation.
They defensively check indices needed for safe table access; they do not replace
whole-Program validation, per-PC control-flow proofs or runtime ticket/session
checks. Their acceptance describes proposed metadata and arguments, not an
executable borrowed CALL or a successful forwarding/recursive invocation.

## Execution gate and remaining work

The core verifier validates the new metadata after checking existing catalog
and function partitions, then rejects a nonzero formal-anchor set. An orphaned
borrowed declaration is rejected by metadata validation itself. The VM always
calls the core verifier before backing allocation, Fuel preparation or dispatch,
so prospective metadata cannot be ignored by the old runtime.

At this metadata checkpoint, the source parser rejected slice parameters/results.
The gated source successor now parses borrowed formals and explicit reference
arguments, but CLI verification/execution and slice results remain unavailable.
No new capability is published. No borrowed instruction, source signature lowering, dynamic runtime
origin, frame admission, CALL mutation, result escape or metering is implemented
here. The [builder successor](m2-array-slice-builders.md) adds shared site reservation,
formal/derived declarations and checked argument encoding while retaining the
execution gate. The [atomic argument batches](m2-array-slice-arguments.md) remain the native
storage foundation for a future combined call transaction.

Next integration must initialize callee origins from retained runtime tickets,
combine mixed owned copies and borrowed batches before publishing frame state,
verify borrowed control flow and cleanup, and prepay normal/error cleanup work.
The execution gate must remain until those paths are implemented and verified.

## Bounds and focused verification

Metadata work is O(R+S+F), with R<=128, S=16 and F<=16. Entry masks inspect at
most eight positions; individual argument checks use O(1) metadata lookups.
No payload read, copy, owner allocation or runtime heap allocation path is added.
Existing source behavior and exact Fuel prices are unchanged; timing and
allocator/process-memory measurements were not run.

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-parameters`
and repeat with `--profile release`. The selection contains 20 native groups:
four new origin/argument groups, nine existing array-call and seven existing
record-parameter IR groups. CLI regression covers 252 invocations: 120 alias,
124 subslice and eight scalar/array/record/unsupported-Buffer sentinels.
Both profiles passed with 324 matching source/test/tool input hashes.

Coverage includes formal/derived origins, retained children without live anchors,
28 malformed metadata variants, duplicate formal bindings, all sixteen sites,
eight positions per function, foreign/dead/non-u8 argument rejection, exact source
kind separation, ordinary Program compatibility and execution rejection before
Fuel/backing admission. The current source successor accepts parameter lowering while honestly rejecting
CLI verification/execution.
The [Windows evidence](../evidence/m2-array-slice-parameters-windows-20261031.json)
records matching profile inputs, compiler/SDK identities, native reports, CLI
matrix receipt hashes and retained executable hashes.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.
