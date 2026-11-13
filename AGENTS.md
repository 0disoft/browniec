- Latest assignment destination checkpoint (2026-11-13):
  [destination contexts](docs/engineering/compiler-destination-context.md).
  `destination_record_work` reuses layout/metadata/copy/range cursors to prepare
  scalar field and aggregate nominal destinations. Scalar SELECT/old-value
  READ/STORE share the staged shape adapter and keep kind-3 source diagnostics;
  aggregate destinations keep their original layout-only proof and kind-5
  diagnostics, without extra checks on unrelated binding rows. Operand checks
  precede layout scans; nominal walks keep internal 128-leaf support and <=16
  visits per child stage. Fixed child State scratch avoids nested borrow conflicts
  without cloning a whole layout plan; its width is reviewed in the evidence.
  `destination_place_work` validates the pending mask, inspects one free-ID bit,
  requests record metadata explicitly, emits one SELECT and publishes the pending
  bit in separate stages. All five ordinary source place kinds are covered.
  Pending advances do not charge/mutate; resume consumes each child result once.
  Owning adapters finish before RHS evaluation. No new binding/owner/register,
  SDK heap class or Bank/Pratt field was added. Both States are inline; fixed
  setup and synchronous drains remain atomic, with logical allowance 4096.
  Lowering remains 66,630,144 bytes; ordinary/input working reservations remain
  66,804,544/66,804,928 bytes, conservative reservations rather than physical peaks.
  Scratch widths remain 37792/5736/14720 against 40000/6000/15000 slot caps.
  Implementation: `ee9f3f0` record metadata, `4d003b3` isolated checks,
  `a2c1179` place selection/publication, `11e5330` scalar READ/STORE shapes.
  Isolated record snapshot passes three groups in development/O2; final snapshot
  passes nine groups in development/O2, with every receipt input matching its
  named commit. Earlier combined six-group and parent eight-group development
  snapshots also pass. The combined six-group O2 attempt hit the pinned compiler's
  default 60-second MSVC build limit; it is recorded as incomplete, never a pass.
  No compiler/optimization/stack/timeout override. Tests cover raw SELECT/READ/
  STORE bytes/errors, pending masks, child waiting, delayed publication, full
  slots, late IR exhaustion, 128 leaves and >16-visit nominal walks. Ordinary
  mixed array/slice/record assignments and returned records verify/run to 42;
  CALL depth 32/33 retains default-stack diagnostics.
  Final Engine integration: `64f6cbe`, development/O2, zero SDK exit heap,
  default 1MiB/4KiB stacks. All 365 Engine input hashes match that
  commit; all 357 production modules are LF and match final focused inputs.
  Root checks: 365 sources / 3902 MIR; Engine mirror: 358 / 4517.
  Transport keeps 36 equivalent declarations, 51 raw-equivalent reviewed layouts
  and all 528 previous recursive definitions without masking. Two inline States
  bring definitions to 530; arrays stay 116. Core/Cursor/Machine remain
  172400/1184/1792 bytes; inline Engine stays 736 bytes.
  See [destination evidence](docs/evidence/compiler-destination-context-windows-20261113.json).
  Complete transitive evaluation, typed/value source walks, declaration headers,
  catalogs/origins, entry/final metadata and unrelated implicit cleanup remain
  outside these named bounds. Other metadata consumers and aggregate STORE
  proofs retain their protocols. No public Pending compiler, measured CPU/time/
  physical-heap/stack improvement or R02-R05 closure. Broader completion stays
  paused. Local only; standalone 28-group memory, broad/public-CLI/full-release
  gates were not rerun; final Engine retains its allocator/compile fixtures.

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
