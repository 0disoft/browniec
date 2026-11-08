# Local handoff for the next thread

Current checkpoint: immutable CALL66 capture plans (`ced4289`) are integrated
into owning synchronous/pending output execution (`5f9bfc3`). Native Windows
development/O2 pass five kernel groups, six returned-view groups and Engine/kernel
regressions with default stacks, zero exit SDK heap and zero SDK attempts on every
resume. Owning execution enters none of the three named recipe helpers; raw
execution still re-proves and scans. See [cache integration](runtime-call-capture-cache.md)
and its [evidence](../evidence/runtime-call-capture-cache-windows-20261108.json).

The user resumed only this cache slice. The broader completion goal remains
paused; this handoff alone does not authorize another slice, push, release or
deployment. Read [AGENTS](../../AGENTS.md) and the authoritative
[remaining-work inventory](../product/04-remaining-work.md) before further work.

## Next bounded implementation

1. Continue R03 CALL/RET metadata work bounds, including planning, live authority
   reconstruction and final publication. The cache removes three named immutable
   recipe scans; it does not bound every metadata visit or establish public step.
2. Preserve whole-program canonical/original-recipe proof, selected origins,
   independently reverified raw execution, and exact Program/plan association.
   Preparation parameters are field 7 and the capture plan is field 8.
3. Follow with setup/proof/seal/cleanup continuations and R04/R05 monotonic
   deadlines, cancellation/STOPPING/poison, bounded cleanup and stable first cause.
   Do not claim all R02-R05 obligations are complete after caching recipes.
4. Keep actual direct/nested/forwarding/second-input source, independent raw
   oracles, fixed/mixed schedules, no resume SDK attempts and exact memory refunds.
   Use `build/toolchain/fairyc.exe`, default stacks and no hidden overrides;
   preserve exact-field authority/pool borrowing and production LF.

The old local stash `39f1c91dcaa8edef5194f8d37b75069d20ce92a0` remains historical
provenance. Its cache is integrated and its superseded layout/fixtures must not
be applied wholesale. Current actual-source coverage extends that draft to
forwarding and second-input selection. Stored grows by 904 inline bytes; the
reserved eight-slot vector adds 7232 charged bytes per retained output Program.

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
