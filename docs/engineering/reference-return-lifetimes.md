# Canonical returned-byte reference lifetime analysis

Date: 2026-11-05. This B04/B05 increment combines the
[returned-reference recipes](reference-return-ir.md) with complete canonical
scalar/owner/loan and CFG validation plus returned-view owner dependencies.
Implementation: `00dcedd`. Native generic-result transfer remains subsequent.

## Complete analysis and local-owner identities

`verifier::inspect_reference_returns` returns a distinct `ReferenceReturnProof`.
It reconstructs the exact code/image recipes and origins, prepares actual image
root sets, runs ordinary canonical metadata/type/liveness/CALL proof, and then
checks returned-byte owner lifetimes. Generic results may select byte or
universal-byte views; image-only results retain their stricter kind rules.
The original `inspect_reference_calls`, Static/public admission and retained
ReferenceProgram/CallProgram still reject result kind 3. A complete analysis
receipt is copyable metadata, not native ticket authority or executable admission.

`reference_lifetimes` computes sixteen masks of this frame's owned array roots.
An image actual contributes zero. An ordinary runtime actual contributes its
local root, or zero when it is a rootless borrowed input. A universal actual
inherits its already proved local dependencies. CALL results remap the callee's
proved logical origin through this CALL's exact actual; aliases/ranges preserve
the mask. Unselected arguments never become dependencies of the returned result.

PARAMs have no local-owner dependency: their backing belongs to an ancestor or
external input. This avoids confusing a recursive invocation's fresh local
with an ancestor owner carrying the same catalog/site index. Rootless input
identity and exact logical ancestry still come from the independent recipes
and canonical ordinary loan proof; zero local dependencies does not prove an
image, an empty range or absence of borrowed authority.

## Effect and CFG rules

The separate view-live plane follows definitions, logical CLOSE, forward merges
and inductive backedges. It unions all still-live views' local dependencies
before each effect. Closing the original ordinary shared loan does not remove a
returned view or its aliases. Closing a parent view does not remove descendants.

While a returned view depends on a local owner, analysis rejects that owner's
DROP, scalar write, fill and assignment; exclusive OPEN/BEGIN/WRITE or an
exclusive CALL actual targeting that root also rejects. Whole-root exclusion
remains consistent with the existing scalar-array loan model. Other owners stay
writable, and mutation of the original owner becomes valid after the last view
closes. Scalar/aggregate returns still require their ordinary complete cleanup.
Failures identify the offending IR instruction through the existing IR error 5.
These are static checks; no source payload or runtime metadata is mutated.

The dependency preparation is one pass over at most 256 instructions. The
lifetime walk examines at most sixteen view masks and eight CALL formals per PC,
plus fixed per-function CFG-state initialization (at most sixteen functions and
256 entries each). The sixteen usize masks use 128 logical bytes on the current
64-bit target, in analysis metadata only. Program/Sites, native frame layouts,
physical pools, runtime prices and public limits remain unchanged. General
compiler-budget and process-RAM/stack targets are not established by these bounds.

## Verification

Run `python -B tools/verify-static-execution.py --profile development --selection
reference-return-lifetimes` and repeat for release. Eight new groups cover:

- Image/runtime dependency distinction, all eight actuals, scalar prefixes,
  transitive selected inputs and zero local dependencies for callee formals.
- Reading a returned view after its original loan closes, with owner DROP rejected
  before the subsequent read; writes/fill/assignment reject at the effect PC.
- Mutation after the last close and mutation of an independent owner.
- Alias/range descendants preserving exclusion after parent/intermediate closes.
- Exclusive acquisition before versus after the last close.
- Rootless shared-input return ancestry plus wrong scalar-index and closed-actual
  rejection by the ordinary canonical proof.
- Existing executable/public admission gates remaining closed.

Eight recipe groups and two actual shared-byte formal VM groups cover affected
analysis/execution regressions. The new tests do not execute generic returns.
Windows development/release each passed 18 native groups on 140 matching committed
inputs, 133 LF production modules and 238-file discovery. Both locked LF mirrors
pass, without compiler/stack overrides or historical-result reuse. See
[focused evidence](../evidence/reference-return-lifetimes-windows-20261105.json).
The earlier eight-group development core probe is excluded from final counts.
Public CLI/Fuel selections, full profiles, general stack/RAM, allocator/OOM/timing,
Linux, restricted delivery and ABI/package checks were not rerun.

## Next integration

Connect this complete proof to a retained returned-reference Program and native
selected handoff, caller destination publication, last-alias close and prepaid
abort. Reuse full-generation native receipts without conflating ordinary slice
and immutable/universal site namespaces. Preserve actual runtime windows, image
borrows, selected owners/parents and recursive scope. Then lower source signatures,
actuals/returns and complete public admission. The [full inventory](../product/04-remaining-work.md)
and [completion plan](completion-plan.md) remain active.
