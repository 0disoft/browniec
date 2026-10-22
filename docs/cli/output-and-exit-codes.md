# Output and Exit Codes

- Status: Draft
- Repository Type: cli-tool

## Contract

Keep terminal and machine-readable results consistent with the actual command outcome.

Project-wide decisions: docs/cli/README.md

## Required Decisions

- Output schema: UNDECIDED. Define JSON fields, versioning, and single-result framing.
- stdout and stderr: UNDECIDED. Separate machine-readable results, diagnostics, progress, and prompts.
- Exit-code taxonomy: UNDECIDED. Distinguish success, validation failure, conflict, and interruption.
- Completion boundary: UNDECIDED. Specify when writes, recovery, and cleanup permit a success report.
- Partial failure details: UNDECIDED. Preserve original causes and accurately report remaining changes.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
