# Domain Model

- Status: Draft

## Contract

Describe the concepts and invariants owned by the product without treating a storage schema or framework model as the domain definition.

Project-wide decisions: docs/architecture/00-system-boundary.md

## Required Decisions

- Domain vocabulary: UNDECIDED. Define important terms, business meanings, ambiguities, and which owner resolves competing definitions.
- Identity and lifecycle: UNDECIDED. Identify entity or value identities, valid states, transitions, and deletion or retention behavior.
- Invariants: UNDECIDED. Record uniqueness, relationship, ownership, and state rules that must hold through ordinary work and recovery.
- Commands and outcomes: UNDECIDED. Specify who may request a change, its preconditions, resulting facts, and expected business rejections.
- Consistency boundaries: UNDECIDED. Define what changes together, what may temporarily diverge, and how conflicting or partial changes are reconciled.
- Evolution examples: UNDECIDED. Provide representative valid and invalid scenarios, compatibility rules, and evidence required when meanings or invariants change.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
