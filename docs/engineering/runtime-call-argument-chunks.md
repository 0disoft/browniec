# Resumable owned CALL argument copies

Implementation: `4e9c7c6` (2026-11-08). Five kernel groups and existing Engine
regressions pass development/O2, with default stacks and zero SDK heap at exit.
The [Windows evidence](../evidence/runtime-call-argument-chunks-windows-20261108.json)
records the receipt, committed input identities and unchanged transport layouts.

The [VM CALL successor](runtime-call-entry-chunks.md) now connects this kernel to
saved dispatch, captures, Fuel and frame/register publication. The original
atomic native entry APIs remain available. CALL metadata/RET and the accepted
public bounded-step contract remain incomplete.

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
`begin_arrays` preserves that order separately for the VM adapter.

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

## VM integration and remaining work

The [VM adapter](runtime-call-entry-chunks.md) reuses deterministic frozen
metadata and charges owned CALL Fuel after the validation-only phase, exactly
once before copying. Zero-Fuel copies resume before the ordinary dispatch gate.
Complete owner, loan, formal, input/static word, register, frame and PC publication
finishes without an intermediate yield. Return, frame teardown, capture/result
metadata, cleanup and seal work remain separate accepted obligations.

See the [remaining inventory](../product/04-remaining-work.md) and
[Engine step contract](runtime-engine-step.md) for the broader incomplete scope.

## Executed native checks

Five groups cover all six scalar domains and signed/unsigned edges, nested
bool/padded records, repeated sources and parity with the independent atomic
oracle; eight maximum-width/bool arguments; late invalid bools and mixed error
priority; both-phase metadata/generation/range/loan/budget/overflow failures; and
alignment padding, whole-batch publication, cancellation and empty arguments.
Every begin/advance checks unchanged SDK allocation attempts and live heap.

The kernel-only checkpoint retained the old Engine layout. The
[VM successor](runtime-call-entry-chunks.md) now embeds this cursor and records
its measured storage/admission costs. Current development/O2 verification adds
array-only error-priority/parity and validation-only boundary groups (eight
kernel groups total). Current source/artifact identities are in that successor's
evidence; the original five-group checkpoint above remains historical evidence.
