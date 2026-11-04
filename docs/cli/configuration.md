# CLI Configuration

- Status: SOURCE/JSON/Fuel flags implemented for bounded M1/M2; project/policy/input configuration designed only (2026-11-03)
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
code file up to 4096 bytes, not guest input; zero-argument i32 `main` is fixed. No project, policy, catalog, environment configuration, effective-config, or
run-grant loader exists. Unsupported options are rejected rather than ignored.

`--isolated` reports unavailable without fallback. Guest input/output, deadline and
cancellation settings have no implementation. See the
[complete remaining-work audit](../product/04-remaining-work.md) before treating any
target configuration field or reference-package schema as accepted by this CLI.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.
