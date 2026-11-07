# Engine-owned instruction stepping

Implementation: `e49bb76` (2026-11-08). This extends
[Engine preparation](runtime-engine-prepared.md) with actual caller-returning
execution, terminal publication and canonical cancellation. This is the private
Fairy Engine facade, not the public C ABI or the accepted bounded-work step API.

## Execution and publication

`step_instance(engine, instance, quantum)` authenticates the existing Engine
owner/guard/epoch and accepts a prepared output or input-output Instance. It
reacquires the exact pinned Program and owned input, then advances the saved
Machine through the canonical dispatcher. It never re-verifies, recreates entry
or drains Pending in a hidden loop. Quantum is 1..4096 dispatch visits. The
[output-copy successor](runtime-output-chunks.md) now includes prepaid copy
continuations in those visits and shares a 4096-byte allowance across emits.

Pending returns Event kind 4 with current Fuel and keeps its owning state intact.
At VM success, sealing transfers the staged backing directly into the Published
Vec reserved during preparation. No temporary output vector is allocated on
resume. The completion records the scalar value, exact Fuel, output length and
emit count. Failure preserves the original Program-mapped diagnostic and never
publishes a staged prefix, including when the final seal exhausts Fuel.

Terminal steps drop Core, Machine, input windows and execution scratch, then
release the empty Machine Vec backing. Only the ordinary retained Execution
remains: Published Vec8 (576 bytes), plus output_limit reserved payload on
success. Failure retains the empty 576-byte vector. The Instance input remains
charged until teardown. All instance, aggregate and combined ledgers shrink to
the actual remaining ownership without a new allocation or quota request.

Cancel and explicit destruction of a running Instance invoke canonical abort
before dropping private VM ownership. Cancellation discards staged output and
refunds pending storage once while preserving spent Fuel and the first terminal
cause. Ordinary Engine destruction also reclaims a genuinely running Machine.
External effects are not replayed or rolled back.

Ready steps reject with status 3; terminal or cancelled steps reject with 11.
Invalid quantum returns 1 without changing VM/Fuel/heap state. Unknown IDs return
2. Existing synchronous execution, output extraction and detached-output lifetime
remain available. Released Program pins and Engine moves remain valid across
successive steps; each invocation uses the normal owner admission epoch.

## Verification

Six [native Engine groups](../../tools/runtime-engine/engine_step_tests.fy) cover:

- Fixed quanta 1, 2, 3, 7, 64, 4096 and mixed batches, in lockstep with the saved
  VM carrier, followed by comparison with synchronous output/value/Fuel.
- Ready, running and terminal states, invalid quanta and frozen first causes.
- Three interleaved Instances, two Engine moves, released Program pins,
  middle-owner extraction/destruction and detached binary output.
- Cancellation after a staged emit, precise refunds and unexposed prefixes.
- Original trap offsets/spans, exact Fuel, one-less final-seal Fuel, dispatch
  Fuel exhaustion and output limits.
- Empty output and automatic destruction of an actually running Engine.

Every resume, including terminal publication, runs with the next SDK allocation
forced to fail; the allocation attempt counter must remain unchanged. Pending
steps retain exactly the previous heap, terminal steps match the reduced plan,
and every fixture returns to its original heap. Native guard tests reject step
from the wrong thread and during active admission. Existing prepared/pending VM,
synchronous Engine and OS regressions share the image.

The [Windows evidence](../evidence/runtime-engine-step-windows-20261108.json)
records development/O2 success, default stacks, zero SDK heap at exit and exact
checkout/Git identities. The transport now reviews 33 typed bindings and 24
layouts, including Output's Execution/completion/publication/Machine fields.

## Remaining accepted work

Dispatch visits do not bound all bytes, metadata visits or native time. Output
copy bytes now have a separate per-step allowance. Setup/proof, other bulk
copy/tag/store/transfer, CALL/RET, seal and cleanup remain atomic.
Chunk those recipes and preserve quantum-independent Fuel/results before
claiming the accepted work-bounded Engine step contract. Deadlines, in-flight
cancellation, STOPPING/poison containment, public lifecycle/ABI/CLI integration
and the full accepted inventory remain open. R03-R05 are incomplete.

Existing VM capacities, guest prices, Fuel default 256 and ceiling 16000000 are
unchanged. This work makes no public availability or external-effect replay claim.
