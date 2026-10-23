# Output and Exit Codes

- Status: Experimental M1 scalar results implemented; wider output remains designed
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

The M1 CLI implements these classes for its subset. There is no cancellation,
deadline, worker IPC, or host-binding implementation yet. A source-file read failure
uses code 7. Verification failure is an internal code 6, not a guest trap.

## Implemented scalar JSON result

`--json` emits one object followed by a newline on stdout, with empty stderr:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

The command is `check` or `run`; status is `checked`, `completed`, or `error`.
Only completed runs have a numeric return_i32. Failures carry an error object with
`kind` and zero-based source `byte_offset`. Kinds are lexical, syntax, type,
compile_limit, verification, overflow, zero_divisor, fuel, input_io, usage, and
unavailable. Non-source failures use offset 0; internal verifier errors identify an
instruction index. JSON mode is honored once its option has been parsed.

Text mode leaves stdout empty and writes checked status, return_i32, or diagnostics
to stderr. Guest output bytes and output_b64 are not implemented. Version JSON uses
`browniec.version/v1` and reports the experimental profile and delivery availability.

Result JSON is staged in an owned Buffer before a single console write. If encoding
or sink writing fails, exit 7 applies; the sink can already hold a partial write.
No second success/error document is appended to partially written JSON.

## Completion and failure

A normal result requires the expected computation to complete, required output staging
to succeed, and publication checks to pass. Guest nonzero remains a normal run result.
Trap, cancellation, deadline, quota, or internal failure publishes no staged output.

A host output sink may fail after computation with code 7. Its partial external effect
is reported rather than hidden or replayed. Cancellation closes publication; unknown
external effects remain unknown. No automatic retry or exactly-once claim is allowed.
