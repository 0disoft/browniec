# Local handoff for the next thread

Current checkpoint: private output returned-view bridge implemented in `f9a76ce`,
verified in native Windows development/O2 with six new groups plus regressions.
Evidence: [returned views](runtime-output-returned-views.md) and
[receipt/audit](../evidence/runtime-output-returned-views-windows-20261108.json).
Read [AGENTS](../../AGENTS.md), [the implementation plan](completion-plan.md),
and the authoritative [remaining-work inventory](../product/04-remaining-work.md).

The user requested finishing only the current slice, then stopping. The broad
completion goal is paused. No new slice, push, release or deployment is authorized
by this handoff alone. A subsequent user request must resume further work.

## Immediate next implementation

1. Integrate the preserved immutable CALL66 capture cache from **local Git stash
   `39f1c91dcaa8edef5194f8d37b75069d20ce92a0`**. Inspect its files with `git show`;
   do not apply/pop it wholesale or overwrite newer compiler/proof/VM work.
2. Preserve independently proved `Preparation.parameters`, raw reproof, owning
   proof reuse and both synchronous/pending selected-origin paths. Parameters
   occupy field 7; the old cache draft expected its Plan at field 7 and must be
   rebased to the next field. Preserve CALL depth exact-field borrowing.
3. Retain the actual direct/chained exclusive-return fixtures, independent raw
   oracle, exact Fuel/output/diagnostics, dynamic Held/owner/loan checks, zero
   owning recipe entries, no resume SDK allocations and actual retained-capacity
   accounting. Regenerate/review transport; use default stacks in both profiles.
4. Then continue R02-R05 metadata work bounds, final publication, setup/proof/
   seal/cleanup continuations, monotonic deadlines, cancellation/STOPPING/poison.
   Cached recipes alone do not establish the public bounded-step contract.

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
