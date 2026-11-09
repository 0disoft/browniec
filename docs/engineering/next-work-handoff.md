# Local handoff for the next thread

Current checkpoint: [private VM lifecycle and CALL/RET stages](runtime-authority-metadata-stages.md)
are integrated into owning Pending output execution. Cleanup `0dee834`, seal
`0c62d6d`, retained-cache checks `1508cc6` and storage initialization `849acb3`
precede owning integration `a287e8f`. Preparation reserves storage and exposes
Pending before entry; setup/cache/input/Core/entry advance separately. Fresh
4096-unit metadata batches are shared with existing payload/CALL/RET work.
Buffer stages initialize <=1024 bytes, vector stages <=64 entries and input
stages sixteen 24-byte cells. No work credit is saved across yields.

Failure/cancellation cleanup reuses the existing unpublished Runtime bank and
needs no guest Fuel. Cancel may return Pending; repeat cancel or step until
terminal. The first cause wins, including a failure followed by repeated cancel.
Publication and refunds remain terminal-only. A dropped sole private owner
releases backing directly. Synchronous/raw helpers remain independent oracles.

Windows development/O2 pass cleanup (4 groups), seal (5), cache checks (3),
storage (3) and complete Engine images, with default stacks, covered-resume
allocation denial and zero process-exit SDK heap. All 292 Engine inputs match
`a287e8f`; all 284 production modules retain LF. Core/Cursor stay 172400/1184
bytes; Machine is 1792 (+160, adding 1280 per reserved Vec8). Input metadata
keeps its 24576-byte reservation while its owner becomes a Buffer.
Typed transport is 36 bindings / 51 layouts. See the [exact evidence](../evidence/runtime-lifecycle-windows-20261110.json).
No timing or peak-stack improvement measured.

The user authorized this lifecycle slice. Broader completion stays paused;
this handoff grants no unrelated work or remote delivery. Read [AGENTS](../../AGENTS.md)
and the [remaining inventory](../product/04-remaining-work.md).

## Remaining bounds and next work

1. Audit logical allowance framing, including whole fixed Runtime-column copies,
   before claiming instrumented field/byte/CPU bounds. Preserve frozen inputs,
   final-only publication, exact valid-program Fuel/diagnostics/output and the
   raw comparison paths. Continuations consume scheduling visits, not another
   opcode Fuel debit.
2. Source compile proof, admission allocator work and raw synchronous setup/
   discovery remain atomic. The staged preparation proof consumes the exact
   retained immutable Program cache; it is not independent admission for raw IR.
3. Public R02/R03, complete accounting/preallocation, R04/R05 deadlines/STOPPING/
   poison, host dispatch and the full inventory remain open. Continue another
   slice only when authorized. No public bounded-step or wall-clock claim.

Use `build/toolchain/fairyc.exe`, default stacks and no hidden overrides. Keep
production LF. The historical stash `39f1c91dcaa8edef5194f8d37b75069d20ce92a0`
contains superseded cache/layout drafts; do not apply it wholesale. The immutable
CALL66 cache is already integrated, including forwarding/second-input selection.

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
