# CLI Configuration

- Status: SOURCE/JSON/Fuel flags, explicit Windows project manifests and binary project input implemented. Policy loaders are pending.
- Default host capability: deny

## Explicit inputs

The proposed CLI obtains configuration only from command flags and explicitly named
project, run, policy, catalog, source, and input files. It does not discover project
files, policies, catalogs, or credentials by walking from the source directory.

The trusted policy is a ceiling. A project or run may narrow its limits and grants
but cannot raise the ceiling. Declared requirements do not grant capability. The
accepted relation is reachable requirements within declared requirements within
run grants within the policy ceiling.

## Precedence

Policy supplies hard ceilings and default-deny host behavior. The explicit project
supplies source identity and entry selection. Run configuration and flags supply a
bounded restriction for one invocation. A requested grant that is absent or exceeds
the ceiling fails; it is never silently dropped or expanded.

Missing required values fail. Empty values are invalid unless a documented field
allows empty bytes. Unknown fields, duplicate keys, invalid UTF-8, excess depth,
excess bytes, and values outside schema bounds are rejected during bounded input.

For check, run and eval-i32, choose a single output format. Text is the default,
`--json` selects result v1, and `--json-v2` selects result v2.

The positional input to eval-i32 is a signed decimal integer from
-2147483648 to 2147483647. Invalid input is rejected before the source is opened.
It uses the same Fuel option and defaults as run.

## Paths and secrets

Policy, catalog, and source paths require explicit selection. Path traversal,
absolute or UNC project members, alternate data streams, device names, and filesystem
case collisions are rejected by design. Configuration must not contain credentials;
host adapters own their external authorization.

## Effective configuration

Diagnostics may report selected source names, limits, and policy identities. They
must not expose secret values or unrelated file contents. A future effective-config
output is diagnostic only and does not authorize execution.

SOURCE selects one UTF-8 code file up to 4,096 bytes with a zero-argument
i32 `main`. Run-only `--fuel` defaults to 256 and accepts 0..16000000.
Policy, catalog, effective-config and run-grant loaders remain pending.

`--isolated` reports unavailable without fallback. Guest output, deadline and
cancellation settings remain pending. See the
[complete remaining-work audit](../product/04-remaining-work.md) before treating any
target configuration field or reference-package schema as accepted by this CLI.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.

The [retained public path](../engineering/public-program.md) admits byte/text and
shared-byte result source with its canonical Fuel schedule. Native [source
snapshots](../engineering/module-sources.md) now own explicit identities and original
bytes.

The [native project input primitives](../engineering/project-input.md) now supply
bounded JSON tokens and canonical spelling checks. The [typed native project format](project-format.md) now admits a complete owning
source map, entry and declared requirements.

## Project selection

On Windows use `browniec check --project FILE [--json|--json-v2]` or
`browniec run --project FILE [--input FILE] [--fuel N] [--json|--json-v2]`. The manifest
may be selected by an absolute drive path or a path relative to the working
directory. Its parent is the project root. The manifest and declared sources
are read under the same local NTFS anchor. The manifest limit is 65,536
bytes. The current compiler reads at most 16 declared files and 4,096 source
bytes in total. The manifest selects a public, zero-argument i32 entry.

The current run profile permits an empty requirements array. Any declared
requirement is rejected before project members are opened. Project execution
uses the ordinary Fuel option and result formats.

Select `--input FILE` once on project run to use a public
`i32(ref u8[])` entry. The input file is independently selected by local
absolute drive path or a path relative to the process working directory.
The compiler checks the project before the file opens. The reader accepts
0 through 1,048,576 raw bytes, including NUL and invalid UTF-8, from a disk file.
The VM borrows an immutable snapshot. Use `--fuel 16000000` when trying input
programs because input metadata alone needs 32,768 Fuel. Without `--input`,
the project entry takes zero arguments.

`inspect SOURCE --ir [--json]` uses the same explicit source selection and public
admission as check. `--ir` is required once; Fuel and guest-input options do not
apply. It never executes the Program or loads policy/catalog/grants. See
[IR inspection](../engineering/inspect-ir.md).
