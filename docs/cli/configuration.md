# CLI Configuration

- Status: Scalar CLI flags implemented; project/policy configuration designed only
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

The current CLI implements only source selection, --json, and a run-only --fuel
limit. No project, policy, catalog, environment configuration, effective-config, or
run-grant loader exists. Unsupported options are rejected rather than ignored.
