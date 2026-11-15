- Latest maintenance checkpoint (2026-11-15):
  [shared whole-record assignment preflight](docs/engineering/record-assign-preflight.md).
  Whole-record assignment authenticates destination token, complete immutable
  table and record kind, then one fresh plan checks both owner shapes. Source
  token/kind/shape and nominal equality remain mandatory. Existing private
  prepared lookup reuses the initial full table validation; raw storage still
  independently plans and stages canonical bytes before publication.
  Plans three to two per assignment; fixed catalog slots 1536 to 1024 and rows
  96 to 64. Full table validation two to one; at sixteen retained owners,
  table-entry visits 64 to 32. Source counts only, not measured throughput,
  machine instructions or physical stack/memory peaks. Payload scratch remains
  128 bytes; no new API, heap allocation, owner, reservation or Fuel price.
  Development/O2 each pass six groups: 1618 differential inputs, exact results
  and all 256 backing bytes, catalog/owner/ledger faults, nominal mismatches,
  diagnostic order, bool/self-copy/padding atomicity, all nominal depths 1..16,
  depth-17 rejection, full owner/backing limits and exact/one-less direct VM Fuel.
  All 376 inputs match tested working bytes. Implementation 1326600 has
  375 raw Git matches and one line-ending-only difference in the unchanged
  struct_vm test; normalized bytes match and both hashes are in the evidence.
  Root check: 375 sources / 4092 MIR; production LF retained.
  Full Engine, public CLI, standalone memory and full release gates not rerun.
  Prior legacy source failure remains recorded, not retested or claimed fixed.
  Public admission unchanged; broader completion paused; local commits only.
  See [evidence](docs/evidence/record-assign-preflight-windows-20261115.json).
  Prior [aggregate selection](docs/engineering/aggregate-record-select-plan.md)
  retains its history.

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
