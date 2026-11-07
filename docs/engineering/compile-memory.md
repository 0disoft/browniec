# Bounded compiler heap reservations

The private `module_budgeted_compile` API now guards the actual ordinary, input,
output and input-output compilers with separate working and combined heap limits.
It delegates to the existing source lowering and independent verifier. Existing
compiler APIs and the Engine's compilation path retain their previous behavior;
binding this API to Engine-wide reservations is the next integration step.

## Working bound

For the current pinned SDK and Windows AMD64 profile, lowering requests heap only
for `compiler::array_list_cells`'s `Vec<usize>`. Source collection, literal Builder,
IR, function/type tables and source duplication use inline storage. This bound
does not count their native stack frames.

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

`working heap <= 8 slots * 8 bytes * N <= 262,144 bytes`.

This is a deliberately conservative reservation, not a measured reachable
maximum. It includes old/new growth overlap and relies on source-byte ownership,
not an assumed number of native recursive frames. Review this proof when source
limits, lowering allocation sites or SDK vector policy change.

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
this API's working reservation. The Engine's control and prior Program backing
can be supplied as the baseline by its future adapter. Native stack, allocation
headers, CRT fragmentation and process RSS are not covered. Instance/output/host
accounting, complete aggregate quotas and bounded work remain open.

The focused native suite is:

```text
python tools/verify-module-output-execution.py --suite compile-memory
```

Development/O2 each passed fourteen groups: seven scalar reservation groups,
six real compiler/allocator groups and one unchanged captured-call regression.
The new wrapper also accepts depth 32 and rejects 33 in its own group. Six real
compiler groups assert zero SDK live blocks/bytes after owner cleanup. The 201
executed input identities match the checkout. Root locked check passed 251 sources
and 2,859 MIR functions. The existing Engine receipt has 216 unchanged inputs;
its native build was not repeated for this opt-in addition.

The suite uses the pinned compiler/runtime, instrumented SDK allocations, isolated test
processes, development/O2 and the unchanged combined captured-call depth 32/33
fixture under default 1MiB/4KiB stack settings. See the recorded
[evidence](../evidence/compile-memory-windows-20261107.json) for executed groups,
input identities and outcomes. Source adapters change only module names and test
visibility. No public gate, VM capacity, opcode or Fuel price changes.
