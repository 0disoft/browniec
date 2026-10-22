---
name: dependency-upgrade
description: "Select, update, or remove a dependency based on necessity, supported compatibility, reproducible evidence, and replacement or recovery cost."
---

# dependency-upgrade

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/engineering/06-dependency-and-change-policy.md](../../../docs/engineering/06-dependency-and-change-policy.md)
- [.agents/checklists/dependency.md](../../../.agents/checklists/dependency.md)

## Work Guidance

- Establish the dependency's role, consumers, selected version range, lock or build behavior, and reason for the change. Consider built-in or existing alternatives where they meet the requirement.
- Use the project's compatibility-update policy. Identify deliberate major-version transitions, affected runtime or package contracts, migration needs, and recovery limits.
- Update the authoritative dependency declaration and required derived or lock surfaces together. Preserve unrelated dependency and configuration choices.
- Verify the affected consumers, supported runtimes, and package behavior with relevant checks. Describe unsupported environments, unresolved compatibility, and remaining removal or rollout work explicitly.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
