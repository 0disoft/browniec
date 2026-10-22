# Project Invariants

- Status: Draft

## Contract

Name the properties that must remain true through ordinary changes, concurrent work, interruption, migration, and recovery.

Project-wide decisions: docs/architecture/00-system-boundary.md

## Required Decisions

- Invariant inventory: UNDECIDED. Record each required property, affected state or contract, reason it matters, and the owner who can clarify it.
- Authority boundaries: UNDECIDED. Identify who may change each authoritative fact and distinguish source decisions from derived copies or cached state.
- Effect completion: UNDECIDED. Define when an effect is accepted, committed, or observable and which evidence permits a success report.
- Partial and conflicting state: UNDECIDED. Describe state allowed after interruption, retries, concurrent changes, and failed recovery without assuming effects were undone.
- Invariant evidence: UNDECIDED. Connect important properties to independent checks and representative invalid scenarios, including remaining coverage gaps.
- Change authority: UNDECIDED. Identify the rationale and consumer evidence required before intentionally revising an invariant.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
