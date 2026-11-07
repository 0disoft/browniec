# Resumable owned CALL argument copies

Implementation: `4e9c7c6` (2026-11-08). Five kernel groups and existing Engine
regressions pass development/O2, with default stacks and zero SDK heap at exit.
The [Windows evidence](../evidence/runtime-call-argument-chunks-windows-20261108.json)
records the receipt, committed input identities and unchanged transport layouts.

This kernel is a prerequisite for bounded CALL execution. The existing VM CALL
dispatcher still uses the atomic entry transaction until a separate integration
connects this cursor to capture, Fuel, frame and register publication. This does
not establish a bounded CALL/RET or public Engine step contract.

## Transaction boundary

The original `array_owners::copy_call_arguments` already validates the complete
batch before copying payload and publishing metadata. The new path preserves that
transaction boundary while allowing payload work to return to its caller.

`call_copy_work::begin(table, catalog, arguments, capacity)` returns a compact
`call_copy_cursor::State`. It reads metadata only. `advance(work, table, catalog,
arguments, data, allowance)` returns `None` while pending or `Some(Copies)` once
the entire batch is published. The caller owns and pins all referenced storage;
neither function allocates SDK heap storage.

At most eight array and nominal record arguments resolve against the original
owner table. Repeated original sources are legal. Every provisional destination
lies beyond the original published arena prefix; an argument cannot name a
provisional destination as its source.

Validation precedes every destination write, including alignment padding. Bool
arrays validate every byte; records validate nested bool leaves and derive a
canonical scalar/padding mask from the checked catalog. A late invalid bool must
leave all destination bytes untouched. After validation, record scalar bytes can
be read directly from the pinned original source, with destination padding zeroed.
This avoids the atomic helper's eight 128-byte record payload snapshots.

Per-argument metadata/reservation failures are deferred until validation reaches
their original position. An earlier invalid bool therefore still precedes a later
slot/quota error, matching `copy_call_arguments`. A bad bool read counts toward
work and permanently deactivates the cursor; retry cannot skip that byte. The
array-only `copy_arguments` API has a different reservation-before-bool order;
its future VM adapter must preserve that order separately.

Only the final byte of the complete batch permits owner/order/depth/arena and
result-token publication. Earlier destination bytes remain unreachable spare
storage. Cancellation abandons that spare storage without publishing an owner.
The caller must not replay external effects when discarding a pending operation.

## Work accounting and pinned state

An advance accepts 1..4096 units and must fit `4096 - last`. A bool validation
read costs one unit; a source/destination transfer costs one; an alignment or
canonical-padding zero write costs one. `written` counts destination bytes only,
while `total` and `last` include validation reads. The caller resets `last` once
per shared batch, not before every helper invocation.

Progress, counter headroom, table validity, source generations/types/shapes,
destination generations and reservations must be authenticated before further
payload work. Cursor facts are comparison data, never independent owner authority.
The catalog, arguments, table and backing stay pinned, and other guest operations
remain frozen while the operation is active. Metadata planning and catalog walks
remain atomic; the byte bound is not a wall-clock or metadata-visit bound.

Eight maximum i64 arrays require 262144 destination bytes, or 64 full 4096-unit
advances. Eight maximum bool arrays require 32768 validation reads before any
destination write, then 32768 copies: 16 full advances. Alignment bytes are
additional work where required. Zero arguments begin inactive and yield an empty
result without payload, table or counter changes.

## Integration still required

The VM adapter must preserve original argument/capture evaluation, diagnostics and
Fuel across quanta. It must publish loan authority, the completed owner batch,
formal bindings, static/input words, registers, frame and PC as one coherent CALL
transition. A pending copy must resume before the zero-Fuel gate without charging
the CALL twice. Return, frame teardown, capture/result metadata, cleanup and seal
work remain separate accepted obligations.

See the [remaining inventory](../product/04-remaining-work.md) and
[Engine step contract](runtime-engine-step.md) for the broader incomplete scope.

## Executed native checks

Five groups cover all six scalar domains and signed/unsigned edges, nested
bool/padded records, repeated sources and parity with the independent atomic
oracle; eight maximum-width/bool arguments; late invalid bools and mixed error
priority; both-phase metadata/generation/range/loan/budget/overflow failures; and
alignment padding, whole-batch publication, cancellation and empty arguments.
Every begin/advance checks unchanged SDK allocation attempts and live heap.

Both profiles retain the existing Engine layout: shared array work 360 bytes,
Cursor 432, Machine 880, Core 120880 and Vec8 extra 2880. The new CALL cursor is
not yet embedded in that layout. All 263 receipt inputs match checkout and Git
raw bytes. The root locked check passes 268 sources/3006 MIR; all 260 production
modules retain LF. No wall-clock throughput/latency benchmark is claimed.
