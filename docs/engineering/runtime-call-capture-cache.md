# Immutable CALL66 capture cache

Implementation: kernel `ced4289`, owning integration `5f9bfc3`.
Verification: **PASSED**, Windows development/O2, with default 1MiB reserve/4KiB
commit stacks, no compiler overrides and zero exit SDK heap. Five plan-kernel
groups, six actual returned-view groups, one focused live-Held group and existing
Engine/kernel regressions pass. [Evidence](../evidence/runtime-call-capture-cache-windows-20261108.json).

## Prepare after proof

The [returned-view bridge](runtime-output-returned-views.md) admits actual
exclusive returned slices through the private output compiler, independent
canonical/original-recipe proof, and selected-origin execution. This cache
extends that bridge and the [Program preparation cache](runtime-program-preparation-cache.md).

`module_output_program::finish` completes `output_return_proof::inspect` on the
exact code, literal image and input mode before `call_capture_plan::prepare`.
The resulting immutable `Preparation.calls` stays with that Program's original
IR, image and source Snapshot. Selected origins remain in `parameters`, field 7;
the new plan occupies field 8. The old stash's field-7 plan cannot be reused.

The plan stores no live loan, owner token, Held receipt, authority snapshot,
payload, pointer or continuation. A copied plan is not raw-IR admission authority.

| Plan field | Physical type | Meaning |
| --- | --- | --- |
| `pcs` | `u32[32]` | CALL66 PC per call map; 256 means absent. |
| `ends` | `u8[256]` | Eight argument END counts per map. |
| `parents` | `u8[256]` | Eight surviving parent sites per map; 16 means absent. |
| `required` | `u32[32]` | Sites requiring an exclusive Held without close-parent/drop. |
| `absent` | `u32[32]` | Sites requiring no Held. |
| `ready` | `bool` | Complete construction succeeded. |

Construction bounds the dimensions and operands it reads and rejects reused
maps across CALL9/64/66/78. Only CALL66 populates recipe rows. Canonical proof
still owns whole-Program validity and complete call-map admission. Preparation
uses the existing `slice_result_call_ir::{binding,chain,creator}` to derive END
counts, surviving parents and the two disjoint receipt masks. Lookup checks
readiness, opcode/PC/map/target/arity identity and bounded cached values without
calling those recipe helpers. Its guards do not re-prove arbitrarily edited IR.

## Dynamic CALL and RET checks

`call_work_execution` borrows the same plan during CALL begin and every saved
advance. Ready CALL66 uses `prepare_enter_cached`; ordinary CALL9/64/78 bypasses
that helper. The existing exact-field authority/pool borrowing is preserved, so
accessing depth or snapshots does not materialize whole parent runtime copies.

Cached counts replace only immutable ancestry scans. Each required live site
must still contain an exclusive Held with `close_parent == false` and
`drop == false`; each absent site must still have no Held. Runtime entry keeps
its ticket/generation, owner, reservation, extent, authority, capacity and future
frame checks. Saved advances reconstruct against the invocation's frozen caller
and compare their existing Fuel facts before publication.

After native borrowed-result handoff, `slice_result_frames::pop_cached` clears
the consumed-site mask and restores masked argument bindings at cached surviving
parents. `loans::consumed` only clears an already-consumed receipt; it never closes
a loan again. Distinct cleared locations have no ordering dependency. Result
retention and frame retirement keep the existing handoff rules.

Owning synchronous execution and native pending execution both borrow the exact
Program's preparation. The Machine stores no plan pointer. Instance pins keep
the Program alive through release/moves. Raw execution still re-proves its exact
candidate and supplies an empty plan; legacy start/step/pop wrappers retain
their original recipe scans. Explicit selected-origin wrappers preserve their
parameters even when no cache is supplied.

## Verification and measurement

The final native receipt is
`build/runtime-engine/20261108T130800677073Z/receipt.json`. Both profiles measure:

| Retained layout | Before | After | Increase |
| --- | ---: | ---: | ---: |
| `Preparation` | 1344 | 2248 | 904 bytes |
| `Stored` | 23360 | 24264 | 904 bytes |
| Reserved `Vec<Stored>` backing, eight slots | 186880 | 194112 | 7232 bytes |

`Plan` itself is 900 bytes; the containing layout adds four padding bytes.
The existing native size query and Program reservation/physical-heap fixtures
account for the actual Stored layout and vector capacity. There is no additional
cache allocation per invocation. Cursor, Machine and Core sizes remain unchanged.

The isolated Engine test-project instruments entries to `binding`, `chain` and
`creator`. Production recipe source has no counter. The sum counts helper
entries, including nested calls; it does not measure all metadata visits,
instructions, elapsed time or a complete work quantum.

The existing six returned-view groups now require actual CALL66 and cached masks
for direct, nested, forwarding and second-input source fixtures. Their raw oracle
must record positive helper entries; owning synchronous runs and every pending
resume must record zero. Fixed quanta 1/7/4096 and mixed 1/7/3/4096/2 retain exact
Fuel, output and diagnostics. Existing allocator-failure guards, moves, released
pins, cancellation/refunds, exact/one-less Fuel and malformed-origin/identity
rejections remain in the same native image.

Five plan-kernel groups separately cover explicit numeric/legacy-recipe parity,
eight arguments, a fifteen-END chain, dimension/map/creator rejection, moves,
lookup guards and zero SDK allocation attempts. They are synthetic recipe
fixtures, not evidence of source admission or runtime authority authentication.

The focused native [live-predicate group](../../tests/m2/call_capture_live.fy)
compares cached and legacy metadata preparation. Missing required Held,
non-exclusive Held, close-parent/drop flags and an unexpected Held at an absent
site must each fail with the same error/offset. The absent-site case also retains
a valid required Held, so it cannot pass by rejecting the wrong condition. After
each rejection, restoring valid metadata must succeed with the same capture and
two-END chain. These synthetic receipts do not authenticate native authority.

The current compiler gives zero required/absent masks to direct, forwarding and
second-input fixtures. The nested fixture exercises both nonzero masks,
so both dynamic receipt predicates are exercised by actual source. An initial
test incorrectly required a nonzero absent mask in every fixture; a diagnostic
image identified that test assumption. The final unmodified verification image
checks masks according to each source form. Diagnostic images are not pass
receipts or timing evidence.

The native host measures Plan, Preparation and Stored layouts. Accounting uses
actual Stored size and reserved vector capacity; the additional inline plan
must be charged for all eight retained slots, including padding. It is a retained
memory tradeoff, not a measured latency improvement.

## Remaining work

The later [CALL/RET authority slice](runtime-authority-metadata-stages.md) reuses
this immutable cache and stages authority restoration/final publication in the
owning Pending VM. The broader completion goal remains paused. Context/copy-plan
and layout metadata, setup/proof/seal/cleanup, monotonic deadlines,
cancellation/STOPPING/poison, public lifecycle/ABI/CLI and the
[accepted inventory](../product/04-remaining-work.md) remain open. These private
slices do not complete R02-R05 or establish a public bounded-step or wall-clock
guarantee. No push, release or deployment is part of the resumed work.
