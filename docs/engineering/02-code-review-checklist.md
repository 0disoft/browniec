# Code Review Checklist

- Status: Draft

## Contract

Review the concrete observable change and its invariant, ownership, effect, and compatibility consequences using evidence relevant to the affected behavior.

Project-wide decisions: docs/engineering/00-project-invariants.md

## Required Decisions

- Observable change: UNDECIDED. Describe the trigger, previous behavior, new behavior, affected users or consumers, and intended scope.
- Authority and compatibility: UNDECIDED. Identify changed contracts, access or ownership rules, derived surfaces, and consumers needing synchronized updates.
- Effect correctness: UNDECIDED. Review reads, mutations, external effects, interruption, retries, and what the reported outcome proves.
- Evidence quality: UNDECIDED. Select meaningful success, rejection, and recovery checks with an independent expected result; disclose skipped or indirect evidence.
- Delivery and recovery: UNDECIDED. Identify migration, rollout, operating, and restoration work required before the change can be used safely.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
