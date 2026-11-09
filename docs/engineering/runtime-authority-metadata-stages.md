# CALL/RET authority metadata stages

The private owning Pending output VM keeps one unpublished authority transaction
in its heap Core. CALL and RET reuse that bank. Their compact cursors carry only
recipes, progress and counters; they never copy the full bank on every dispatch.
The independent raw/synchronous dispatch and atomic authority helpers remain
available as comparison oracles. This does not establish a public bounded-step
API or complete R02/R03.

## Scheduling contract

Each authority stage reserves a conservative 4096-unit allowance immediately
before executing. It needs a fresh batch; unused partial room is not saved as
credit. Snapshot, reconstruction and final publication are separate stages.
Payload byte work and these authority charges share one 4096-unit dispatch
allowance. Only `last` resets at the outer dispatch boundary; totals remain
checked and monotonic. This is logical work accounting, not milliseconds.

A continuation consumes one scheduling visit without repeating opcode Fuel.
Owning dispatch statistics therefore include metadata continuation visits, not
just guest opcodes. Valid frozen inputs retain quantum-independent terminal
Fuel, results, output and diagnostics. An authority stage that cannot fit leaves
its work and Fuel unchanged; opcode/prefix work may already have run once.

The owning invocation pins the Program, preparation/cache, bindings, Runtime,
input snapshot, payload and source bytes. No other guest work or external
callback runs during an unfinished transaction. Original authority and frame
metadata are published only after final checks; cancellation discards private
plans and aborts canonical live state. External effects are never replayed.

## CALL

The separate `call_owned_work` prerequisite now prepares the owned portion of
the context with fresh 4096-unit stages: cost/cache header, one capture argument,
one CALL66 Held site (at most 47 receipt slots), then one owned argument's
array/record descriptors. Record lookup visits at most sixteen bindings twice.
CALL66 requires the exact proved cache; this owning kernel never falls back to
raw IR recipe discovery. Raw `prepare_enter` and `prepare_enter_cached` remain
comparison oracles. Six native groups pass development/O2, covering full mixed
arity, supplied captures, Held ordering, Fuel boundaries and unchanged inputs on
partial-room deferral (`build/call-owned-work/{development,release}/receipt.json`).
This prerequisite is not yet connected to the owning context adapter below.

`call_argument_work` similarly admits one fixed header/preprice stage and one
Static/reference argument per stage. Generic arguments prepay before source
authentication; Static arguments authenticate before payment, including the
positive zero-argument price. One Runtime argument can inspect the sixteen-slot
pool and its fixed owner table, or locate one returned Held receipt; it never
reads payload bytes. Five native groups pass development/O2 against the raw
argument helpers, including image/Runtime/Input/returned sources, full arity,
exact/one-less Fuel, late errors and partial-room deferral
(`build/call-argument-work/{development,release}/receipt.json`). Canonical array
CALL cost lookup now borrows its exact catalog instead of copying it for each
scalar field read.

`call_context_work` coordinates these banks with separate prefix, argument,
selection, owned-preparation and final-adoption stages. It preserves frame/Fuel/
place error order and charges input-frame work once. Argument Fuel becomes
externally visible only after complete authentication, matching raw context
preparation. Four native groups pass development/O2 against raw `begin`, with
enabled/disabled input, depth/Fuel/place precedence, scalar/zero-arity success
and every-stage partial-room immutability
(`build/call-context-work/{development,release}/receipt.json`). The owning VM
adapter below still needs to adopt this coordinator.

1. Prepare the invocation context once, outside the authority bound.
2. Reserve a snapshot stage, then reconstruct authority over separate stages.
3. Build the copy recipe in fresh 4096-unit stages: initialize/inspect the
   catalog, traverse up to sixteen dependency edges, lay out one node (up to
   sixteen fields), plan up to eight arguments, and cache masks/bool positions.
   The catalog proof is built once per invocation, including unused records.
4. Reauthenticate the copy plan in its own fresh 4096-unit stage before every
   payload invocation. The owning wrapper also requires a fresh payload batch
   before copying its saved Context/Cursor. Copying pays a fixed 3072-unit metadata entry plus
   each record bool-position read and copy-mask visit, sharing room with payload
   bytes. Array bytes/padding cost one unit; record bytes cost two. Insufficient
   room defers without payload, Fuel or counter changes. No credit crosses yields.
5. Reserve a final stage and publish owner, authority, frame and input bindings.

The invocation pins its catalog, arguments, source bytes and planned owners.
Validation checks at most eight arguments and sixteen owner slots, plus up to
128 cached bool positions per record. It never rebuilds the full catalog or
rescans non-bool mask bytes. Deferred source/metadata/quota errors retain the
raw argument error order; copying charges Fuel once after payload validation.
The prepared path is private owning execution, not a public proof token. Raw
`call_copy_work` and atomic owner APIs remain independent comparison oracles.

The fixed entry includes compiler-generated Cursor/Context/Prepared array
copies, bounded argument/range previews and final owner-table stores. Exact
field references in dispatch-room calculation and the pending-CALL guard avoid
copying record scratch and CALL descriptor arrays just to read scalar fields.
The ledger counts logical metadata entries and payload bytes; scalar loop/
counter control is part of processing each unit, not a separate CPU-instruction
budget. A full array-only payload batch therefore transfers at most 1024 bytes.
Kernel short-room admission uses a constant 3074-unit minimum (entry plus two
work units), so deferral never scans arguments. Exact `Copies` references avoid
materializing eight tokens just to inspect their count. The fixed allowance
covers 2288 conservative wrapper-copy touches, 512 units for four eight-argument
passes and 192 for result propagation: 2992 in total, with 80 units of headroom.

The owning Core stores the large work once. Exact-field references also avoid
compiler-generated whole-transaction temporaries when reading the nested Call.
No peak-stack or latency improvement has been measured.

RET previously grew Cursor 1048 -> 1184 bytes and Machine 1496 -> 1632 bytes.
The CALL copy-plan bank now grows Core 153792 -> 163984 bytes (+10192); Cursor
and Machine retain their post-RET sizes. The bank is passed by mutable reference
as Core field 8, separately from the shared authority transaction at field 7.
Existing admission/accounting uses these actual native sizes.


## RET

Prefix preparation selects ordinary, owned-array, record, borrowed, static or
input/reference return state once. Existing payload validation is admitted
whole before the opcode/prefix runs. Its work counter is recorded in the batch
that performed successful validation/preparation; it is not a successful-RET
receipt. Later restoration or final checks can still fail.

The compact pending recipe then advances through snapshot/root compaction,
authority restoration, and final frame/output publication. Phase 4 records the
last completed return until another RET starts. Final publication consumes a
fresh authority allowance, so a following COPY/SNAPSHOT waits for another batch.
CALL and RET never retain separate large transaction banks.

Pure final checks preserve ordinary/static frame-error offsets and native
RET65/reference offsets. Synthetic late bad-frame tests intentionally retain
original metadata and pinned Fuel on staged rejection; legacy raw RET65 can
already have debited handoff Fuel before its frame-pop failure. This malformed
private-state difference is explicit, not valid-program Fuel parity evidence.

## Evidence and limits

See the [CALL copy-plan evidence](../evidence/runtime-call-copy-plan-windows-20261109.json)
for the current catalog/planner/owning integration snapshots, native images,
storage and exact input audits. The [preceding authority evidence](../evidence/runtime-authority-metadata-windows-20261109.json)
retains the earlier CALL/RET snapshots. Direct adapter groups compare against raw
helpers, including partial-room deferral, frozen original state, final-only
publication and late frame errors. Actual Engine fixtures cover fixed/mixed
quanta, exact/one-less Fuel, binary output, moves/pins, cancellation/refunds and
SDK allocation denial on covered resumes.

Still atomic or incompletely bounded: CALL context preparation, ordinary bool
ARET scans, SRET catalog/layout
preparation, raw recipe discovery, setup/proof/seal and cleanup. Bounding the
authority kernel does not bound every CALL/RET metadata visit. Public lifecycle,
wall-clock deadlines, STOPPING/poison and the full remaining inventory stay open.
The broader completion goal remains paused; this slice is local only.
