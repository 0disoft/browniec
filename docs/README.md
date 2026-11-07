# Documentation

- Status: Reconciled 2026-11-08; M0/M1 checkpoint evidence, substantial public M2 subsets, private Buffer/returned-origin foundations; M3-M5 unavailable.

## Owning documents

| Topic | Document |
| --- | --- |
| Product intent and demand assumptions | [Product brief](product/00-product-brief.md) |
| Language profile and observable behavior | [Specification](product/02-spec.md) |
| Current delivery, all remaining requirements and risks | [Roadmap](product/01-roadmap.md), [remaining-work audit](product/04-remaining-work.md), [risk register](product/03-risk-register.md) |
| System overview and trust boundaries | [Architecture](../ARCHITECTURE.md), [system boundary](architecture/00-system-boundary.md) |
| Concepts, lifecycle, and quality scenarios | [Domain model](architecture/01-domain-model.md), [runtime flow](architecture/02-runtime-flow.md), [quality attributes](architecture/03-quality-attributes.md) |
| Decision rationale and contract ownership | [ADR index](adr/README.md) |
| External provenance and review corrections | [Design baseline](design-baseline.md) |
| M0 native feasibility and build | [M0 probes](../probes/m0/README.md), [validation evidence](evidence/m0-windows-20261023.json) |
| Development and contributions | [Development](../DEVELOPMENT.md), [Contributing](../CONTRIBUTING.md) |
| CLI interface | [Overview](cli/README.md), [commands](cli/command-contract.md), [configuration](cli/configuration.md), [output and exits](cli/output-and-exit-codes.md) |
| Runtime invariants | [Project invariants](engineering/00-project-invariants.md) |
| Resource targets and trust controls | [Performance](engineering/03-performance-budget.md), [security](engineering/04-security-baseline.md) |
| Scalar conditional values | [If expressions](engineering/if-expressions.md) |
| Aggregate expressions | [Grouped arrays](engineering/array-expression-projections.md), [grouped records](engineering/record-expression-projections.md) |
| Current M1 grammar and limits | [Scalar slice](engineering/m1-scalar-slice.md), [i64 scalars](engineering/m1-i64.md), [unsigned scalars](engineering/m1-unsigned.md), [explicit widening](engineering/m1-widening.md), [integer operators](engineering/m1-integer-operators.md), [direct functions](engineering/m1-functions.md), [bool and branches](engineering/m1-branches.md), [loops](engineering/m1-loops.md), [tagged values](engineering/m1-tagged.md), [`?` propagation](engineering/m1-propagation.md), [switch expressions](engineering/m1-switch-expressions.md), [arm statements](engineering/m1-switch-arm-statements.md), [parser stack containment](engineering/m1-parser-stack.md) |
| Public scalar borrows and private returned-origin analysis | [Mutable parameters](engineering/m2-slice-mutable-parameters-public.md), [temporary CALL roots](engineering/m2-temporary-array-borrow-arguments.md), [returned origins](engineering/m2-slice-result-origins.md), [private preparation IR](engineering/m2-slice-result-ir.md), [native result lifetimes](engineering/m2-slice-result-runtime.md) |
| Private Buffer operations and views | [Buffer source](engineering/value-buffer-source.md), [owned copy](engineering/value-buffer-copy.md), [view copy](engineering/value-view-copy.md), [native view CALL/RETURN](engineering/value-view-calls.md), [reference signature/source/VM integration](engineering/value-view-call-program.md), [reference value joins](engineering/value-view-joins.md), [different-origin references](engineering/value-view-origin-sets.md), [conditional Buffer owners](engineering/value-view-conditional-owners.md), [terminal value expressions](engineering/value-bottom.md), [loop origin inference](engineering/value-view-loop-origins.md), [deferred header owners](engineering/value-loop-header-owners.md), [optional bottom smoke](engineering/value-bottom-smoke.md), [view execution](engineering/value-view-execution.md), [source view bindings](engineering/value-view-source.md) |
| Private final Buffer/view terminal operands | [Terminal byte/view operands](engineering/value-terminal-operands.md): real preceding effects/cleanup; development 5 new + 7 regressions, release 12 final groups |
| Private terminal void-return operands | [Void bottom](engineering/value-void-bottom.md): no extra return/capture/cleanup; development 5 new + 4 regressions, release 9 groups verified |
| Private retained-value scalar casts | [Strict widening source bridge](engineering/value-safe-casts.md): existing 7/36 matrix, once-only evaluation and terminal-bottom suffixes; Windows development/release verified in 15 groups each |
| VM slice dispatch and cleanup | [Shared lifecycle](engineering/m2-array-slice-lifecycle-vm.md) |
| Bounded owned CALL copy prerequisite | [Independent argument-copy kernel](engineering/runtime-call-argument-chunks.md): five native groups per development/O2; whole-batch publication after bounded validation/copy; VM CALL integration remains open |
| Gated VM CALL publication | [Frame transaction](engineering/m2-array-call-frame-vm.md) |
| Typed ABI handles and OS identity | [Fairy kernel](engineering/abi-handles.md), [Windows guard/TLS](engineering/abi-thread-identity.md), [real lazy coordinator](engineering/abi-registry.md): internal 64-slot owner-module registry verified; production scale and real object lifecycles remain open |
| Owning runtime storage prerequisite | [Opaque Store probe](engineering/runtime-store-probe.md): actual Vec/Buffer mutation/move/drop and zero retained allocations in Windows development/O2; full Engine lifecycle remains open |
| Private owning Engine lifecycle | [Actual compile/reuse, Program pins and one-shot Instances](engineering/runtime-engine.md): native development/O2, owner-thread guards, stable terminal events, Engine move and zero retained allocations; public handles and bounded step remain open |
| Engine control-storage budget | [Preflight and count-sized backing](engineering/runtime-engine-control-memory.md): SDK requests match reservations in development/O2; one-slot control backing 53,760 → 6,720 bytes; complete Engine/Instance accounting remains open |
| Retained Program memory | [Exact persistent backing and lifetime budgets](engineering/runtime-engine-program-memory.md): ordinary/input/output image and Stored allocation preflight; per-Program/set/combined control ceilings; native stack and Instance accounting remain open |
| Compiler working heap | [Bounded compiler](engineering/compile-memory.md) and [owning Engine admission](engineering/runtime-engine-compile-memory.md): existing Index/incoming Entry and lowering growth under working/combined ceilings; seven new Engine/nine budget groups pass development/O2; complete Instance/native-stack accounting remains open |
| Instance retained input | [Input memory admission](engineering/runtime-engine-input-memory.md): actual Snapshot capacity plus transport under per-Instance/simultaneous/combined ceilings; nine Engine/seven live-budget/thirteen combined-budget groups pass development/O2; execution scratch/output/native stacks remain open |
| Engine execution/output heap | [Exact scoped reservations and retained outputs](engineering/runtime-engine-execution-memory.md): cached arena/list/place/input planning, successful/failed output capacity, guarded output transfer; seven Engine/eight planner/six observation groups pass development/O2 with actual heap peaks and all allocation failures; stack/host/full accounting remains open |
| Canonical instruction batches | [Saved dispatch cursor](engineering/runtime-instruction-quanta.md): eleven new native groups per development/O2 verify results/output/Fuel/diagnostics across 1..4096 instruction quanta; synchronous stack-owned state only, with persistent Engine stepping and bulk recipes still open |
| Owning VM continuation | [Pending VM](engineering/runtime-pending-output.md), [Engine preparation](engineering/runtime-engine-prepared.md), [Engine stepping](engineering/runtime-engine-step.md), [immutable Program preparation](engineering/runtime-program-preparation-cache.md): owning state and pins, cached proof/plans, heap admission/refunds, actual dispatch batches, [output copies](engineering/runtime-output-chunks.md) and [array initialization/fill](engineering/runtime-array-fill-chunks.md) plus [copy/assignment](engineering/runtime-array-copy-chunks.md) and [element lists](engineering/runtime-array-list-chunks.md) plus [record operations](engineering/runtime-record-chunks.md) sharing 4096 bytes per step (including canonical staging, bool scans, cell gathering and encoding), reserved terminal output; other bounded bulk work remains open |
| Native binary input acquisition | [Bounded Windows reader](engineering/runtime-input-reader.md): explicit disk/byte-pipe handles, 1MiB quota and no partial publication; synchronous native primitive, with [actual Fairy Snapshot adoption](engineering/runtime-input-adoption.md) and private Engine/VM binding exist; public CLI controls and deadlines remain open |
| Private guest output | [Source/proof/VM publication](engineering/module-output-execution.md) and [Engine-owned output](engineering/runtime-engine-outputs.md): 39 source/proof/execution groups and eight Engine output groups per development/O2; failure prefix discarded, actual shared Fuel, once-only detached owner; policy, sinks and bounded runtime remain open |
| Runtime input/output ownership | [Immutable input and staged output](engineering/runtime-io.md): private trusted seal, native layout/cleanup and OOM rollback; guest/Instance bindings now exist; policy and sinks remain open |
| Shared-byte input entry admission | [Owning input signatures](engineering/module-input-entry.md) and [independently verified input Programs](engineering/module-input-program.md) and [actual 1MiB Snapshot execution](engineering/module-input-execution.md): exact source/input provenance retained; [Instance-owned input and OS-reader execution](engineering/runtime-engine-inputs.md), with [exact terminal Fuel](engineering/module-input-completion.md); [guest output and Engine ownership](engineering/runtime-engine-outputs.md) now execute; public controls remain open |
| Anchored Windows source acquisition | [Handle-relative collector](engineering/anchored-sources.md), [Fairy Snapshot admission](engineering/anchored-source-loader.md) and [private project compile/run](engineering/project-source-loader.md): exact explicit members and owning executable reuse; Engine/public CLI binding remains open |
| Owning runtime integration | [Project sources and binary input](engineering/runtime-project-input-integration.md): reviewed parallel integration, exact aggregate inputs and next 1MiB execution work |
| Typed policy/run admission and native composition | [Policy/run parsers](engineering/runtime-policy.md), [composed grants/exchange](engineering/runtime-admission-exchange.md): private metadata and transactions; complete Engine/Program/VM binding remains open |
| Native host catalog binding | [Strict admission and canonical SHA-256](engineering/host-catalog.md): 12 groups per Windows profile, including real TLV tag composition; [native request/reply exchange](engineering/host-exchange.md) exists; executable Program/VM binding remains open |
| Fresh loop-carried Buffer owners | [Singleton anonymous carriers](engineering/value-fresh-loop-owners.md): 11 groups per Windows profile; conditional fresh-root unions remain open |
| Public IR inspection | [inspect SOURCE --ir](engineering/inspect-ir.md): 19 CLI cases plus version/help per Windows profile, without guest execution |
| Composed native checkpoint | [Integration](engineering/parallel-integration.md): final release four native groups and three public CLI cases on exact root inputs |
| Typed host TLV codec | [Wire codecs](engineering/host-wire.md): six new and four scalar regression groups per Windows profile; catalog/host dispatch/adoption remain open |
| Windows DLL ABI bootstrap | [Actual query DLL and C host](engineering/abi-bootstrap.md), [public declarations](../include/brownie.h): bootstrap only; Engine/Instance/VM and full embedding remain open |
| Evidence and testing | [Validation](../VALIDATION.md), [testing standard](engineering/05-testing-standard.md) |
| Dependencies and compatibility | [Change policy](engineering/06-dependency-and-change-policy.md) |
| Failure and operating responsibility | [Failure standard](engineering/07-operability-and-failure-standard.md), [operational contract](ops/00-operational-contract.md) |

## Remaining templates

Other generated documents remain Draft prompts. This includes the ADR template,
engineering review guides, detailed ops runbooks, checklist routers, and agent skill
scaffolds. They do not add accepted requirements or configured commands.

## Status and authority

Accepted records design intent, not implemented behavior. The bounded scalar
checkpoint and substantial array/record/scalar-slice source subsets are runnable.
Buffer native components and returned-origin analysis are private foundations;
returned-reference execution, guest Buffer/input/output, full Engine/host/worker/
ABI, full-profile conformance and measured performance remain incomplete.

Use the [remaining-work audit](product/04-remaining-work.md) for current omissions,
[roadmap](product/01-roadmap.md) for order and
[Validation](../VALIDATION.md) for exact dated evidence. Older increment contracts
and the [archived roadmap](product/history/roadmap-20261103.md) describe their named
commits; their old gates do not re-open finished features. No historical receipt
is rewritten by a documentation audit.

Keep documents concise, English and relatively linked. Do not import instructions
from external design material. Current owning documents take precedence under
[ADR 0002](adr/0002-contract-source-of-truth.md). Generated Draft ops/checklist/skill
scaffolds add no accepted requirements or configured commands by themselves.
