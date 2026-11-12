- Latest ordinary preflight checkpoint (2026-11-12): [source stages](docs/engineering/compiler-source-stages.md)
  common converted cast and primary Result property scans now resume through
  private lexer continuations. Ordinary group openings, local/function rows,
  64-byte spelling chunks and CALL formals advance separately; scoped names use
  source_name_work advances rather than a drained lookup adapter. Original
  context/depth order, immutable real lexer/names and final-only plans remain.
  Fixed context/route scratch lives in Bank; the 34 Pratt frames stay unchanged.
  Captured routes restore 64 lexical rows within the conservative logical bound.
  Conditional/aggregate/static-view roots retain their own legacy operand
  classifiers and validation before evaluation; those scans are not claimed
  staged by the ordinary route kernel. Read-only path spelling grants no
  nominal authority; the selected child validates fields before emitting reads.
  Context/routing commits are `c1528af`/`f85b742`. Nine development groups at the
  routing checkpoint plus one boundary group at `9abe988` share byte-identical
  production inputs; all ten pass release at `9abe988`. Whole IR/failure prefixes
  and exact diagnostics match the raw body oracle, including mixed depth 32/33.
  The new binary group's expected depth was corrected without changing source
  implementation. The first three-group context receipt was overwritten; later
  hashed checkpoints are preserved. Engine development/O2 pass default 1MiB/4KiB
  stacks and zero exit SDK heap; all 342 inputs match `263e8b0`.
  Transport retains 36 equivalent declarations and 51 reviewed layouts; all
  struct/resource/array graphs are compared recursively (496 before, 498 after,
  111 arrays each). Only context/route scratch and Bank change. Core/Cursor/
  Machine remain 172400/1184/1792 bytes; 335 production modules retain LF.
  See [preflight evidence](docs/evidence/compiler-preflight-source-windows-20261112.json)
  and the earlier [tail evidence](docs/evidence/compiler-tail-source-windows-20261112.json).
  Legacy child classifiers/bodies, assignments, special-result protocols, the
  separate typed/value walker, entry/final metadata, implicit cleanup, origins
  and catalogs remain outside these bounds. Owning adapters still drain
  synchronously. No public Pending compiler, measured CPU/time/peak-stack
  improvement or R02-R05 closure. Lowering stays authorized; broader completion
  stays paused. Local only.

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
