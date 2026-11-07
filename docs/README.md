# Documentation

- Status: Reconciled 2026-11-07; M0/M1 checkpoint evidence, substantial public M2 subsets, private Buffer/returned-origin foundations; M3-M5 unavailable.

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
| Gated VM CALL publication | [Frame transaction](engineering/m2-array-call-frame-vm.md) |
| Typed ABI handles and OS identity | [Fairy kernel](engineering/abi-handles.md), [Windows guard/TLS](engineering/abi-thread-identity.md): separately verified; actual singleton/coordinator and lifecycles remain open |
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
