# Synchronous CALL borrowing a live exclusive source in suspended reborrow forests

`slice_reborrow_call_ir::inspect` is an analysis-only proof, exposed by
`verifier::inspect_reborrow_calls`. It proves that a synchronous CALL may forward
a live exclusive source from a proved suspended reborrow forest while preserving
the caller's live word and source ownership exactly: on success it returns the
same live word unchanged. It neither executes nor promotes the call. The CALL
borrows the existing live source; ownership does not move.

`verifier::inspect_reborrow_calls` is an independent, whole-program entry. It
first validates ordinary slice metadata and the reborrow forest. It then reaches
the local CALL helper, ahead of the remaining function and argument flow. A
successful local helper result is not acceptance by itself: the existing complete
IR/dataflow/function proof must then finish before the entry accepts.

`verifier::inspect`, `verifier::verify`, checked canonical execution, public
execution admission, and the existing execution gates remain unchanged. Those
paths still reject a CALL while any reborrow parent is suspended; only the
explicit analysis-only entry accepts it. This proof does not promote checked
canonical or public execution.

## Live state and forest closure

The per-PC live word keeps available slice sites in bits 32..47 and suspended
sites in bits 48..63. The pending set is their union; the two sets must be
disjoint. Every pending site must belong to the current caller: for an owned
root, the nonzero slice root must be present in the array catalog and that
array's function must be the caller; for a rootless formal slice, the origin and
caller-specific function identity must be present and valid.

Every pending site's parent, when present, must be suspended. A suspended parent
has exactly one pending child; an active site has none. Active sites are
therefore leaves, and each suspended forest is closed. The existing immutable
forest metadata supplies unique acyclic exact parent edges, agreement of root,
origin, function, tag, and mode, and site-use validity.

On success the proof rewrites no live bits and copies no slice payload. The
caller's live word and source ownership remain unchanged.

## CALL descriptor and arguments

The instruction must be opcode 9 (CALL). The proof validates the PC, caller and
target function identities, and the argument-map identity; the target arity
must be at most eight, and the CALL arity must equal the target arity exactly.
The local helper runs before the remaining function/argument flow; the complete
proof must still finish before acceptance.

Only slice-typed formal positions are passed to `slice_parameters::argument`.
Scalar, array, and record arguments remain covered by the existing complete
`array_parameters` argument checker.

For each slice-typed formal, `slice_parameters::argument` resolves the source. A
slice argument must be live and active, not suspended, and exactly exclusive or
exactly shared. Across the CALL, its mode and element tag and type must match the
destination formal exactly. Shared/exclusive coercion remains forbidden.

Caller function/origin validation is separate from callee tag/mode matching.
Owned roots and their functions, and rootless formal origins and their functions,
must belong to the caller. Equality of caller and destination function/origin is
not a requirement, including recursive CALLs that reuse the same static formal
origin in a distinct frame. An exclusive owned source must still name a mutable
caller-owned root.

For exclusive mutable arguments, the source site, owned root, and rootless
formal origin must each be unique within the CALL: two sites backed by one root,
or two backed by one formal origin, are rejected. Shared duplicates remain
legal. With at most eight arguments, these local bit sets are bounded.

## Bounds and metadata

Within the fixed 16-site metadata bound, checking each pending site's parent
against the fixed child relation costs `O(S^2 + A)` per CALL, with `S <= 16` and
`A <= 8`. This is a bounded static analysis cost, not a measured native
performance result.

The proof uses only metadata and verifier scratch (`slice_reborrow_ir::Sites`,
local integer and bit-set state). It adds no Program field, persistent-state
field, opcode, layout change, Fuel change, capability change, payload copy, or
authority or receipt clone. It makes no native memory, allocation, stack,
timing, or performance claim.

## Future integration (not implemented here)

Not part of this slice: native receipt authentication, dynamic combined
CALL/reborrow depth reservation, ticket-generation restoration for suspended or
derived sources, executable VM coordination for these calls, and runtime
promotion. Any future integration must authenticate receipts, reserve combined
depth atomically across admission, return, and abort, restore the correct ticket
generations, coordinate cleanup and results, and only then deliberately promote
execution and public admission.

## Verification

The implementation is committed at `eb2a0ce`. Development and release each
passed 20 selected native groups and 2,495 public slice/M1 CLI cases. All 397
current input hashes, compiler/artifact identities, selected native identities,
and retained CLI receipts were rechecked. Verifier and the new proof module are
the only production changes; 94 existing sources are unchanged from `5fa17ca`.
See [Windows evidence](../evidence/m2-slice-reborrow-call-ir-windows-20261103.json).

Verification uses both profiles:

- `python -B tools/verify-m2-slice-elements.py --profile development --reborrow-call-ir`
- `python -B tools/verify-m2-slice-elements.py --profile release --reborrow-call-ir`

Each selection contains 8 `slice_reborrow_calls` groups, 6
`slice_reborrow_ir` groups, and 6 `slice_mutable_calls` groups: 20 selected
native groups in total. It also runs the current public slice and M1 CLI
regression set: 74 mutable-parameter, 222 owned mutable, 192 readonly scalar,
and 2,007 M1 cases, for 2,495 public cases.

The boundary case fills the 16 total metadata sites with one callee formal, one
caller formal anchor, and 14 derived child edges. The existing tests cover all
six scalar tags over owned and rootless formal roots, that boundary case,
balanced loops, independent roots, suspended, intermediate, and closed-source
rejection, duplicate writers, mode, tag, and function mismatch, malformed CALL
descriptors and late arguments, exact joins and backedges, forged live bits,
immutable snapshot behavior, and unchanged legacy or public execution gates.

Selection does not establish full native, other M2, Linux, isolation, packaging,
allocator, size or stack, timing, native memory, or performance results.
