# Program preparation cache

Implementation: `28fbbe9` (2026-11-08). Native Windows development/O2 passed
six new groups plus existing Engine regressions with default stacks and zero
SDK heap at exit. All 243 receipt inputs match checkout and committed Git.
This slice covers private output and input-output Programs only.

## Compile once, retain immutable preparation

[`module_output_program`](../../src/module_output_program.fy) freezes the exact
image and calls `verifier::inspect_output_returns` in `finish`, before publishing
the owning Program. Successful lowering alone is still not executable proof.
The independent verifier covers the exact code, image and selected input ABI.

`Stored.prepared` retains the execution-relevant proof fields and planning facts:

- Static sites and reference-return site origins from the verifier result;
- list and place storage requirements, including their preparation prices;
- owned-call entry work, including entry arity;
- payload capacity and the execution scratch byte requirement.

The scratch field is a size plan, not shared mutable execution storage. Every
invocation still owns its runtime state, buffers, frames, Fuel and staged output.
`preparation(ref Program)` borrows the record from the same immutable owner as
the code, literal image, source Snapshot and input-mode flag. Copying this record
does not authorize unrelated raw IR or a different image/ABI.

## Synchronous and pending reuse

`complete` and `complete_quantized` read the retained requirements and enter
[`execute_output_admitted`](../../src/slice_result_execution.fy). They do not
repeat the full verifier or rebuild the cached list/place/entry-work plans.
Invocation-specific entry, input and runtime-authority checks still run.

[`runtime_pending_output`](../../native/runtime-engine/runtime_pending_output.fy)
passes the same sites, origins, requirements and work into `open_prepared` and
`start_output_prepared`. Advance uses saved Machine state and the pinned Program;
it neither repeats proof nor recreates entry. Engine publication also reads the
cached scratch requirement rather than rescanning the output Program.

The independent raw entries `execute_output_scalar_metered` and
`execute_output_scalar_quantized` remain available. Each valid-quantum raw call
enters `inspect_output_returns` again, including calls that reject a wrong input
ABI. The trusted owning entry is an internal boundary, not a raw proof bypass.

For **P successfully compiled Programs and N owning executions**, full verifier
entries were **P + N** and are now **P**. Pending resumes add no verifier entry.
Separate deliberate raw calls and independent test oracles still each verify;
they must be counted separately. This counts full verifier entries, not planner
scans, all native work, elapsed time or a wall-clock speedup.

## Ownership, pins and retained-memory tradeoff

The cache belongs to `Program` and is reclaimed with its final owner. Existing
Engine Instance pins keep a released Program and its cache alive; release blocks
new admissions but does not invalidate existing Instances. Program/Engine moves
transfer ownership without moving backing allocations or recomputing proof.
Low-level pending callers must keep the exact Program and input Snapshot alive;
the Engine layer authenticates the Instance association and owns its pins.

The tradeoff is a larger inline `Stored`, multiplied by the SDK's minimum
**Vec8 capacity**, although only one element is initialized. The Engine's outer
Program-handle Vec8 and actual literal payload remain separately accounted.

- Preparation is 1328 bytes; `sizeof(Stored)` grows from 22016 to 23344 bytes.
- Stored Vec8 backing grows from 176128 to 186752 bytes: 10624 extra bytes
  per owning Program. Both native profiles record the same exact layout.

Do not reuse the earlier output width in the
[Program-memory receipt](runtime-engine-program-memory.md) as this cache's size.
Native layout facts and checked admission must charge the larger allocation.
Existing per-Program, aggregate and combined heap ceilings are unchanged; the
larger retained footprint can exhaust the same quota sooner.

Fuel prices, defaults and ceilings remain unchanged. Cached work still incurs
the existing preparation/entry charges on every invocation. Error categories,
original-source mapping, first-cause behavior and OOM rollback remain the existing
contracts; planning now happens before Program retention. Allocation failure must
publish no partial owner or retained charge. The cache adds no guest authority.

## Native verification

The [cache fixture](../../tools/runtime-engine/engine_preparation_cache_tests.fy)
passes four groups in each profile:

1. `owning_program_reuses_preparation_and_matches_independent_proof`: getters,
   synchronous/quantized/pending reuse, dropped pending state and proof oracle.
2. `engine_instances_reuse_proof_across_release_moves_and_resume`: shared pins,
   release, Engine moves, synchronous execution and resumed output/Fuel parity.
3. `unrelated_programs_keep_separate_immutable_preparations`: distinct input and
   no-input owners, interleaving, moves and independent cached-field comparison.
4. `raw_calls_reverify_and_reject_wrong_input_abi_without_fuel_mutation`:
   repeated raw verification, both ABI mismatches and preserved pre-dispatch Fuel.

The [gap fixture](../../tools/runtime-engine/engine_preparation_reuse_tests.fy)
adds two groups: rejected compile/slot admissions with pinned-owner teardown and
fresh recompilation, and same-address raw IR mutation/rejection/restoration.

The [Windows evidence](../evidence/runtime-program-preparation-cache-windows-20261108.json)
records the executed commands, source/artifact identities, 33 bindings/29 layouts,
layout measurements and verified implementation commit. Instrumentation exists
only in the isolated native fixture; the production verifier has no counter.
Existing Engine quota/OOM, step/output-copy and OS guard groups share the image.
Separate OS I/O and metered-output images were not repeated for this slice.

## Owning contracts and remaining work

This supersedes the per-execution proof descriptions in
[output execution](module-output-execution.md) and
[pending output](runtime-pending-output.md) for owning cached Programs.
[Engine preparation](runtime-engine-prepared.md), [stepping](runtime-engine-step.md)
and [compile-memory admission](runtime-engine-compile-memory.md) own the surrounding
lifecycle and accounting. [Output-copy quanta](runtime-output-chunks.md) remain a
separate bound. Compile-time proof is still synchronous, not resumable.
Other setup, bulk operations, CALL/RET, final seal, cleanup, deadlines,
in-flight cancellation/poison and public lifecycle/ABI/CLI remain open under the
[accepted inventory](../product/04-remaining-work.md). R03-R05 are not complete.
