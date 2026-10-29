# Command Contract

- Status: Experimental scalar check/run/version implemented; other surfaces designed
- Repository type: cli-tool

## Surface and availability

| Command | Intended behavior | Current state |
| --- | --- | --- |
| browniec --version | Report experimental profile and delivery availability; full metadata planned | Implemented for brownie.m1-scalar/1 |
| browniec check SOURCE | Compile and verify without running guest code or host calls | Implemented for brownie.m1-scalar/1 |
| browniec run SOURCE | Compile, verify, and run one selected source | Implemented for brownie.m1-scalar/1 |
| browniec run --project FILE | Use an explicit source map, policy, entry, grants, and run limits | Not implemented |
| browniec check SOURCE --isolated | Use a restricted compile-only worker | Designed; unavailable |
| browniec run SOURCE --isolated | Use the restricted worker and parent broker | Designed; unavailable |
| browniec inspect SOURCE --ir | Emit bounded private diagnostics | Not implemented |
| browniec worker | Broker-only restricted IPC endpoint | Designed; unavailable |

The implemented grammar is `browniec check SOURCE [--json]` and
`browniec run SOURCE [--fuel N] [--json]`, plus `--version [--json]` and `--help`.
Fuel defaults to 256 and accepts 0..1000000; duplicate/unknown options are errors.
Run grants no guest host capability. SOURCE selects one local disk file with a
4096-byte UTF-8 source limit. The experimental [M1 scalar subset](../engineering/m1-scalar-slice.md),
scalar arrays (including [named u8-array UTF-8 validation](../engineering/m2-array-utf8-source.md)),
and [helper-local records](../engineering/m2-struct-function-source.md)
are implemented. Project, input-byte, policy, catalog, inspect, and worker options
remain unavailable. `--isolated` returns an availability denial, with no fallback.

## Execution rules

check and run read bounded source snapshots and invoke the native Brownie frontend
directly. Neither may launch Go, MSVC, a C compiler, or another compiler child.
Worker mode is not an interactive interpreter and rejects user-supplied handles.

Project members are explicit, root-relative paths. Glob expansion, ambient
policy/catalog lookup, absolute or parent member paths, alternate streams, device
names, duplicate canonical paths, and
case collisions are rejected by design. Untrusted file collection requires anchored
root membership and reparse-point checks; until implemented, use a host snapshot.

## Failure and compatibility

Cancellation closes publication immediately. Preparation failure for isolated mode
must reject rather than fall back to an unrestricted process. External effects are
not replayed automatically. Guest i32 return data is separate from CLI exit status.

Changing command grammar, path resolution, output framing, exit codes, or delivery
availability requires updates to configuration.md, output-and-exit-codes.md, and
compatible consumer evidence.
