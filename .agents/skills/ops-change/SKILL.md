---
name: ops-change
description: "Change operating configuration, rollout, or recovery behavior with evidence of active state, affected journeys, and reversible or irreversible effects."
---

# ops-change

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/ops/00-operational-contract.md](../../../docs/ops/00-operational-contract.md)
- [docs/ops/rollback.md](../../../docs/ops/rollback.md)
- [.agents/checklists/ops-change.md](../../../.agents/checklists/ops-change.md)

## Work Guidance

- Identify the affected user journeys, actual active state, declared configuration, and operating owner. Distinguish an artifact or configuration change from runtime activation.
- Map possible partial states and compatibility constraints. Choose rollback, reconciliation, or forward repair according to the effects that can actually be reversed.
- Prepare the relevant evidence and stop conditions before the authorized operation. Record outcomes and do not repeat an uncertain external effect without checking its identity and state.
- Verify the intended active behavior and critical journeys. Report remaining mixed or unknown state, recovery responsibility, and the evidence used to decide that the change succeeded.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
