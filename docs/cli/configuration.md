# CLI Configuration

- Status: Draft
- Repository Type: cli-tool

## Contract

Define how a command obtains, validates, and explains its effective configuration.

Project-wide decisions: docs/cli/README.md

## Required Decisions

- Configuration sources: UNDECIDED. List supported files, environment variables, and command flags.
- Configuration precedence: UNDECIDED. Define the order of defaults, files, environment, and flags.
- Missing, empty, and invalid values: UNDECIDED. Specify defaults and failure behavior separately.
- Validation and unknown keys: UNDECIDED. Identify accepted types and diagnostics.
- Effective-config output: UNDECIDED. Explain selected sources without exposing secrets.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
