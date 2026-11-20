# Private OS project source admission and execution

`native/project-source-loader/loader.fy` composes the existing anchored source
loader, project source admission and project executable APIs. It stays outside
root `src`, so the public CLI gains no unresolved FFI or availability claim.
All collector, source loader, manifest/parser/compiler/VM and lock files remain
unchanged. This is a private synchronous zero-argument i32 project path.

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

## Verification

Run `python tools/verify-project-source-loader.py` with Windows/MSVC/SDK and the
exact pinned compiler. `--core-root` optionally selects a read-only core checkout
or archive; default is the current checkout. The verifier copies that actual
import closure byte-for-byte into an ignored build project. Its isolated
bytes/text/vec SDK closure is pinned to `e256aabf...`, distinct from the full-root
SDK source digest; compiler/version/runtime ABI remain the exact repository pin.
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

Project input/output entry selection, host dispatch, CLI delivery, bounded
collection, and complete Engine accounting remain open. Source bytes
remain an owned bounded copy, not a point-in-time snapshot against preexisting
writable mappings. No source collection is implicitly repeated on runtime failure.
