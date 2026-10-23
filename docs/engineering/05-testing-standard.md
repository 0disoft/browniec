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
- M2: aggregate initialization/copying, whole-root borrows, Buffer growth, and bytes.
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
