# Independent borrowed slice control-flow inspection

Implementation: `b6b5525`. The shared private IR verifier now
checks borrowed formal/derived slice dataflow through `verifier.inspect`.
This is an inspection result, not an execution permit. `verifier.verify`, CLI
check/run and VM admission keep the early nonzero borrowed-signature gate.
The [source lowering checkpoint](m2-array-slice-parameter-source.md) remains
unexecutable until metered CALL/frame support is implemented and verified.

## Shared validation and entry state

`inspect` and `verify` call one private validator. Both independently check
catalogs, function/register partitions, metadata, scalar definitions, instruction
encodings, argument kinds and resource dataflow. Only execution validation
rejects declared borrowed formals before body analysis. No VM entry point uses
the inspection result to bypass its own execution verification.

Formal register positions are reserved/written but never enter the scalar
defined set. They retain type zero and cannot act as scalar sources, indices,
bounds or returned values. Scalar readers in the main, array, record and slice
verifiers explicitly exclude borrowed positions. Function entry adds each
borrowed formal's slice bit, with no invented array-owner bit. Derived sites
start inactive. Existing scalar and owned aggregate entry rules are unchanged.

## Slice operations and flow

Owned slice instructions still require a same-function, live array root.
Rootless borrowed instructions instead require same-function origin metadata
already validated against a unique formal. Reads, length and UTF-8 checks need
their own live slice bit and produce fresh, correctly typed scalar values.
Closing one site clears only that bit; closing it twice or reading it afterward
fails. A retained derived site can remain readable after its formal ticket was
closed. No live anchor ticket or extra owned root is invented.

Opcode 59 requires a dead derived destination and live parent with exactly
matching root/origin/function metadata and ordinary defined usize endpoints.
A borrowed formal cannot be reinitialized by subslicing. Opcode 54 remains
owned-root-only. Existing protection of locally borrowed array roots against
mutation, release and result transfer remains in force.

Forward joins require exactly equal owner/borrow live masks from every incoming
edge. Scalar definitions retain their existing intersection rule. Backedges
must preserve the target's live mask and scalar entry invariant. The existing
forward pass and bounded inductive backedge proof are reused; no cyclic
worklist or extra per-PC origin table is introduced. Unreachable instructions
retain the existing rejection rule.

## Calls and exits

The existing argument checker dispatches each formal position to borrowed,
record, owned-array or scalar validation. Borrowed CALL arguments must be
160..175, live and owned by the calling function, with a u8 root for local
owned slices. Derived borrowed sources need their own live ticket, even if the
formal anchor is closed. Scalar/owned-array/record encodings cannot stand in
for a borrowed argument; unused argument bytes must remain zero.

A CALL preserves caller borrow bits. Array/record result publication uses the
existing result rules. Duplicate/forward/recursive borrowed arguments can pass
inspection, but inspection does not construct runtime frames or retain actual
tickets. Each function is checked with its declared entry contract, including
unused functions; no recursive call-graph worklist is required.

Normal scalar returns require no live owners or borrows and an ordinary scalar
result. Aggregate returns require the sole remaining owner to be the matching
result, so formal/derived loans must already be closed. A slice cannot escape
as a scalar, array or record result. The existing internal match-failure
instruction remains an abnormal terminal; its runtime error cleanup is not a
newly verified borrowed-frame path.

## Bounds and execution boundary

Existing limits remain sixteen slice sites, sixteen functions, eight arguments,
128 register positions, 32 call sites and 256 instructions. Metadata checks are
bounded by the existing tables; entry scans inspect at most eight formals and
CALL argument scans at most eight positions. Slice steps use constant metadata
lookups; local borrowed-root protection retains its at-most-sixteen-site scan.
The existing scalar and resource state arrays are reused without new per-PC
state, Program/frame fields, runtime allocation or payload copies. Timing and
allocator/process-memory measurements were not run.

The VM still calls `verify` before Fuel/backing admission, so inspected borrowed
IR remains rejected even with zero Fuel and zero array quota. Dynamic callee
origins, retained runtime argument tickets, mixed owned/borrowed frame admission,
recursive-frame cleanup and metering remain pending. No opcode, Fuel price or
version capability is added. The [frame-adapter successor](m2-array-slice-call-vm.md)
adds private metered retention/cleanup and dynamic origin bindings, still without
executable dispatch or mixed aggregate transaction integration.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-borrow-flow`
and repeat with `--profile release`. Each profile selects sixteen native groups:
five borrowed-flow groups, five source-lowering groups with mandatory whole-IR
inspection, three subslice VM groups and three index VM groups. CLI regression
selects 326 tool-free invocations: 74 gated-source, 120 alias, 124 subslice and
eight ordinary/unsupported-Buffer sentinels. Both profiles passed with 331
matching input hashes. Exact checkout bytes match both receipts; committed
text matches after CRLF-to-LF normalization.

Coverage includes retained-child reads and recursive forwarding after anchor
close, branch/backedge mask equality, missing/double cleanup, invalid opens,
scalar bounds, typed scalar separation, all CALL argument kinds and unused
bytes, dead/foreign sources, duplicate references, aggregate exits and ordinary
array-call execution compatibility. Forged instruction/argument failures assert
verification kind 5 at the failing IR instruction; malformed metadata fails
before body analysis. Executable verification and VM admission remain rejected
for every inspected borrowed program.

See the [Windows evidence](../evidence/m2-array-slice-borrow-flow-windows-20261031.json).
Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.
