# Initial Architecture Boundaries

- Status: Draft
- Owner: UNASSIGNED
- Decision date: UNDECIDED
- Supersedes: UNDECIDED
- Superseded by: UNDECIDED

Draft the initial ownership and interaction boundaries from the product needs. This seeded record does not select an architecture for the project.

## Context

- Product constraints: UNDECIDED; link the relevant outcomes and requirements in [Product Specification](../product/02-spec.md).
- Owned responsibilities: UNDECIDED; identify capabilities, state, and invariants this repository must own.
- External authority: UNDECIDED; identify other owners and contracts that this repository consumes.

## Decision

- Proposed boundaries: UNDECIDED; map responsibilities to components and name each owner.
- Trust crossings: UNDECIDED; describe exchanged data, caller authority, validation, and effect ownership.
- Boundary rationale: UNDECIDED; explain cohesion, dependency direction, and reasons for separating responsibilities.

## Alternatives

- Centralized ownership: UNDECIDED; compare a single owner with the proposed boundaries.
- Different boundary placement: UNDECIDED; compare another split and its coordination and operating costs.

## Consequences

- Failure containment: UNDECIDED; record failure propagation, interruption, retry, and recovery responsibilities.
- Handoffs and migration: UNDECIDED; describe compatibility, state transfer, and changes required of external owners.
- Boundary review trigger: UNDECIDED; identify growth or failure evidence that would justify changing the split.

## Verification

- Boundary evidence: UNDECIDED; demonstrate a representative success and failure flow across the proposed boundaries.
- Documentation alignment: UNDECIDED; keep [System Boundary](../architecture/00-system-boundary.md) and [Architecture](../../ARCHITECTURE.md) aligned with the recorded decision.
- Implementation follow-up: UNDECIDED; name remaining contract changes, owners, and observable completion criteria.
- Validation routing: [VALIDATION.md](../../VALIDATION.md); record the actual checks and results rather than assuming a draft is implemented.

## Lifecycle

- Keep this record Draft until the project owner records a dated decision and its rationale. Use Accepted or Rejected to record the outcome.
- Acceptance does not prove implementation; keep implementation evidence and follow-up work separate from decision status.
- For a material change to an accepted decision, create a new numbered ADR, mark the prior record Superseded, link both records, and preserve the previous rationale.
- Record dated amendments and update the status and links in the [ADR index](README.md).
