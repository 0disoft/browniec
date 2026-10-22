---
name: refactor
description: "Reorganize implementation responsibilities while preserving agreed observable behavior, ownership, and consumer contracts."
---

# refactor

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [ARCHITECTURE.md](../../../ARCHITECTURE.md)
- [docs/engineering/00-project-invariants.md](../../../docs/engineering/00-project-invariants.md)

## Work Guidance

- Identify the responsibility or dependency problem and the behavior and contracts that must remain true. Treat intentional behavior changes as separate decisions rather than hiding them in a refactor.
- Choose boundaries that reduce duplication or coupling without creating a second authority, moving user-owned state, or imposing an unrelated architecture.
- Preserve effect ordering, lifetimes, error propagation, and recovery guarantees across the new boundaries. Update callers and ownership documentation together.
- Compare relevant behavior and contract outputs before and after the change. Prefer existing focused evidence over tests that merely mirror the new internal structure.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
