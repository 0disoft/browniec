---
name: cli-tool
description: "Change CLI commands, configuration, machine-readable output, or exit behavior while preserving argument contracts and accurate reporting of effects and recovery."
---

# cli-tool

## Read First

- [AGENTS.md](../../../AGENTS.md)
- [VALIDATION.md](../../../VALIDATION.md)
- [CHECKLIST.md](../../../CHECKLIST.md)
- [.agents/context-map.md](../../../.agents/context-map.md)
- [docs/cli/README.md](../../../docs/cli/README.md)
- [docs/cli/command-contract.md](../../../docs/cli/command-contract.md)
- [.agents/checklists/cli-tool.md](../../../.agents/checklists/cli-tool.md)

## Work Guidance

- Identify the command's purpose, argument grammar, target resolution, side effects, and effective configuration. Distinguish omitted, empty, and invalid inputs, and follow existing interactive and non-interactive behavior.
- Keep terminal output, machine-readable framing, and exit status consistent with actual effects. Define the completion boundary across writes, recovery, and cleanup before reporting success or cancellation.
- Preserve original and recovery failures and existing user files. Account for interrupted work, repeatability, and dry-run behavior without letting diagnostics, progress, or prompts corrupt machine-readable results.
- Verify the actual executable or installed entrypoint with relevant arguments, output parsing, and failure or interruption scenarios. Keep unsupported shells, platforms, and configuration paths explicit.

## Validation and Delivery

Use repository rules and the task routes in VALIDATION.md to select relevant configured checks. Repair missing setup within the authorized scope or report the gap; an unconfigured or skipped check is not passing evidence.

Report observable changes, actual checks and results, remaining gaps, and incomplete recovery or delivery work. Follow existing execution and delivery authority; this skill does not authorize additional publication or external mutations.
