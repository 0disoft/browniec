# CI

- Status: Draft

## Contract

Define the smallest reliable verification pipeline for the changed risks, with reproducible evidence and explicit execution and cost boundaries.

Project-wide decisions: docs/ops/00-operational-contract.md

## Required Decisions

- Verification scope: UNDECIDED. Map checks and environment rows to affected contracts, runtime support, packaging, or user-visible risks instead of running every check by default.
- Evidence identity: UNDECIDED. Tie results to the tested commit, toolchain, inputs, and produced artifact; distinguish a passing check from publication or deployment.
- Execution boundary: UNDECIDED. Specify trusted and untrusted inputs, credential access, job permissions, isolation, and which jobs may publish or mutate external state.
- Failure and interruption: UNDECIDED. Define blocking checks, timeouts, concurrency cancellation, partial output, retry eligibility, and local reproduction.
- Cost and duplication: UNDECIDED. Set a justified matrix and run frequency, reuse equivalent evidence, and avoid duplicate build or package checks without losing required coverage.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
