# CLI Tool Checklist

- Status: Draft

## Source of Truth

- [AGENTS.md](../../AGENTS.md)
- [VALIDATION.md](../../VALIDATION.md)
- [docs/cli/README.md](../../docs/cli/README.md)
- [docs/cli/command-contract.md](../../docs/cli/command-contract.md)

## Failure Modes

Ambiguous arguments, wrong effective configuration, unintended target effects, corrupt machine-readable output, misleading exit status, and incomplete recovery or cleanup.

## Checklist

Complete applicable items only with evidence. Record unresolved choices and the reason for any skipped or inapplicable item.

- [ ] Argument grammar, defaults, missing or empty values, and interactive versus non-interactive behavior match the affected command contract.
- [ ] Selected executable, effective configuration, target resolution, and permitted side effects are clear without exposing credentials or private values.
- [ ] Machine-readable framing, diagnostics, and exit status agree with actual committed effects, interruption, recovery, and cleanup.
- [ ] Dry-run and repeated execution respect their mutation and recovery boundaries, preserving valid user files and original failure causes.
- [ ] Relevant installed-entrypoint, argument, configuration, and output-parsing evidence covers supported environments.
- [ ] Affected failure or cancellation paths report remaining state accurately, with unsupported shells or platforms and delivery gaps explicit.

## Validation

- Relevant validation names: lint, typecheck, test, smoke, check
- Select configured checks from VALIDATION.md for the affected contracts and failure paths.
- Report skipped or unconfigured checks with reasons and remaining risk; they are not passing evidence.
