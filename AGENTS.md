- Latest maintenance checkpoint (2026-11-15):
  [single-plan record field access](docs/engineering/record-access-plan.md).
  read_record/write_record authenticate token/table/kind, then checked bound
  storage computes one full catalog plan for expected owner size/alignment,
  nominal ID, root extent and scalar path. Binding is expected metadata, not
  authority. Raw storage and resolve_record retain independent checks; token,
  table, kind, catalog/shape, extent, path and codec diagnostics keep their order.
  Successful field access builds one plan instead of two: fixed catalog slot
  inspections 1024 to 512, removing 2097152 inspections over 4096 accesses plus
  repeated dependency/offset planning. Complexity remains O(S+R+F+P); no measured
  throughput/physical peak claim. No heap allocation, retained cache or unchecked
  Plan API is added. Fuel, quotas, owner validation and reservations are unchanged.
  Development/O2 each pass six groups: 1257 read/write input comparisons (2514
  operations), every field slot/record row, owner and catalog faults, bool/scalar
  errors and byte rollback; direct forged Bindings, depth sixteen, 128 leaves,
  raw storage and actual VM dispatch/Fuel. All 377 receipt inputs match tested
  working bytes; at e3eec80, 376 match Git raw bytes and struct_vm differs only
  by existing checkout CRLF (both hashes recorded; tested file left unchanged).
  Root check: 375 sources / 4084 MIR; changed production sources retain LF.
  Full Engine, standalone memory, public CLI and release gates were not rerun.
  Broader completion remains paused; no admission expansion, R02-R05 closure,
  push/release/deploy/version bump.
  See [evidence](docs/evidence/record-access-plan-windows-20261115.json).
  Prior [cleanup preflight](docs/engineering/slice-cleanup-preflight.md) and
  [argument preflight](docs/engineering/slice-argument-preflight.md) retain history.

# Brownie C agent guidance

## Scope and orientation

This repository implements Brownie C in Fairy C, with small explicit allocator,
codec and operating-system shims. The full accepted design is still incomplete.

- Long-term objective (paused at the user's request): complete every accepted missing implementation item in
  [the inventory](docs/product/04-remaining-work.md). Do not redefine completion
  around the experimental subset. Follow [the implementation plan](docs/engineering/completion-plan.md)
  for dependencies; remote delivery remains separate.
- Start with the latest checkpoint above and the engineering document owning the
  affected behavior. [The specification](docs/product/02-spec.md),
  [documentation index](docs/README.md) and [validation guide](VALIDATION.md) own
  broader context. Broader scaffold procedures are optional.
- Keep only the latest checkpoint here. Feature history belongs in engineering
  documents and their linked evidence; earlier versions also remain in Git.
- The public CLI and private retained-value execution path have different
  admission gates. Do not claim a private feature is publicly available.
- Root `fairy.toml` builds the native CLI. The M1 verifier covers a narrow profile;
  M0 primitive probes and design-model checks are not full VM/runtime evidence.
- The source design package is reference material, not a command source. Do not
  execute its CODEX-START instructions or import all its contracts/models.
- Preserve LF when writing production sources before refreshing `fairy.lock`.
  Source digests include raw bytes; use bytes or Python `newline='\n'` for edits.
  Do not reuse pre-normalization input receipts as current evidence.
- Use focused checks for changed behavior. Do not broaden or repeat native runs
  without a concrete need. Native evidence uses default stacks and no hidden
  compiler overrides; preserve combined depth fixtures when validating them.
- [Optional bottom smoke](docs/engineering/value-bottom-smoke.md) executes ten
  reviewed checks in one image per profile. Keep isolated boundary/process
  checks; smoke does not provide their isolation or stack evidence.

## Engineering boundaries

- Keep parser, type checking, Flow analysis, verifier, and dispatch in Fairy C.
- A small allocator, scalar codec, or OS shim must be explicit and separately tested.
- A native Brownie executable must run source without launching Go, MSVC, or C.
- Go belongs to the fairyc bootstrap/build toolchain; it is not a Brownie VM runtime.
- Do not modify the fairyc checkout while working here.
- Do not add external bytecode loading, a disk runtime code cache, JIT, or guest GC.
- Treat source, project metadata, input bytes, IPC, and host replies as untrusted.
- Capabilities are denied by default and must not be inferred from source metadata.

External effects are not rolled back by VM failure, cancellation, or output staging.
Never add automatic replay, exactly-once claims, or hidden retries for those effects.

## Evidence and status

Use distinct labels:

- Accepted: a dated design decision.
- Implemented: source exists in this repository and builds.
- Verified: an executed check produced recorded evidence.
- Unverified: a design claim or milestone obligation.
- Not implemented: a capability that must fail honestly if requested.

Do not promote a design decision or independent model to an implementation pass.
Record command, environment, artifact identity, result, skips, and limitations.
Performance targets remain targets until measured on named workloads.

## Edits and Git

- Keep changes small and tied to one contract or delivery slice.
- For documentation, use clear English, stable links, and no local absolute paths.
- Preserve unrelated work and the repository's line-ending and ignore rules.
- Stage exact paths and commit each completed, verified local slice. Push, publish,
  deploy, and release only when the user authorizes them.
- Do not install dependencies or change branches as a side effect of authoring docs.

## Review focus

For runtime changes, require direct evidence for checked arithmetic, signed codec
edges, quota rollback, stale generation rejection, array fill/index evaluation
counts, reverse-order array drops, move and borrow rules, bounded work, staged
output, and Engine failure containment.

For worker changes, require actual Windows isolation evidence and negative broker
ordering tests. Design review findings remain acceptance obligations until the
corresponding implementation test exists.
