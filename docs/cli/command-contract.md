# Command Contract

- Status: Experimental native scalar/aggregate/scalar-slice check/run/version; wider surfaces designed (2026-11-03)
- Repository type: cli-tool

## Surface and availability

| Command | Intended behavior | Current state |
| --- | --- | --- |
| browniec --version | Report experimental profile and delivery availability; full metadata planned | Implemented for the bounded M1/M2 feature subsets |
| browniec check SOURCE | Compile and verify without running guest code or host calls | Implemented for the bounded M1/M2 feature subsets |
| browniec run SOURCE | Compile, verify, and run one selected source | Implemented for the bounded M1/M2 feature subsets |
| browniec eval-i32 SOURCE N | Evaluate a scalar rule with one signed decimal i32 input | Implemented for `module main` sources with `fn i32 evaluate(i32 ...)` |
| browniec check --project FILE | Check an explicit source map and its named entry | Windows, zero-argument i32 entry, empty requirements |
| browniec run --project FILE [--input FILE or --stdin] | Run the checked named entry | Windows, zero-argument i32 entry or one shared-byte parameter with explicit input, empty requirements |
| browniec check SOURCE --isolated | Use a restricted compile-only worker | Designed; unavailable |
| browniec run SOURCE --isolated | Use the restricted worker and parent broker | Designed; unavailable |
| browniec inspect SOURCE --ir | Compile/verify and emit bounded private IR diagnostics without executing | Implemented for the same public M1/M2 admission as check; optional --json |
| browniec inspect SOURCE --limits --json | Report consumed and remaining compile capacity without executing | Implemented for the same public M1/M2 admission as check |
| browniec worker | Broker-only restricted IPC endpoint | Designed; unavailable |

The implemented grammar is `browniec check SOURCE [--json|--json-v2]` and
`browniec run SOURCE [--fuel N] [--json|--json-v2]`, `browniec inspect SOURCE --ir [--json]`,
`browniec inspect SOURCE --limits --json`, plus `--version [--json]` and `--help`.
Scalar evaluation uses `browniec eval-i32 SOURCE N [--fuel N] [--json|--json-v2]`.
On Windows, check and run also accept `--project FILE` in place of `SOURCE`.
Fuel defaults to 256 and accepts 0..16000000; duplicate/unknown options are errors.
Run grants no guest host capability. SOURCE selects one local disk file with a
4096-byte UTF-8 source limit. The public language supports six scalar types,
fixed scalar arrays, nominal scalar/nested records, aggregate parameters/results,
shared/exclusive scalar slices, inline whole/ranged/temporary CALL borrows and
array/view UTF-8 checks. Exact grammar and limits remain narrower than the target
profile; the [complete audit](../product/04-remaining-work.md) lists every gap.

Version JSON reports incremental flags alongside the existing scalar/array/struct
profile identifiers. `core: true` advertises only the experimental native CLI.
The [retained reference profile](../engineering/public-program.md) admits immutable
byte/text literals, explicit text::bytes/equality and shared byte parameters/results.
General mutable/non-byte/Buffer/input results and host-visible reference tickets
remain unavailable.
Guest Buffer/output, policy/catalog/grant CLI loaders, worker,
cancellation and deadlines remain unavailable. `--isolated` returns an availability
denial, with no unrestricted fallback. Ordinary check/run use zero-argument i32
`main`. The separate eval-i32 command selects a single-i32 `evaluate` entry.
The source file is not a guest input snapshot.

## Execution rules

check and run read bounded source snapshots and invoke the native Brownie frontend
directly. Neither may launch Go, MSVC, a C compiler, or another compiler child.
Worker mode is not an interactive interpreter and rejects user-supplied handles.

Project members are explicit, root-relative paths. Glob expansion, ambient
policy/catalog lookup, absolute or parent member paths, alternate streams, device
names, duplicate canonical paths, and
case collisions are rejected. On Windows, the explicitly selected manifest and
its members are read through the same directory anchor. See the
[project configuration contract](configuration.md#project-selection).

## Failure and compatibility

Cancellation/publication below describe the target lifecycle; current availability
is stated above and in the [output contract](output-and-exit-codes.md).

Cancellation closes publication immediately. Preparation failure for isolated mode
must reject rather than fall back to an unrestricted process. External effects are
not replayed automatically. Guest i32 return data is separate from CLI exit status.

Changing command grammar, path resolution, output framing, exit codes, or delivery
availability requires updates to configuration.md, output-and-exit-codes.md, and
compatible consumer evidence.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.

IR inspection is read-only diagnostic output, not reloadable bytecode. It exposes
no new source/capability admission. See [the exact contract](../engineering/inspect-ir.md)
for output bounds, fields, source limits and verified Windows cases.
