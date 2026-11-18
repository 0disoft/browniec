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
The [array initialization/fill successor](runtime-array-fill-chunks.md) shares
that same byte allowance across CREATE/FILL and emits, including alignment
padding. Array continuations also consume visits without new dispatch Fuel;
the dispatcher freezes the current PC until the entire value is initialized.
The [array-copy successor](runtime-array-copy-chunks.md) extends that allowance
to COPY34, ASSIGN38 and actual selected STORE85, including bool validation reads.
COPY publishes only on completion; selected assignments keep their snapshot,
ticket and price while writing the existing target incrementally.
The [element-list successor](runtime-array-list-chunks.md) gathers register cells,
encodes and commits 80/81 and selected 87 mode 1 through that same allowance, using
existing scratch. Destination writes follow complete codec validation.
The [record successor](runtime-record-chunks.md) also admits complete canonical
staging through this allowance and resumes root/child commits. Identity rewrites
normalized padding; same-owner source ranges are snapshotted before any write.

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

The [owned CALL continuation](runtime-call-entry-chunks.md) now connects the
copy kernel to actual saved dispatch, Fuel, captures and final frame publication.
CALL validation/copy shares the same byte allowance; the appended cursor is
included in native size-based admission. Frame/loan metadata still remains atomic.

## Policy-checked input and output (2026-11-18)

The private `prepare_granted_output` entry selects the exact module and function
from the run configuration and compiles it into an owning Program. It checks
the run against the trusted Engine owner's supplied Policy. The selected
verified Program is walked from its entry through branches and calls to derive
whether it requires `brownie.output.emit`. At most 256 instruction positions are
queued once. A reachable emit requires both declaration and grant, including
when it would emit zero bytes. An uncalled function confers no requirement.

Admission checks input length, the requested Fuel, output capacity and the
retained input plus pending-execution bytes. A successful call returns a
prepared Instance for the existing step/cancel and output transfer paths. The
prepared Instance pins its Program after admission releases the Program ID.
Rejection after compilation releases that Program, including when preparation
must destroy a partially admitted Instance. Staged output is available on
successful completion under the existing publication and transfer rules.

The Windows development Engine harness verifies declaration denial, input
length rejection, multiple resumes, binary output and owner reclamation with
zero live SDK allocations. It used Fairy C preview.2, default 1 MiB reserve /
4 KiB commit and 360 source inputs. The reviewed transport retains 36 typed
bindings and 51 layout roles. The seven runtime inputs match the bytes from
the previous transport pin. The separate selected-entry authority group
passes under the same compiler in development. Root locked check verifies
375 source files and 4113 MIR functions.

This admission is one input/output entry per invocation with a Policy supplied
by the trusted native owner. Persistent Engine policy ownership, reuse of a
configured Program for multiple runs, full enforcement of remaining policy
limits including deadlines, and C ABI delivery remain open. Typed host
request/reply and optimized builds of this admission are unverified.

## Engine-owned policy

`create_with_policy` consumes a validated Policy and keeps it for the lifetime
of the Engine. Configured run admission rechecks declarations, grants and run
limits against that owned Policy. Legacy Instance constructors cannot supply
authority to a configured Engine. The supported Engine count, Fuel, compile
working memory and Instance memory ceilings narrow the existing limits.
Policy vector and capability backing are charged as control storage and
released on successful Engine destruction.

Windows development verification passed with Fairy C preview.2, default
native stacks, 37 reviewed bindings and 53 layouts. The run exercised
declaration denial, the input limit and successful step/output/teardown,
with zero live SDK allocations. Root locked verification passed 375
sources and 4115 MIR functions.

## Remaining accepted work

Dispatch visits do not bound all bytes, metadata visits or native time. Output
copy, scalar array initialization/fill, copy/assignment and element-list gather/
encode/commit plus record staging/commit share one 4096-byte step allowance,
including bool scans. Catalog planning, nominal walks and owner-table checks,
setup/proof and other bulk
copy/tag/store/transfer, CALL metadata/RET, seal and cleanup remain atomic.
Chunk those recipes and preserve quantum-independent Fuel/results before
claiming the accepted work-bounded Engine step contract. Deadlines, in-flight
cancellation, STOPPING/poison containment, public lifecycle/ABI/CLI integration
and the full accepted inventory remain open. R03-R05 are incomplete.

Existing VM capacities, guest prices, Fuel default 256 and ceiling 16000000 are
unchanged. This work makes no public availability or external-effect replay claim.
