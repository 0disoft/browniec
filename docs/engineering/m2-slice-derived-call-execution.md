# Private derived CALL execution

This slice adds one native-only path for executing a CALL whose exclusive slice
argument originates from an authenticated reborrow child. The checked execution
entry is `vm_reborrow_execution::execute_derived`; `inspect_derived` also exposes
its static admission separately. The shared execution loop reaches the
new handoff through `call_frame_vm::step_canonical_derived`. These are native
implementation symbols used by the existing shared loop; they do not promote a
language feature, source syntax, CLI mode or public API.

The earlier [native loan handoff](./m2-slice-reborrow-call-vm.md) established
the CALL-side receipt, writer rotation, shared-reader retention and return
restoration. This slice connects that handoff to complete guest execution.
CALLs without a statically derived exclusive source retain the existing
owned/aggregate transaction. The new derived path accepts borrowed and scalar arguments
with a scalar result only.

## Admission and dispatch

`inspect_derived` is an explicit native opt-in. It first runs
`verifier::inspect_reborrow_calls` over the immutable program and builds the
existing `slice_reborrow_ir::Sites`. It then walks every CALL, evaluates the
existing canonical CALL price, and classifies whether that CALL needs the new
derived transaction. A derived CALL is rejected if it has an owned argument,
an array result or a record result. The full static proof and this derived
subset check finish before a context is accepted, Fuel is spent or guest
dispatch begins.

`execute_derived` requires one fresh authority state, one CALL-binding map and
one child-site map. It validates that context before execution, runs the
existing shared VM core, and always routes the outcome through the combined
cleanup operation. The pre-existing `inspect` and `execute` entry points keep
their old verifier and do not admit a derived CALL.

At a guest CALL, the shared loop first computes the existing canonical CALL
price and runs `call_frame_vm::prepare`. That scalar/control preflight:

1. validates the CALL descriptor, target signature and argument-site row;
2. checks the complete Fuel charge and caller frame bound;
3. checks the caller/callee register windows and result destination;
4. copies only the checked scalar arguments into a fixed local plan; and
5. records the child return PC and destination without publishing them.

`step_canonical_derived` then classifies the CALL statically. If an exclusive
slice formal comes from a derived reborrow site, it calls
`slice_reborrow_call_vm::enter`. Otherwise it calls the existing
`slice_authority_call_vm::enter_owned`, so ordinary owned, shared, scalar and
aggregate-result CALLs keep their current transaction. A mixed CALL that needs
the derived transaction cannot smuggle an owned copy or aggregate result
through the shared loop.

The derived admission order is deliberate:

1. revalidate the CALL descriptor and reject owned or aggregate signatures;
2. compute the complete canonical CALL price and reject short Fuel;
3. authenticate the canonical receipt stack, child bindings, frame, live
   sources, roots, ranges, tags, tickets and generations;
4. reject a CALL frame or combined stack entry at the existing bound and
   require fresh callee tickets, owner cells and origins;
5. resolve every original argument before staging any retention or rotation;
6. stage retained readers and writer rotation in a local pool and unpublished
   authority entry; and
7. publish the authority entry, local pool, CALL-map PC, writer tickets,
   retained-reader tickets and callee origins only after every fallible step
   has succeeded.

The scalar argument and return-PC/destination writes happen after that handoff.
Consequently a CALL descriptor, Fuel, depth, stale-map, source, ticket, owner,
pool or generation failure leaves the caller's scalar registers, return arrays,
authority stack, both metadata maps, pool and payload unchanged. Publication
itself contains no failure point.

## Existing logical prices

No logical price changes in this slice. The canonical CALL charge is

`1 + arity + owned-copy cost + slice-retention cost`.

The slice-retention term is zero when the CALL has no slice formals. Otherwise
it is

`65,537 * (1 + R + 2 * W)`,

where `R` is the number of readonly slice arguments and `W` is the number of
exclusive slice arguments. The derived path has no owned copies, so its
owned-copy cost is zero, but the shared loop still charges the same complete
canonical price exactly once before dispatch. Ordinary CALLs retain the existing
array/record copy component.

The borrowed operations invoked by the executed guest program retain these
existing prices:

| Operation | Logical Fuel price |
| --- | ---: |
| open an exclusive slice | 65,537 |
| begin or end a derived reborrow | 65,537 each |
| directly close or release a slice | 4,097 |
| obtain slice length | 4,097 |
| UTF-8 predicate over the selected range | 4,097 + 4 * root length |
| scalar read | 4,130 + element stride |
| scalar write | 4,130 + 2 * element stride |

The UTF-8 predicate scans the selected range but conservatively prices the
root length retained in the authenticated View. Each operation checks its own
complete price before changing guest state.
The derived CALL integration adds no second dispatch charge, receipt charge or
cleanup multiplier.

## Return and cleanup

On an ordinary scalar return, the shared loop authenticates and restores the
active CALL. Readonly child handles are staged for cleanup from the highest
site slot to the lowest. The existing handoff restore then rotates exclusive
writer tickets in reverse argument order, restores the exact caller tickets and
views, and only afterward publishes the staged pool changes and clears the
callee maps. A pending child, wrong root, stale ticket, range mismatch or
generation mismatch fails before any staged restoration becomes visible.

Invocation abort and raw-core failure use the same combined drain transaction.
The pool and owner table are staged, live slots are closed from slot 15 down to
slot 0, and metadata is committed only after the whole drain succeeds. The
original guest outcome is saved first. If execution already failed and cleanup
succeeds, cleanup returns that original error; if execution succeeded, it
returns the original scalar value. If drain itself fails, its error is returned
and the receipt, pool, tickets, origins and maps remain available for a retry.

Cleanup never rolls back guest payload writes or earlier statements. Prior
writes survive both a successful drain and failed guest execution. External
effects remain outside the VM rollback boundary. Loan cleanup does not dispose
owned array/record storage or the backing buffer; those remain the native
caller's responsibility.

## Fixed frames and closed gates

Guest recursion runs through the existing fixed frame array rather than native
recursion. The core has 32 frame slots with 128 registers each, fixed return-PC,
return-destination and function arrays, 16 program functions, 256
instructions, 16 slice sites, 16 pool slots and at most eight arguments. A CALL is
rejected at the existing frame bound; the canonical stack also rejects entry
when it already has 31 combined CALL/child entries. These bounds
apply to ordinary and derived execution alike.

The pre-existing native wrapper, public verification and legacy execution
remain closed to this shape. Public source compilation does not accept
the private reborrow opcodes or derived CALL signature. Legacy dispatch has no
canonical authority map and therefore continues through the old readonly or
mutable CALL steps. Opcodes 61 and 62 still require the single native canonical
map and are not exposed by the compiler or CLI. The new native entry points add
no opcode, Program field, source grammar, capability, public execution mode,
payload copy or persistent receipt.

## Verification status

Implemented at `cce170a`. The explicit native verification commands were:

```text
python -B tools/verify-m2-slice-elements.py --profile development --derived-execution
python -B tools/verify-m2-slice-elements.py --profile release --derived-execution
python -B tools/verify-m2-slice-elements.py --profile release --derived-execution-phase regression
```

Development passed 8 new native groups from
[slice_derived_call_execution.fy](../../tests/m2/slice_derived_call_execution.fy).
Release passed those 8 groups plus 10 regression groups: four from
`call_frame_vm` and six from `slice_reborrow_execution`, for 18 groups total.
Release also passed all 74 public mutable-parameter CLI cases. The tests cover
owned-root and formal-derived calls across the six scalar edge tags, recursive
scalar counters and combined depth, mixed shared and multiple-writer calls,
ordinary owned CALL coexistence, bounds/arithmetic/Fuel failure cleanup, exact
execution Fuel, preflight publication boundaries, and retryable raw-core
cleanup.

All 402 current input hashes and the compiler, retained CLI and native receipt
identities were verified. Core manifests differ from the final regression/CLI
manifests only in `tools/verify-m2-slice-elements.py`: the initial 30-group
existing regression selection was narrowed to 10 directly affected groups after
one 30-group batch exceeded the verifier's 600-second deadline. That attempt has
no completed assertion verdict and is never counted as a pass. Production, test,
lockfile and compiler inputs are identical across the completed phases.

Four production sources changed: `call_frame_vm` imports and a new helper,
`slice_reborrow_call_vm` appends a classifier, `vm_execution` adds dispatch,
and `vm_reborrow_execution` adds the opt-in entry and private run path. The
other 94 production sources are unchanged under Git LF normalization. The
existing call-frame and handoff bodies are unchanged except for two imports in
`call_frame_vm`.

Native cleanup preserves guest writes and the original outcome, or retryable
metadata when cleanup fails. Owned storage and backing disposal remain the
caller's responsibility. The next deliberate step is promotion through
existing/default checked admission. Owned derived arguments, aggregate results
and guest/public promotion remain gaps.

No full native, other M2, full M1, Linux, isolation, packaging, allocator,
native-size/stack or timing rerun was performed. This work is local only; no
push was made.

[See evidence for executed scope](../evidence/m2-derived-call-execution-windows-20261103.json).
