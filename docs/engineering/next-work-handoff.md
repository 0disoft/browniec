# Local handoff for the next thread

Current checkpoint: [private compiler source stages](compiler-source-stages.md).
Sixteen new source kernels now cover immutable source/UTF-8/literal/token/context/
name/type foundations, complete untyped single/indexed function scans, and
single-source/scoped struct scans. Record fields/types/names resume separately;
layout validation reuses `struct_layout_work`. All declaration syntax is checked
before field types. Private candidates remain unavailable until final checks.

Owning adapters drain fresh 4096-unit stages synchronously; compilation is not
public Pending. Raw signature/single/index/struct/field/layout helpers remain
comparison paths. Preserve scoped packed-prefix lookup and the difference
between single-source first-name and scoped first-failed-root diagnostics.

The record slice passes six frozen groups/profile and six current owning adapter
groups/profile. Engine development/O2 pass default 1MiB/4KiB stacks and zero SDK
heap at exit. All 329 Engine inputs match `da8fe2c`; 321 production modules retain
LF. Transport keeps 36 bindings/51 layouts and equivalent 176 aggregate graphs;
Core/Cursor/Machine remain 172400/1184/1792 bytes. See [record evidence](../evidence/runtime-compiler-records-windows-20261111.json),
[signature evidence](../evidence/runtime-compiler-signatures-windows-20261111.json)
and [foundation evidence](../evidence/runtime-compiler-source-windows-20261111.json).
Older unit results describe frozen snapshots, not the final whole tree. No
wall-clock/peak-stack improvement was measured. Instrumented diagnostic images
are not acceptance receipts.

The preceding [twenty compiler proof kernels](runtime-authority-metadata-stages.md#compiler-proof-stages)
remain connected to owning input/output and borrowed-return compilation. The
[setup/cache/seal/cleanup and CALL/RET stages](runtime-authority-metadata-stages.md)
remain integrated into owning Pending execution. Preparation exposes Pending
before entry; failure/cancel cleanup consumes no guest Fuel and preserves the
first cause. Repeat cancel or step until terminal; publication/refunds remain
terminal. See the [proof evidence](../evidence/runtime-compiler-proof-windows-20261111.json)
and [lifecycle evidence](../evidence/runtime-lifecycle-windows-20261110.json).

## Required continuation of the authorized lowering slice

1. Literal collection/interning with final-only builder publication. Pin the
   original Builder and use separate private candidate/control banks; preserve
   whole-source UTF-8-before-tokenization and Source/Image error ordering.
2. Typed/value signature and catalog preparation remain separate from completed
   untyped signature and struct scans.
3. Slice origin inference, preserving all seventeen rounds and exact error
   order, with expression/atom/CALL/name/control-flow continuations.
4. Aggregate parameter/result preparation; then body/statement/expression/control
   lowering with explicit task/continuation requests. A metered call to the
   existing recursive `body` is still atomic and is not a valid completion.
5. Final entry-call restrictions, output normalization and repeated raw context
   validation/state setup outside scoped name lookup.
6. Integrate the full lowering coordinator only after all its semantic children
   resume independently. Compare emitted IR and exact diagnostics, then execute
   complete Engine images on default stacks again.

The user authorized source lowering and small verified local commits. Continue
this same scope without asking for authorization again. The broader completion
goal stays paused; this handoff grants no unrelated work or remote delivery.
Read [AGENTS](../../AGENTS.md) and the [remaining inventory](../product/04-remaining-work.md).

Fixed initial scratch construction, post-proof cache planning, admission
allocations, raw synchronous discovery and the remaining runtime inventory are
not bounded by these kernels. Logical framing is not an instrumented scalar-
field/byte/CPU bound. Public Pending compile, deadlines/STOPPING/poison and full
R02-R05 closure remain unimplemented.

Use `build/toolchain/fairyc.exe`, default stacks and no hidden overrides. Keep
production LF and raw comparison helpers independent. The deep borrowed-return
compile fixture exercises real nested constructor pressure; retain it and keep
the flattened seeds in `output_proof_work::inspect` equivalent to both empty
constructors. Do not restore the full parser Table in every proof State. The
historical stash `39f1c91dcaa8edef5194f8d37b75069d20ce92a0` contains superseded
cache/layout drafts; do not apply it wholesale.

## Full remaining inventory

The inventory has 48 named IDs. L07 lexical compatibility is implemented;
**47 IDs remain incomplete, including substantial partial implementations**.
This is an inventory count, not 47 untouched features or a completion percentage.

| IDs | Remaining accepted work |
| --- | --- |
| L01-L06 | Public project/module/entry loading; complete inference and grouped/constructor/aggregate/reference composition; public Buffer and wide/nested Option/Result composition; full assignment and must-use contracts. |
| B01-B05 | Complete public returned-reference admission; mutable/non-byte/Buffer-object references and returned-image host lifetimes; full CFG last-use/root conflicts, generations and bounded descriptor reclamation. |
| D01-D05 | Instance-owned/accounted Buffer and registry integration; conditional fresh-root unions, general methods/AllocError/public admission; failure and partial-initialization cleanup; resumable UTF-8/text/equality work across chunks. |
| R01-R05 | Public Engine/Program/Instance lifecycle and policy/run binding; complete preallocation/accounting and stack containment; payload plus metadata work bounds; deadlines, cancellation/STOPPING/poison; bounded cleanup and quantum-independent Fuel/results. |
| I01-I02 | Public binary file/stdin input and binary/JSON/text sinks; immutable policy/grant binding, deadlines/cancellation, total accounting and staged publication without replay on sink failure. |
| H01-H04 | Executable requirements/catalog/grants, actual VM host dispatch and typed destination adoption, HOST_REQUEST/WAITING_HOST/reply checkpoints, bounded commits and complete quota/reservation integration. |
| C01-C05 | Public project/policy/catalog/grant loaders and CLI controls; restricted check/run/worker surfaces; bounded multi-source diagnostics; complete version/result metrics; deliberate full-profile caps and IR/cost reconciliation. |
| W01-W06 | Real Windows restricted process/AppContainer/token/Job setup; authenticated bounded IPC; broker publication barrier; cancellation/deadline/drain races; completion-owned I/O leases/REAPING; aggregate budgets and actual OS denial/race evidence. |
| E01-E04 | Public C lifecycle exports beyond the ABI-info bootstrap; production lazy registries and one-process ownership; handle/pin/output/error lifetimes; clean-machine executable/DLL packaging and separately verified Linux execution. |
| V01-V05 | Full source-to-VM conformance; focused mutation/fuzz/OOM coverage; representative performance and memory measurements; retained build/cache/scratch costs; release/compatibility/rollback/platform evidence and minimal useful CI. |

Open target decisions also remain: source/operand/profile limits, dialect and
IR/cost/ABI compatibility, and how to measure the accepted performance targets.
Targets (unmeasured) include reused setup p95 <=1ms, 10KiB compile+verify p95
<=10ms, empty Instance accounted memory <=32KiB, zero warm scalar-loop
allocations, and 100 retained edit builds <=32MiB excluding reported debug/
toolchain artifacts. The current 4KiB source ceiling cannot execute the 10KiB
compile target; reconcile the profile before claiming it.

## Working discipline

Use `build/toolchain/fairyc.exe`; preserve production LF and the pinned runtime.
Do not modify the fairyc checkout or introduce hidden compiler/stack overrides.
Sol High workers can own disjoint source, test and documentation files; the
parent serializes transport review, native verification and local commits.
The complete goal remains broader than the private engine subset.
