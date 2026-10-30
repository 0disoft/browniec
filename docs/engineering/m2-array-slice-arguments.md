# Private atomic slice argument batches

Implementation: `515c274`. This is a native storage foundation for
future borrowed slice parameters; it does not enable guest parameter syntax,
change CALL, add an opcode/Fuel price or advertise a version capability.

The [parameter-origin successor](m2-array-slice-parameters.md) adds checked
private formal/derived IR metadata and argument helpers. It keeps borrowed
programs behind an explicit execution gate; source syntax and VM CALL remain
unavailable.

The existing [shared slice registry](m2-array-slices.md) now has `Arguments`,
`empty_arguments`, `borrow_arguments` and `close_arguments`. A batch contains up
to eight independent tickets, matching the current function arity ceiling.
Each ticket retains the complete selected range of one incoming slice and
shares its root read session. Duplicate incoming slices receive distinct tickets.
Empty ranges and the existing six native scalar element types are supported.
Current guest slices remain u8-only; source parameter integration is pending.

## Atomic admission

`borrow_arguments(pool, sources, owners, capacity)` first rejects more than eight
inputs and validates every incoming ticket against the original pool. It saves
their checked selected lengths before constructing any child. This ordering is
necessary: a fabricated later ticket for a currently free slot must not become
valid merely because an earlier staged child would occupy that slot.

After preflight, the operation stages a fixed-size pool copy, creates whole-range
children using the existing `subslice` operation, and commits the pool only after
all children exist. Any stale ticket/session, invalid range/backing or capacity
failure leaves both original tables unchanged, including slot generations. In
particular, two available slots cannot partially admit a three-argument batch.
No read session is opened: every accepted argument already retains one, so the
owner table is shared and unchanged throughout admission.

## Atomic cleanup

`close_arguments(pool, batch, owners, capacity)` checks count, live-ticket shape,
unique used slots and canonical unused entries (`slot=16,generation=0`). It then
stages both metadata tables and closes the tickets in reverse argument order.
A late stale-ticket or backing failure discards all staged changes, preserving
the original batch for diagnosis or corrected cleanup. Success commits the tables
and resets the batch to canonical empty state.

Caller and peer tickets remain live. A caller may close its original ticket
before the batch; the retained batch ranges still work. Only the last ticket on
a root ends its session and restores writes. A copied stale batch cannot close
reused tickets or a newer root session. Empty acquisition and cleanup are valid
no-ops on valid metadata; cleaning an already consumed canonical empty batch
returns zero. These are private native records, not authenticated public handles
or a guest/host ABI. The future VM must retain returned batches in trusted frame
bookkeeping rather than accepting caller-supplied ticket records from guest code.

## Resource bounds

There is one new ticket per argument and no new array owner, payload extent,
payload scan/copy or heap allocation path. Existing sixteen-handle and owner
ceilings stay unchanged. Eight caller handles plus eight argument handles can
fill the pool. Source payload bytes, owner depth/order and arena use are unchanged.

For A arguments, D pool slots and O owner slots, metadata work is bounded
O(A*D*O + A*A), with A<=8 and D=O=16. Cleanup duplicate detection compares at
most 28 pairs. Staging copies at most one sixteen-slot pool and, during cleanup,
one sixteen-owner table plus its fixed order/arena metadata. This is structural
accounting, not a timing, allocator instrumentation or process-memory result.
The primitive is unmetered and must not be exposed to guest execution until the
CALL admission and cleanup work receive an explicit bounded Fuel contract.

## Integration still required

- Parse and type-check readonly slice parameters and arguments; represent dynamic
  borrowed origins without treating a callee parameter as an owned fixed array.
- Independently verify parameter origins, argument liveness and callee borrow
  state, including forwarding, recursion and nonescaping results.
- Integrate frame admission, mixed owned aggregate copies and borrowed batches
  into one failure-safe CALL protocol before publishing frame/register state.
- Meter preparation and all normal/error cleanup, preserve existing argument
  effects and evaluation order, and connect source scope/return/question exits.

Source slice parameters/results remain rejected. No forwarding, frame ownership,
recursion, cancellation or mixed CALL transaction has been implemented by this
foundation. Existing slice source syntax and Fuel prices remain unchanged.

## Focused verification

Run `python -B tools/verify-m2-array-utf8-source.py --profile development --slice-arguments`
and repeat with `--profile release`. The selection has 14 native groups: four
new batch groups, seven shared-registry and three subslice VM groups. It runs 252
tool-free CLI invocations: 120 existing alias, 124 subslice and eight sentinels.
Both profiles passed with 322 matching source/test/tool input hashes.

Coverage includes duplicate/mixed/empty arguments, all six scalar types, maximum
4096-element ranges, eight arguments at full capacity, an invalid future ticket,
late and partial-capacity failures, unchanged metadata/generations/payload,
parent-before-batch close, stale copied batches, duplicate/noncanonical cleanup,
short backing and honest source parameter/result rejection.
The [Windows evidence](../evidence/m2-array-slice-arguments-windows-20261031.json)
records matching profile inputs, compiler/SDK identities, native reports, CLI
matrix receipt hashes and retained executable hashes.

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing benchmarks are outside this selection.
