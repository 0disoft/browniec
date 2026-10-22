# Command Contract

- Status: Designed only; not executable
- Repository type: cli-tool

## Proposed surface

| Command | Intended behavior | Current state |
| --- | --- | --- |
| browniec --version | Report build, profile, IR, ABI, IPC, and available delivery levels | Designed |
| browniec check SOURCE | Compile and verify without running guest code or host calls | Designed |
| browniec run SOURCE | Compile, verify, and run one source with explicit input | Designed |
| browniec run --project FILE | Use an explicit source map, policy, entry, grants, and run limits | Designed |
| browniec check SOURCE --isolated | Use a restricted compile-only worker | Designed; unavailable |
| browniec run SOURCE --isolated | Use the restricted worker and parent broker | Designed; unavailable |
| browniec inspect SOURCE --ir | Emit bounded private diagnostics | Designed |
| browniec worker | Broker-only restricted IPC endpoint | Designed; unavailable |

User-facing commands may request --json; its proposed shape is not yet a stable
schema. run SOURCE may select bytes with --input FILE, and project runs explicitly
select --policy FILE. These are proposed options, not implemented commands.

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
