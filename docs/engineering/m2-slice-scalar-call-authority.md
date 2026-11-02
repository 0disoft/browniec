# Private scalar-only canonical CALL coordination

The private canonical execution mode now admits scalar-only CALLs alongside
scalar/exclusive-formal CALLs. It uses the existing shared scalar/control loop,
CALL preflight/publication, authority stack and return/abort paths from the
[shared-core integration](m2-slice-reborrow-execution.md). Public scalar CALLs
already worked through their legacy path; this extends the private coordinator.
No guest reborrow capability, source syntax or public execution gate is promoted.

## Price, receipts and maps

A scalar-only CALL costs exactly `1 + arity`, matching existing scalar CALLs.
A scalar/exclusive CALL retains `1 + arity + 65537*(1 + 2*writers)`. There is no
new price, opcode, state field, owner session, receipt collection or heap allocation.
Scalar/control admission still validates immutable operands, Fuel, spans, depth,
argument types and return destination before publication.

Each scalar-only CALL adds one native empty Batch event to the same authority
stack. Its count and reserve column remain zero, but both VM frame depth and
combined pending restoration depth advance. Enter/return leave all pool views,
sessions and ticket generations unchanged. Later writer admissions continue to
reserve conservatively against the complete pending depth, including empty
ancestors. Existing native authority/handoff algorithms are unchanged.

The existing CALL PC map is populated even for zero-writer admissions. Inspection
validates every mapped CALL against its immutable scalar/formal positions, count
and empty child origin cells. Every detached cell for a scalar-only CALL must be
absent. Return requires the current top CALL, exact mapped target, no unexpected
child tickets or owned values, and a valid empty native receipt. Only successful
restoration clears the PC and child maps, then the shared core publishes the
scalar return/control state. A bad PC or detached binding cannot pop the frame.

Native callers may still create unmapped empty events for the older direct
protocol. Inspection retains that compatibility; a canonical adapter return
always needs its real mapped PC and target. Removing a mapped PC therefore fails
return even though a native unmapped event can remain structurally inspectable.
Do not treat arbitrary native state mutation as guest authority.

## Interleaving, execution and failure

Scalar helpers can run while an outer mutable formal remains available. The
outer caller binding/session stays held and is not transferred to the helper.
The current frame/function checks prevent the helper from accessing its caller's
sites. After return, that same current ticket remains available to the caller.
The scalar helper can instead create its own owned local root, execute private
reborrow instructions, restore/close/drop it and return through its empty Batch.
Existing source-lowered owned cleanup must finish before return.

Scalar, tagged and recursive execution continue to use the shared core and its
32 fixed frames. Empty and writer events share the 31 pending-event limit;
reusing a frame clears its map first. Native CALL/control admission retains its
atomic failure behavior. Both automatic admitted-outcome finish and explicit
raw-core finish use the existing combined drain. Earlier payload writes and the
original result/error survive successful cleanup. Failed cleanup retains empty
and nonempty CALL records together for diagnosis and overrides the outcome.
No hidden effect replay or cleanup retry is added.

Shared/owned arguments, aggregate results, suspended/derived CALL admission and
guest/public reborrow promotion remain gated. Independent IR inspection still
rejects every CALL while a lexical parent is suspended. Existing public VM/CLI,
compiler, verifier, core, scalar/control helper bodies and primitive algorithms
are unchanged. The prior inert-view backing and unmeasured native stack/allocator/
performance limitations continue to apply; this change adds no further backing.

## Verification and next step

```text
python -B tools/verify-m2-slice-elements.py --profile development --scalar-call-authority
python -B tools/verify-m2-slice-elements.py --profile release --scalar-call-authority
```

The focused selection runs six new scalar-CALL, six existing canonical-CALL and
six shared reborrow-execution groups. New cases cover zero and eight arguments,
all scalar tags and tagged values/results, exact/one-short CALL price and short
control spans, unchanged unrelated live pool/tickets, corrupt return maps,
scalar/mutable interleaving, recursive counters/frame reuse, 30 empty CALLs before
a writer at frame31 and next-frame rejection, owned reborrow inside a scalar
callee, and empty/nonempty abort preservation and cleanup failure. Native deep
runs use sufficient budgets; they do not expand the public CLI allowance.

Public regression covers 74 mutable parameter, 222 owned mutable, 192 readonly
scalar and 2007 M1 CLI cases. Full native, other M2, Linux, M0, isolation,
packaging, native size/stack, allocator and timing are outside the selection.
Next is canonical coordination for remaining shared/owned argument and result
shapes before deliberate suspended CALL proof and guest/public promotion.
No push, publication, packaged release or deployment.

Implemented at `c1b2c0c`. Development and release each passed all 18 selected
native groups and 2,495 CLI cases, with 389 matching current input hashes.
Compiler, retained CLI, original receipt and matrix/M1 identities were rechecked.
Program/signature/map declarations, native authority/handoff/reborrow/owner/pool
primitives, compiler, verifier, public VM/CLI, shared core/control and invocation
admission/cleanup sources match `e960ec0`. Only canonical CALL shape/price/mapped
inspection admission changes; the prior execution test now expects Fuel rather
than unsupported-shape failure for a zero-budget scalar CALL program.
Both profiles accept parser depth32 in check/run and reject depths33/64 with
`compile_limit`. See the
[Windows evidence](../evidence/m2-slice-scalar-call-authority-windows-20261102.json).
Local commits only; no push, publication, packaged release or deployment.
