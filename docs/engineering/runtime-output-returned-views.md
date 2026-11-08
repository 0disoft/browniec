# Private output returned views

Verification: **PASSED**, Windows development/O2. Implementation: `f9a76ce`.
[Evidence and input audit](../evidence/runtime-output-returned-views-windows-20261108.json).
Six new native groups and existing Engine/kernel regressions passed with default
1MiB reserve/4KiB commit stacks, no compiler overrides and zero exit SDK heap.

This bridge is the prerequisite identified by
[CALL snapshot stack storage](runtime-call-stack-snapshots.md). It connects
private output compilation to borrowed-result proof and selected-origin VM
execution. The [owning CALL66 capture-cache successor](runtime-call-capture-cache.md) now
reuses proved recipes in synchronous and pending execution; the original bridge
verification below predates that integration.
The existing [Program preparation cache](runtime-program-preparation-cache.md)
continues to retain immutable admission facts; these are distinct caches.

## Private compiler gate and recipes

[`compiler::lower_prepared`](../../src/compiler.fy) keeps the ordinary/public
declaration rejection, with an explicit exception for private output lowering
when both `signatures.output` and `returns` are enabled. Source-origin inference
still runs. For returned slices outside the existing shared-reference result
dialect, the private body records return type 12 (`usize`) as a proof identity.
That identity is not a guest-visible pointer or permission to use a returned
view as a scalar.

After body lowering,
[`output_return_ir::lower`](../../src/output_return_ir.fy) converts the
terminal borrowed-result definitions and returns:

| Original proof operation | Private returned-view recipe | Meaning |
| --- | --- | --- |
| 57, slice length identity | 63, PREPARE_VIEW | Prepare the actual borrowed site for handoff. |
| 9, scalar CALL identity | 64, PREPARE_FORWARD | Forward a callee's prepared borrowed result. |
| 8, scalar RETURN identity | 65, RETURN_VIEW | Complete the prepared borrowed handoff. |

The source lowerer already emits CALL66 for a returned view captured by a
caller. Its recipe identifies the callee, argument map, result site, surviving
parent and caller-END mask. END_CAPTURE68 and BIND_RESULT67 describe the proved
cleanup and result binding. They contain no live loan ticket. Existing shared
image/input result recipes keep their separate dialect.

The new fixtures require exclusive byte results, including actual CALL66;
substituting a shared/static result or a proxy scalar call cannot satisfy them.
The bridge does not open public CLI, public lifecycle or external bytecode
admission. The private entry remains scalar, with either zero arguments or the
separately selected shared-byte external input ABI.

## Proof before publication

[`output_return_proof::inspect`](../../src/output_return_proof.fy) adapts the
existing canonical output verifier rather than treating lowering as admission.
It follows two paths:

1. If no 63/64/65 recipe appears, it uses
   `verifier::inspect_output_returns` directly and supplies zero borrowed-result
   metadata.
2. Otherwise, `output_return_ir::signature` bounds the initial reads, derives
   exact element/access tags from PREPARE_VIEW sites and propagates tags through
   forwarding edges. Ungrounded cycles and incompatible tags fail. Borrowed
   functions must be non-entry functions with ordinary result kind zero,
   return type 12 and a claimed input position within their arity.
3. A private copy of the candidate is normalized: CALL66 recipes use
   `slice_result_call_ir::rewrite`, then 63/64/65 become 57/9/8. Borrowed-result
   origin claims are cleared only in that copy so that the ordinary verifier
   sees the scalar proof dialect. The original immutable recipes are retained.
4. `verifier::inspect_output_returns` proves the exact normalized candidate,
   literal image and input mode. This includes canonical CFG, types, loans,
   executable calls, reference lifetimes and EMIT admission. EMIT remains
   visible to that verifier.
5. `slice_result_verifier::inspect_output_admitted` grounds the original
   borrowed-result recipes against the normalized body. Only success of both
   stages permits the owning Program to be retained.

The original-recipe pass reconstructs selected input positions independently
of `unit.origins`. Positions are one-based, with zero meaning no selected
borrowed result. All returns must agree. Local owners cannot establish an
escaping input origin; forwarding must reach a grounded producer. When CALL66
bindings exist, origin reconstruction follows actual alias and call definitions
and argument maps rather than accepting flattened metadata alone.

[`slice_result_verifier`](../../src/slice_result_verifier.fy) also checks
CALL66 argument selection, result element/access mode, surviving ancestry,
END masks and cleanup ordering. Prepared return identities must reach their
matching RETURN65 through only the allowed cleanup operations. Every RETURN65
must have exactly one matched preparation; an ordinary RETURN8 in a borrowed
function is rejected. Claimed selected positions must equal the independently
grounded positions. These stages establish admission facts, not live runtime
authority; actual loans and generations still require runtime authentication.

### Original CALL dialect check

Both the existing borrowed-result verifier and output adapter reuse
`validate_signature`. It rejects an ordinary CALL9 targeting a borrowed-result
function before origin reconstruction. PREPARE_FORWARD64 and ordinary CALL9
normalize to the same scalar proxy; the original dialect must therefore be
checked in addition to that proxy. The mutation fixture supplies an otherwise
valid original signature and exact normalized forward body, substitutes CALL9,
and requires error kind 5 at that PC. This closes the static review finding;
final execution evidence is recorded below.

## Immutable preparation and execution

[`module_output_program::finish`](../../src/module_output_program.fy) calls the
adapter before retention. `Preparation.parameters` stores the independently
proved selected positions as `u8[16]`, alongside the existing static sites,
shared-reference site origins, list/place requirements, entry work, payload
capacity and scratch requirement.

`preparation(ref Program)` returns a reference tied to the same immutable owner
as its original code, literal image, source Snapshot and input-mode flag.
Copying preparation alone does not authorize other IR, another image or a
different input ABI. Each invocation still owns its mutable frames, authority,
payload, Fuel, output transaction and continuation state.

Raw `execute_output_scalar_quantized` calls the adapter on every valid-quantum
invocation and passes its proved elements and parameters to dispatch. Its
metered wrapper inherits that reproof. The owning synchronous path instead
calls `execute_output_admitted` with the retained sites, origins, parameters and
plans; it reuses admission proof while retaining invocation-specific input,
entry and live-authority checks. It does not repeat canonical proof on each run.

[`runtime_pending_output`](../../native/runtime-engine/runtime_pending_output.fy)
borrows the same pinned Program's preparation when entering and advancing:

- Entry calls `start_output_prepared_with_parameters` with the retained work
  and selected positions.
- Resume calls `step_output_saved_with_parameters` with those same positions.
- The selected positions feed runtime call contracts for direct calls,
  forwarding and caller capture, including CALL66. An all-zero substitute is
  reserved for the legacy wrappers, not the new owning path.

This metadata does not cache an authenticated live loan or skip CALL's staged
authority/pool validation. Engine Instance pins keep the immutable Program
alive after release, while release prevents new admissions. Moving the Engine
transfers ownership of that backing storage; a continuation still uses the
same Program. Low-level pending callers must preserve the exact Program and
input Snapshot themselves.

## Measured retained-memory cost

Both native profiles measured `Preparation` at **1344 bytes**, previously 1328,
and `Stored` at **23360 bytes**, previously 23344. The selected-origin array adds
16 inline bytes. The owning SDK vector reserves eight Stored slots, so its
complete charged backing rises from 186752 to 186880 bytes: **128 bytes per
retained output Program**. The existing native quota/physical-heap fixtures pass
with this layout; there is no separate vector for this metadata. Outer Engine
handle storage and literal payload remain separately accounted. No peak-stack,
latency or throughput change was measured.

## Release descriptor construction

The first release candidate rejected valid sources: diagnostics observed zero
result-element and selected-input arrays in the returned `Signature`, while the
development candidate passed. `signature` now fills standalone local arrays and
constructs its result once. The final uninstrumented development/O2 suites prove
the actual descriptors and execution; no compiler checkout or optimization flag
was changed. Earlier failed/diagnostic builds are not the verification receipt.

## Six executed test groups

[`engine_output_returned_view_tests.fy`](../../tools/runtime-engine/engine_output_returned_view_tests.fy)
contains six groups. Each group checks its initial physical SDK heap is restored
after teardown. All four positive source fixtures use zero-argument entries;
"second input" below means a callee's second borrowed formal, not external
guest-input ABI coverage.

1. **Actual source, raw oracle and synchronous quanta.** Direct `tail`, nested
   caller capture `tail(tail(...))`, callee `forward` and `pick(x, y)` selecting
   the second input compile into owning Programs. Recipe inspection requires
   exclusive byte tag 138, selected position 1 or 2, CALL66 and RETURN65;
   forwarding additionally requires PREPARE_FORWARD64. Distinct arrays in
   `pick` expose selection of the wrong input. Mutation yields scalar 42 and
   bytes `*)` in one two-byte EMIT. An independently reverified raw dispatcher
   oracle includes the same metered output preparation, owner backing and final
   seal. Owning runs at quanta 1, 7 and 4096 compare exact completion and output.
2. **Engine fixed and mixed pending schedules.** Synchronous Engine execution
   and pending quanta 1, 7, 4096, plus repeating 1/7/3/4096/2, compare exact
   result, Fuel, diagnostics and output with the raw oracle. Every resume,
   including terminal success/failure, runs with allocator failure armed and
   asserts zero SDK allocation attempts. Intermediate pending resumes preserve
   the physical heap and tracked charge and reject premature output extraction.
3. **Exact and one-less Fuel.** Whole-run price comes from the raw oracle.
   Exact Fuel must succeed with zero remaining; one less must fail with Fuel
   error kind 8 and publish no bytes. Synchronous and all pending schedules
   compare completion, mapped diagnostics, output availability and bytes,
   including terminal seal failure.
4. **Moves, released pins, cancellation and refunds.** Two Instances stage real
   borrowed-result output before Program release and two Engine moves. Existing
   pins preserve execution while new admission fails. Cancelling one Instance
   preserves its last Fuel, hides staged bytes, makes no allocation attempt and
   refunds exactly its pending allocation and charge once. Repeated cancellation
   leaves heap and accounting unchanged. The peer completes at the raw price;
   final Instance destruction releases the remaining pins and Program storage.
5. **Local-owner escapes.** Both the owning Program compiler and Engine
   compiler reject a returned local array, with and without an input formal
   that could tempt a false origin claim. Failed Engine admission retains no
   Program, Instance or pin and no instance-memory charge.
6. **Forged origins and malformed recipes.** Copies of compiler-produced
   candidates receive zero, wrong-input, Static or out-of-arity origin claims.
   The two-input fixture includes an in-arity wrong claim, requiring independent
   grounding. Wrong RETURN identity, out-of-range PREPARE_VIEW site and invalid
   CALL66 surviving parent must also fail proof. Detached candidate mutation
   must leave the owning Program's recipes and raw result unchanged.

All six groups executed in both native profiles. Group 6 also proves the scalar
identity boundary: CALL66 never writes its scalar proxy identity at runtime, so
RANGE76 low/high operands and CALL78 scalar arguments must not read it. Each
mutation first passes the normalized canonical verifier, then fails original
recipe admission with kind 5 at the exact offending PC.

## Verification handoff and remaining scope

Final checks: root locked source check 273 sources/3046 MIR; private transport
33 bindings/32 layouts with 128 recursive type-pair checks. Only Preparation's
new field 7 changes the reachable shapes. All 271 receipt inputs and the root
lock/review-tool audit inputs match raw checkout and implementation Git blobs;
265 production Fairy modules retain LF. Both profiles pass exact Fuel/output,
source diagnostics, all six new groups and existing regressions. Every tested
resume has zero SDK allocation attempts, including terminal success/failure.
Full CLI matrices, Linux and clean-machine packaging were not repeated.

The owning CALL66 capture cache remains deferred, including its preserved
actual-source parity and storage obligations from the CALL snapshot document.
Public admission gates remain in place. Broader metadata/catalog work,
resumable setup/proof/seal/cleanup, deadlines, STOPPING/poison and public
lifecycle/ABI/CLI remain open under the
[remaining-work inventory](../product/04-remaining-work.md). R03-R05 and the
full accepted implementation goal remain open.
