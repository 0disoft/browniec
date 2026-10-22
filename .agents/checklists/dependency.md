# Dependency Checklist

- Status: Draft

## Source of Truth

- [AGENTS.md](../../AGENTS.md)
- [VALIDATION.md](../../VALIDATION.md)
- [docs/engineering/06-dependency-and-change-policy.md](../../docs/engineering/06-dependency-and-change-policy.md)
- [docs/engineering/00-project-invariants.md](../../docs/engineering/00-project-invariants.md)

## Failure Modes

Unnecessary dependencies, incompatible consumers, unsupported environments, stale update policy, unexplained artifact drift, and costly or incomplete removal.

## Checklist

Complete applicable items only with evidence. Record unresolved choices and the reason for any skipped or inapplicable item.

- [ ] The required capability and affected consumers justify the dependency after considering built-in or existing alternatives.
- [ ] Runtime or development role, transitive exposure, maintenance ownership, and applicable license requirements are understood.
- [ ] Selected ranges, lock or build inputs, compatible-update adoption, and intentional major-version transitions follow the project's policy.
- [ ] Changed API, type, runtime, install, and package behavior is compatible with supported consumers or has an explicit migration path.
- [ ] Replacement, removal, or recovery accounts for affected data and interfaces rather than assuming a version change can reverse every effect.
- [ ] Relevant distributed-artifact and consumer checks support compatibility claims, with unsupported combinations and delivery gaps recorded.

## Validation

- Relevant validation names: lint, typecheck, test, check
- Select configured checks from VALIDATION.md for the affected contracts and failure paths.
- Report skipped or unconfigured checks with reasons and remaining risk; they are not passing evidence.
