- Latest conditional/projection checkpoint (2026-11-12): [source stages](docs/engineering/compiler-source-stages.md)
  `value_syntax_work` interprets conditional/value/regular/constructor probes on
  40 fixed frames. Balanced heads/bodies, statement tails, assignment-vs-value
  checks and place-index delimiters advance without recursive syntax drivers.
  `aggregate_probe_work` stages record/array/literal/static projection probes and
  repeated/list separators. Name rows, <=64-byte comparisons, group/delimiter
  transitions, field tokens and leaf-count graph visits yield independently.
  `record_location_work` composes staged single-source declaration discovery or
  scoped context/name/state restoration. These are read-only advisory plans.
  The common expression driver resumes grouped conditional/record/array/literal/
  enabled static classification before operand dispatch; literal roots also
  resume. Two States live in the separately pinned Bank, outside the unchanged
  34 Pratt frames. Captured dispatch restores at most 64 lexical rows within the
  conservative logical bound. Real lexer/names/IR stay unchanged during probing;
  type/ownership/field authority is revalidated by the actual evaluation child.
  Implementation: `205c2a5`/`c8b1998`/`50206b3`; boundary tests: `08117e7`.
  Development and release each pass 11 groups in 9+2 batches sharing identical
  production bytes. Complete raw plans/IR/failure prefixes and exact diagnostics
  match, including conditional/body/index and combined CALL depth boundaries,
  16/17 selectors and 200-byte field names in single/scoped catalogs. Current
  `--syntax-only` discovers all 11; the final combined selection was not rerun.
  Engine development/O2 pass default 1MiB/4KiB stacks and zero exit SDK heap.
  All 345 Engine inputs match `b21567d`; all 338 production modules retain LF.
  Transport retains 36 equivalent declarations and 51 reviewed layouts. All 498
  previous struct/resource/array shapes remain equivalent after removing Bank's
  two new scratch fields; 504 definitions now include 112 arrays (previously
  111). Core/Cursor/Machine remain 172400/1184/1792 bytes.
  See [projection evidence](docs/evidence/compiler-projection-source-windows-20261112.json)
  and [earlier preflight evidence](docs/evidence/compiler-preflight-source-windows-20261112.json).
  Owning classifier adapters still drain synchronously. Actual conditional/
  aggregate evaluation bodies, general assignment plans, typed/value walkers,
  entry/final metadata, implicit cleanup and catalogs/origins remain outside
  these bounds. No public Pending compiler, measured CPU/time/peak-stack
  improvement or R02-R05 closure. Broader completion stays paused. Local only.

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
