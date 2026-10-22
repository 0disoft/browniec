# Contract Source of Truth

- Status: Accepted for design
- Decision owner: Zerodi / Rodisoft
- Decision date: 2026-10-23
- Implementation: documentation only

## Context

The generated scaffold and external v0.3.0 package contain overlapping contracts.
Copying every document, model, and acceptance fixture would obscure which decisions
apply and could make model results look like implemented behavior.

## Decision

| Contract fact | Authoritative document |
| --- | --- |
| Observable language behavior and first-profile limits | [Product specification](../product/02-spec.md) |
| System ownership and trust crossings | [Architecture](../../ARCHITECTURE.md) |
| CLI commands and arguments | [Command contract](../cli/command-contract.md) |
| Configuration authority and precedence | [Configuration](../cli/configuration.md) |
| Output and process results | [Output and exit codes](../cli/output-and-exit-codes.md) |
| Performance targets and measurement boundaries | [Performance budget](../engineering/03-performance-budget.md) |
| Delivery sequence | [Roadmap](../product/01-roadmap.md) |
| Evidence requirements | [Validation](../../VALIDATION.md) |
| External provenance and review corrections | [Design baseline](../design-baseline.md) |
| Decision rationale and supersession | Individual numbered ADRs |

README and document indexes summarize and link these authorities. Untouched Draft
templates are prompts, not extra requirements. The external package remains dated
reference material; its instructions and model outputs do not override this repository.

## Alternatives and consequences

Vendoring the full package would preserve convenient local access but duplicate
authority. A generated schema is useful later for machine-readable interfaces;
there is no executable interface here to justify that infrastructure yet.

Change the owning contract and affected summaries together. A disagreement between
code and the contract is a review finding; neither silently changes the other.
Zerodi / Rodisoft owns material scope changes. Record such decisions in a new ADR.

## Verification

Check links, terminology, status, and changed consumers in each documentation slice.
Future implementation checks must exercise these contracts through real artifacts;
static document checks establish no native execution or security result.
