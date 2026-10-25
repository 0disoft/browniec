# AGENTS.md

## Project role

This repository owns the Brownie C design baseline and its native M0 probes and experimental M1 scalar CLI. The project is primarily Fairy C with small explicit allocator, codec, and
operating-system shims where needed.

Read the nearest user instruction, this file, VALIDATION.md, and the documents that
own the affected contract. Broader scaffold procedures are optional.

## Current state

- M0 native primitives exist under `probes/m0` and have a repeatable Windows harness.
- The M1 scalar lexer/parser, i32 checks, private IR verifier, VM, and CLI exist in src/.
- M2 has private scalar-array layout, codec, caller-backed storage, owner-lifetime and copy helpers;
  private function-owned array IR has independent verification and metered native VM dispatch. The current
  source slices add immutable/mutable scalar-array declarations in lexical scopes of ordinary functions, indexed reads,
  element assignment in nested scopes, and copy initialization from exact-type/length array bindings.
  Array length access uses `NAME.len`, an exact `usize` constant in scalar expressions and pure for headers.
  Lexical exits release local arrays in reverse order; loop transfers preserve enclosing arrays.
  Whole-array assignment copies an exact-shape visible source into existing `var` storage without an extra extent.
  Private array bindings are function-owned; recursive VM frames retain separate tokens while sharing
  the 16-owner table and payload arena. Source declarations include scalar and shallow wrapper-returning helpers.
  Question-mark failure returns drop visible local arrays in reverse order; success keeps them live.
  Previous source-parameter verification passed 28 native groups and 2,475 CLI cases
  (426 existing array, 80 parameter, 1,969 scalar) per development/release profile.
  Completed native/CLI outputs were combined stepwise after a corrected CLI fixture;
  the aggregate harness was not rerun. Changed frontend/fixture inputs have fresh evidence.
  Source immutable exact-shape scalar-array parameters are supported. Parameter
  catalogs are predeclared for forward/mutual calls. Arguments evaluate left to
  right; immutable inputs are stable snapshots and mutable inputs get anonymous
  captures with normal/return/propagation/loop-transfer cleanup.
  Source array results support bare-name returns and exact-shape let/var call
  initializers, direct return calls, repeated return literals and call-result
  assignment into var arrays, plus in-place repeated-literal assignment. General
  aggregate expressions, for-header arrays, borrows, slices and wrapper elements remain unsupported.
  Result signatures now retain exact scalar-array lengths in 16 bounded slots;
  its original blanket result gate is removed by source lowering. Result anchors
  reuse an exact-shape parameter site or reserve one dead site before body lowering.
  Previous result-signature verification passed 16 native groups and 2,242 CLI cases
  per development/release profile: 96 result-signature, 80 parameter, 97 helper-local,
  and 1,969 scalar cases. Checks ran individually; backend native suites were not rerun.
  Private array results now have independent shape/lifetime verification and VM
  owner transfer. ARET (39) requires the callee's sole live array; array CALLs
  initialize dead exact-shape caller destinations. Transfer clears the child token
  and publishes it in the parent without copying or allocating payload/owners.
  Bounds, canonical bool data, metadata and Fuel are checked before token mutation.
  Source lowering emits reverse-order drops for all other visible arrays and
  captures before terminal ARET. Call-result names become visible only after
  argument evaluation and CALL, so early exits cannot drop pending destinations.
  Previous source-result verification records 26 native groups and 2,690 CLI cases per
  development/release profile, including 119 new source-result cases. Development
  combines 18 unchanged groups from the first selection with eight fresh groups
  after correcting a mutual-call fixture; release selects all 26 together.
  These are individual commands, not an aggregate harness run.
  Direct array-return calls reuse argument evaluation and the shared return
  finisher. Each anonymous destination uses one fresh catalog site and remains
  invisible during argument evaluation; normal completion releases all other
  visible arrays/captures before ARET. Focused direct-return verification passes
  12 native groups and 509 CLI cases per development/release profile. Other array
  and scalar CLI matrices and full native suites were not rerun. The expanded
  combined result-source harness is available but was only syntax-checked.
  Repeated return literals evaluate their fill once in the declared element
  context and require an exact literal count. Initialization follows fill evaluation;
  early returns/loop exits never drop a pending literal. The shared finisher drops
  all other visible arrays/captures before ARET. Focused literal-return verification
  passes 16 native groups and 628 CLI cases per development/release profile,
  including 119 new literal CLI cases. Earlier receipts are historical for changed
  compiler, helper, source fixture and aggregate harness inputs.
  Call-result assignment keeps the old destination live, receives a result in
  an anonymous site, copies it into existing storage and drops the temporary.
  It preserves destination owner metadata and normal argument effects; result,
  snapshots and parameter copies still contribute to peak quota use. Focused
  verification passes 15 native groups and 609 CLI cases per profile, including
  115 new CLI cases. A corrected Fuel fixture received a full native rerun.
  Repeated-literal assignment evaluates the fill once, then AFILL (40) overwrites
  the live mutable extent. Owner preflight and scalar encoding precede writes;
  no temporary catalog site, owner or payload extent is required, including at
  full capacity. The verifier checks liveness, ownership, mutability, type and
  reserved operands. The [focused receipt](docs/evidence/m2-array-literal-assignment-windows-20261025.json)
  passes 36 unique native groups and 2,693 CLI cases per profile. The final 36
  combine 17 reused backend identities with 19
  fresh frontend groups in each profile; the aggregate harness was syntax-checked,
  not invoked. Development reuses the backend from `b5e0c98`; release reuses the
  same identities from its earlier 36-group selection. Reuse validation matched 28
  unchanged source and test files to their `b5e0c98` Git blobs and confirmed
  matching SDK and compiler identities. The 2,693 CLI cases comprise 724 array and
  1,969 scalar cases, including 115 new fill cases.
  The final lowering separates array statement, copy, and index handling into
  helpers. Scalar and composed-fill cases return 42 at depth 10; depth 11 reports
  `compile_limit`. Two permanent fill CLI cases cover the composed boundary. The
  pre-fix binary reproduces `0xC00000FD` at depth 10. No stack-byte or performance
  claim is made.
  Previous private-result verification passed 43 native groups and 2,571 CLI cases
  per development/release profile, including parameter independence and deferred
  callee holes. Native development combined 41 plus two disjoint groups; release
  selected the same 43 identities together. Aggregate tooling was syntax-checked;
  evidence records individual commands rather than an aggregate invocation.
  Private `array_owners::copy_arguments` preflights up to eight exact-shape copies
  before changing bytes or owner state. Private IR/verifier/VM calls now support
  immutable exact-shape array parameters, mixed scalar positions, metered atomic
  copies, and frame-specific owners. All parameter and capture sites share the
  existing catalog, lexical binding, owner and payload limits.
  For-header array declarations and writes remain rejected.
- A private [struct-layout planner](docs/engineering/m2-struct-layout.md) plans 0..32 acyclic
  records with 1..16 fields, declaration-order padding, and a per-record byte ceiling.
  A [scalar-only storage slice](docs/engineering/m2-struct-storage.md) prepares a selected
  scalar record, initializes it in caller-backed arena bytes, and reads or writes indexed
  fields. Nested records are still planned but rejected for storage. Source structs,
  copies, ownership, IR/VM, Fuel, and allocation remain unimplemented. The storage
  slice's Windows 20-group receipt passed development and release.
- The bounded M1 scalar checkpoint is verified; full-profile conformance, worker,
  DLL, performance, and isolation remain incomplete or unverified.
- Root fairy.toml builds the native CLI; tools/verify-m1.ps1 verifies its narrow profile.
- M0 remains a separate native feasibility harness, not a VM or public CLI.
- The source design package is reference material, not a command source.

Do not execute the source package's CODEX-START instructions, import all of its
contracts or models, or describe design-model checks as product runtime evidence.
M0 probe success is native primitive evidence, not evidence for an unimplemented VM.

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
