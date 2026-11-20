# CLI Configuration

- Status: SOURCE/JSON/Fuel flags, explicit Windows project manifests and binary project input implemented. Configured Windows project runs load explicit policy and run files.
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
Effective-config reporting remains pending.

`--isolated` reports unavailable without fallback. Configured project runs enforce
compile and execution deadlines and support console cancellation while executing. See the
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

## Single-source host check

On Windows, `check SOURCE --catalog FILE --policy FILE --run FILE` compiles
and verifies the host dialect for the `main::main` entry. It accepts text and
both JSON output formats. All three configuration paths must be given explicitly.
Policy and run files are read first, followed by a catalog of up to 16 KiB using
`brownie.catalog/1`. The Engine binds the retained Program to the SHA-256 digest
of the parsed catalog. Each referenced capability must be declared by the run,
granted to it, and allowed by policy. The check releases the Program without
creating an Instance or invoking an adapter.

The current host compiler enforces its native dialect bounds and the policy's
source byte, lexical token (excluding EOF), function, instruction, per-function
register and compile deadline limits. The token limit is checked during catalog
binding before signature and body lowering. Function, instruction and register
limits are checked before Program retention. Full compile work accounting remains pending. See the
[host compiler contract](../engineering/host-exchange.md#scalar-host-calls-from-source).

## Single-source host execution

On Windows, run trusted local source with explicit policy, run, catalog and reply
files:

    browniec run SOURCE --catalog CATALOG --policy POLICY --run RUN --host-replies REPLIES --json

This mode uses the catalog-backed `main::main` entry and the run file's Fuel,
memory, host quotas and deadline. It also accepts text and JSON v2. The source
input flags and `--fuel` are unavailable in this mode. Console interruption
cancels the owning Instance at a runtime checkpoint.

The reply file is one UTF-8 JSON object with schema `brownie.host-replies/1`,
`catalog_sha256` (the 64 lowercase hexadecimal digits of the [canonical catalog
digest](../engineering/host-catalog.md#exact-canonical-identity)) and a
`replies` array. Each row contains exactly four fields:

| Field | Value |
| --- | --- |
| `import_id` | Numeric import ID in the selected catalog |
| `request_hex` | Complete typed request encoded as lowercase hexadecimal |
| `kind` | `0` for success, `1` for the guest's `u32` error arm, `2` for a fatal reply |
| `reply_hex` | Typed reply encoded as lowercase hexadecimal, empty for kind `2` |

For an import with ID 0 that takes i32 41 and returns i32 42, a row is
`{"import_id":0,"request_hex":"0100030000000400000029000000","kind":0,"reply_hex":"03000000040000002a000000"}`.
See the [typed wire format](../engineering/host-wire.md) for the field encoding.
The file fits in 65,536 bytes and at most 64 rows. Each wire message fits in 4,096
bytes. Hex strings use literal ASCII digits without escapes. Duplicate
`(import_id, request_hex)` pairs, invalid typed payloads and digest mismatches
fail before execution. Missing matches fail at the suspended request. A later
guest call with the same exact request can use the same row. Only an explicit
file supplies replies, and policy still controls whether the guest may call the
import. This adapter serves precomputed data from memory and causes no external
I/O when the guest calls an import.

Windows development and /O2 passed the CLI contract. It checks return values
77 and -7, text and both JSON formats, exact-match rejection, malformed and
duplicate rows, catalog binding, authority and Fuel. The owning Engine
regression passed both profiles with zero live SDK allocations after teardown.
The local Engine receipt is
`build/runtime-engine/20261120T155908271691Z/receipt.json`.

## Single-source guest input

On Windows, `run SOURCE --input FILE` and `run SOURCE --stdin` select
`pub fn i32 main(ref u8[] data)` in `module main`. Compilation verifies that entry
before opening guest input. It uses the same binary reader, 1 MiB limit and Fuel
schedule as ordinary project input below. Source diagnostics report offsets in
`SOURCE`. The input options are mutually exclusive and available only on `run`.

## Project selection

On Windows use `browniec check --project FILE [--json|--json-v2]` or
`browniec run --project FILE [--input FILE|--stdin] [--fuel N] [--json|--json-v2]`. The manifest
may be selected by an absolute drive path or a path relative to the working
directory. Its parent is the project root. The manifest and declared sources
are read under the same local NTFS anchor. The manifest limit is 65,536
bytes. The current compiler reads at most 16 declared files and 4,096 source
bytes in total. The manifest selects a public, zero-argument i32 entry.

Without policy and run files, the current run profile permits only an empty requirements array. Any declared
requirement is rejected before project members are opened. Project execution
uses the ordinary Fuel option and result formats.

Select one of `--input FILE` or `--stdin` on project run to use a public
`i32(ref u8[])` entry. Select a local file by its absolute drive path or a path
relative to the process working directory. On Windows, `--stdin` accepts a
redirected disk file or synchronous byte pipe. Input is acquired after project
compilation and can block until EOF. The reader accepts 0 through 1,048,576 raw
bytes, including NUL and invalid UTF-8. The VM borrows an immutable snapshot.
Use `--fuel 16000000` when trying input programs because input metadata alone
needs 32,768 Fuel. With neither input option the project entry takes zero arguments.

## Project host execution

Windows projects can use the same catalog and precomputed reply format as
[single-source runs](#single-source-host-execution). The project selects a
public zero-argument i32 entry. It may call guest helpers across modules and
use typed host imports inside those helpers.

    browniec check --project FILE --catalog FILE --policy FILE --run FILE
    browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE --json

The manifest and run configuration must select the same entry and declare the
same set of capabilities. The Engine checks that relation and the run's grants
against its policy before collecting source members from the manifest's directory
anchor. Each source module resolves its own host aliases against the explicit
catalog. The normal guest module visibility rules still apply. The retaining
verifier checks the catalog digest and grants for every compiled host call.

Check accepts text and both result schemas without creating an Instance or
reading a reply file. Run accepts the same output formats and requires a reply
file. The policy bounds source bytes, module count, tokens, functions,
instructions, per-function registers and the compilation deadline within the
host dialect's native limits. This mode supports the existing host dialect and
its reply-file bounds. Project input, emit and external adapters are separate
delivery paths.

The Windows development and /O2 CLI checks compile and run a two-module
project, producing 77 through a typed host response. They also cover reused
alias names across modules, qualified host calls, private guest helpers,
original member diagnostics and authority denial before source collection.
The owning Engine regression passed both profiles with zero live SDK
allocations. Its receipt is
`build/runtime-engine/20261120T161854659274Z/receipt.json`.

## Configured project output

On Windows, supply both `--policy FILE` and `--run FILE` to `run --project`.
Choose `--json` or `--json-v2` to receive the result. Fuel comes from the
run configuration. The configured command rejects an additional `--fuel` flag.

Policy and run files are explicitly selected disk files up to 65,536 bytes
each. The run selects the same entry and requirements as the manifest and can
only narrow the policy ceiling. The configured entry takes a single shared
byte slice. Pick `--input FILE` or `--stdin` for binary input. Omitting both
supplies an empty snapshot. The input limit is the smaller of the configured
input and memory limits, capped at 1 MiB. Read completes before guest execution
starts, after project compilation and authority checks.

Use `check --project FILE --policy FILE --run FILE [--json|--json-v2]` to
validate the same policy, grant, entry and source under the compile deadline.
Check accepts text and both JSON formats. It opens no guest input, creates no
Instance and executes no guest code. `--fuel`, `--input` and `--stdin` are run-only.

The only configured guest capability in this command is `brownie.output.emit`.
A project that calls it must declare it, the run must grant it, and the policy
must allow it. A successful emit is published as `output_b64`. The guest return
value remains a separate field in the same JSON object.

During configured execution on a Windows console, Ctrl+C or Ctrl+Break requests
cancellation. The Engine samples the request between steps and preserves any
already committed terminal result. A cancelled run exits 5 with `cancelled`
and discards staged output. Compilation and synchronous input acquisition finish
before the console handler is registered.

From the repository root on Windows, run the checked-in example:

```powershell
$project = 'examples/projects/configured-output'
./build/browniec.exe run --project "$project/project.json" --policy "$project/policy.json" --run "$project/run.json" --input "$project/app.brc" --json-v2
```

The command returns 77 in `return_i32` and encodes the exact bytes passed to
the entry in `output_b64`.

`inspect SOURCE --ir [--json]` uses the same explicit source selection and public
admission as check. `--ir` is required once; Fuel and guest-input options do not
apply. It never executes the Program or loads policy/catalog/grants. See
[IR inspection](../engineering/inspect-ir.md).
