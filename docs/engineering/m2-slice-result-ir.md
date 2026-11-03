# Private returned-view preparation IR and independent proof

Implemented at `670a041`, following private body-origin analysis at `0d1a8cb`.
This is the B01 preparation subset, not runtime result handoff or public execution.

## Representation

`slice_result_ir::Program` contains the existing bounded `ir::Program` plus sixteen
exact element/access tags and sixteen claimed one-based formal input origins.
The 32 extra field bytes are logical payload, not a native sizeof/stack measurement.
Existing VM Program fields, public opcodes, prices, profiles and flags are unchanged.

Within this separate private type, eight-byte instructions add the following
markers. Proof alone does not authorize execution; the private VM adapter has
its own admission and ownership transactions.

| Opcode | Fields | Meaning |
| --- | --- | --- |
| 63 PREPARE_VIEW | dst=result identity, a=live slice site, b=0 | Select an exact named view before cleanup |
| 64 PREPARE_FORWARD | dst=result identity, a=callee, b=argument-map ID | Select a typed borrowed-result CALL |
| 65 RETURN_VIEW | dst=0, a=prepared result identity, b=0 | Finish that result recipe |

Reserved bytes are zero. A result identity uses a bounded register position but
is not a guest usize. It can only flow through cleanup to its paired RETURN_VIEW.
This representation selects an existing view/range; it creates no runtime owner,
loan, descriptor, ticket or executable returned reference.

## Source bridge and independent verification

`compiler::inspect_slice_result_ir` uses the existing source/type/Flow lowerer,
converts its private proxies into explicit preparation/forward/return instructions,
and runs `slice_result_verifier::inspect` before returning the private unit.
`slice_result_ir::from_proxy` is construction, not admission by itself.

The verifier accepts only the private unit, with no source signature table or
compiler proof supplied. It rejects malformed dimensions before indexing and
builds fresh signature facts from the unit's typed function metadata. A private
local normalization maps preparation to existing LEN/CALL/RET proof operations.
That normalized Program is never returned or executed.

The existing verifier independently reconstructs function partitions, definitions,
CFG joins/backedges, scalar/access types, exact formal/derived live loans and
suspended-parent restrictions. The origin solver independently recomputes selected
inputs, including reordered forwarding and grounded recursion, then compares all
sixteen claimed origin slots. Local, by-value or selected temporary owners cannot
become input origins. Unselected temporary CALL roots may clean up normally.

Additional recipe proof requires a unique preparation for every private return;
only array/record drop, slice close or reborrow-end may intervene. It rejects normal
scalar returns from borrowed-result functions, ordinary CALL opcodes targeting
borrowed-result functions, scalar consumers after selection, wrong/unused metadata,
wrong source identities and mismatched markers/reserved bytes. Even a normalized
Program that is valid ordinary scalar IR can fail this stricter result proof.

The bounded origin solver retains at most 17 passes over 16 functions/256
instructions. Recipe scans add O(I squared) work and O(I) matched-return scratch;
this is compile-time analysis, not a runtime/Fuel or measured speed claim.

## Execution boundary and next unit

Public compilation still rejects every borrowed-result declaration, including
unreachable functions. Ordinary verifier/VM admission rejects the new instructions
before guest effects. Ordinary programs inspected through this API remain ordinary.
The private proof is not a transferable authorization or protection against later
unit mutation: re-inspect changed IR.

[B02/B03 native transactions](m2-slice-result-runtime.md) now implement ticket
handoff, selected capture/root retention and exclusive-parent suspension. The
[private VM dialect](m2-slice-result-vm.md), added at `d468ca1`, now connects result
destinations, frames, rootless sites and op63/64/65. It defers the proved terminal
CLOSE/END recipe to atomic handoff; the ordinary VM must not execute that recipe
unchanged. [Owned array/record locals and ordinary CALL integration](m2-slice-result-record-vm.md)
now execute privately. Native owned entry inputs, final public metering, Static
origins, inline return reslicing and general
borrowed-result binding/expression/argument admission remain later work.

## Focused verification

Windows development and release each passed **10 native groups and 208 CLI cases**
with no result reuse in the final recorded runs. Native coverage includes all six
scalar modes, lexical/branch/loop/switch results, forwarding/recursion, forged
metadata/instructions, valid-normalization scalar misuse, suspended/dead selections
and unchanged public admission. CLI coverage is 88 existing public borrowed-result
rejections plus 120 temporary-array borrow regressions, using cleared/tool-free
environments. All 476 final input hashes agree across profiles and retained CLI
artifacts/reports were rechecked. 100 prior source files match `f2d6588` under
Git LF; only the compiler and two new private modules differ in production.

The source commit precedes a root lock refresh after compiler LF normalization.
The final runs use that refreshed lock and unchanged adopted SDK, recorded in the
[Windows evidence](../evidence/m2-slice-result-ir-windows-20261104.json). This is native analysis/closed-gate evidence,
not actual guest returned-reference execution, a full native/M1/M2 corpus run,
Linux/isolation/ABI/packaging, allocator instrumentation or native size/stack/timing
verification. Local only; no push, release or deployment.

To reproduce the selected scope from the repository root:

```text
python3 tools/verify-m2-slice-result-ir.py --profile development
python3 tools/verify-m2-slice-result-ir.py --profile release
```
