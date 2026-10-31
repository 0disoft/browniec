# M2 Private Mixed Borrowed/Owned Call Transaction

- Status: implemented at `6282245`; verified within the focused scopes below.
- Scope: CALL (9) admission for owned arrays/records together with borrowed
  u8 slices.
- Implementation: [mixed transaction](../../src/mixed_call_vm.fy),
  [borrowed plan](../../src/slice_call_vm.fy), and
  [owned copy step](../../src/struct_call_vm.fy).
- Related contract: [private borrowed-frame adapter](m2-array-slice-call-vm.md).
- Evidence: [Windows receipt](../evidence/m2-array-mixed-call-vm-windows-20261031.json).

`mixed_call_vm` is a private native boundary for a Program that has passed
independent flow inspection. The later [CALL frame adapter](m2-array-call-frame-vm.md)
connects it to executable dispatch; borrowed IR remains rejected by the executable gate. The source evaluator is
unchanged. This checkpoint does not enable a source capability, opcode, profile,
or CLI path.

## Charge

`mixed_call_vm::cost` requires both component prices and returns
`1 + p.arities[target] + owned.cost + borrowed.cost`. The `owned.cost` term
includes its existing array and record work; the `borrowed.cost` term is zero
without borrowed formals and otherwise includes the adapter's retention reserve.

`mixed_call_vm::step` validates the CALL site and signature, checks the whole
charge, checks the parent-frame bound, and only then begins frame or backing
work. The total is paid once, before `borrowed::prepare`, owned frame admission,
source resolution, scratch use, owner mutation, or payload writes. When the
borrowed price is zero, the operation delegates to the existing
`owned::step`; otherwise it passes `fuel - borrowed.cost` to that step so the
borrowed reserve is not charged again.

Malformed metadata reports kind 5 at the CALL source offset, insufficient Fuel
reports kind 8, and a parent frame at or beyond 31 reports kind 12. The charge is
not a per-argument, per-ticket, or post-publication debit.

## Unpublished plan

`borrowed::prepare` requires the destination child frame's sixteen ticket
entries and eight root bindings to be canonical empty. It validates each
borrowed source against the caller's function, frame, root token, range length,
and u8 element type. It then builds an invocation-local `Admission` containing
a bounded pool copy, at most eight prospective tickets, eight roots, and the
matching site and formal-position maps.

The plan does not snapshot a frame or any payload. Preparing it mutates only the
local staged pool; caller tickets, the live loan pool, owner sessions, child
frame bookkeeping, owned state, and backing bytes remain unpublished. The plan
is private and single-use. From prepare until publish, no other borrowed-slice
mutation, overlapping pool mutation, or conflicting child-frame mutation may
interleave. The type system does not enforce that caller sequencing requirement.

## Transaction order

1. Preflight the CALL metadata and the complete combined Fuel charge.
2. Build and validate the local borrowed plan without publishing it.
3. Invoke `owned::step` to resolve and copy owned array and record arguments.
4. Publish the borrowed pool, child tickets, and root bindings only after owned
   copying succeeds.
5. Return the Fuel left by the owned step.

`owned::step` performs a failure-atomic copy at this synchronous boundary. It
validates the whole array/record batch, stages record scratch and owner metadata,
and finishes all fallible checks before payload writes. Child tokens are bound
only after the batch succeeds. On failure, no borrowed publish occurs, and the
owned transaction retains its original owner table, payload, and child slots.

After owned success, `borrowed::publish` is infallible and performs only table
and binding assignments. No fallible operation, payload write, register write, or
return-frame publication follows its first publication in this transaction.
Registers and return-frame state remain outside the mixed admission boundary.

## Failure atomicity

Synchronous failure atomicity means that returning an error from this private
operation leaves the call transaction's participating borrowed and owned state
unchanged: no partial plan, ticket batch, owner copy, or payload batch is
published. Earlier guest statements and unrelated native observers are not
rolled back.

This is not hardware, thread, process, signal, or crash atomicity. The plan is
not a lock or an atomic object. There is no cross-thread visibility guarantee,
memory-ordering guarantee, cancellation recovery, or rollback if a thread or
process stops between the owned writes and borrowed publication. Concurrent
access to the same loan pool, frames, owner table, or backing buffer is outside
the contract, and interleaving is prohibited.

## Storage and bounds

The plan stores only bounded metadata: the existing pool's fixed slots, eight
tickets, eight roots, and eight site/position pairs. No full payload or full
frame snapshot is created. No allocation is made to clone an argument payload;
owned record copying uses its existing fixed 1024-byte scratch path.

At most eight borrowed formals are planned. The existing 32-frame, eight-argument,
and owner/payload limits remain in force. This document makes no claim about
measured peak memory, allocation count, execution time, or latency.

## Pending integration

A [private dynamic slice adapter](m2-array-slice-frame-vm.md) now dispatches
borrowed instructions through frame origins. The executable VM does not yet
connect that dynamic instruction adapter. The [CALL frame successor](m2-array-call-frame-vm.md)
now resolves mixed admission from live CALL context and publishes scalar/return
state after success. Automatic normal/error frame cleanup remains pending, so
frame release is not part of this admission claim. Gate integration and guest
execution of borrowed source remain disabled.

## Focused verification

Development passed the new five-group `mixed_call_vm` file plus four
`slice_call_vm`, eight `struct_call_vm` and four `slice_arguments` groups: 21
native groups and 326 tool-free CLI invocations. The same combined release
native command timed out after 600 seconds without a report. That attempt is
neither a pass nor a reported assertion failure.

Release passed a narrowed nine-group native selection:
five mixed transaction and four borrowed-frame groups, plus the same 326 CLI
invocations. The eight owned-call and four registry-batch groups are omitted
from the release rerun to bound repeated compilation. The ignored release
harness copies the tracked harness and narrows only its native selection; its
exact source, SHA and command are archived in the evidence receipt. Both profiles
have 335 matching tracked source/test/tool input hashes and retained CLI hashes.
Restore the archived release harness source to its recorded path before using
the second command. The executed focused commands are:

```text
python -B tools/verify-m2-array-utf8-source.py --profile development --mixed-call-vm
python -B build/verify-mixed-call-release.py --profile release --mixed-call-vm
```

Full suites, other CLI matrices, M0, Linux, DLL embedding, isolation, packaging,
allocator instrumentation and timing were not rerun.
