# CLI Tool Validation

- Status: Draft

## Source of Truth

- [VALIDATION.md](../../VALIDATION.md)
- [docs/cli/README.md](../../docs/cli/README.md)
- [docs/cli/command-contract.md](../../docs/cli/command-contract.md)
- [.agents/checklists/cli-tool.md](../../.agents/checklists/cli-tool.md)

## Validation Scope

Verify installed command behavior, effective configuration, and accurate effect reporting across affected supported environments.

## Validation Selection

- Relevant validation names: lint, typecheck, test, smoke, check
- Stable names and executable routing come from root VALIDATION.md and the configured runner. Do not infer commands from this guide.
- Select checks for affected contracts and failure paths. Review-only changes may use focused document or contract review; scaffold text does not prove implemented runtime behavior.
- Unconfigured or skipped checks require reasons and remaining risk; they are not passing evidence.

## Required Evidence

- Invoke the supported entrypoint with affected arguments, absent or empty values, and configuration precedence, observing the selected target and permitted side effects.
- Parse affected machine-readable output according to its framing contract and compare diagnostics and exit status with actual committed, interrupted, or recovered state.
- Where mutation or cleanup changes, verify dry-run boundaries, repeated execution, cancellation, and partial failures while preserving user files and original failure causes.
- Use the installed or distributed command where packaging is affected and record tested shells, runtimes, configuration inputs, and unsupported combinations.

## Report

Record the affected contract, artifact and environment where relevant, executed checks, actual results, skipped checks and reasons, and remaining work or risk.
Distinguish planned, delivered, active, and completed state where relevant. This guide does not authorize deployment or additional external effects.
