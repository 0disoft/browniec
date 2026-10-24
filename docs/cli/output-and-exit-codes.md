# Output and Exit Codes

- Status: Experimental M1 scalar and M2 source-array results implemented; read verification recorded; write focused verification passed in development and release; array copy focused verification passed in development and release; wider output remains designed
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

The CLI implements these classes for its scalar and array subsets. There is no
cancellation, deadline, worker IPC, or host-binding implementation yet. A source-file read failure
uses code 7. Invalid or missing source main declarations are compile/type errors
(code 3); external entry binding in code 4 remains a future interface. Verification
failure is an internal code 6, not a guest trap. The direct-call slice adds
frame_limit as a guest quota error (code 5). The source-array slice adds
array_limit, bounds, and allocation errors, all with exit code 5.

## Implemented result profiles

`--json` emits one object followed by a newline on stdout, with empty stderr:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

A source program with at least one array declaration uses the existing schema and
reports the array-read profile after compilation succeeds:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-read/1","command":"run","status":"completed","return_i32":42,"error":null}
```

A source program with any mutable array catalog entry and no `ACOPY` uses the same
schema and reports the array-write profile after compilation succeeds:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-write/1","command":"run","status":"completed","return_i32":42,"error":null}
```

A source program containing `ACOPY` uses the same schema and reports the copy
profile after compilation succeeds:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-copy/1","command":"run","status":"completed","return_i32":42,"error":null}
```

The copy profile takes precedence when a program also has mutable array entries.
Scalar programs plus programs with only immutable arrays retain
`brownie.m1-scalar/1` and `brownie.m2-array-read/1`; programs with mutable writes
but no `ACOPY` retain `brownie.m2-array-write/1`. Compile, input, and usage failures
before successful compilation retain their existing profile behavior. A source-array
program that compiles and then fails verification or execution keeps its selected
array profile. The result schema and error kinds do not differ from the scalar
result schema.

The command is `check` or `run`; status is `checked`, `completed`, or `error`.
Only completed runs have a numeric return_i32. Failures carry an error object with
`kind` and zero-based source `byte_offset`. Kinds are lexical, syntax, type,
compile_limit, verification, overflow, zero_divisor, fuel, frame_limit, input_io, usage, and
array_limit, bounds, allocation, and unavailable. Non-source failures use offset 0;
internal verifier errors identify an instruction index. JSON mode is honored once
its option has been parsed.

Text mode leaves stdout empty and writes checked status, return_i32, or diagnostics
to stderr. Guest output bytes and output_b64 are not implemented. Version JSON uses
`browniec.version/v1`, preserves `profile` as `brownie.m1-scalar/1`, adds the
`array_profile`, `array_write_profile`, and `array_copy_profile` fields, and
reports delivery availability:

```json
{"schema":"browniec.version/v1","profile":"brownie.m1-scalar/1","array_profile":"brownie.m2-array-read/1","array_write_profile":"brownie.m2-array-write/1","array_copy_profile":"brownie.m2-array-copy/1","core":true,"restricted":false,"embed":false}
```

The CLI Fuel default remains 256 for scalar compatibility. A Program with an array
catalog prepares the default 65536-byte arena before guest execution, which costs
65537 Fuel. Array runs therefore need an explicit larger budget in the current
CLI; use `--fuel 100000` or `--fuel 1000000`. The accepted maximum is 1000000, and
remaining instruction and array-operation costs still apply. `ACOPY` charges
`49 + payload_bytes + 7 + (bool ? length : 0)`. Source and destination payloads
share the existing 65536-byte arena, and a copy adds no separate heap backing
allocation beyond that arena.

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
