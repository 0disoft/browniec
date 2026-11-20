# Typed runtime policy and run configuration admission

This private H01/C01 sidecar implements native Fairy admission of the exact
`brownie.policy/0.3` and `brownie.run/0.3` design contracts. The base is `845a056`.
The Windows Engine uses these typed owners for configured Program and Instance
admission. See [policy-checked project output](project-source-loader.md#policy-checked-output).

`runtime_policy::parse(bytes)` returns an owning `Policy` only after every required
field, scalar range, duplicate/unknown field, capability and policy relation passes.
`runtime_run_config::parse(bytes, ref policy)` returns an owning `RunConfig` only
when its entry spelling, complete limits and capability lists pass, its requested
limits do not exceed Policy.run, and `requires <= grants <= policy.capabilities`.
The accepted policy relations are checked again using the requested run limits.

Admission copies decoded strings into bounded native buffers. Input has one UTF-8
JSON root of at most 65536 bytes. The shared cursor allows at most 8192 JSON tokens;
fixed object/array grammar rejects arbitrary nesting without recursive descent.
Fields are compared after escape decoding, so escaped duplicate keys fail.
Integers use canonical unsigned decimal spelling, at most 20 characters, and
preflight subtraction/division before multiply/add. Fractions, exponents, negative
numbers including -0, leading zeroes, booleans, strings and overflow fail.
Every field is required: schema defaults are documentation, never inserted.
Capability arrays have at most 65 unique decoded names of at most 128 bytes.

Naming reuses `project_names::capability` and `host_catalog_names::symbol`.
Entry modules use the exact schema identifier/`::` grammar, including segments up
to the full 128-byte module ceiling. Source-language keyword and reserved-root
exclusions from `project_names::module_name` would narrow this schema incorrectly;
entry resolution and executable/program binding remain integration obligations.
No capability is granted by source metadata, and admission dispatches no host call.

The policy relation checks match the reference model: each run backing/input/output/
request/reply component fits run memory, run memory fits the Instance set, Program
memory fits the Program set, compiler working/control/Program-set/Instance-set fit
Engine memory, source fits compiler working memory, and startup/compile/run phases
fit the worker session. Worker memory includes Engine + 4MiB transport + 4MiB ABI
registry + 32MiB headroom. These are individual ceilings, not a sum reservation for
all components or a claim that every ceiling can be consumed simultaneously.

## Integration API

- `runtime_policy_json::{Failure,Error}`: shared categorized failure and byte offset.
  Categories: Json, Limit, Unknown, Duplicate, Missing, Value, Relation, Authority,
  Allocation, Bounds. Relation/authority failures use offset zero.
- `runtime_policy_limits::{CompileLimits,EngineLimits,RunLimits,WorkerLimits}`:
  typed structures with every schema field as `usize`; native target is 64-bit.
- `runtime_policy::{parse,compile_limits,engine_limits,run_limits,worker_limits}`:
  owning admitted policy and copies of all typed limit fields.
- `runtime_policy::{capability_count,capability,contains_capability,allows,allows_run}`:
  indexed decoded names, exact membership/subset, and valid run ceiling comparison.
- `runtime_run_config::{parse,module_name,function_name,run_limits}`: owning narrowed
  configuration, decoded entry getters and copied requested limits.
- `runtime_run_config::{requires_count,grants_count,requirement,grant,declares,grants}`:
  bounded indexed names and exact membership getters. Out-of-range indices fail.
- `runtime_run_config::narrowed_to(config, policy)`: recheck against the actual
  Engine policy when binding. Admission against one Policy does not confer authority
  under a different Engine. Config strings and limits are retained independently.

Policy/run structs are metadata and ceilings. Accepting the full design values
(including 4096 frames and run Fuel up to 1000000000000) does not enlarge current
VM capacities: 32 frames, 256 instructions, 16 owners. Public CLI Fuel remains
default 256, ceiling 16000000. Integration must enforce actual implementation
capacities in addition to these accepted ceilings. Reachable-required catalog/
program binding, entry resolution, host exchange, public CLI/gates, Engine resource
reservations, enforcement of deadlines and full H01/C01 completion remain open.

## Explicit Windows configuration acquisition

The Windows CLI reads a caller-selected policy and run file
through the same bounded Windows disk reader as project input. Each file has
a separate 65,536-byte ceiling and is parsed directly from its immutable
native buffer. The native owner closes after parsing, and the typed results own
their decoded data. Run admission requires the already admitted Policy.
[Configured project runs](../cli/configuration.md#configured-project-output) bind both files to the owning Engine.

`python -B tools/verify-cli-run-configuration.py` checks both locked native
profiles. Its fixture accepts valid policy and run files at 65,536 bytes and
rejects a 65,537-byte file, an unauthorized grant, malformed JSON and a missing
path. The fixture runs as a separate executable.

## Focused verification and delivery

Run `build/toolchain/fairyc.exe check` to refresh only the mirror lock, then
`python tools/verify-runtime-policy.py`. The verifier reuses the established native
selected-test mirror runner in development and release, with the pinned compiler,
locked inputs, default stacks and no compiler overrides. It does not build or
change the public CLI. Exact original ZIP policy/run bytes are asserted against
native literals; mutation corpus inputs are reconstructed byte for byte and checked
by an independent schema/range/relation/subset oracle before native execution.
Tests cover every required numeric field, all decoded duplicate object keys,
unknown fields, canonical integer/overflow, malformed JSON/UTF-8/escapes, bounds,
65/66 capability lists, full accepted maxima/minima, relation/narrowing failures,
owned getters and rechecking under a different policy.

`build/runtime-policy/{development,release}/receipt.json` records exact commands,
compiler hash, every input SHA-256, native report hash and selected groups.
`build/runtime-policy/reference-receipt.json` records ZIP identity, each native
mutation input SHA-256, changed paths and public API signatures. Reference files
and their original archive paths/hashes are recorded in
`tools/runtime-policy/reference/provenance.json`. The ZIP Python model and prose
are inert source references, never invoked as commands or production code.

The mirror-only lock is excluded from the integration patch. The sidecar patch
contains only the listed new source/test/tool/reference/document files. No root
production files, fairyc checkout, root lock, commits, public gates, dispatch or
Fuel pricing change. Broad language/CLI, other operating systems, adversarial OOM,
performance and clean-machine delivery suites are outside this focused slice.
