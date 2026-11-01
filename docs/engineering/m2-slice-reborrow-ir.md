# Private exclusive reborrow IR and lifetime proof

Independent inspection can now prove exclusive child/parent lifetimes for owned
scalar-array roots and rootless mutable scalar-slice formals. This builds on the
[native range transaction](m2-slice-exclusive-reborrow.md). It adds checked IR
construction and flow proof, not executable reborrow or source syntax.

Public verification runs the complete proof and then rejects the new private
instructions before backing, Fuel or dispatch. Both internal execution entries
also reject their presence before instruction execution or state publication,
including when only an unused function contains them. Existing public mutable
parameters and owned/readonly scalar slices keep their behavior and prices.

## Instruction shape and immutable provenance

Two internal eight-byte instructions are reserved:

| Opcode | Meaning | Operands |
| --- | --- | --- |
| 61 | Begin exclusive reborrow | dst=child site, a=parent site, b=start usize register, byte4=end usize register |
| 62 | End child and restore parent | dst=child site, a=parent site, other bytes zero |

`slice_reborrow_ir::derived` reserves an exact exclusive child descriptor without
another scalar register or array owner. Owned children reuse their parent's
catalog root. Rootless children reuse the same formal origin, function and exact
tag plus exclusive bit. `begin` and `end` check construction-time shape and
operand kinds; they do not claim liveness or runtime bounds validation.

After existing catalogs, function partitions and slice metadata are proved, one
immutable-code prepass derives a sixteen-entry child-to-parent table. Each child
has exactly one static begin instruction; a loop may execute that instruction
repeatedly after complete restoration. Metadata rejects duplicate definitions,
cycles, cross-function roots, mode/tag/anchor mismatches and formal anchors used
as children. Rootless exclusive derived sites require such a definition, even if
unused. This prevents merely relaxing the old descriptor gate from admitting an
unproved mutable child.

The table is verifier scratch, not an added Program field. The prepass takes
`O(N + S^2)` bounded work for at most 256 instructions and 16 sites, including
cycle checks. Each new instruction's flow transition uses constant-time table
lookups; it does not rescan the instruction stream.

## Available and suspended authority

The existing per-PC live word retains arrays in bits0..15, records in bits16..31
and available slices in bits32..47. Previously unused bits48..63 record
suspended parent sites. No per-PC array or Program field is added.

Begin requires an available unsuspended parent, an inactive unsuspended child,
the exact independently proved parent relationship and defined ordinary
same-function usize bounds. It removes the parent's available bit, adds its
suspended bit and makes the child available. End requires an available child
without a live descendant and its exact suspended parent. It removes the child,
clears that parent's suspended bit and makes the parent available again.

Suspended parent read/write/length/UTF-8/close/reopen fail. Child use after end
fails. Derived sites cannot bypass the protocol through ordinary open, readonly
subslice or ordinary close. Wrong-parent and ancestor-before-descendant restores
fail even for equal ranges: ordering follows the proved graph and state, not
native range equality. Independent roots may retain independent lifetimes.

The available exclusive leaf retains the owned root conflict guard, so direct
root access, mutation, copying and destruction cannot bypass suspension. Exact
live-word equality at joins and backedges now includes suspended bits. Normal
scalar/tagged/array/record exits cannot leave either active or suspended loans.
The existing explicit match-failure terminal remains an abort path; eventual
runtime integration must drain its outstanding native receipts.

Calls while any parent is suspended are rejected in this stage, including calls
that return aggregates. Calls after complete restoration retain existing proof.
Combined CALL/reborrow depth reserves, per-frame receipt ownership, charging and
return/abort coordination must be connected before relaxing this restriction.

## Admission and verification scope

`verifier.inspect` accepts well-formed private reborrow Programs. `verify` runs
that same complete proof then rejects op61/62. The shared execution core checks
for their presence before using invocation state, so an inspected private IR
Program cannot accidentally execute a supported prefix through either internal
entry. No reborrow Fuel charge, public feature flag or profile change is added.

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-ir
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-ir
```

The selection includes six new IR groups, five readonly flow groups, six mutable
formal groups and six public mutable source groups. New cases inspect all six
scalar tags over owned and formal roots, fifteen nested child sites, suspended
parent and direct-root access, stale children, wrong restore order, malformed
metadata/operands, balanced and unbalanced joins/backedges, a real CALL descriptor
before/after restoration and public/internal execution gates. New reborrow cases
are construction/proof evidence; actual reborrow writes remain native transaction
evidence from the preceding stage. Runtime index/range values are not executed
or range-checked by this proof.

Implemented at `3987195`. Development and release each passed all 23 selected
native groups and 2,495 CLI cases, with 376 matching current input hashes.
Compiler, retained CLI and all matrix/M1 receipt identities were rechecked.
Program/signature declarations and owner/pool/native reborrow/handoff/shared-frame
helpers, compiler and public VM/CLI entry files match `febe841`; the verifier and
execution core contain the new private proof/gates. Both profiles accept parser
depth32 in check/run and reject depths33/64 with `compile_limit`. See the
[Windows evidence](../evidence/m2-slice-reborrow-ir-windows-20261102.json).

The [native authority successor](m2-slice-authority.md) now coordinates combined
CALL/reborrow depth and receipt ownership. Its strict independent-root restore
order must align with inspected IR before metering and executable VM integration.
Guest syntax and public admission remain separate deliveries.

Public CLI regression runs 74 mutable parameter, 222 owned mutable, 192 readonly
scalar and 2007 M1 cases on Windows. Full native, other M2, Linux, M0, isolation,
packaging, allocator, timing and native memory/stack measurements are outside the
selection. Local commits only; no push, publication, packaged release or deployment.
