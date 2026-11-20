# Windows project source admission and execution

`src/project_source_loader.fy` composes the anchored source loader, project
source admission and project executable APIs. This is a synchronous Windows path.

## Public CLI

`check --project FILE` and `run --project FILE` accept an explicit manifest.
The manifest's parent directory anchors both the manifest and declared source
reads. The manifest limit is 65,536 bytes. The current source limit is 16 files
and 4,096 cumulative bytes. The CLI selects a public zero-argument i32 entry
and rejects nonempty requirements before opening any source member.
`check` compiles and verifies without guest execution. `run` uses the normal
Fuel, exit codes and result formats. See the [CLI configuration](../cli/configuration.md#project-selection).

## Private source loader

`select(ref Project, root UTF-8 bytes, source_bytes)` borrows explicitly admitted
metadata and an explicit root. It packs only `project_manifest::path` values in
manifest order, then invokes the actual anchored loader. There is no ambient
manifest search, directory enumeration, glob, import-based file discovery or
fallback entry selection. Bounds remain 16 files, 4096 source bytes, 240 bytes
per path. The accepted 32-source metadata ceiling does not enlarge native storage.
`project_sources::select` checks the exact identities, mapped module headers,
imports, public named entry and zero-argument i32 signature against the owning
Index. Returning an Entry is binding evidence, not executable admission.

`compile(Project, root, source_bytes, image_limit)` consumes the admitted metadata,
selects its exact source entry, and calls unchanged `project_program::compile`.
The real compiler admits all bodies and retains original sources and metadata.
The returned resource is the actual `project_program::Program`, with its existing
snapshot/metadata/run APIs. Run still rejects every declared requirement before
Fuel/guest execution; metadata never grants a capability. Limit/Acquisition/
Binding/Compile are intentionally coarse adapter errors; detailed parse and run
errors remain with their existing APIs. Every rejection releases its consumed
metadata and intermediate owners. No emitted layout is read or fabricated.

## Engine admission

`runtime_engine::compile_project` checks Engine ownership and Program capacity
before collecting an explicit root. The ordinary zero-argument Program profile
denies nonempty capability requirements before opening a file. The collector
uses the smaller of the 4,096-byte native limit and the configured Engine
policy's source-byte limit. It loads only declared members, checks their module
headers and selects the declared public i32 entry. Source binding failures
retain the original source span when one exists.

The selected Entry enters the existing Engine compile and retention path.
Instance creation pins the same immutable Program. Replacing a source file
affects later compilations and does not affect retained Programs or their
Instances.

Windows development and /O2 verified that two Instances of one retained
Program both return 77 after the upstream module is rewritten. A newly compiled
Program reads the replacement and returns 42. A swapped manifest mapping and
an invalid root cannot publish a Program. Nonempty requirements reject even
with an invalid root. Both native profiles ended with zero live SDK
allocations. Local receipt: `build/runtime-engine/20261120T102944067619Z/receipt.json`.

### Shared-byte input

`runtime_engine::compile_project_input` selects the declared public
`i32(ref u8[])` entry against the same anchored snapshot and header mapping.
It rejects nonempty requirements before opening project members. Each
`create_input_instance` consumes a separate immutable input snapshot and
pins the retained Program through execution and destruction.

The Windows Engine fixture compiles a two-module project once and executes
two Instances after releasing the Program ID. Inputs containing NUL bytes
return 77 and 42 respectively. The fixture also checks denial before source
acquisition, an invalid root, a mismatched entry signature, and zero live SDK
allocations after teardown in development and /O2. Local receipt:
`build/runtime-engine/20261120T105539545392Z/receipt.json`.

### Policy-checked output

`runtime_engine::compile_project_output` uses the shared-byte entry and checks
the run's entry and requirements against the project manifest before collecting
sources. This profile supports the `brownie.output.emit` requirement. The
Engine-owned Policy must allow the run, and the run must grant every declared
requirement. Reachable emission without a manifest declaration fails before
Program publication.

The retained Program records the manifest's output requirement even when no
emit instruction is reachable. `prepare_granted_instance` rechecks it for
every run and reserves output capacity only for a reachable emit. Each Instance
owns its input and staged output. The Windows fixture exercises denied
compilation and reuse, an unused declaration, and independent binary output
from two Instances of one Program. Development and /O2 each ended with zero
live SDK allocations. Local receipt:
`build/runtime-engine/20261120T110558978981Z/receipt.json`.

## Verification

Run `python tools/verify-project-source-loader.py` with Windows/MSVC/SDK and the
exact pinned compiler. `--core-root` optionally selects a read-only core checkout
or archive; default is the current checkout. The verifier copies that actual
import closure byte-for-byte into an ignored build project. Its isolated
bytes/text/vec SDK closure is checked against the Windows SDK identity in
`toolchain.json`, along with the compiler, SDK version and runtime ABI.
Runtime C comes from
the compiler revision's exact Git objects. The emitted C is compiled unchanged
for development and O2 with default 1MiB/4KiB stacks and no CL/_CL_/LINK overrides.
Native execution uses an empty tool PATH. No core/root lock refresh is performed.

Actual temporary Unicode-root projects exercise two-file named selection returning
42, alternate explicit entry returning 99, re-execution after source rewrite,
retained exact source identities/bytes, swapped map/header mismatch, missing/private/
input signatures, missing paths, invalid UTF-8, oversized sources, actual body type
errors and current limits including 17 admitted metadata files. A real division
by zero is a Runtime error without requirements and Requirements with a declaration,
at both zero and ample Fuel. Bridge/anchor/native-Snapshot allocation failures
exercise acquisition rollback. Every process asserts stable handle counts, zero
bridge/collector owners and zero tracked Fairy heap allocations after all project
owners drop. Fixtures are removed and checked. Receipts include exact core/new/
prerequisite/compiler/runtime/transport/object/executable/fixture hashes.

General project host dispatch, public input/output and policy loaders, work-bounded
collection, and complete Engine accounting remain open. Source bytes
remain an owned bounded copy, not a point-in-time snapshot against preexisting
writable mappings. No source collection is implicitly repeated on runtime failure.
