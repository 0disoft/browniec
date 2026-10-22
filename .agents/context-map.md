# Agent Context Map

- Status: Draft
- Scope: general
- Repository Type: cli-tool
- Addons: none

## Context Sources

- Product scope route: docs/product/02-spec.md
- Architecture route: docs/architecture/ and docs/adr/
- Documentation update route: docs/README.md

Use the project's checklist router and validation policy to select applicable evidence and configured checks. Generated procedures remain design guidance until project owners record implementation choices and execution authority.

## Task Skills

Choose the applicable skill by its stated purpose and read its contract sources before editing. This list reflects the skills generated for the selected scope, repository type, addons, and density; it does not grant command or delivery authority. Update the list when the project retires or replaces a skill.

- [feature](skills/feature/SKILL.md): Implement new or expanded product behavior from project requirements, ownership boundaries, and observable acceptance criteria.
- [bugfix](skills/bugfix/SKILL.md): Diagnose and repair observed incorrect behavior using a reproducible trigger, the intended contract, and evidence of actual effects and recovery.
- [refactor](skills/refactor/SKILL.md): Reorganize implementation responsibilities while preserving agreed observable behavior, ownership, and consumer contracts.
- [ops-change](skills/ops-change/SKILL.md): Change operating configuration, rollout, or recovery behavior with evidence of active state, affected journeys, and reversible or irreversible effects.
- [dependency-upgrade](skills/dependency-upgrade/SKILL.md): Select, update, or remove a dependency based on necessity, supported compatibility, reproducible evidence, and replacement or recovery cost.
- [test-hardening](skills/test-hardening/SKILL.md): Improve evidence for existing behavior or a demonstrated regression through independent expectations, meaningful failure fixtures, and proportionate execution cost.
- [cli-tool](skills/cli-tool/SKILL.md): Change CLI commands, configuration, machine-readable output, or exit behavior while preserving argument contracts and accurate reporting of effects and recovery.
