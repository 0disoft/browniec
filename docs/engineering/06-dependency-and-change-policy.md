# Dependency and Change Policy

- Status: Draft

## Contract

Choose and maintain dependencies deliberately from the required capability, compatibility evidence, maintenance burden, and replacement cost.

Project-wide decisions: docs/engineering/00-project-invariants.md

## Required Decisions

- Necessity and alternatives: UNDECIDED. State the required capability, built-in or existing alternatives, and the cost or risk that justifies a new dependency.
- Dependency inventory: UNDECIDED. Record runtime or development role, consumer impact, maintenance owner, licensing requirements, and relevant exposure.
- Compatibility updates: UNDECIDED. Define supported major ranges, reproducible build and lock behavior, compatible-update adoption, and evidence before deliberately promoting a new major.
- Change validation: UNDECIDED. Check affected runtime, package, consumer, and behavioral contracts and disclose unsupported environments or remaining gaps.
- Replacement and exit: UNDECIDED. Identify rollback limits, data or API migration, removal work, and triggers for replacing an unmaintained or unsuitable dependency.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
