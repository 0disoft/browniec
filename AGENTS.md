- Latest maintenance checkpoint (2026-11-16):
  [one header preflight for view shutdown](docs/engineering/value-buffer-views.md#one-header-preflight-for-view-shutdown-2026-11-16).
  Shutdown reuses one complete registry header preflight across canonical row
  retirement. Every row retains fresh exact ticket/root/token/backing/lease/
  window authentication. Private close_prepared shares the unchanged sibling
  scan, last-lease release and retirement; standalone close keeps its resolver.
  At 32 live views, headers fall 33 to 1, outer-row visits 1056 to 32 and
  live-pair comparisons 5952 to 496 (5456 removed, 91.7%). Registry cleanup
  worst-case work is O(C^2) instead of O(C^3), C registry capacity <= 32.
  All 32 per-view root authentications remain. Ascending order, exact errors, partial
  progress, terminal generations, final refund and zero-Fuel cleanup remain.
  No new public API/cache/persistent state/heap allocation; throughput and
  physical peaks were not measured. Development/O2 each pass five native groups,
  including 2101 frozen close/shutdown comparisons over healthy counts 0..32,
  every slot's metadata faults at 0/1/8/32 and root faults with 16 native roots.
  Full pool/store/ledger/closing-plan parity, bytes/vector capacities, late
  failure retaining one row/lease, repair/retry, idempotence, zero-Fuel drain,
  direct-close/lease/quota and actual frame CALL/RETURN cleanup are covered.
  All 376 native inputs match implementation cdc76c7 and the Git index.
  Root check: 375 sources / 4108 MIR; all 367 production files retain LF.
  Full Engine/source CALL/public CLI/memory/release gates and known legacy
  failures not rerun. Broader completion remains paused. No push or deployment.
  See [evidence](docs/evidence/value-view-shutdown-windows-20261116.json).

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
