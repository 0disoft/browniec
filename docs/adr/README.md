# Architecture Decisions

- Status: Draft
- Owner: UNASSIGNED

## Decision Records

The generated records are draft prompts, not accepted architecture decisions. Fill them with project evidence and explicit choices before recording an outcome.

| Record | Status | Owner | Decision date | Superseded by |
| --- | --- | --- | --- | --- |
| [Initial Architecture Boundaries](0001-initial-architecture-boundaries.md) | Draft | UNASSIGNED | UNDECIDED | UNDECIDED |
| [Contract Source of Truth](0002-contract-source-of-truth.md) | Draft | UNASSIGNED | UNDECIDED | UNDECIDED |

## Recording a Decision

- Copy the [ADR template](0000-template.md) to the next unused numbered filename; the template itself is not a project decision.
- Give each record a clear decision scope, owner, context, chosen option, alternatives, consequences, and verification evidence.
- Keep new records Draft while evaluating options. Record Accepted or Rejected with a date and rationale, then update this index from the individual records.
- Acceptance does not prove implementation. Track implementation evidence and remaining work in the record and route checks through [VALIDATION.md](../../VALIDATION.md).

## Changing a Decision

- Amend drafts as evidence changes. Record dated clarifications to accepted decisions without hiding their original context.
- For a material change, create a new ADR, mark the prior record Superseded, link both records, and preserve the previous rationale.
- Keep the individual records authoritative for status, rationale, and supersession; update this index and the affected architecture or contract documents to match.
