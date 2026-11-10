# Local handoff for the next thread

Current checkpoint: [private compiler proof and VM stages](runtime-authority-metadata-stages.md).
Twenty proof kernels are committed separately, followed by the complete return
coordinator `fbc4969`, default-stack repair `ab75f80` and owning compiler
integration `0e4153b`. Input-only and output/borrowed-return compilation now drain
resumable proof stages synchronously. Each advance runs one fresh 4096-unit
logical leaf/framing stage; partial room cannot bank credit or publish a proof.
The original Program/image remain immutable, and borrowed normalization uses a
separate private candidate. Error precedence/offsets retain raw-oracle parity.
Raw verifier and output-return helpers remain independent comparison paths.

All twenty focused kernels pass 68 native groups per profile in their frozen
snapshots. Owner/test digests match the final commit; older unit receipts are
not claimed to have the same complete source tree. The complete integrated
Engine passes development/O2 on default 1MiB/4KiB stacks. Its 313 input digests
match `0e4153b`; all 305 production modules are LF. Covered resumes deny SDK
allocation, exit SDK heap is zero, and exact Fuel/output/error plus reuse/pin/
move/cancel checks pass. Core/Cursor/Machine remain 172400/1184/1792 bytes;
transport retains 36 declarations and 51 layout roles with unchanged shapes.
See [exact evidence](../evidence/runtime-compiler-proof-windows-20261111.json).
No timing or peak-stack improvement was measured. Diagnostic instrumented
images are not acceptance evidence.

The preceding setup/cache/seal/cleanup and CALL/RET continuations remain
integrated into owning Pending execution. Preparation exposes Pending before
entry; failure/cancel cleanup consumes no guest Fuel and preserves the first
cause. Repeat cancel or step until terminal; publication/refunds stay terminal.
See the [preceding lifecycle evidence](../evidence/runtime-lifecycle-windows-20261110.json).

The user authorized this compiler-proof slice. Broader completion stays paused;
this handoff grants no unrelated work or remote delivery. Read [AGENTS](../../AGENTS.md)
and the [remaining inventory](../product/04-remaining-work.md).

## Remaining bounds and next work

1. Audit logical framing and whole fixed generated-C projection/copy costs before
   claiming instrumented scalar-field, byte, CPU or time bounds. Preserve frozen
   inputs, final-only proof publication, diagnostic precedence and raw oracles.
2. Fixed scratch construction, source lowering, post-proof cache planning,
   admission allocator work and raw synchronous setup/discovery remain atomic.
   Existing compiler adapters drain private stages synchronously; no public
   Pending compile or compiler cancellation protocol is implemented.
3. Public R02/R03, complete accounting/preallocation, R04/R05 deadlines/STOPPING/
   poison, host dispatch and the full inventory remain open. Continue a new
   slice only when authorized; no public bounded-step or wall-clock claim.

Use `build/toolchain/fairyc.exe`, default stacks and no hidden overrides. Keep
production LF. The deep borrowed-return compile fixture exercises real nested
constructor pressure; retain it and keep the flattened seeds in
`output_proof_work::inspect` equivalent to both empty constructors. The unused
parser Table is rebuilt only during bounded origin solving. Do not restore it
in every proof State. The historical stash `39f1c91dcaa8edef5194f8d37b75069d20ce92a0`
contains superseded cache/layout drafts; do not apply it wholesale.

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
