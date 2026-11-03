# Testing Standard

- Status: Accepted evidence approach; M0 and M1 native harnesses available

## Proportionate checks

Use the narrowest check that can establish the changed behavior. Do not create a
large CI matrix for documentation work or repeat valid checks for unchanged inputs.
Run broader checks when source semantics, security boundaries, or release scope
require them. Never report a missing command or skipped check as a pass.

## Milestone coverage

- M0: native codec extremes, checked arithmetic status, fallible storage, quota
  rollback/peak accounting, and stale-generation rejection.
- M1: real scalar source through parser, type/Flow, codegen, verifier, and native VM.
- M2: aggregate constructors/copy/replacement/parameters/results and whole-root
  scalar-slice loans, aliases/reborrows and named/ranged/temporary CALL captures;
  returned-view proof/handoff/retention, guest Buffer, text/input/output and cleanup.
  Private native components and source-only origin analysis do not close guest
  integration or full-profile coverage.
- M3: fake in-memory typed host replies, cancellation, malformed/duplicate replies.
- M4: actual Windows isolation, broker phase/cancellation, exit/EOF, and I/O leases.
- M5: real DLL export/call, clean-machine delivery, and named performance workloads.

Expected results come from the contract and independently chosen vectors. Include
the broker ordering, layout-depth separation, and minimum-capacity Buffer fallback
cases in the [review findings](../design-baseline.md).

## Evidence limits

A model is useful as an oracle but cannot replace native or OS integration evidence.
Record commands, artifact identity, environment, actual result, skips, and gaps.
Long fuzzing and benchmarks may run manually when their risk justifies the cost.
Retire tests for removed behavior while preserving coverage of surviving contracts.
The [validation policy](../../VALIDATION.md) owns evidence levels and reporting.

## Reconciled evidence scope

The [remaining-work audit](../product/04-remaining-work.md) tracks public, private
and missing boundaries as of 2026-11-03. Focused Windows receipts are increment-
specific; counts are not additive full-suite evidence. A docs-only audit checks
links, requirement coverage and recorded identities without rerunning native suites.
Retain original receipt skips/reuse and never mark reference-bundle cases executed
merely because an equivalent low-level primitive has a test.
