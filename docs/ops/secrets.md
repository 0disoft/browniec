# Secrets

- Status: Draft

## Contract

Assign secret ownership and lifecycle responsibilities while keeping secret values out of repository documentation, examples, telemetry, and build artifacts.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Secret inventory: UNDECIDED. Record references, purpose, owner, consumers, environment scope, and storage authority without recording plaintext values.
- Access boundary: UNDECIDED. Define issuance, retrieval, permitted identities, execution scope, audit evidence, and separation between build and runtime access.
- Rotation and revocation: UNDECIDED. Specify replacement ordering, overlap limits, consumer adoption, invalidation, and how failed rotation is detected and recovered.
- Exposure response: UNDECIDED. Define containment, revocation, affected copies, artifact or log handling, communication, and recovery evidence after a suspected leak.
- Lifecycle evidence: UNDECIDED. Verify consumers use the intended current identity and that revoked or retired credentials no longer authorize work.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
