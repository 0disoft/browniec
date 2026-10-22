# Dependency Upgrade Validation

- Status: Draft

## Source of Truth

- [VALIDATION.md](../../VALIDATION.md)
- [docs/engineering/06-dependency-and-change-policy.md](../../docs/engineering/06-dependency-and-change-policy.md)
- [docs/engineering/00-project-invariants.md](../../docs/engineering/00-project-invariants.md)
- [.agents/checklists/dependency.md](../../.agents/checklists/dependency.md)

## Validation Scope

Verify dependency changes against affected public interfaces, supported consumers, and distributed artifacts rather than relying only on installation success.

## Validation Selection

- Relevant validation names: lint, typecheck, test, smoke, check
- Stable names and executable routing come from root VALIDATION.md and the configured runner. Do not infer commands from this guide.
- Select checks for affected contracts and failure paths. Review-only changes may use focused document or contract review; scaffold text does not prove implemented runtime behavior.
- Unconfigured or skipped checks require reasons and remaining risk; they are not passing evidence.

## Required Evidence

- Compare selected ranges, resolved versions, transitive changes, runtime or development roles, and build inputs with the project's update and compatibility policy.
- Check affected types, public APIs, defaults, errors, and lifecycle behavior in representative supported consumers, including actual packaged entrypoints where relevant.
- Verify meaningful changed failure, install, and recovery paths, making required consumer migration and irreversible state effects explicit.
- Inspect resulting artifacts and relevant dependency, license, or environment changes; report unsupported combinations and removal or delivery work that remains.

## Report

Record the affected contract, artifact and environment where relevant, executed checks, actual results, skipped checks and reasons, and remaining work or risk.
Distinguish planned, delivered, active, and completed state where relevant. This guide does not authorize deployment or additional external effects.
