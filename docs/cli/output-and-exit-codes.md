# Output and Exit Codes

- Status: Scalar/array/record/scalar-slice results implemented; guest output and broader lifecycle remain designed (2026-11-03)
- Guest integer: data, never the process exit code

## Process exits

| Code | Meaning |
| --- | --- |
| 0 | Normal check, inspection or run completion, including a nonzero guest i32 |
| 1 | A `test-i32` row returned a value different from its expected i32 |
| 2 | Command or configuration shape error |
| 3 | Source syntax, type, Flow, or compile-limit failure |
| 4 | Policy, grant, entry, or host-binding rejection |
| 5 | Guest trap, cancellation, deadline, or quota termination |
| 6 | Internal compiler or VM invariant failure |
| 7 | Worker, IPC, forced termination, or output-sink failure |

The CLI uses these exit classes for its bounded scalar, array, record and scalar-slice subsets.
The Windows scalar `worker` endpoint returns exit 4 with empty stdout and stderr
when invoked directly or with arguments. An admitted worker writes protocol frames
on its inherited pipe.
A source-file read failure uses code 7. Invalid or missing source main declarations are compile/type errors
(code 3); external entry binding in code 4 remains a future interface. Verification
failure is an internal code 6, not a guest trap. The direct-call slice adds
frame_limit as a guest quota error (code 5). The source-array slice adds
array_limit, bounds, and allocation errors, all with exit code 5.

`test-i32` writes text to stderr. Success reports the case count. A mismatch
reports the one-based row, expected result and actual result. A guest failure
reports the row and the same diagnostic and exit code as `eval-i32`. Invalid
case rows and batch allowance violations use exit 2.

The private typed-source compiler additionally uses diagnostic kind 18,
`must_use_result`, with the compile-error exit class 3. It identifies an unhandled
Result at scope/return/overwrite and early propagation boundaries independently
of native ownership. This mapping does not select the private compiler in the
public CLI or enable the public `must_use_result` capability.

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

For `browniec.result/v1`, command is `check`, `run` or `eval-i32`; status is `checked`, `completed`, or `error`.
Only completed runs have a numeric return_i32. Failures carry an error object with
`kind` and the legacy numeric `byte_offset` field. Kinds are lexical, syntax, type,
compile_limit, verification, overflow, zero_divisor, fuel, frame_limit, input_io, usage, and
array_limit, bounds, allocation, and unavailable. Non-source failures use offset 0;
the legacy field also carries instruction indices for internal verifier errors.
JSON mode is honored once its option has been parsed.

For check, run and eval-i32, `--json-v2` selects `browniec.result/v2`. The error object
contains `kind` and `location`. Location has a `kind` of `source_byte`,
`instruction_index` or `none`. Source and instruction locations include
their zero-based `offset`. An absent location omits the offset. Text mode
labels source bytes and instruction indices explicitly and omits absent locations.

For an ordinary single-file scalar call with the wrong scalar argument type,
text diagnostics show the expected and actual types and the parameter
declaration location. JSON v2 adds `expected_type`, `actual_type` and
`related_location` to the error object. The primary location points to the
call, and the related location points to the parameter name in that file.
Both include a zero-based byte offset and one-based line and byte column.
JSON v1 preserves the original `type` error and call byte offset.

For check/run/eval-i32, text mode leaves stdout empty and writes checked status, return_i32, or diagnostics
to stderr. Configured project runs require JSON. Version JSON uses
`browniec.version/v1`, preserves `profile` as `brownie.m1-scalar/1`, adds the
`array_profile`, `array_write_profile`, and `array_copy_profile` fields, and
reports delivery availability. The following shows selected fields only: actual
version JSON also emits struct profile identifiers and per-increment feature flags
for record construction/parameters/results, UTF-8 and typed mutable/reborrow/ranged/
temporary CALL slices. `core: true` does not certify full safe/0.3 completion:

```json
{"schema":"browniec.version/v1","profile":"brownie.m1-scalar/1","array_profile":"brownie.m2-array-read/1","array_write_profile":"brownie.m2-array-write/1","array_copy_profile":"brownie.m2-array-copy/1","core":true,"restricted":false,"restricted_scalar":true,"embed":false,"fuel_default":256,"fuel_limit":16000000}
```

The CLI Fuel default remains 256 for scalar compatibility. A Program with an array
catalog prepares the default 65536-byte arena before guest execution, which costs
65537 Fuel. Array runs therefore need an explicit larger budget in the current
CLI; use `--fuel 100000` or `--fuel 1000000`. The accepted maximum is 16000000, and
remaining instruction and array-operation costs still apply. `ACOPY` charges
`49 + payload_bytes + 7 + (bool ? length : 0)`. Source and destination payloads
share the existing 65536-byte arena, and a copy adds no separate heap backing
allocation beyond that arena.

Result JSON is staged in an owned Buffer before a single console write. If encoding
or sink writing fails, exit 7 applies; the sink can already hold a partial write.
No second success/error document is appended to partially written JSON.

## Completion and failure

Configured Windows project runs enforce compile and execution deadlines and
publish sealed `output::emit` transactions. General cancellation and worker
publication remain target contracts.

A normal result requires the expected computation to complete, required output staging
to succeed, and publication checks to pass. Guest nonzero remains a normal run result.
Trap, cancellation, deadline, quota, or internal failure publishes no staged output.

A host output sink may fail after computation with code 7. Its partial external effect
is reported rather than hidden or replayed. Cancellation closes publication; unknown
external effects remain unknown. No automatic retry or exactly-once claim is allowed.

## Record and borrow result profiles

Records use `brownie.m2-struct-read/1`, `brownie.m2-struct-write/1`,
`brownie.m2-struct-copy/1` or `brownie.m2-struct-nested/1`. Nested layouts select
nested; root copy/replacement/assignment selects copy; otherwise emitted scalar
field writes select write and other record programs select read. Record profiles
take precedence over array profiles in mixed Programs.
The result remains i32 from `main`; helper aggregate values never become CLI return
types. Record parameters/results and typed shared/exclusive scalar-slice arguments
are now public. No new result schema is implied by those version feature flags.

The retained `brownie.m2-reference/1` path now admits shared-byte image/runtime
results internally; the CLI still returns only scalar data and exposes no runtime
ticket. General mutable/non-byte/Buffer/input results remain unavailable.
For exact current capabilities and future metrics/output/ABI/IPC fields, use the
[complete remaining-work audit](../product/04-remaining-work.md), not a historical
increment's old rejection list.

## Retained literal and shared-byte result profile

Successfully admitted retained source uses `brownie.m2-reference/1` for check/run
results, including runtime failures. Version JSON adds `reference_profile`,
`byte_literals`, `text_literals`, `immutable_byte_views`, `shared_byte_parameters`
and `shared_byte_results`; general `array_slice_results` remains false/absent.
The schema, process exits, default 256 and ceiling 16000000 remain unchanged.
Canonical entry/leave prices apply even to image-only source, so small literal
programs need an explicit larger Fuel budget. See [the public retained contract](../engineering/public-program.md)
for exact pricing and current native/standalone evidence.

## Single-source host check

A successful catalog-backed check reports `checked` in the existing result schema.
Invalid catalog syntax, schema, and size report `usage` (2). Failure to open or
read the selected file reports `input_io` (7). Policy or grant denial reports
`unavailable` (4). Source compilation uses the existing diagnostic kinds and byte offsets.

## Single-source host run

The [configured host run](configuration.md#single-source-host-execution)
publishes the ordinary signed i32 run result. An invalid reply file reports
`usage` (2). A missing exact match or a fatal reply reports `unavailable` (4).
A guest-handled `u32` error reply follows the guest's Result branch and can
complete with exit 0. If the guest uses the success value directly, an error reply
reports `unavailable` (4) with no source location. Fuel exhaustion, run deadline and cancellation report
`fuel`, `deadline` and `cancelled` (5).

The [catalog-backed project mode](configuration.md#project-host-execution) uses the same
host result and exit classes. Compile diagnostics and located runtime traps use
the original project member path and byte column in text. JSON v2 also includes
the source index and half-open byte range. JSON v1 retains the member-relative
`byte_offset` field. The CLI resolves the location from the acquired source
snapshot using the same renderer as configured project execution.

## Project check and run

Windows project commands use the ordinary check/run results and exit classes.
A malformed or oversized manifest is a configuration error (2). Nonempty
requirements are unavailable (4), and failure to open or read the manifest or
its declared files is an input I/O error (7). Source compilation and runtime
failures use their existing error classes.

Configured checks accept text and both JSON versions. A successful check reports
`checked` with profile `brownie.m2-reference/1` and no guest output.
Configured runs accept both JSON versions. A successful publication includes
`output_b64` with standard padded Base64 and uses the existing `return_i32`.
An emitted empty result is encoded as an empty string. Any compile or run
failure leaves the field absent, including a trap after an emit. The configured
path reports `deadline`, `memory_limit`, and console `cancelled` as exit 5. Its source diagnostics
use the same canonical project locations described below.

After successful compilation, Windows source and project runs with `--input FILE` or
`--stdin` report
`brownie.m2-reference/1`. Oversized input reports `input_limit` and exit 5.
Input acquisition errors have no source location and use `input_io` and exit 7.
Guest errors keep the ordinary source diagnostic and exit conventions.

When a project source error has a validated span, text prints one line in the
form `browniec: type at lib/helper.brc:2:31`. In JSON v2 the
`source_byte` location includes the root-relative `path`, zero-based
`source_index` in the manifest's source list, and the half-open byte range
`[offset, end_offset)`. It also includes one-based `line` and `byte_column`.
Only LF advances the line. Columns count original UTF-8 bytes, including CR
before LF. JSON v1 keeps the same numeric `byte_offset` and field set.
Manifest errors, absent locations and verifier instruction indices keep
their existing forms. Only canonical source identities are rendered.
No source excerpt is read from disk.

## IR inspection

Inspection uses its own `browniec.ir/v1` schema with `command: "inspect"` and
`status: "inspected"` or `"error"`. It emits bounded ASCII text or one staged JSON
object to stdout; text failures use stderr. The [contract](../engineering/inspect-ir.md)
describes numeric instruction bytes, function/type/constant metadata, packed
unsigned cells and omitted catalog/literal contents. Output is not executable
bytecode. `inspect_ir: true` in version JSON reports only this CLI capability.
