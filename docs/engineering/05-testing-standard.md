# Testing Standard

- Status: Draft

## Contract

Choose checks that establish important behavior and recovery properties while keeping evidence reproducible, interpretable, and proportionate to the risk.

Project-wide decisions: docs/engineering/00-project-invariants.md

## Required Decisions

- Risk coverage: UNDECIDED. Map required contracts, invariants, and user outcomes to the narrowest useful unit, integration, consumer, runtime, or recovery checks.
- Independent oracle: UNDECIDED. Define expected results from the behavior contract rather than copying implementation details into assertions.
- Failure fixtures: UNDECIDED. Select meaningful invalid inputs, partial effects, concurrency ordering, interruption, and recovery scenarios using controlled fixtures where needed.
- Environment and evidence: UNDECIDED. Identify required support rows, artifact and toolchain identity, skipped conditions, and limits of automated or simulated checks.
- Evidence cost: UNDECIDED. Avoid redundant broad suites, bound execution cost, and retire checks whose original risk or contract no longer exists while preserving needed coverage.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
