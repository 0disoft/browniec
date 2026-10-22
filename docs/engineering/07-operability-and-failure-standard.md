# Operability and Failure Standard

- Status: Draft

## Contract

Make failure state, observable completion, diagnosis, and recovery responsibility explicit for each important owned effect.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Failure state: UNDECIDED. Describe rejected, unavailable, interrupted, partially committed, and unknown outcomes at the operation's effect boundaries.
- Completion reporting: UNDECIDED. Tie public success or failure to observable evidence and disclose committed effects or incomplete recovery accurately.
- Recovery ownership: UNDECIDED. Assign retries, compensation, reconciliation, restore, escalation, and bounded termination conditions to responsible owners.
- Diagnostic contract: UNDECIDED. Provide useful operation identities, original and recovery causes, safe public messages, and telemetry without exposing sensitive values.
- Failure evidence: UNDECIDED. Demonstrate representative interruption and recovery paths and align runbooks, alerts, and operator actions with the actual remaining state.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
