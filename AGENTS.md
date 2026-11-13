- Latest record/copy metadata checkpoint (2026-11-13):
  [record/copy source metadata](docs/engineering/compiler-record-copy-metadata.md).
  `record_leaf_source_work` stages one DFS visit, preserving source limits of
  16 leaves, depth 16 and 4096 visits. `record_field_source_work` reuses bounded
  declaration location/scoped cursor children and compares <=64 spelling bytes.
  `record_path_source_work` stages sibling counts, selected hops and lookahead,
  retaining distinct path/project ordinal checks, double-dot cursor behavior
  and diagnostic offsets. Nominal lookup and declaration size checks reuse
  record_location_work/struct_layout_work with the original error mapping.
  `record_initializer_source_work` stages field/constructor lookup, closing
  tokens and caller-owned initializer mutations at their original commit points.
  `record_read_source_work` authenticates/flattens the entire catalog before
  owner/leaf checks, SREAD and tag assignment. Catalog errors remain kind 5 at
  offset 0 before invalid-operand errors; internal reads retain 128-leaf support.
  Parent aggregate_copy_source_work delegates explicit source-count/read child
  requests instead of charging a whole catalog scan as one copy transition.
  Pending advances do not charge/mutate; resumes consume each child result once.
  All five new states are inline; the allowance remains 4096. No SDK heap class
  or Bank/Pratt field was added. Lowering remains 66,630,144 bytes; ordinary/input
  working reservations remain 66,804,544/66,804,928 bytes, conservative rather
  than physical peaks. Scratch widths remain 37792/5736/14720 against
  40000/6000/15000 slot caps.
  Implementation commits: `0bd5a6d` (source metadata), `5d28a39`
  (initializer/read metadata), `f3d5a70` (explicit parent read requests).
  Source snapshot passes seven groups in development/O2; intermediate copy
  snapshot passes eleven development groups; final copy snapshot passes twelve
  groups in development/O2. Every receipt input matches its named commit, with
  no compiler/stack/timeout overrides. Tests compare raw IR, tokens, initializer
  mutation/error prefixes, cycles/depth/leaf limits, 200-byte scoped field names,
  budget denial, publication and terminal guards, plus CALL depth 32/33.
  Final Engine integration: `3bde222`, development/O2, zero SDK exit
  heap and default 1MiB/4KiB stacks. All 363 Engine input hashes match
  that commit; all 355 production modules are LF and match final copy inputs.
  Root checks: 363 sources / 3886 MIR; Engine mirror: 356 /
  4501. Transport keeps 36 equivalent declarations, 51 raw-equivalent
  reviewed layouts and all 523 retained recursive definitions without masking.
  The obsolete emitted struct_source::Location disappears; five new inline
  State shapes bring definitions from 524 to 528. Arrays stay 116.
  Core/Cursor/Machine remain 172400/1184/1792 bytes; inline Engine stays 736.
  See [record/copy evidence](docs/evidence/compiler-record-copy-metadata-windows-20261113.json).
  Complete transitive record/group/static evaluation, general destination-context
  preparation, typed/value walkers, catalogs/origins, entry/final metadata and
  unrelated implicit cleanup remain outside these named bounds. Other general
  struct_meta::prepare callers retain their protocols. Adapters still drain
  synchronously; no public Pending compiler, measured CPU/time/physical-heap/
  stack improvement or R02-R05 closure. Broader completion remains paused.
  Local only; standalone 28-group memory, broad/public-CLI/full-release gates
  were not rerun; final Engine retains its owning allocator/compile fixtures.

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
