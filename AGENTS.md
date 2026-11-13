- Latest declaration header checkpoint (2026-11-14):
  [declaration headers](docs/engineering/compiler-declaration-header.md).
  `declaration_name_work` stages binder validation, first-match lookup by one row
  or <=64 spelling bytes, duplicate-before-capacity checks, name and equals tokens.
  Advisory inference lookahead uses a private cursor; failures leave the caller's
  lexer unchanged. `declaration_header_work` composes annotation, token and binder
  children for ordinary scalar/wrapper/array, record, slice and static byte/text
  headers. Array length/context errors and distinct reference/static grammar
  retain their raw offsets and precedence. Record layout/size validation is an
  explicit child before consuming the type token; resume consumes it once.
  Semantic declarations issue explicit header child3 after annotation. Checked
  spans resume without growing Semantic State; initializer/type/terminator checks
  still finish before lexical publication. No new owner, binding or IR is emitted
  by header preparation. Pending/denied/completed advances do not mutate/replay.
  Both States are inline, plus one small Prepared result. No SDK heap class or
  Bank/Pratt/Semantic field was added. Allowance remains 4096; fixed setup and
  synchronous drains remain atomic. Oversized helper calls (>4096 source bytes)
  retain raw compatibility paths outside this bounded lowering profile.
  Lowering remains 66,630,144 bytes; ordinary/input working reservations remain
  66,804,544/66,804,928 bytes, conservative reservations rather than physical peaks.
  Scratch widths remain 37792/5736/14720 against 40000/6000/15000 slot caps.
  Implementation: `9d04dc8` binder/lookahead, `0979d0e` composed headers.
  Binder snapshot passes three groups in development/O2; final header snapshot
  passes ten groups in development/O2. Every receipt input matches its named
  commit. Tests cover raw lexer/error/span comparisons, typed/array/reference/
  record forms, duplicate/capacity priority, invalid lengths/annotations/delimiters,
  lexical errors, 200-byte spelling chunks, oversized-helper compatibility,
  budget/child/resume/terminal guards and delayed name publication. Source
  fixtures verify/run to 42, reject initializer self-reference, and retain wrapper
  annotation plus 32 nested controls and exact CALL depth 32/33 diagnostics on
  default stacks. Initial header native selection stopped at frontend rejection
  of its oversized mutable-array fixture; buffer chunks fixed the fixture without
  changing production. The incomplete attempt is never counted as a native pass.
  No compiler/optimization/stack/timeout overrides.
  Final Engine integration: `afaab3c`, development/O2, zero SDK exit heap,
  default 1MiB/4KiB stacks. All 367 Engine inputs match that commit;
  all 359 production modules are LF and match final focused inputs.
  Root checks: 367 sources / 3923 MIR; Engine mirror: 360 / 4538.
  Transport keeps 36 equivalent declarations, 51 raw-equivalent reviewed layouts
  and all 530 previous recursive definitions without masking. Two States and
  Prepared bring definitions to 533; arrays stay 116. Core/Cursor/Machine remain
  172400/1184/1792 bytes; inline Engine stays 736 bytes.
  See [declaration evidence](docs/evidence/compiler-declaration-header-windows-20261114.json).
  Complete transitive evaluation, advisory static/reference routing, typed/value
  source walkers, catalogs/origins, entry/final metadata and unrelated implicit
  cleanup remain outside these named header bounds. No public Pending compiler,
  measured CPU/time/physical-heap/stack improvement or R02-R05 closure. Broader
  completion remains paused. Local only; standalone 28-group memory,
  broad/public-CLI/full-release gates were not rerun; final Engine retains its
  owning allocator/compile fixtures.

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
