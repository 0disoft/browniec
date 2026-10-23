# Documentation

- Status: Accepted design documentation; M0 verified; experimental M1 scalar CLI/VM; earlier slices and unsigned scalars have verified historical receipts; explicit widening historically verified; bitwise operators and checked shifts implemented and verified

## Owning documents

| Topic | Document |
| --- | --- |
| Product intent and demand assumptions | [Product brief](product/00-product-brief.md) |
| Language profile and observable behavior | [Specification](product/02-spec.md) |
| Delivery and open risks | [Roadmap](product/01-roadmap.md), [risk register](product/03-risk-register.md) |
| System overview and trust boundaries | [Architecture](../ARCHITECTURE.md), [system boundary](architecture/00-system-boundary.md) |
| Concepts, lifecycle, and quality scenarios | [Domain model](architecture/01-domain-model.md), [runtime flow](architecture/02-runtime-flow.md), [quality attributes](architecture/03-quality-attributes.md) |
| Decision rationale and contract ownership | [ADR index](adr/README.md) |
| External provenance and review corrections | [Design baseline](design-baseline.md) |
| M0 native feasibility and build | [M0 probes](../probes/m0/README.md), [validation evidence](evidence/m0-windows-20261023.json) |
| Development and contributions | [Development](../DEVELOPMENT.md), [Contributing](../CONTRIBUTING.md) |
| CLI interface | [Overview](cli/README.md), [commands](cli/command-contract.md), [configuration](cli/configuration.md), [output and exits](cli/output-and-exit-codes.md) |
| Runtime invariants | [Project invariants](engineering/00-project-invariants.md) |
| Resource targets and trust controls | [Performance](engineering/03-performance-budget.md), [security](engineering/04-security-baseline.md) |
| Current M1 grammar and limits | [Scalar slice](engineering/m1-scalar-slice.md), [i64 scalars](engineering/m1-i64.md), [unsigned scalars](engineering/m1-unsigned.md), [explicit widening](engineering/m1-widening.md), [integer operators](engineering/m1-integer-operators.md), [direct functions](engineering/m1-functions.md), [bool and branches](engineering/m1-branches.md), [loops](engineering/m1-loops.md), [tagged values](engineering/m1-tagged.md), [`?` propagation](engineering/m1-propagation.md), [switch expressions](engineering/m1-switch-expressions.md) |
| Evidence and testing | [Validation](../VALIDATION.md), [testing standard](engineering/05-testing-standard.md) |
| Dependencies and compatibility | [Change policy](engineering/06-dependency-and-change-policy.md) |
| Failure and operating responsibility | [Failure standard](engineering/07-operability-and-failure-standard.md), [operational contract](ops/00-operational-contract.md) |

## Remaining templates

Other generated documents remain Draft prompts. This includes the ADR template,
engineering review guides, detailed ops runbooks, checklist routers, and agent skill
scaffolds. They do not add accepted requirements or configured commands.

## Status and authority

Accepted records design intent, not implemented behavior. The M0 harness and first
M1 scalar check/run CLI are runnable; wider interfaces remain designed. Verified means an
executed check has recorded evidence; unmeasured targets are not results. See
[ADR 0002](adr/0002-contract-source-of-truth.md) for authoritative facts and update
direction.

Keep documents concise and in English, use relative links, and update affected
consumers with the owning contract. Do not import source-package instructions or
local absolute paths. M0 establishes primitive results. M1 establishes a narrow
i32/i64/u8/u32/usize/bool source path with explicit widening, branches, loops,
shallow Option/Result, switch statements and expressions, and scalar `?`
propagation. The earlier receipts
remain historical for their verified slices; the switch-expression receipt records
41 native groups and 580 CLI cases. The [i64 receipt](evidence/m1-i64-windows-20261023.json)
is historical and records 49 native groups and 760 CLI cases in each development
and release profile. The [unsigned receipt](evidence/m1-unsigned-windows-20261023.json)
remains historical at 59 native groups and 1,159 CLI cases in each development and
release profile. The [widening contract](engineering/m1-widening.md) is implemented
and verified. Its [receipt](evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each profile, including 113 widening cases.
That receipt is historical after integer operators. The
[integer-operator receipt](evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each profile, including 626 new cases.
Full M1,
arrays, structs, borrows, richer value-arm statements, Windows isolation, ABI, and
packaging remain unimplemented or unverified.
