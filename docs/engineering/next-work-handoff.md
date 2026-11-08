# Local handoff for the next thread

Current checkpoint: [CALL/RET authority stages](runtime-authority-metadata-stages.md)
are integrated into private owning Pending output execution. Kernel commits
`84b382d`, `41c9eb4`, `6d1a2d7` and `047f6cb` precede CALL `bf965ea`, RET adapter
`4ca1ba8` and owning RET `8870a2c`. One Core work bank is reused; metadata and
payload share dispatch room, with final-only authority/frame publication.

Windows development/O2 pass direct CALL (1 group), RET (9 groups), and complete
Engine regression images with default stacks, covered-resume allocation denial
and zero exit SDK heap. The final Engine's 278 inputs match committed code.
See the [evidence](../evidence/runtime-authority-metadata-windows-20261109.json)
for exact historical/direct/integration snapshots. No timing improvement measured.

The user authorized this CALL/RET authority slice. The broader completion goal
remains paused; this handoff alone does not authorize unrelated slices or remote
delivery. Read [AGENTS](../../AGENTS.md) and the
[remaining inventory](../product/04-remaining-work.md).

## Next bounded implementation

1. Bound CALL copy-recipe preparation and metadata scans inside copy-plan
   validation. Current `copies::begin` runs alone but remains outside the proved
   authority ledger; a scheduling yield does not make its work bounded.
2. Finish bounds for CALL context and RET catalog/layout/result preparation.
   Whole bool ARET payload validation is already admitted into one byte batch;
   that does not prove all surrounding metadata visits are bounded.
3. Preserve the independent raw/synchronous oracles, immutable CALL66 cache and
   original-recipe proofs, exact valid-program Fuel/output/diagnostics, moves,
   cancellation/refunds and allocation-denial evidence. Synthetic late bad-frame
   failures intentionally retain staged originals/Fuel; raw RET65 may debit first.
4. Public R03, setup/proof/seal/cleanup, R04/R05 deadlines/STOPPING/poison and the
   full inventory remain incomplete. No public bounded-step or wall-clock claim.

Use `build/toolchain/fairyc.exe`, default stacks and no hidden overrides. Keep
production LF. A continuation consumes a scheduling visit, not another opcode
Fuel debit. RET validation counters record actual prefix work; phase 4 reports
final publication and stays set until the next RET. Full publication consumes
4096 metadata units, so following COPY work resumes in a later batch.

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
