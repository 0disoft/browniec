# Ops Change Checklist

- Status: Draft

## Source of Truth

- [AGENTS.md](../../AGENTS.md)
- [VALIDATION.md](../../VALIDATION.md)
- [docs/ops/00-operational-contract.md](../../docs/ops/00-operational-contract.md)
- [docs/product/02-spec.md](../../docs/product/02-spec.md)

## Failure Modes

Declared and active state diverge, uncertain external effects are repeated, recovery is incompatible with data, critical journeys remain broken, and completion is overstated.

## Checklist

Complete applicable items only with evidence. Record unresolved choices and the reason for any skipped or inapplicable item.

- [ ] Affected user journeys, operating owners, declared configuration, and observed active state are identified.
- [ ] The authorized change, compatibility constraints, stop conditions, and partial states are understood before external effects are applied or repeated.
- [ ] Rollback, reconciliation, or forward repair matches the effects that can actually be reversed and preserves valid user state.
- [ ] Relevant configuration, credentials, telemetry, and restore prerequisites have owners and evidence appropriate to the changed behavior.
- [ ] Critical journeys and intended active behavior are verified; artifact delivery or a healthy process alone is distinguished from successful operation.
- [ ] Original and recovery failures, mixed or unknown state, and remaining activation or handoff work are reported accurately.

## Validation

- Relevant validation names: docs, smoke, check
- Select configured checks from VALIDATION.md for the affected contracts and failure paths.
- Report skipped or unconfigured checks with reasons and remaining risk; they are not passing evidence.
