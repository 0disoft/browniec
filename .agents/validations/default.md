# Default Validation

- Status: Draft

## Source of Truth

- [VALIDATION.md](../../VALIDATION.md)
- [AGENTS.md](../../AGENTS.md)
- [docs/engineering/00-project-invariants.md](../../docs/engineering/00-project-invariants.md)
- [CHECKLIST.md](../../CHECKLIST.md)

## Validation Scope

Select evidence for the requested outcome and preserved contracts without treating every available check as mandatory for every change.

## Validation Selection

- Relevant validation names: format, lint, typecheck, test, docs, check
- Stable names and executable routing come from root VALIDATION.md and the configured runner. Do not infer commands from this guide.
- Select checks for affected contracts and failure paths. Review-only changes may use focused document or contract review; scaffold text does not prove implemented runtime behavior.
- Unconfigured or skipped checks require reasons and remaining risk; they are not passing evidence.

## Required Evidence

- Identify the affected behavior, source of truth, ownership boundaries, and invariants that must survive, then select the relevant task checklist and validation guide.
- Use representative inputs and independent expected results for the changed contract; distinguish a demonstrated defect from an unverified assumption or pre-existing failure.
- Observe affected success and meaningful rejection, interruption, or recovery paths where behavior changes, choosing configured checks appropriate to their actual risk.
- For affected documentation, hygiene, packaging, or consumer surfaces, verify the actual references or artifacts and report untested environments instead of inferring correctness from a passing unrelated command.

## Report

Record the affected contract, artifact and environment where relevant, executed checks, actual results, skipped checks and reasons, and remaining work or risk.
Distinguish planned, delivered, active, and completed state where relevant. This guide does not authorize deployment or additional external effects.
