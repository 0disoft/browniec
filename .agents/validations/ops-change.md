# Ops Change Validation

- Status: Draft

## Source of Truth

- [VALIDATION.md](../../VALIDATION.md)
- [docs/ops/00-operational-contract.md](../../docs/ops/00-operational-contract.md)
- [docs/product/02-spec.md](../../docs/product/02-spec.md)
- [.agents/checklists/ops-change.md](../../.agents/checklists/ops-change.md)

## Validation Scope

Verify intended active behavior and recoverable state for an authorized operational change, including mixed or uncertain outcomes.

## Validation Selection

- Relevant validation names: docs, smoke, check
- Stable names and executable routing come from root VALIDATION.md and the configured runner. Do not infer commands from this guide.
- Select checks for affected contracts and failure paths. Review-only changes may use focused document or contract review; scaffold text does not prove implemented runtime behavior.
- Unconfigured or skipped checks require reasons and remaining risk; they are not passing evidence.

## Required Evidence

- Compare declared configuration, delivered artifacts, observed active state, and affected user journeys in the selected environment.
- Where effects are authorized, verify prerequisites, compatibility, stop conditions, and actual transition results without assuming that retrying an unknown outcome is safe.
- Observe affected partial-state recovery, rollback, reconciliation, or forward repair against valid user state and actual recovery prerequisites.
- Verify critical journeys at relevant operating boundaries and retain original and recovery failures, remaining activation work, and ownership of unresolved state.

## Report

Record the affected contract, artifact and environment where relevant, executed checks, actual results, skipped checks and reasons, and remaining work or risk.
Distinguish planned, delivered, active, and completed state where relevant. This guide does not authorize deployment or additional external effects.
