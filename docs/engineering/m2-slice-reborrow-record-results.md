# Record results from derived slice CALLs

Implemented at `e8105f6`, extending derived array results and owned arguments
to exact-nominal record results. See the [example](../../examples/mutable-slice-record-result.brc).

## Source contract

A function receiving an exclusive reborrow child may return a record, including
nested records with any of the six scalar field types. Existing owned arrays,
records, readonly slices, independent mutable children and scalar arguments may
be mixed. Returning an owned parameter or its record child, forwarding through
formals, recursion, root assignment and child-path assignment use existing
lowering. A returned record and the resumed child are both available after CALL;
lexical child cleanup later restores its parent.

```text
let ref mut i32[] child = ref mut parent[1..];
let Answer result = update(ref mut child, input);
```

Version JSON adds `array_slice_reborrow_record_results: true`. Existing grammar,
profiles, nominal type checks and layout bounds are unchanged. Independent proof
still rejects duplicate mutable arguments and suspended-parent access, including
in unreachable functions. A same-layout record with a different nominal type
cannot satisfy the result signature.

## Admission and return

After the full existing CALL charge is prepaid, derived admission requires both
slot and generation of `record_state.tokens[frame * 16 + destination]` to be zero.
A live record, slot-only token or generation-only token fails before loan staging,
argument copying or authority/control publication. CALL descriptor checks prove
the encoded destination and nominal shape before indexing. Existing scalar/control
preflight, source authentication and atomic argument copying retain their order.
The shared admission hook no longer restricts independently proved result shapes.

The unchanged shared VM dispatches SRET through
`slice_authority_call_vm::return_record`. It authenticates the mapped CALL and
uses `struct_result_vm::prepare` to check the exact nominal result, unique live
owner, canonical payload, empty caller destination and absence of other callee
owners. Canonical restoration resumes the caller child before the infallible
publication clears the callee token and installs the same token in the caller.
Restoration failure preserves the result and diagnostic state.

No second persistent result extent or payload snapshot is introduced. Existing
bounded validation scratch remains. SRET still costs 42,113 Fuel; CALL prices,
persistent layouts, quota/site/frame/depth limits, cleanup, allocator and shared
VM dispatch bodies are unchanged. Earlier guest writes survive later failure;
there is no automatic replay or external-effect rollback.

## Verification

Development and release each passed **20 native groups and 282 CLI cases**.
The CLI total is 50 record-result, 44 array-result, 46 owned-argument, 68 lexical
reborrow and 74 mutable-parameter cases. Native coverage comprises five new
record-result source groups, five array-result groups, four admission/atomicity
groups, two updated source-admission groups and four existing record-authority
groups. All 445 final input hashes match across profiles. Compiler, retained CLI,
native reports and receipt hashes were rechecked. Only the shared derived guard,
derived CALL preparation and version JSON change production; 97 other sources
match `f8642ea` under Git LF normalization. See the
[Windows evidence](../evidence/m2-derived-record-result-windows-20261103.json).

An initial native attempt failed with test stack overflow and is not counted.
Final development native results followed the fixture-selector fix. They are
reused after a CLI-only Fuel expectation correction and lighter CLI fixtures;
every native source and compiler hash is unchanged. Original inputs and reuse
provenance are retained. Final CLI matrices and release native groups ran after
the harness change. Development started with uncommitted implementation inputs;
each final input is bound to `e8105f6` under Git LF normalization.

The selected Windows matrices cover record results, array results, owned
arguments, lexical reborrows and mutable parameters. Native
admission tests compare payload, owners, tokens, tickets, authority receipts,
maps, origins, scalar registers and return controls before and after failure.
Existing result-authority tests cover invalid result/CALL authentication, late
restoration failure followed by one successful move, destination/control/Fuel
checks and abort after transfer. The test fixture selector lives in a separate
function to avoid overlapping large IR temporaries in the native test frame.

Native source fixtures use 16M Fuel and 256-byte backing; the CLI uses its existing
1M Fuel cap and 64KiB backing. Recursion and allocation boundary expectations
reflect those budgets. The larger nested mixed-record, recursive and repeated
root-assignment fixtures reach the public Fuel cap; lighter mixed-record and
repeated-result fixtures complete within it. CLI cases run with a cleared
environment and tool-free PATH. Full native suites, full M1, other M2, Linux, isolation, packaging,
allocator, native size/stack and timing are not part of this focused verification.
No performance claim is made.

Escaping borrows and inline temporary CALL borrows remain outside this slice.
The [whole-array argument successor](m2-array-borrow-arguments.md) now permits
call-scoped borrows of existing whole-array names; inline ranges and temporary
roots remain unsupported.
There is no external bytecode loader, runtime code cache, JIT or guest GC.
Local work only; no push, release or deployment.
