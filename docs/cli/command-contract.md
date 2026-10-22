# Command Contract

- Status: Draft
- Repository Type: cli-tool

## Contract

Specify each command's inputs, side effects, cancellation, and compatibility independently of its implementation.

Project-wide decisions: docs/cli/README.md

## Required Decisions

- Command purpose and side effects: UNDECIDED. State what success changes and what requires confirmation.
- Argument grammar: UNDECIDED. Define positional arguments, flags, defaults, aliases, and incompatible options.
- Path and working-directory rules: UNDECIDED. Specify target resolution and overwrite boundaries.
- Dry-run, retry, and cancellation: UNDECIDED. Define repeatability and recovery after partial work.
- Compatibility and deprecation: UNDECIDED. Identify observable changes and migration guidance.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
