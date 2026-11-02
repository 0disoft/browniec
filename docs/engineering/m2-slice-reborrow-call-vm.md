# Native derived CALL reborrow handoff

`slice_reborrow_call_vm::enter` is the native loan handoff for a synchronous CALL
that borrows checked, live reborrow sources. It consumes
`slice_reborrow_call_admission::prepare` synchronously in the same invocation.
There is no callback, external plan, returned prepared value, or separate publish
operation. The earlier admission note is historical; this document defines the
coherent native handoff without exposing standalone publication.

The immutable `Program` and its matching `slice_reborrow_ir::Sites` must already
have passed `verifier::inspect_reborrow_calls`. `enter` revalidates dynamic state;
it does not repeat the static proof or accept a changed invocation. Callers must
complete all fallible scalar/control/register preflight before `enter`, then
publish that state infallibly only after `enter` succeeds. The loan
adapter coordinates the existing CALL metadata only. It is not shared-core
dispatch, checked-canonical admission, or promotion of the public VM, legacy
path, compiler, or CLI gates.

## Prepare then publish

`prepare` performs every fallible loan step before loan publication. It:

1. validates the CALL descriptor and function signature, accepting borrowed and
   scalar signatures with scalar or tagged-cell results; owned arguments and
   array or record aggregate results remain rejected;
2. charges the complete existing CALL price and rejects short Fuel;
3. checks the canonical receipt stack, child maps, authority frame, combined
   depth, and the fresh callee frame;
4. authenticates every source root, selected range, ticket, mode, tag, and
   generation against the immutable Sites metadata; and
5. stages retained shared readers and exclusive writer rotation in a local pool,
   including generation headroom and the unpublished authority entry.

Only after `prepare` succeeds does `enter` call the infallible authority publish,
install that pool, record the CALL-map PC, move writer tickets, bind retained
reader tickets, and bind callee origins. Caller shared tickets remain unchanged.
Those writes are the publication transaction. Invalid CALL or
Fuel input, stale maps, tickets, roots, or views, a dirty callee frame, depth
exhaustion, shared retention failure, or writer-generation exhaustion therefore
leave the invocation, owners, payload, authority, pool, tickets, origins, CALL
map, child-site map, and PC state unchanged.

The callee uses the existing formal slice access and release operations. On
successful return, `slice_authority_call_vm::leave` restores the exact caller
child ticket and selected view before clearing callee metadata. Pending children,
stale or wrong-root bindings, and range/generation mismatches reject return
without partial restoration. If staged reader cleanup is followed by a writer
reserve failure, the original readers, owners, maps and payload remain intact.

Abort uses `slice_formal_reborrow_vm::finish` to drain loans and clear maps only
after cleanup succeeds. It preserves payload writes and the original outcome;
failed cleanup instead returns its error with diagnostic metadata retained.

## Rootless derived origin

`slice_authority_call_vm::origin` now resolves a rootless derived source through
its immutable formal anchor. It finds the canonical CALL write lease for that
anchor and checks that frame's origin binding and element tag. It does
not search the formal positions using the derived site as though that derived
site were itself a formal. The selected range and ticket are still authenticated
before payload access, return, and restoration.

This path adds no receipt owner, persistent field, payload copy, opcode, Fuel
price, or capability. It reuses the existing 32-frame, 31 combined-depth, 16-site,
eight-argument, pool, ticket, and authority bounds.

## Verification status

Implemented at `cf18d2d`. Windows validation passed development core 8 groups,
release core 8 groups, and release regression 12 groups: 6 prior admission groups
plus 6 `slice_authority_call_vm` groups. Native coverage includes the six scalar
edge tags through owned and formal descendants, shared and multiple writers,
repeated frame reuse, recursion through a callee lexical child, rejected
pending-child return, stale and wrong-root binding failures, late generation
return failure atomicity with retained-reader cleanup, abort preservation,
depth 31 with generation reserve headroom, and unchanged public/legacy gates.

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-call-vm --call-vm-phase core
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-call-vm --call-vm-phase core
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-call-vm --call-vm-phase regression
```

All 401 current input hashes, compiler identity and selected native receipts
were rechecked. The existing CALL module changes only its `origin` body; 96
other production sources match `edb9b0a`. Development passed 8 native groups;
release passed 20. See [Windows evidence](../evidence/m2-slice-reborrow-call-vm-windows-20261103.json).

No CLI, full native suite, other M2 suite, Linux, isolation, packaging, allocator,
native size/stack or timing check was rerun. Complete guest execution through the
shared scalar/control loop is the next integration; public promotion remains gated.
