# Bounded compiler heap reservations

The private `module_budgeted_compile` API now guards the actual ordinary, input,
output and input-output compilers with separate working and combined heap limits.
It delegates to the existing source lowering and independent verifier. Existing
standalone compiler APIs retain their previous behavior. The
[owning Engine successor](runtime-engine-compile-memory.md) now adopts this API
and additionally accounts for the selected Index and incoming Entry backing.

## Working bound

For the current pinned SDK and Windows AMD64 profile, lowering allocates legacy
`array_list_cells` vectors and three private evaluation scratch vector kinds.
Source collection, literal Builder, IR, function/type tables and source duplication
still use inline storage. This bound excludes native stack frames.

Each already-pushed cell in every simultaneously live vector, plus the cell
whose push may allocate, corresponds to a different original source byte. A
parent's completed cells precede the expression currently parsing its child.
Child scratch returns and is dropped before the parent pushes its result. CALL
emits instructions rather than recursively compiling the callee's body; bodies
are compiled sequentially. Loop-post and grouped-destination reparsing happens
after earlier temporary vectors have been dropped. The combined source contains
at most 4,096 bytes, so this cell count N is at most 4,096.

SDK vector storage begins at eight elements and doubles capacity. Initial
allocation needs at most eight slots per cell. While growing a full n-slot
vector, old and replacement allocations coexist: `3*n <= 8*(n+1)`. Other live
vectors obey the same bound. With eight-byte usize:

`legacy cell heap <= 8 slots * 8 bytes * N <= 262,144 bytes`.

Bank, expression State and conditional State each use a separate SDK vector with
one initialized element. First capacity is eight slots; these vectors never grow.
The expression and structure guards are each 32. Including roots and the rejected
boundary, the conservative per-kind owner bound is
`2 * ((32 + 2) + (32 + 2)) = 136`. Idle uncaptured conditional roots may reuse
their parent's Bank, but this proof takes no credit for that reduction.

| Scratch kind | Reviewed emitted bytes | Reserved bytes per slot |
| --- | ---: | ---: |
| Bank | 37,792 | 40,000 |
| Expression State | 5,736 | 6,000 |
| Conditional State | 14,720 | 15,000 |

The transport reviewer discovers these private types structurally and checks
their emitted widths against the slot caps. Native Engine verification repeats
the checks and emits C static assertions; numerical type IDs are not trusted.

`working heap <= 262,144 + 136 * 8 * (40,000 + 6,000 + 15,000) = 66,630,144 bytes`.

This is a deliberately conservative reservation, not a measured physical peak.
It includes old/new growth overlap. The cell proof uses source-byte ownership; the
scratch proof uses the existing guarded nesting limits. Review both when source
limits, scratch layouts, lowering allocation sites or SDK vector policy change.

The later [aggregate CALL/copy continuations](../evidence/compiler-aggregate-call-copy-windows-20261113.json)
reuse the existing CALL State and add only inline scalar copy state and borrowed
staging spans. They add no SDK heap class or change to this reservation.

## Allocation barrier and observations

`compile_memory::Plan` reserves work before delegation. The wrapper copies the
trusted `retention_plan::Plan`, narrowing its available persistent allowance to
the remaining combined limit. It checks `fixed <= narrowed limit` before calling
the existing admission routine, which relies on that subtraction invariant.
The original Plan's configured fixed cost and ceiling are preserved.

The original compiler checks exact fixed backing plus deduplicated literal
payload before image/Stored allocation. All lowering scratch has been destroyed
by then. Work and retention therefore use `max(working, persistent)` rather than
their sum. The wrapper records an admitted retention reservation even if a later
allocation or verifier fails. Success finishes with the persistent observation;
failure aborts to the external baseline while preserving the reservation peak.
Quota is private diagnostic kind 21; SDK OOM remains kind 15.

Zero fixed backing is rejected. The positive fixed backing must come from
trusted layout facts or a conservative upper bound; the scalar Plan is not an untrusted guest metadata format. A reused Plan
is rejected. Its observation is not an owning lifetime ledger: Program release
and Engine publication need the existing owning Engine ledger.

## Scope and verification

The caller's prebuilt Index and the Engine's incoming Entry vector are outside
this standalone API's working reservation. The owning Engine adapter now includes
those classes, fixed control and prior retained Programs in its baseline. Native stack, allocation
headers, CRT fragmentation and process RSS are not covered. Instance/output/host
accounting, complete aggregate quotas and bounded work remain open.

The focused native suite is:

```text
python tools/verify-module-output-execution.py --suite compile-memory
```

The latest staged-evaluation checkpoint passes 28 groups per development/O2
profile: seven scalar reservation groups, six real compiler/allocator groups,
13 Engine scalar accounting groups, the staged CALL operand kernel and the
captured-call depth regression. The wrapper accepts depth 32 and rejects 33;
real compiler groups assert zero SDK live blocks/bytes after owner cleanup.
The earlier fourteen-group results remain historical evidence.

The suite uses the pinned compiler/runtime, instrumented SDK allocations, isolated test
processes, development/O2 and the unchanged combined captured-call depth 32/33
fixture under default 1MiB/4KiB stack settings. See the recorded
[original evidence](../evidence/compile-memory-windows-20261107.json) and
[staged-evaluation evidence](../evidence/compiler-evaluation-source-windows-20261113.json)
for executed groups, input identities and outcomes. The latter also records
Engine integration with test-only compiler-allocation scope instrumentation.
No public gate, VM capacity, opcode or Fuel price changes.

The later [argument/dependency checkpoint](../evidence/compiler-argument-returned-dependencies-windows-20261113.json)
adds only inline source continuations. Existing SDK scratch widths, slot caps and
the 66,630,144-byte lowering reservation remain unchanged. Focused acquisition
and dependency development/O2 checks plus final owning Engine integration cover
that change; the standalone 28-group memory selection was not rerun for it.

The [record/copy metadata checkpoint](compiler-record-copy-metadata.md) reuses
existing bounded layout/flattening work with inline source cursors. It adds no
SDK heap class, Bank/Pratt field or working reservation. Its evidence records
focused source/copy checks and final owning Engine allocator/compile fixtures;
the standalone 28-group memory gate was not rerun.

The [assignment destination checkpoint](compiler-destination-context.md) adds two
inline States, reusing existing metadata and nominal range/copy cursors without
new SDK heap classes or Bank/Pratt fields. Working reservations and scratch slot
caps are unchanged. Its evidence records final owning Engine allocator/compile
fixtures; it does not rerun the standalone 28-group memory gate.

The [declaration header checkpoint](compiler-declaration-header.md) adds inline
binder/header cursors and a small scalar result. Existing SDK heap classes,
Semantic/Bank/Pratt fields, scratch slot caps and working reservations remain
unchanged. Its evidence retains final owning Engine allocator/compile fixtures;
the standalone 28-group memory gate was not rerun.

The [typed/value traversal checkpoint](compiler-typed-source-walk.md) adds inline
private source cursors without SDK heap classes, binding/Bank/Pratt/Semantic
fields or scratch/working reservation changes. Its changed modules are outside
the owning Engine closure. All 367 Engine inputs and the complete closure match
the earlier passed receipt, so that evidence is reused; this is not a new
allocator or physical peak measurement for the value source compiler.

The [typed/value evaluation checkpoint](compiler-typed-evaluation.md) adds inline
authentication/capture/operand/CALL/constructor cursors and a private property
adapter. Intrinsic expression modes share inactive token/type scratch and keep
three suspended control States instead of multiple host frames; actual recursive
operands retain their depth checks. No SDK heap class, ledger/Bank/Pratt/Semantic
field, scratch slot cap or working reservation changes. Default-stack CALL 32/33
fixtures pass after four recorded incomplete attempts; this is not a measured
physical peak or performance result. The unchanged complete owning Engine closure
and all 367 inputs reuse prior evidence, not a new typed/value allocator measure.
The standalone memory gate was not rerun.

The [typed Buffer/view checkpoint](compiler-typed-buffer-view.md) uses inline
operand/effect/copy States and existing snapshot storage. Staged special operands
share inactive lexer/type scratch; raw scalar routing and namespace dispatch
avoid retaining unrelated frames. Actual special CALL32/33 passes on default
stacks; pre-correction assembly does not measure a final physical peak. Ledger,
Bank/Pratt/Semantic fields, SDK heap classes, scratch caps and working reservations
are unchanged. Complete Engine closure and all 367 input hashes match prior
passed evidence; this is not a new typed allocator measurement. Standalone memory
was not rerun.
