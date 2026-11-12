- Latest evaluation checkpoint (2026-11-13): [source stages](docs/engineering/compiler-source-stages.md)
  `array_operand_work`, `conditional_evaluation_work`, `record_evaluation_work`
  and `static_evaluation_work` stage actual scalar children, joins, fields,
  list-cell publication, index/len operations and reverse binding cleanup.
  They use the existing 4096-unit logical allowance and explicit child requests;
  specialized aggregate CALL/copy/tail and metadata preparation remain legacy.
  Bank adds 34 array frames and 1024 shared cells, following the existing token
  cap without reducing the repeated-array limit of 4096. Conditional bodies use
  35 frames. Raw owners preserve complete IR/failure-prefix and exact errors.
  Bank, expression State and conditional State use one-element SDK vectors.
  Borrowed classifier fields, captured helper separation and guarded reuse of an
  idle uncaptured Bank avoid the reproduced nested-head native stack overflow.
  Staged and full compile depth 30 execute; depth 31 rejects with full-compile
  kind 4 at offset 126, on default stacks. Fixed scratch construction and owning
  adapters still drain synchronously; no public Pending compiler.
  Implementation: `f15d428`/`23ad24a`/`6d46420`/`8e4cb0e`/`1697ec5`.
  Scratch reservation: `43115b6`; memory/CALL tests: `1095daa`.
  Final Engine integration: `f624833`.
  Evaluation development/O2 each pass 15+1 groups at `1697ec5`, sharing identical
  production bytes. The sole subsequent production change updates the working
  reservation in `module_budgeted_compile`; final memory/Engine receipts cover it.
  Lowering conservatively reserves 66,630,144 bytes; ordinary/input total working
  allowances are 66,804,544/66,804,928, still within the existing 64MiB policy.
  This is not a measured physical peak. Emitted scratch widths 37792/5736/14720
  fit checked slot caps 40000/6000/15000; each vector reserves eight slots without
  growth, with a conservative 136-owner bound per kind. See the heap proof.
  Memory development/O2 each pass 28 groups. Engine development/O2 pass default
  1MiB/4KiB stacks and zero exit SDK heap. Global compile OOM sweeps cover all
  allocation ordinals and three scratch kinds; retention seams are separately
  injected. Real simultaneous owners preserve exact/one-less combined runtime
  boundaries above compilation history without resetting historical peaks.
  All 350 Engine input hashes match the final integration commit. Transport
  retains 36 equivalent declarations, 51 raw-equivalent reviewed layouts and all
  504 prior shapes after masking the two Bank fields and expression cell cursor.
  There are 516 definitions / 115 arrays; added shapes include private scratch
  owners and a test-only allocation probe. Core/Cursor/Machine remain
  172400/1184/1792 bytes. All 342 production modules retain LF.
  See [evaluation evidence](docs/evidence/compiler-evaluation-source-windows-20261113.json).
  General assignments, specialized aggregate protocols, typed/value walkers,
  catalogs/origins, entry/final metadata and unrelated implicit cleanup remain
  outside these bounds. No measured CPU/time/physical-heap/peak-stack improvement
  or R02-R05 closure; broader completion stays paused. Local only.

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
