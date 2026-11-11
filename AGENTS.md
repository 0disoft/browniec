- Latest ordinary semantic checkpoint (2026-11-12): [source stages](docs/engineering/compiler-source-stages.md)
  common compiler Pratt traversal now uses 34 fixed frames and explicit converted
  operand requests. Annotated primitive/legacy Option/Result declarations stage
  tokens, initializer, terminator, optional slot/store and final local registration.
  Scalar/void returns stage expression, terminator, reverse pending/local cleanup
  and RETURN. One finalizer runs per stage; slice cleanup may inspect 256 IR rows.
  Ordinary body controls retain their 67 explicit frame slots. Owning adapters
  still drain synchronously; unsupported semantic children stay outside the bound.
  Pratt checkpoints pass 5 groups/profile; declaration checkpoint passes 7
  development groups. Final development/release each pass 13 groups, including
  body kernels and exact raw IR/errors for 32 successful/28 failing sources,
  expression/control depth 32/33 and local binding limits 64/65. Engine
  development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap; all 338
  Engine inputs match `5fa36fa`. Transport retains 36 bindings/51 layouts/176
  equivalent aggregate graphs; Core/Cursor/Machine stay 172400/1184/1792 bytes.
  331 production modules retain LF. See [semantic evidence](docs/evidence/compiler-semantic-source-windows-20261112.json)
  and the earlier [body evidence](docs/evidence/compiler-body-control-windows-20261112.json).
  Twenty-six private source kernels are implemented. Converted operands (including
  nested expressions/CALLs), scalar assignments, inferred/aggregate/reference
  declarations, special return protocols, for-post probe/replay, value-yielding
  scopes and the separate typed/value body walker remain. Function entry/final
  metadata, implicit-return cleanup, origins and aggregate catalogs also remain.
  No complete resumable compiler/coordinator, public Pending compile, measured
  CPU/time/peak-stack improvement or R02-R05 closure. Lowering stays authorized;
  broader completion stays paused. Local only.

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
