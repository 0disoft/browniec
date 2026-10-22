# Observability

- Status: Draft

## Contract

Make operating signals answer concrete diagnosis and recovery questions rather than collecting telemetry without a responsible action.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Diagnosis questions: UNDECIDED. Identify user impact, failures, delay, capacity, and unknown effects that an operator must distinguish.
- Signal interpretation: UNDECIDED. Specify events, metrics, traces, units, observation points, aggregation windows, exclusions, and missing-data meaning.
- Correlation boundaries: UNDECIDED. Define operation, attempt, artifact, environment, and dependency identities without confusing request acceptance with effect completion.
- Collection constraints: UNDECIDED. Bound sampling, telemetry overhead, sensitive fields, access, retention, and failure of the collection path.
- Actionable response: UNDECIDED. Connect each actionable threshold to an owner, diagnosis steps, recovery choices, and evidence that the condition cleared.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
