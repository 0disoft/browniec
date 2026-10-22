# Output and Exit Codes

- Status: Designed only; proposed JSON shape is not implemented
- Guest integer: data, never the process exit code

## Process exits

| Code | Meaning |
| --- | --- |
| 0 | Normal compile or run completion, including a nonzero guest i32 |
| 2 | Command or configuration shape error |
| 3 | Source syntax, type, Flow, or compile-limit failure |
| 4 | Policy, grant, entry, or host-binding rejection |
| 5 | Guest trap, cancellation, deadline, or quota termination |
| 6 | Internal compiler or VM invariant failure |
| 7 | Worker, IPC, forced termination, or output-sink failure |

These codes are design taxonomy. No executable mapping is validated.

## Proposed result content

A future JSON result may carry schema, build, profile, status, return_i32, output_b64,
diagnostic or trap data, and metrics. The field names and versioning are not stable
until an implementation records its schema. Binary worker IPC should carry bytes
directly; human CLI JSON may use Base64 for output bytes.

One invocation should produce one machine-readable result. Progress or prompts belong
on stderr and must not corrupt JSON on stdout. Text mode may write output bytes to
stdout and result metadata or diagnostics to stderr.

## Completion and failure

A normal result requires the expected computation to complete, required output staging
to succeed, and publication checks to pass. Guest nonzero remains a normal run result.
Trap, cancellation, deadline, quota, or internal failure publishes no staged output.

A host output sink may fail after computation with code 7. Its partial external effect
is reported rather than hidden or replayed. Cancellation closes publication; unknown
external effects remain unknown. No automatic retry or exactly-once claim is allowed.
