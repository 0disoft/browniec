# CLI Tool

- Status: Experimental native M1 scalar CLI implemented; earlier slices and unsigned scalars have verified historical receipts; explicit widening historically verified; bitwise operators and checked shifts implemented and verified
- Native runtime intent: direct .brc source execution
- Contract owner: docs/cli/command-contract.md

## Boundary

The CLI is the developer-facing route to the Brownie compiler, verifier, and native
VM. It does not ship a Go runtime or compiler toolchain to end users. Compile and run
must work without launching Go, MSVC, a C compiler, or an interpreter subprocess.
Restricted mode may launch the designated native worker.

The proposed surface is --version, check, run, inspect, and worker, with explicit
--project and --isolated options where applicable. check, run, --version and --help
are implemented for the M1 scalar profile.
The broader commands/options remain designed or unavailable.

The current scalar increment adds i32/i64/u8/u32/usize/bool values, explicit
widening, bounded branches, loops, shallow `Option`/`Result` values with exhaustive
`switch` statements and expressions. It keeps
`main` as a zero-argument i32 function, so the CLI result field remains
`return_i32`; guest integer, bool, and wrapper values are internal to the program. The tagged slice
remains verified by its [historical receipt](../evidence/m1-tagged-windows-20261023.json).
Postfix `?` propagates shallow scalar Option and Result payloads. Switch expressions
add exhaustive shallow-wrapper arms in expression position with one exact yield
type, restricted value-arm statements, and optional direct returns. The earlier
receipts, including i64, are historical; the switch-expression receipt records 41
native groups and 580 CLI cases, and the i64 receipt records 49 native groups and
760 CLI cases in each profile. The unsigned increment keeps `main` and the JSON
result contract unchanged while adding internal unsigned values. Wrappers remain
i32/bool payloads; i64 and unsigned wrapper payloads are unsupported, and functions
returning i64 or an unsigned type reject `?`. The
[unsigned receipt](../evidence/m1-unsigned-windows-20261023.json) records 59 native
groups and 1,159 CLI cases in both development and release, including 399 cases; it
remains historical after explicit widening. `EXPR as TYPE` admits seven
domain-preserving integer pairs and adds no implicit conversion or promotion. The
CLI profile and `return_i32` field are unchanged. The
[widening receipt](../evidence/m1-widening-windows-20261023.json) records 67 native
groups and 1,272 CLI cases in each profile, including 113 widening cases.
The [integer-operator contract](../engineering/m1-integer-operators.md) adds
fixed-width bitwise operations and checked shifts. Shift count and range failures
use the existing runtime `overflow` outcome and exit code 5. There is no new CLI
option, result field, profile identifier, or implicit integer/bool conversion.
The [integer-operator receipt](../evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each development and release profile.
Language contracts are in the [branch](../engineering/m1-branches.md), [loop](../engineering/m1-loops.md),
[tagged](../engineering/m1-tagged.md), and
[propagation](../engineering/m1-propagation.md) documents, with switch-expression
rules in the [switch-expression contract](../engineering/m1-switch-expressions.md),
full-width signed integer rules in the [i64 contract](../engineering/m1-i64.md),
unsigned rules in the [unsigned contract](../engineering/m1-unsigned.md), and cast
rules in the [widening contract](../engineering/m1-widening.md). Command availability,
output framing, and exit behavior remain governed by the owning CLI documents.

## Authority and availability

Command syntax, paths, cancellation, and compatibility are owned by the command
contract. Configuration precedence is owned by configuration.md. Output framing and
exit status are owned by output-and-exit-codes.md.

Core CLI, restricted worker, and embed DLL are separate delivery levels. Missing
restricted support rejects isolated commands. Missing ABI support does not block the
core CLI. Capabilities never expand because a command option is present.

## Review blockers

- A command claims execution without a native artifact and recorded evidence.
- check or run starts a compiler child process.
- Policy or catalog files are discovered implicitly from the source folder.
- Guest return data is reported as the CLI process exit code.
- Output is published before normal completion and its publication barrier.
- External effects are automatically replayed after an unknown outcome.
- Help, JSON framing, diagnostics, and exit codes disagree with actual state.
