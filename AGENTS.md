- Latest maintenance checkpoint (2026-11-15):
  [integer-array shape validation](docs/engineering/value-integer-array-validation.md).
  The private typed/value codec no longer decodes every integer-array element:
  retained immutable layout proves an admitted fixed-width integer tag/extent,
  and exact input length is checked before active payload selection. All integer
  bit patterns are canonical. Bool arrays still check every byte <=1. Records,
  scalar values, wrapper tags/padding/inactive bytes and Buffer authority guards
  remain unchanged. Maximum 4096-element integer leaf inspection eliminates
  a 32768-byte payload scan and 4096 scalar decodes; O(N*W) validation becomes O(1).
  This is structural work, not measured CPU/time/heap/stack improvement; copying,
  Fuel prices, quotas and memory reservations are unchanged. No new allocation,
  unchecked-layout API, native layout, state/ledger field or public Pending API.
  Six groups pass development/O2: 637 original-array-branch comparisons, integer
  extremes/all u8 and bool bytes, maximum/short/oversized arrays, bool copy rollback,
  inactive integer payload/padding/snapshot independence, records/opaque words,
  actual frame copies/moves and maximum arrays through four wrappers. Every final
  input hash matches implementation be38901. Root: 375 sources / 4074 MIR; 367
  production sources are LF. Full Engine, standalone memory, public CLI and
  release gates were not rerun. Broader completion stays paused; no R02-R05
  closure, push/release/deploy/version bump.
  See [evidence](docs/evidence/value-integer-array-validation-windows-20261115.json).
  Prior [view lookup](docs/engineering/value-view-lookup.md),
  [root authentication](docs/engineering/value-root-authentication.md) and
  [typed Buffer/view work](docs/engineering/compiler-typed-buffer-view.md) retain history.

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
