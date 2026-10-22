# Contract Source of Truth

- Status: Draft
- Owner: UNASSIGNED
- Decision date: UNDECIDED
- Supersedes: UNDECIDED
- Superseded by: UNDECIDED

Draft where each contract fact is authoritative and how derived consumers stay aligned. This seeded record does not designate project-specific sources.

## Context

- Contract inventory: UNDECIDED; list contract facts, existing representations, owners, and affected consumers.
- Current disagreement: UNDECIDED; record duplication or conflicting behavior and the evidence showing its impact.
- Compatibility constraints: UNDECIDED; identify consumers and versions that must continue working.

## Decision

- Canonical authority: UNDECIDED; designate one authoritative source and owner for each contract fact.
- Derived consumers: UNDECIDED; identify generated or manually maintained copies and their update direction.
- Conflict resolution: UNDECIDED; explain how conflicting representations are resolved without accepting a derived copy as authority.

## Alternatives

- Keep separate definitions: UNDECIDED; compare coordination costs and the likelihood of divergent changes.
- Shared schema or generation: UNDECIDED; compare tooling cost, compatibility, and limits against explicit manual synchronization.

## Consequences

- Update responsibilities: UNDECIDED; identify who changes authority and synchronizes each consumer.
- Migration and compatibility: UNDECIDED; define the transition order, affected consumers, and recovery if adoption fails.
- Authority review trigger: UNDECIDED; identify when a new consumer or contract change requires revisiting this decision.

## Verification

- Drift detection: UNDECIDED; define a check that detects disagreement between the authoritative fact and its consumers.
- Compatibility evidence: UNDECIDED; verify representative consumers and link the observed behavior.
- Follow-up work: UNDECIDED; assign synchronization and migration tasks with completion criteria.
- Validation routing: [VALIDATION.md](../../VALIDATION.md); record the actual checks and results rather than assuming a draft is implemented.

## Lifecycle

- Keep this record Draft until the project owner records a dated decision and its rationale. Use Accepted or Rejected to record the outcome.
- Acceptance does not prove implementation; keep implementation evidence and follow-up work separate from decision status.
- For a material change to an accepted decision, create a new numbered ADR, mark the prior record Superseded, link both records, and preserve the previous rationale.
- Record dated amendments and update the status and links in the [ADR index](README.md).
