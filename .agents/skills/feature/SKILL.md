---
name: feature
description: "Implement new or expanded product behavior from project requirements, ownership boundaries, and observable acceptance criteria."
---

# feature

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/product/02-spec.md](../../../docs/product/02-spec.md)
- [docs/architecture/00-system-boundary.md](../../../docs/architecture/00-system-boundary.md)

## Work Guidance

- Connect the requested behavior to existing requirements and observable acceptance criteria. Identify unresolved product choices rather than inventing a domain or technology stack.
- Map affected state, contract owners, and consumers. Identify compatible behavior and the failure or interrupted states the new operation can leave behind.
- Choose an implementation and delivery sequence suited to those boundaries. Preserve existing user work and keep derived contracts or documentation aligned with their authority.
- Demonstrate the intended user outcome and relevant rejection or recovery behavior. Distinguish completed implementation from remaining integration, migration, or release work.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
