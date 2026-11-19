# CLI Configuration

- Status: SOURCE/JSON/Fuel flags and native project metadata implemented; project file/CLI, policy and input loaders pending (2026-11-05)
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

The current scalar/array/record/scalar-slice CLI implements only SOURCE selection,
`--json` and run-only `--fuel` (default 256, range 0..16000000). SOURCE is one UTF-8
code file up to 4096 bytes, not guest input; zero-argument i32 `main` is fixed. This CLI has no project, policy, catalog, environment configuration, effective-config, or
run-grant loader exists. Unsupported options are rejected rather than ignored.

`--isolated` reports unavailable without fallback. Guest input/output, deadline and
cancellation settings have no implementation. See the
[complete remaining-work audit](../product/04-remaining-work.md) before treating any
target configuration field or reference-package schema as accepted by this CLI.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.

The [retained public path](../engineering/public-program.md) admits byte/text and
shared-byte result source with its canonical Fuel schedule. Native [source
snapshots](../engineering/module-sources.md) now own explicit identities and original
bytes, but no filesystem project/source-map loader or additional CLI flag is implemented.

The [native project input primitives](../engineering/project-input.md) now supply
bounded JSON tokens and canonical spelling checks. The [typed native project format](project-format.md) now admits a complete owning
source map, entry and declared requirements. File collection, filesystem anchoring,
a CLI flag and grants remain pending.

`inspect SOURCE --ir [--json]` uses the same explicit source selection and public
admission as check. `--ir` is required once; Fuel and guest-input options do not
apply. It never executes the Program or loads policy/catalog/grants. See
[IR inspection](../engineering/inspect-ir.md).
