---
name: bugfix
description: "Diagnose and repair observed incorrect behavior using a reproducible trigger, the intended contract, and evidence of actual effects and recovery."
---

# bugfix

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/engineering/00-project-invariants.md](../../../docs/engineering/00-project-invariants.md)
- [docs/ops/00-operational-contract.md](../../../docs/ops/00-operational-contract.md)

## Work Guidance

- Establish the failing trigger, environment, selected command or configuration, expected behavior, and observed state. Separate reproducible evidence from suspected causes.
- Trace the responsible path and identify the violated contract or invariant. For mutations, distinguish rejected work, committed effects, partial recovery, and unknown outcomes.
- Repair the cause while preserving valid user state and unrelated behavior. Keep original and recovery failures visible instead of hiding the symptom or claiming an unobserved rollback.
- Use a focused reproduction or regression with an independent expected result. Verify the original trigger and the relevant successful or recovery path before describing the defect as fixed.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
