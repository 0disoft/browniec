# Config and Environment

- Status: Draft

## Contract

Treat configuration as a versioned behavior contract, including how values become active and how conflicting or invalid state is detected.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Configuration inventory: UNDECIDED. Identify keys, types, owners, environment scope, defaults, required values, and sensitive values that belong in secret storage.
- Source precedence: UNDECIDED. Define canonical sources, overrides, validation, and behavior for missing, malformed, or conflicting values.
- Activation and drift: UNDECIDED. Explain reload or restart requirements, active-value evidence, and detection of differences between declared and running configuration.
- Compatibility and recovery: UNDECIDED. Define key changes, version overlap, rollback limits, and preservation of valid project-specific values.
- Configuration evidence: UNDECIDED. Check representative environments, invalid inputs, partial activation, and recovery without exposing sensitive values in diagnostics.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
