# Runtime Flow

- Status: Draft

## Contract

Trace an operation from entry to observable completion and explain the state left behind at each failure or interruption point.

Project-wide decisions: docs/architecture/00-system-boundary.md

## Required Decisions

- Entry and completion: UNDECIDED. Name the initiating actor, input boundary, validation, completion predicate, and user-visible result.
- Execution ownership: UNDECIDED. Map components, asynchronous work, state owners, and the handoff that makes each step accountable.
- Effect ordering: UNDECIDED. List reads, mutations, external effects, durable receipts, and result publication in the order they can occur.
- Interruption and retry: UNDECIDED. Define cancellation ownership, timeout meaning, duplicate prevention, and what may safely resume or repeat.
- Partial state and recovery: UNDECIDED. Identify possible state after each failure, compensation or reconciliation, and unresolved outcomes needing an operator.
- Completion evidence: UNDECIDED. Connect the reported result to durable or observable effects and select representative failure and recovery scenarios.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
