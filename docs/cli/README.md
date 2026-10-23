# CLI Tool

- Status: Experimental native M1 scalar CLI implemented; bool/branch, loop, and tagged slices verified; scalar `?` propagation verified
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

The current scalar increment adds i32/bool values, bounded branches, loops, and
shallow `Option`/`Result` values with exhaustive `switch` statements. It keeps
`main` as a zero-argument i32 function, so the CLI result field remains
`return_i32`; guest bools and wrappers are internal to the program. The tagged slice
remains verified by its [historical receipt](../evidence/m1-tagged-windows-20261023.json).
Postfix `?` propagates shallow scalar Option and Result payloads; the current
[propagation receipt](../evidence/m1-propagation-windows-20261023.json) records
37 native groups and 510 CLI cases in each development and release profile.
Language contracts are in the [branch](../engineering/m1-branches.md), [loop](../engineering/m1-loops.md),
[tagged](../engineering/m1-tagged.md), and
[propagation](../engineering/m1-propagation.md) documents. Command availability,
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
