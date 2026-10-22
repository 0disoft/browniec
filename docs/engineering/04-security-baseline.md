# Security Baseline

- Status: Draft

## Contract

Connect protected assets and operations to explicit control ownership and evidence at the relevant trust boundaries.

Project-wide decisions: docs/engineering/00-project-invariants.md

## Required Decisions

- Protected operations: UNDECIDED. Identify sensitive data, important effects, caller capabilities, and invariants that must survive misuse or unauthorized access.
- Trust crossings: UNDECIDED. Identify untrusted inputs, identities, destinations, dependencies, and the validation required when control or data crosses a boundary.
- Control ownership: UNDECIDED. Assign identity, permission, isolation, secret handling, audit, and failure-containment responsibilities to their actual owners.
- Control evidence: UNDECIDED. Select relevant rejection, revocation, cross-owner, unavailable-control, and resource-exhaustion scenarios without treating a checklist as proof.
- Residual risk: UNDECIDED. Record uncovered scenarios, assumptions, mitigation or containment owners, and conditions that require reassessment.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
