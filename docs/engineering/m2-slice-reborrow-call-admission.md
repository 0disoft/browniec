# Private native admission for CALLs with derived reborrow sources

The subsequent [native handoff protocol](m2-slice-reborrow-call-vm.md) consumes
this preparation internally and adds coordinated publication, return and abort.
This document still describes the standalone preparation API, which exposes no
publish operation; callers must not activate its plan outside that protocol.

`slice_reborrow_call_admission::prepare` builds a private, single-use `Prepared`
value for a CALL whose exclusive source is a live, checked reborrow child. This
is native preparation only: it does not execute or publish a CALL, restore a
source, or enable a public path. It requires an immutable Program and matching Sites
approved by `verifier::inspect_reborrow_calls`; it does not repeat that proof.
The trusted native staging value holds one copied `slices::Pool`, one unpublished
`authority::Entry`, retained shared `slices::Arguments`, up to eight roots, and
the original `pc`, `frame`, combined receipt `depth`, and remaining Fuel. The
canonical authority stack alone owns persistent receipts. The prepared entry
remains outside it; no receipt or map is cloned.

## Admission order

1. `slice_authority_call_vm::info` validates the CALL descriptor, caller, target,
   arguments, and signature. Owned arguments and owned or aggregate results are
   rejected, leaving borrowed/scalar arguments and scalar results only.
2. `slice_authority_call_vm::cost` computes the complete existing CALL price.
   That price must be prepaid before any runtime source authentication.
3. `slice_formal_reborrow_vm::checked` validates the whole canonical receipt
   stack and every child map. It includes `slice_authority_call_vm::inspect`, so scalar-only calls also
   authenticate the CALL receipts and child maps. Admission requires
   `frame < 31` and combined receipt `depth < 31`, with matching authority frame.
4. The callee frame must be fresh: all sixteen loan tickets and array/record
   tokens, plus all eight shared origins, must be empty.
5. Every source authenticates against canonical child maps and live tickets.
   Exclusive sources use `slice_formal_reborrow_vm::view` for forest identity,
   parent range, write session, generation, and root; shared sources match the
   declared element. All arguments validate before retention or rotation.
6. A local pool copy is made. `array_slices::borrow_arguments` stages retained
   shared arguments there. `authority::prepare_call` checks unchanged authority
   state and stages exclusive write rotation in the same copy. Generation
   headroom uses combined receipt depth, not frame depth alone.
7. Only if both staging operations succeed does `prepare` return `Prepared`.
   The module exposes no publish operation and performs no callback.

Fallible source checks use original state. A late retention or rotation failure discards
the local copy. On success or failure, the original invocation, owner state, payload,
CALL map, child-site map, and pool stay unchanged; only `Prepared`'s pool changes.

Retained shared arguments remain independent of canonical receipts. Exclusive
rotation exists only in the unpublished `authority::Entry` and local pool; no
child ticket or origin is written. The staged value cannot authorize payload
access or a callee frame by itself.

## Closed execution boundary

There is no `publish` method and no VM dispatch. Passing `Prepared` to a VM,
using it as execution admission, or applying its local pool is prohibited. A
future handoff must first integrate derived-source CALL return authentication,
exact ticket-generation and range restoration, normal cleanup, abort cleanup,
and one reviewed publication transaction. Plans are trusted native, unpublished
staging only, with no callbacks or unrelated state changes.

Owned copying, aggregate arguments, and array or record results remain outside
this path. Callee binding cells remain empty; this step prepares handles only in
private staging and publishes none of them. Only the visibility of existing
`slice_authority_call_vm::info` and `slice_formal_reborrow_vm::checked` becomes
public; their bodies remain byte-identical.

Existing `verifier::inspect`, `verifier::verify`, checked canonical admission,
public/legacy gates, and dispatch remain unchanged, including rejection of this
unpublished shape. No Fuel price, Program or slice layout, opcode, capability, or
public grammar changes. No payload copy or payload snapshot, allocator claim, or measured
native size or timing is introduced.

## Verification

Implemented at `a4a1430`. Development and release core each passed all six
new native groups. Release also passed twelve existing helper regression groups:

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-call-admission --admission-phase core
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-call-admission --admission-phase core
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-call-admission --admission-phase regression
```

Core covers all six scalar tags with owned and formal roots, mixed retention/
rotation, short Fuel, late failure, forged receipts, dirty cells, combined
depth, generation reserves, and unchanged execution gates. Development
recorded 6 passed groups; release recorded 18. All 399 current input hashes and
compiler/native-receipt identities were rechecked. The two exported helper
bodies are unchanged from `27bdb90` after removing the added `pub`; 94 other
production sources match that baseline. No CLI runs in this increment. See
[Windows evidence](../evidence/m2-slice-reborrow-call-admission-windows-20261103.json).

## Future work

Later work must authenticate the derived source on return, restore exact ticket
generation and selection, add normal/abort cleanup, coordinate scalar/control
publication, and publish staged metadata transactionally. Owned arguments,
aggregate results, shared-core dispatch, verifier admission, guest syntax, and
public promotion remain separate gated slices. Selected release evidence is
recorded in this increment; the full native suite, other M2, Linux, isolation,
packaging, allocator, native size/stack, and timing/performance measurement
remain for later work.
