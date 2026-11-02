# Private canonical reborrow shared-core execution

`vm_reborrow_execution` admits a bounded native-only execution mode over the
existing `vm_execution::core`. Scalar arithmetic, branches, tagged values,
register/control arrays, owned operations and the outer dispatch loop are shared
with legacy execution. It wires the previously verified
[formal/data adapter](m2-slice-formal-reborrow-vm.md) into real instruction order,
CALL scalar/control publication, normal returns and invocation cleanup.

Public verifier/VM/CLI and both existing execution entries retain their op61/62
rejection. No guest syntax or capability is promoted. The native wrapper accepts
an immutable Program and caller-owned arrays, payload, loans, shared origins,
one canonical authority, one CALL map and one child-site map. It does not allocate
payload backing or introduce external bytecode loading. Native callers provide
appropriate backing/quota and dispose their owned roots/backing after use.

## Admission and supported mode

Before execution, the wrapper runs the complete independent IR/flow inspection,
derives Sites from that same immutable Program and checks its private subset.
All declared slices must be exclusive; aggregate results are rejected. Every
CALL must satisfy canonical scalar/exclusive-formal admission, including at least
one writer. Scalar-only, shared/owned-argument, aggregate-return, derived-source
and suspended CALLs remain outside this mode. Existing independent inspection
continues to reject CALL while any lexical parent is suspended.

The three invocation slices must each contain exactly one unique fresh state.
`slice_reborrow_context::ready` checks the empty canonical stack and every CALL,
detached, child, loan and shared-origin binding plus inactive pool slots. Dirty
maps are rejected without draining or clearing a different active invocation.
Rejection during admission has no execution effect. Once admitted, every outcome
passes through the same combined finish, including Fuel, bounds and arithmetic
errors. Owned resources and capacity are still enforced by their native helpers.

The raw `execution::execute_canonical` entry retains the same native trust boundary
as existing raw execution: its caller must inspect immutable IR/Sites, enforce
this subset and fresh state, and finish every outcome. The wrapper provides those
steps. It is not another public source/CLI entry.

## Shared dispatch and atomic control publication

Private begin/end dispatch occurs before the generic record-opcode branch.
Available exclusive length/read/write/u8 UTF-8 use the canonical data adapter;
rootless close uses canonical formal release. Owned root open/close keep existing
owned dispatch. Metadata/flow inspection prevents a derived close from replacing
its required op62 restoration. Existing readonly/legacy dispatch remains selected
when the canonical invocation views are empty.

`call_frame_vm::step_canonical` reuses the existing scalar/control `prepare` and
`publish` functions. It checks price, depth, spans, scalar argument types and return
destination before canonical authority mutation. Canonical handoff is the last
fallible step; only then are child scalar registers and return controls published.
The core advances function/frame/PC afterward, exactly as for legacy calls.
Normal scalar return authenticates/restores the canonical CALL before publishing
the scalar to its caller. Source-lowered owned cleanup must already have happened;
canonical return rejects unexpected remaining owned/loan bindings. Main-frame
owned cleanup retains the existing lifecycle rules.

The authority stack remains the sole owner of Batch/Loan receipts. Existing
CALL/site maps stay separate mutable roots to satisfy Fairy C borrowing; no
aggregate with aliased mutable member parameters or duplicate receipt collection
is introduced. Guest recursion remains in 32 fixed VM frames, not native recursion.
Lexical operations use the same combined 31-event bound and generation reserve
as their directly verified adapters. All existing logical instruction/CALL prices
and the public CLI's one-million Fuel cap remain unchanged.

## Cleanup and storage boundaries

Combined finish drains the authentic pool before clearing canonical receipts,
CALL/detached/site maps, invocation tickets and shared origins. Success preserves
earlier writes and the exact success/error; failed cleanup overrides the outcome
and retains diagnostic metadata. The wrapper never replays effects. Tests also
exercise the raw boundary by injecting a native session mismatch between core
failure and finish, proving failed cleanup preservation and a successful native
repair/drain. Guest code cannot inject that native mutation.

No Program, signature, owner, pool-slot, shared-frame or existing map field grows.
The canonical caller supplies the existing authority and maps once. Legacy
wrappers now pass empty views over one inert authority value, one CALL-map value
and one child-map value; canonical execution instead supplies one inert legacy
Frame for its empty legacy view. These fixed backing values are required by the
current typed-view construction and are additional local storage, not a claim
of unchanged native memory use. No new heap allocation is added by this wiring.
Native stack size, allocator behavior and performance are unmeasured.

## Verification and next work

```text
python -B tools/verify-m2-slice-elements.py --profile development --reborrow-execution
python -B tools/verify-m2-slice-elements.py --profile release --reborrow-execution
```

The focused selection runs six new execution groups, four existing CALL/control
groups and six legacy mutable-execution groups. It also runs 74 mutable parameter,
222 owned mutable, 192 readonly scalar and 2007 M1 CLI cases. New groups exercise
all six scalar tags with actual child and restored-caller reads/writes, owned
reborrow, bounded recursive counters/frame reuse, Fuel/bounds/arithmetic failure,
atomic scalar/control admission, mandatory finish, dirty state/unsupported modes,
legacy gates and native cleanup failure preservation. Direct adapter evidence
for mixed depth31 remains in the preceding contract; do not relabel it as a new
full-program mixed-depth measurement. Deep native runs use their own sufficient
budgets, not the unchanged public CLI allowance.

Next is extending canonical coordination to remaining CALL shapes, especially
zero-writer/scalar-only frames, while retaining exact ownership and prices.
Suspended/derived CALL proof, guest grammar and public promotion remain separate.
Full native, other M2, Linux, M0, isolation, packaging, native stack/allocator and
performance are outside this selection. No push, publication, release or deployment.

Implemented at `94d73bd`. Development and release each passed all 16 selected
native groups and 2,495 CLI cases, with 388 matching current input hashes.
Compiler, retained CLI, original receipt and matrix/M1 identities were rechecked.
Program/signature and existing map declarations, native authority/loan/owner/pool
primitives, formal/owned reborrow and canonical CALL adapters, verifier, compiler
and public VM/CLI sources match `7b899d1`. Existing scalar/control preflight and
publication bodies also match that baseline; only a new canonical CALL entry is
appended to that module. Shared-core dispatch changes are described above.
Both profiles accept parser depth32 in check/run and reject depths33/64 with
`compile_limit`. See the
[Windows evidence](../evidence/m2-slice-reborrow-execution-windows-20261102.json).
Local commits only; no push, publication, packaged release or deployment.
