# Rollback

- Status: Draft

## Contract

Choose a safe recovery action from the actual failed state rather than assuming that restoring an older artifact reverses every effect.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Observed state: UNDECIDED. Identify active artifacts, configuration, data versions, external effects, user impact, and unresolved completion before acting.
- Recovery eligibility: UNDECIDED. Determine reversible steps, compatibility limits, irreversible effects, and when rollback must yield to reconciliation or forward repair.
- Recovery procedure: UNDECIDED. Record the selected target, owner, operation order, checkpoints, and how a partial or repeated recovery attempt is handled.
- Restoration evidence: UNDECIDED. Verify state integrity, supported consumers, and critical user journeys against the intended recovery target.
- Stop and escalation: UNDECIDED. Define time limits, unsafe or unconfirmed states, communication, and the owner of unresolved recovery decisions.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
