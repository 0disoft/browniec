# Development

- Status: Draft

## Contract

Record a reproducible local development path from project-owned tools and commands without inventing installation, build, test, or service behavior.

Project-wide decisions: VALIDATION.md

## Required Decisions

- Setup contract: UNDECIDED. Identify supported tools and runtime ranges, dependency installation, required inputs, and environment initialization from actual project configuration.
- Command inventory: UNDECIDED. Record exact project-owned command names, working directories, inputs, outputs, and whether a command finishes or starts an ongoing process.
- Local evidence: UNDECIDED. Map relevant checks to changed risks and describe reproducible execution, required environment rows, expected results, and known gaps.
- State and cleanup: UNDECIDED. Distinguish source, generated output, caches, fixtures, secrets, and mutable external state; define safe setup, reset, and recovery boundaries.
- Troubleshooting ownership: UNDECIDED. Record useful diagnostics, missing prerequisites, common failure causes, and the owner of unresolved environment or command problems.

## Verification

- Owner: UNASSIGNED
- Source of truth and related ADR: UNDECIDED
- Required evidence and remaining gaps: UNDECIDED
- Validation route: VALIDATION.md
