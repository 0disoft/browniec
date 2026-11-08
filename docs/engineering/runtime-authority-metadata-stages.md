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

1. Prepare the invocation context once, outside the authority bound.
2. Reserve a snapshot stage, then reconstruct authority over separate stages.
3. Prepare the payload-copy recipe alone and yield. This catalog/layout work
   remains atomic and is deliberately outside the bounded authority ledger.
4. Validate/copy payload into unpublished destinations with the shared byte room.
5. Reserve a final stage and publish owner, authority, frame and input bindings.

The owning Core stores the large work once. Exact-field references also avoid
compiler-generated whole-transaction temporaries when reading the nested Call.
No peak-stack or latency improvement has been measured.

The native host measures Cursor 1048 -> 1184 bytes and Machine 1496 -> 1632 bytes
when adding RET. Core remains 153792 bytes; RET reuses the CALL transaction bank.
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

See the [Windows evidence](../evidence/runtime-authority-metadata-windows-20261109.json)
for named snapshots, commands, native images, default stack settings, storage
measurements and exact input audits. Direct adapter groups compare against raw
helpers, including partial-room deferral, frozen original state, final-only
publication and late frame errors. Actual Engine fixtures cover fixed/mixed
quanta, exact/one-less Fuel, binary output, moves/pins, cancellation/refunds and
SDK allocation denial on covered resumes.

Still atomic or incompletely bounded: CALL context/copy planning, metadata scans
inside payload-plan validation, ordinary bool ARET scans, SRET catalog/layout
preparation, raw recipe discovery, setup/proof/seal and cleanup. Bounding the
authority kernel does not bound every CALL/RET metadata visit. Public lifecycle,
wall-clock deadlines, STOPPING/poison and the full remaining inventory stay open.
The broader completion goal remains paused; this slice is local only.
