# AGENTS.md

## Project role

This repository owns the Brownie C design baseline and its native M0 probes and experimental M1 scalar CLI. The project is primarily Fairy C with small explicit allocator, codec, and
operating-system shims where needed.

Read the nearest user instruction, this file, VALIDATION.md, and the documents that
own the affected contract. Broader scaffold procedures are optional.

## Current state

- Private prepaid Buffer UTF-8 scanning: implemented and verified in development
  and release, each with 63 native scenarios (4 new, 59 regressions); all 126
  processes exit with zero tracked live allocations. Begin costs 128 Fuel; each
  step prepays `128 + 4*min(request,256)` before validation. Short budgets preserve
  progress and Fuel; admitted errors keep their charge. VM/guest wiring is pending.
  See [the metered contract](docs/engineering/m2-buffer-utf8-meter.md).
- Private resumable Buffer UTF-8 scanning: implemented and verified in development
  and release, each with 59 native scenarios (4 new, 55 regressions); all 118
  processes exit with zero tracked live allocations. Each call processes at most
  256 new bytes, retaining at most three suffix bytes across calls. No allocation;
  stable content remains a caller obligation. Its prepaid successor is above;
  VM and guest integration remain pending.
  See [the scan contract](docs/engineering/m2-buffer-utf8-scan.md).
- Private Buffer UTF-8 validation: implemented and verified in development and
  release, each with 55 native scenarios (4 new, 51 regressions); all 110 processes
  exit with zero tracked live allocations. Token/table/backing checks precede an
  allocation-free SDK scan of initialized bytes. Results are not cached; the
  resumable successor is described above. Fuel and guest integration are pending.
  See [the UTF-8 contract](docs/engineering/m2-buffer-utf8.md).
- Private Buffer writes before replacement publication: implemented and verified
  in development and release, each with 51 native scenarios (4 new, 47 regressions);
  all 102 processes exit with zero tracked live allocations. Writes validate full
  transaction snapshots, native metadata, current quotas and initialized bounds.
  The old root, Plan, table and ledger remain unchanged; writes add no allocation.
  See [the prepared-write contract](docs/engineering/m2-buffer-prepared-write.md).
- Private Buffer writes within initialized length: implemented and verified in
  development and release, each with 47 native scenarios (4 new, 43 regressions);
  all 94 processes exit with zero tracked live allocations. Complete preflight
  includes ledger and current-quota checks even for empty input; this guarded
  path rejects pending growth with State. No allocation, resize, token/generation
  or accounting change. The Windows receipt is archived.
  See [the write contract](docs/engineering/m2-buffer-write.md).
- Private Buffer bulk copy-out: implemented and verified in development and
  release, each with 43 native scenarios (4 new, 39 regressions); all 86 processes
  exit with zero tracked live allocations. Copies initialized binary bytes into
  distinct caller-owned native output after token, full-table, exact backing
  metadata and overflow-safe range checks. No allocation, token/generation,
  metadata or ledger change. The Windows receipt is archived.
  See [the copy-out contract](docs/engineering/m2-buffer-copy-out.md).
- Empty Buffer registration: implemented and verified in development and release,
  each with 39 native scenarios (4 new, 35 regressions); all 78 processes exit
  with zero tracked live allocations. Each registration
  admits a 64-byte logical owner without payload allocation. Multiple empty roots
  and registration after final close share caller-managed accounting.
  See [the create contract](docs/engineering/m2-buffer-create.md).
- Buffer grow-and-resize preparation: implemented and verified in development and
  release, each with 35 native scenarios (7 new, 28 regressions); all 70 processes
  exit with zero tracked live allocations. Growth-only
  preparation preserves the old root and zeroes the unpublished replacement's
  new bytes. Publication and metadata commit remain explicit caller steps.
  See [the grow-and-resize contract](docs/engineering/m2-buffer-grow-resize.md).
- Buffer resize within retained capacity: implemented and verified in development
  and release, each with 28 native scenarios (4 new, 24 regressions); all 56
  processes exit with zero tracked live allocations.
  Shrinking preserves the prefix; growing zeroes newly exposed bytes. Capacity
  and accounting stay unchanged; equal length retains the token without SDK work.
  See [the resize contract](docs/engineering/m2-buffer-resize.md).
- Buffer truncate and clear: implemented and verified in development and release,
  each with 24 native scenarios (4 new, 20 regressions); all 48 processes exit
  with zero tracked live allocations. Shortening advances generation once;
  equal length retains the token. Capacity and accounting stay unchanged.
  See [the truncate contract](docs/engineering/m2-buffer-truncate.md).
- Buffer grow-and-append preparation: implemented and verified in development
  and release, each with 20 native scenarios (7 new, 13 lifecycle/allocator
  regressions). Growth-only preparation appends into an unpublished replacement
  and commits its initialized length/capacity after caller publication. The old
  root remains live for self-append and rollback; publication is still explicit.
  See [the grow-and-append contract](docs/engineering/m2-buffer-grow-append.md).
- Buffer close accounting: implemented and verified in development and release,
  each with 13 native scenarios (4 close, 9 append/allocator regressions).
  Begin retires the token while keeping its charge; after native root destruction,
  finish validates snapshots and releases payload plus logical owner usage.
  Native destruction order remains the trusted caller's responsibility.
  See [the close contract](docs/engineering/m2-buffer-close.md).
- Buffer append within admitted capacity: implemented and verified in development
  and release, each with 9 native scenarios (4 append, 5 allocator regressions).
  Nonempty append updates initialized length and token generation without changing
  capacity/accounting. Instrumented append cases allocate only the initial root.
  Guest Buffer syntax and VM integration remain future work.
  See [the append contract](docs/engineering/m2-buffer-append.md).
- Buffer allocator-failure probe: verified in development and release, each with
  5 native scenarios. Forced 320/384-byte allocation failures preserve the original
  data, token, inactive Plan and restored usage; explicit retries then commit.
  Every scenario exits with zero outstanding allocations at the instrumented
  FY system-heap seam. Runtime sources are unchanged by this verification slice.
  See [the failure probe](docs/engineering/m2-buffer-failure.md).
- Buffer replacement transactions: implemented and verified in development and
  release, each with 31 native groups (8 replacement, 23 regressions) and 8 CLI
  sentinels. Both invocations rechecked 259 identical inputs.
  Private preparation keeps the original token live; completion rechecks full
  descriptor/accounting snapshots before updating generation and final charges.
  Owning-root publication remains an explicit trusted caller step.
  See [the replacement contract](docs/engineering/m2-buffer-replacement.md).
- Buffer owner descriptors: implemented and verified in development and release,
  each with 23 native groups (8 descriptors, 7 storage, 8 admission) and 8 CLI
  sentinels. Both invocations rechecked 256 identical inputs.
  Private table-local slot/generation tokens guard initialized byte access;
  release invalidates tokens and exhausted generations retire their slots.
  Native root association and lifetime remain trusted caller responsibilities.
  Guest Buffer syntax, borrow tracking and VM integration remain future work.
  See [the descriptor contract](docs/engineering/m2-buffer-owners.md).
- Native Buffer storage: implemented and verified in development and release,
  each with 15 native groups (7 storage, 8 admission) and 8 CLI sentinels.
  Both invocations rechecked 253 identical inputs.
  Private replacement allocation copies initialized bytes while preserving the
  original root. Publication/commit and discard/cancel remain explicit caller steps.
  Guest Buffer syntax, owner tokens and VM integration remain future work.
  See [the storage contract](docs/engineering/m2-buffer-storage.md).
- Buffer growth admission: implemented at `3f99138` and verified in
  development and release, each with 8 native groups and 8 CLI sentinels. Both
  invocations rechecked 250 identical inputs.
  Private capacity planning and begin/commit/cancel accounting include old-plus-new
  payload and owner charges, with minimum-capacity fallback at quota ceilings.
  Guest Buffer syntax, allocation, move/borrow and VM integration remain future
  work. See [the foundation](docs/engineering/m2-buffer-growth.md).
- Returned subrecords in constructor fields: implemented at `c0d6217` and verified in
  development and release, each with 16 native groups and 442 CLI cases. Both
  combined invocations rechecked 247 identical inputs.
  `Box { .child = make().child }` stages only the selected exact-nominal leaves
  and releases the returned root before later fields. Declarations, replacement
  and constructor returns share this path. See [the source contract](docs/engineering/m2-struct-child-call-paths.md).
- Returned subrecords as direct returns: implemented at `c789300` and verified in
  development and release, each with 16 native groups and 444 CLI cases. Both
  combined invocations rechecked 244 identical inputs.
  `return make().child;` and deeper exact-nominal paths release the returned
  parent before creating the child, then use existing mixed return cleanup.
  See [the source contract](docs/engineering/m2-struct-call-path-returns.md).
- Returned subrecords as assignment values: implemented at `2971169` and verified in
  development and release, each with 16 native groups and 440 CLI cases. Both
  combined invocations rechecked 241 identical inputs.
  See [the source contract](docs/engineering/m2-struct-call-path-assignment.md).
- Returned subrecords as declaration initializers: implemented at `e38f00a` and verified in
  development and release, each with 22 native groups and 537 CLI cases. Both
  combined invocations rechecked 238 identical inputs.
  `let Point p = make().child;` and `var` create an independent exact-nominal
  child after releasing the returned root. Pending names remain invisible until
  CALL, path and delimiter validation finish. See [the source contract](docs/engineering/m2-struct-call-path-declarations.md).
- Returned subrecords as arguments: implemented at `7284da8` and verified in
  development and release, each with 17 native groups and 410 CLI cases. Both
  combined invocations rechecked 235 identical inputs.
  `take(make().child)` snapshots the exact-nominal child, releases the returned
  root before child creation, and reuses existing mixed argument cleanup.
  See [the source contract](docs/engineering/m2-struct-call-path-arguments.md).
- Direct record call-result scalar reads: implemented at `aee9885` and verified in
  development and release, each with 16 native groups and 374 CLI cases. Both
  combined invocations rechecked 232 identical inputs.
  `make().x` and deeper scalar field paths read the returned value, then
  immediately release its anonymous root through existing SREAD/SDROP.
  See [the source contract](docs/engineering/m2-struct-call-reads.md).
- Direct array call-result reads: implemented at `b822089` and verified in
  development and release, each with 18 native groups and 335 CLI cases. Both
  combined invocations rechecked 229 identical inputs.
  `make()[INDEX]` and `make().len` release the anonymous result after producing
  the scalar; index-expression exits use existing mixed cleanup.
  See [the source contract](docs/engineering/m2-array-call-reads.md).
- Repeated array literals as arguments: implemented at `ea6854f` and verified in
  development and release, each with 20 native groups and 344 CLI cases. Both
  combined invocations rechecked 226 identical inputs.
  `take([EXPR; N])` evaluates the filler once before publishing an anonymous
  immutable capture. Existing mixed cleanup handles calls and early exits.
  See [the source contract](docs/engineering/m2-array-literal-arguments.md).
- Array call results as arguments: implemented at `03795b9` and verified in
  development and release, each with 29 native groups and 507 CLI cases. Both
  combined invocations rechecked 223 identical inputs.
  `take(make_array())` and nested exact-shape calls join the existing mixed
  argument capture cleanup after CALL. Element type and length must match;
  visible local callee shadowing is rejected. See [the source contract](docs/engineering/m2-array-result-arguments.md)
  and the [Windows receipt](docs/evidence/m2-array-result-arguments-windows-20261028.json).
- Record constructors as arguments: implemented at `bd9db83` and verified in
  development and release, each with 26 native groups and 874 CLI cases. Both
  combined invocations rechecked 220 identical inputs.
  `take(Point { .x = 42 })` stages fields in declaration order before creating
  an anonymous immutable capture; existing mixed cleanup handles calls and early
  exits. See [the source contract](docs/engineering/m2-struct-constructor-arguments.md) and the
  [Windows receipt](docs/evidence/m2-struct-constructor-arguments-windows-20261028.json).
- Subrecord paths as arguments: implemented at `9650f12` and verified in
  development and release, each with 27 native groups and 570 CLI cases.
  The two successful combined profile invocations rechecked 217 identical inputs.
  An exact-type
  `take(outer.child)` or deeper path stages scalar leaves into an independent
  immutable snapshot before later arguments run. Existing mixed capture cleanup
  handles calls and early exits. See [the source contract](docs/engineering/m2-struct-path-arguments.md)
  and the [Windows receipt](docs/evidence/m2-struct-path-arguments-windows-20261028.json).
- Record call results as arguments: implemented at `7671f25`. A bare exact-type
  `take(make())` or nested `id(id(make()))` uses an anonymous argument capture
  after the inner CALL, then shared reverse mixed cleanup. Development and
  release each passed 29 native groups and 588 CLI cases in separate
  core/regression phases, with 214 matching rechecked inputs.
  See [the source contract](docs/engineering/m2-struct-result-arguments.md) and the
  [Windows receipt](docs/evidence/m2-struct-result-arguments-windows-20261028.json).
- M0 native primitives exist under `probes/m0` and have a repeatable Windows harness.
- The M1 scalar lexer/parser, i32 checks, private IR verifier, VM, and CLI exist in src/.
- Entry-only mutable root constructor assignment is verified in development and release; child constructor assignment is verified in development and release.
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Source helper-local records are verified at `98a4525`: 48 native groups and 2,860 CLI cases per development/release profile. Development completed stepwise after tooling fixture fixes; release completed the aggregate. See [the source contract](docs/engineering/m2-struct-function-source.md) and [receipt](docs/evidence/m2-struct-function-source-windows-20261027.json).
- Nominal record parameter signature metadata is verified at `4a6792b` (16 native groups and 2,226 CLI cases per development/release profile). Its pre-lowering source gate is historical and superseded by source record parameter lowering. See [the foundation](docs/engineering/m2-struct-parameter-signatures.md).
- Private record-parameter IR metadata and independent verification are verified at `9b43e0d` (28 native groups and 2,226 CLI cases per development/release profile); its initial VM availability gate and source gate are historical and superseded by metered calls and source lowering. See [the IR foundation](docs/engineering/m2-struct-parameters-ir.md).
- Private mixed array/record argument copies are verified in development and release (70 native groups per profile, 9 new and 61 affected) through `array_owners::copy_call_arguments`; full-batch source validation and owner/payload admission precede mutation. Its statement that source lowering remained unavailable is historical. See [the storage contract](docs/engineering/m2-call-argument-copies.md).
- Private metered record CALL execution is implemented at `97bf1e2`; development and release each passed 47 unique native groups stepwise (21 core, then 26 regressions) with matching 58 input hashes across both receipts. Mixed aggregate copies precede scalar/return-frame publication; existing scalar/array prices remain unchanged. Its source-gate claim is historical and superseded by the source parameter slice. See [the VM contract](docs/engineering/m2-struct-call-vm.md).
- Immutable nominal by-value source record parameters are verified in development and release. Bare exact-type binding arguments are accepted; mutable inputs are captured with `SCOPY` before later arguments evaluate. Development and release each passed 51 native groups (14 core, 37 regressions) and 2,318 CLI cases. See [the source contract](docs/engineering/m2-struct-parameters-source.md).
- A bounded nominal record-result signature foundation was implemented and verified
  for its original baseline (22 native groups and 2,317 CLI cases per profile).
  `return_records` retains ID + 1 in 1..32, while `return_types` remains zero. Its
  blanket rejection of every scanned record result before IR, catalog, or body
  lowering is historical and superseded by the bounded source successor. See
  [the signature contract](docs/engineering/m2-struct-result-signatures.md).
- Private record-result IR and verification are implemented at `dc1574b` and verified in development and release. The
  `u8[16]` `record_results` table stores a callee-owned shape site plus one; `SRET` (50) requires one
  live exact-nominal callee record, and CALL destinations use `144 + site`. Its kind 11 runtime gate is
  historical and is superseded by the VM ownership-transfer successor. See [the IR contract](docs/engineering/m2-struct-results-ir.md).
- Private record-result VM ownership transfer is implemented at `68552f0` and verified for its original inputs.
  `SRET` (50) prepays 42,113 Fuel, checks the child and parent token layout, validates the complete planned
  record through a 128-byte scratch snapshot, clears the child token, and publishes that token in the caller.
  Owner descriptors, order, generations, and payload stay unchanged; no owner or payload is reserved.
  Profiles, version capabilities, and scalar/array prices were unchanged by that VM slice.
  Development and release each passed 34 native groups and 2,317 CLI cases.
  See [the VM contract](docs/engineering/m2-struct-result-vm.md) and
  [Windows receipt](docs/evidence/m2-struct-result-vm-windows-20261028.json).
- Bounded source record results are verified in development and release at
  `bb401a4` with tooling `78a1fb4`. A bare visible
  exact-nominal `return name;` and an explicit `let`/`var` exact-nominal call
  initializer now reach `SRET` and the existing record-result VM. Result anchors
  are reserved before bodies by reusing an exact nominal formal or adding a dead
  function-owned site. Pending initializer names stay invisible until CALL and
  capture cleanup finish. The source finisher drops other mixed arrays and records
  in reverse lexical order before `SRET`. Development and release each passed 14
  native groups and 2,438 CLI cases. The 70 result-signature CLI cases were then
  rerun per profile after a checker-only metadata repair. See [the source
  contract](docs/engineering/m2-struct-result-source.md) and [Windows
  receipt](docs/evidence/m2-struct-result-source-windows-20261028.json), which
  rechecks 219 inputs.
- Direct nominal record return calls are implemented at `c23e6e4`. An exact-type
  `return make(...);` uses the existing CALL/SRET ownership transfer and shared
  reverse mixed cleanup. Pending destinations remain absent from names during
  argument evaluation. Development and release each passed 18 native groups and
  505 CLI cases in separate core/regression phases; 196 input hashes match and
  were rechecked. Earlier receipts remain historical for their original inputs.
  See [the contract](docs/engineering/m2-struct-return-calls.md)
  and [focused receipt](docs/evidence/m2-struct-return-calls-windows-20261028.json).
- Direct nominal record constructor returns are implemented at `0a7b539` and
  verified in development and release. Fields and exact-nominal child values
  stage in declaration order before anonymous site allocation and `SINIT`.
  Nested returns and loop transfers therefore leave no pending owner or name.
  The shared reverse mixed finisher emits `SRET`; no opcode, Fuel charge, profile
  or version flag changes. Each profile passed 26 native groups (6 new, 20
  regressions) and 532 CLI cases in separate core/regression phases. The
  [receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json)
  records 199 matching rechecked inputs and both retained CLI identities.
  Earlier receipts remain historical for their original inputs. See [the
  contract](docs/engineering/m2-struct-return-constructors.md).
- Exact-nominal subrecord return paths are implemented at `d4aa643` and verified
  in development and release. A bare `return outer.child;` accepts an
  exact-nominal record endpoint, including deep paths. The shared
  extractor emits consecutive `SREAD` operations into consecutive registers,
  allocates one anonymous immutable site, and emits one `SINIT`; the source
  stays live through creation. The shared finisher drops other mixed arrays and
  records in reverse order before `SRET`. No opcode, Fuel charge, profile, or
  version field changes. Development and release each passed 25 native groups
  (6 core, 19 regressions) and 579 CLI cases. All four phase invocations
  rechecked 205 identical inputs; development core ran before `d4aa643` and the
  other phases ran after it. Record borrows, general/parenthesized expressions,
  and `call().child` returns remain unsupported. Earlier receipts remain
  historical for their original inputs. See [the
  contract](docs/engineering/m2-struct-return-paths.md).
- Exact-nominal child record call-result assignment is implemented at
  `63be9e5`. A shared `compiler::record_call_assignment` handles root and child
  destinations. The child branch validates a mutable exact path, emits
  `SSUBASSIGN` (47) with source leaf zero, then `SDROP` releases the anonymous
  result. Existing CALL and capture cleanup precede the normal assignment;
  destination roots, owners, and neighboring bytes stay live. Development and
  release each passed 26 native groups and 575 CLI cases. No opcode, VM, Fuel,
  profile, or version changes. See [the
  contract](docs/engineering/m2-struct-child-call-assignment.md) and [Windows
  receipt](docs/evidence/m2-struct-child-call-assignment-windows-20261028.json).
- Exact-nominal record calls in constructor child fields are implemented at
  `c4cd6ab` and verified in development and release. `compiler::record_child_call` reserves the exact child result site,
  evaluates arguments, stages every returned scalar leaf through the shared
  `struct_value_source::stage_part`, then emits `SDROP` before later fields or
  parent publication. Declaration, root replacement, child replacement, and
  direct constructor return all use the same `record_constructor`. A pending
  parent is not live during the child call; an old replacement parent remains
  live and visible until replacement or early-exit cleanup; argument effects
  are not rolled back. Each profile passed 23 native groups (6 core,
  17 regressions) and 529 CLI cases in four separate phase invocations, with
  211 verified input identities. No opcode, VM, Fuel, profile, or version
  change is involved. General aggregate arguments outside the exact-record-formal call position,
  parenthesized child calls,
  and call-result field
  selection remain unsupported. See [the
  contract](docs/engineering/m2-struct-child-calls.md) and [Windows
  receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json).
- The record-result IR slice's evidence remains 39 unique native groups and 2,317 CLI cases in development and release. The [core receipt](docs/evidence/m2-struct-results-ir-core-windows-20261028.json) records 21 native groups (8 new record-result, 6 array-result, 7 record-parameter), CLI builds and all 2,317 cases; the [regression receipt](docs/evidence/m2-struct-results-ir-regressions-windows-20261028.json) records 18 native-only groups (6 array-result VM, 8 record-call VM, 4 scalar-function), with no build or CLI rerun. CLI coverage is 72 record-result signature, 66 record-formal signature, 114 source record-parameter, 96 array-result signature and 1,969 M1 cases per profile. These were two separate phase invocations across implementation commit `dc1574b`, with disjoint native selections and matching 212 input hashes, compiler and SDK identities. All inputs and the final release CLI were rechecked before archival. Full native/CLI suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.
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
  fields. A [private copy/assignment slice](docs/engineering/m2-struct-copy.md) appends
  independent scalar records and overwrites existing records with normalized snapshots,
  including self and partial overlap. A [private nested-storage slice](docs/engineering/m2-struct-nested-storage.md)
  initializes selected acyclic records from depth-first scalar leaf inputs and reads or
  writes scalar field paths in the shared arena. Selected roots are capped at 128 bytes;
  the full catalog is replanned at each boundary, and unselected valid records may be
  larger. A [private nested copy/assignment slice](docs/engineering/m2-struct-nested-copy.md)
  appends nested records by value and overwrites existing extents without a cursor
  change, including self and partial overlap. A shared [struct-owner foundation](docs/engineering/m2-struct-owners.md)
  puts record descriptors in the existing 16-slot table and rechecks catalog layout on
  access; array-only APIs reject record tokens. A [private struct-owner copy/assignment slice](docs/engineering/m2-struct-owner-copy.md)
  appends independent record owners and requires exact record identity for assignment.
  Its 17-group Windows selection passed development and release. The previous 34-group owner receipt is historical
  for changed inputs. A [private struct IR and verifier](docs/engineering/m2-struct-ir.md)
  introduced entry-owned bindings for opcodes 41..46: SINIT, SCOPY, SREAD,
  SWRITE, SDROP, and SASSIGN. Initialization consumes all depth-first scalar leaves
  in consecutive registers with exact types; reads and writes use flattened leaf
  ordinals. Full catalogs are replanned, record lifetimes occupy bits 16..31 beside
  array bits 0..15, and joins or backedges require exact live sets. The original
  verifier limited struct instructions to entry; calls into entry remain rejected
  when bindings exist. A
  [private struct VM](docs/engineering/m2-struct-vm.md) now executes those
  instructions. It adds sixteen entry binding tokens while sharing the existing
  owner table and one payload arena. A nonempty array or record catalog prepares
  1+capacity Fuel with a 65,536-byte cap; the scalar path is unchanged. Every struct
  opcode prepays a fixed charge before traversal, owner checks, staging, or token
  and register mutation. Success returns remaining Fuel; runtime failures abort the
  invocation. The `--vm` selection passed all 38 groups in development and release,
  and the existing 115-case CLI suite passed in both profiles. Results are recorded
  in the struct VM native and CLI receipts. The old `--ir` 46-group and
  115-case CLI receipts are historical for changed runtime, test, harness, and
  root-lock inputs.
  A [private function-owned record IR foundation](docs/engineering/m2-struct-function-ir.md)
  assigns each of the 16 static record sites to a function. Active owners must be
  declared functions, unused owner bytes must remain zero, and every opcode
  41..49 must target the active function; copy/assign/subassign sources must use
  the same function. Each function starts with all record bindings dead, while
  existing cleanup, joins, backedges, and entry reentry rules are unchanged. No
  opcode, Fuel charge, VM dispatch, version capability, or source form is added.
  The entry-frame-only kind 5 boundary was the foundation's historical checkpoint.
  The complete `--function-ir` invocation passed 31 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-function-ir-windows-20261027.json) records 106 input hashes,
  compiler/artifact identities, commands and outcomes. Other CLI matrices, full
  native suites, Linux, packaging, isolation and performance were not rerun. That
  31-group receipt remains historical for its original runtime and test inputs.
  A [private frame-local record VM](docs/engineering/m2-struct-function-vm.md)
  now executes verified helper IR in up to 32 guest frames. Each frame has sixteen
  record token slots over the same shared 16 owners and payload arena, indexed like
  arrays. Opcodes, Fuel, frontend lowering, and version capabilities are unchanged.
  The 13-group smoke suite passed in one native invocation. The complete `--function-vm` invocation passed 46 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
  compiler/artifact identities, commands and outcomes. Implementation commit:
  `80ed712`. Other CLI matrices, full native suites, Linux, packaging,
  isolation and performance were not rerun.
  Frame entry allocates no separate table or arena, while `SINIT`/`SCOPY` reserve
  shared owners and payload and require dead destination tokens. Writes and
  assignments require live mutable destinations. Drops clear frame tokens; dead
  middle extents stay charged until suffix reclamation. Only one of the six
  function-owned IR test groups changed expectation, from kind 5 to return 42.
  At `80ed712`, source helper records and record parameters/results remained
  unsupported. Source successors now implement helper records, record parameters,
  and a bounded set of record results; record borrows remain unsupported. The 512-slot token
  array carries no measured allocation, stack, or speed claim.
  Source [record parameters](docs/engineering/m2-struct-parameters-source.md) are
  implemented at `d0ca7e7` and verified in development and release. Each formal is an immutable nominal
  record; at that checkpoint each argument was one bare visible binding of that
  exact type. The result-argument successor also accepts a bare exact-result call.
  Constructors, paths, casts, and aggregate expressions do not satisfy the formal.
  A mutable source is copied by `SCOPY` into an anonymous lexical capture before
  the next argument evaluates; the final CALL still creates an independent callee
  owner. All formal sites are predeclared after the catalog scan and bound by
  owning function plus record-formal ordinal within the unchanged 16 static sites.
  No second 128-byte signature site map is added. Scalar and array returns, `?`
  propagation, normal lexical exits, and loop transfers reuse the record-aware
  `array_source::release_from`; array results reuse the existing finisher. Those
  paths already supported records, so no new cleanup change is claimed. A scalar
  return drops each visible formal, including a record formal, before `RET`; an
  array return drops non-result records before `ARET`. Record results, borrows,
  `ref`, and `var` parameters remain unsupported.
  Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](docs/evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](docs/evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.
  A [declaration-only source struct slice](docs/engineering/m2-struct-source.md)
  parses bounded top-level declarations, resolves scalar and by-value named
  fields, and attaches immutable declaration-order layouts. Its 23 native groups
  and 2,208 CLI cases per profile remain historical evidence for that
  declaration-only slice. The [bounded source struct-value slice](docs/engineering/m2-struct-values.md)
  is the historical read baseline: entry-only
  `let|var TYPE NAME = TYPE { .FIELD = EXPR, ... };` construction for scalar-field
  roots; exact, declaration-ordered typed fields staged before consecutive loads
  and `SINIT`. The compiler declares the name only after emitting the complete
  initializer; runtime `SINIT` failure aborts. One-level
  `NAME.FIELD` reads use `SREAD`. Mixed lexical exits, loop transfers, and
  returns release arrays and records in reverse order. Read-only record programs
  select `brownie.m2-struct-read/1`; declaration-only programs keep their existing
  profile. Construction is capped at 128 planned bytes and 16 fields, with 16
  record sites, the shared owner table, 65,536-byte payload cap, and existing
  Fuel. For that read baseline, development and release each passed 28 native
  groups and 2,352 CLI cases through the focused harness, plus three supplemental
  early-transfer/forward-name cases. The
  [receipt](docs/evidence/m2-struct-values-windows-20261026.json) records
  toolchain, inputs, artifacts, commands, and limitations. That read receipt is
  historical for the current field-write, source-copy, and nested-source compiler
  inputs. At that baseline, struct parameters/results and borrows were unsupported;
  nested type declarations and construction are handled by the nested successor,
  and source record parameters by their later successor. Record results and
  borrows remain unsupported.
  A [source struct-field write slice](docs/engineering/m2-struct-write.md) adds
  entry-only `NAME.FIELD = EXPR;` for one mutable scalar leaf. The binding and
  field resolve before a single exact-typed RHS; `SWRITE` follows the expression
  and terminator and reuses the existing record extent. For-header writes remain
  rejected, condition reads and body writes follow normal statement handling, and
  no copy, owner, or payload extent is added. Programs with nonempty record
  bindings and opcode 44 select `brownie.m2-struct-write/1`; `--version --json` adds
  `struct_write_profile`. VM checks, codec, 41,281 Fuel, 16 shared owners, and the
  65,536-byte cap remain unchanged. The full `--write` selection passed 24 native
  groups and 2,472 CLI cases in each development/release profile. The
  [write receipt](docs/evidence/m2-struct-write-windows-20261026.json) records
  commands, source/tool identities, artifacts, outcomes, and limitations; its
  results are historical for the current source-copy and nested-source inputs. The earlier nested-storage 18-group receipt is
  historical for changed inputs; nested-copy 24-group checks passed development and release.
  The copy slice's Windows 28-group receipt passed development and release after
  moving snapshot staging into caller-owned scratch. Earlier planner and storage
  receipts are historical for changed inputs.
  A [source struct-copy slice](docs/engineering/m2-struct-source-copy.md) adds
  entry-only bare-name `let|var P q=p;` initialization and `p=q;` assignment for
  exact nominal record types, including whole nested roots. Sources may be immutable, assignment targets
  must be mutable, and self-assignment is accepted. `SCOPY` creates an independent
  owner and extent; `SASSIGN` reuses the destination extent. The type-name/local
  ambiguity is resolved by inspecting `{` after the initializer name. Record
  statements remain unavailable in helpers and `for` initializer/post clauses;
  that slice left constructor RHS assignment, aggregate expressions, struct
  parameters/results, and borrows unsupported. Nested constructors, scalar paths,
  and child binding initializers are handled by the successors. Programs with
  nonempty record bindings and opcode 42 or 46 select
  `brownie.m2-struct-copy/1`, before opcode 44 write selection and read fallback;
  `--version --json` adds `struct_copy_profile`.
  Existing 128-byte roots, 16 fields, 16 record sites, 16 shared owners, and the
  65,536-byte payload cap remain. Development and release each passed
  39 native groups and 2,582 CLI cases, including 110 source-copy cases.
  [Stepwise evidence](docs/evidence/m2-struct-source-copy-windows-20261026.json)
  records input hashes, artifacts and development native/build reuse after CLI
  fixture corrections. The complete aggregate harness was not rerun. That receipt
  is historical for the current nested-source compiler inputs.
  Implementation commit: `f9cf654`.
  A [bounded source nested-struct slice](docs/engineering/m2-struct-source-nested.md)
  admits inline named child constructors, multi-segment scalar read/write paths,
  and whole-root copies for entry-owned records. A nested constructor is traversed
  iteratively in source order. Each scalar leaf's tag comes directly from the
  cursor, and one staging slot is allocated immediately before that leaf's
  expression is parsed; no tag array is returned. Leaves stage left to right,
  then consecutive loads and one `SINIT` follow the complete initializer. Child
  constructors reserve no owner, site, or extent. Verifier and VM rules are
  unchanged. Path segments resolve to depth-first scalar-leaf
  ordinals, including leaves in preceding nested siblings; `SREAD`/`SWRITE` use the
  exact scalar tag at the endpoint. The compiler declares a binding only after
  emitting its complete initializer and `SINIT`; runtime failure aborts. Control-
  transfer cleanup drops only owners visible before the pending declaration.
  Whole nested roots use the existing `SCOPY`/`SASSIGN`.
  Source staging is capped at 16 scalar leaves total, record nesting and path
  length at 16, selected roots at 128 bytes, and the existing 16 record sites, 16
  shared owners, 65,536-byte arena, 128-register and 256-instruction limits remain.
  The private VM still accepts 128 leaves. Traversals of the record tree are
  iterative; scalar expression depth limits are unchanged. A bound record with a
  nested field selects `brownie.m2-struct-nested/1` ahead of the copy, write, and
  read profiles; unused nested declarations do not promote a flat or non-record
  program. `--version --json` adds `struct_nested_profile`. Development and
  release each passed 36 native groups and 2,710 CLI cases, including 128 nested
  cases, through the complete `--nested` harness on the corrected source.
  The [receipt](docs/evidence/m2-struct-source-nested-windows-20261027.json)
  records input hashes, artifacts, commands and the corrected release regression;
  it is historical for the current child-binding compiler inputs.
  Implementation commits: `576d062` and `716c14b`.
  A [child binding initializer slice](docs/engineering/m2-struct-child.md) admits
  inline child values such as `R { .i = i }` when the field type and a visible
  whole binding have the same nominal identity. At the child field, it emits one
  `SREAD` and `STORE` per source scalar leaf into the parent's staging before any
  later sibling expression; the snapshot is independent and the source stays
  live. No `SCOPY`, temporary owner, site, or extent is created. Only the new
  parent root consumes an owner and extent, and its name becomes visible after
  the complete `SINIT`. Existing leaf, depth, root, site, owner, arena, register,
  and instruction limits are unchanged. The profile remains
  `brownie.m2-struct-nested/1`; version JSON adds
  `struct_child_binding_initializers: true`. The complete `--child` harness passed
  21 native groups and 2,798 CLI cases in each development/release profile.
  The [receipt](docs/evidence/m2-struct-child-windows-20261027.json) records 90
  input hashes, compiler and CLI artifact hashes, commands, and outcomes.
  Implementation commit: `ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.
  A [subrecord declaration initializer](docs/engineering/m2-struct-extract.md)
  also admits `let I i = p.i` and deeper exact-nominal record endpoints. It reads
  the selected scalar leaf range directly into consecutive registers and emits
  one `SINIT`, without `STORE`, `LOAD`, `SCOPY`, or a temporary owner. The source
  stays live; the destination has an independent site, owner, and extent. Scalar
  expressions still reject record endpoints. The assignment successor below adds
  writes to/from record endpoints.
  At that checkpoint, helper records, parameters/results, and borrows were
  unsupported; later source slices add helper records and record parameters. Version
  JSON adds `struct_subrecord_initializers: true`; the nested profile is unchanged.
  Development and release each passed 26 native groups and 2,915 CLI cases
  stepwise. Development reuses its unchanged 26-group result after two CLI-only
  diagnostic fixes; final CLI matrices and release native groups ran afterward.
  The [receipt](docs/evidence/m2-struct-extract-windows-20261027.json) records 92
  input hashes, compiler/artifact hashes, commands, and native reuse provenance.
  Implementation commit: `f65a1d7`.
  The child-binding receipt is historical for changed compiler and fixture inputs.
  A [subrecord assignment successor](docs/engineering/m2-struct-subassign.md)
  admits exact-nominal `p.i = q.i`, `p.i = i`, and `i = p.i` with a mutable
  destination. All source leaves are read before writing the existing target.
  No new site, owner, extent, or temporary structure is created. Whole bare-name
  assignment retains `SASSIGN`; its historical partial lowering emitted
  `SREAD`/`SWRITE`. That baseline did not guarantee transaction rollback.
  Existing bounds and the nested profile remain; version JSON adds
  `struct_subrecord_assignment`. The complete `--subassign` invocation passed
  15 native groups and 3,044 CLI cases in each development/release profile.
  The [receipt](docs/evidence/m2-struct-subassign-windows-20261027.json) records
  91 harness input hashes plus four CLI fixture hashes, compiler/artifact hashes,
  commands, and outcomes. Implementation commit: `666da70`.
  The extraction receipt is historical for changed compiler and fixture inputs.
  The [atomic successor](docs/engineering/m2-struct-subassign-atomic.md) lowers
  those same forms to `SSUBASSIGN` (47), with independently verified live mutable
  destination, source, nominal node IDs, and leaf ordinals. Runtime prepays
  131,072 Fuel, validates owners/ranges, stages at most 128 canonical bytes, then
  commits once. Failure leaves the selected destination unchanged; external
  effects and earlier statements are not rolled back. No new site, owner,
  extent, or scalar register is used. Sixteen-leaf assignments now execute in
  the CLI allowance. Version JSON adds `struct_subrecord_assignment_atomic`;
  the nested profile remains. The complete `--atomic` invocation passed 26
  native groups and 3,046 CLI cases per development/release profile. The
  [receipt](docs/evidence/m2-struct-subassign-atomic-windows-20261027.json) records
  99 input hashes, compiler/artifact identities, commands, and outcomes. The
  separately [verified foundation](docs/evidence/m2-struct-atomic-foundation-windows-20261027.json)
  passed nine groups per profile at `2b5917c`. Integration commit: `5589803`.
  The per-leaf assignment receipt is historical for changed inputs.
  The [constructor child-path successor](docs/engineering/m2-struct-child-path.md)
  admits `R { .i = p.i }` and deeper exact-nominal record endpoints. It snapshots
  selected leaves before later sibling expressions and introduces no temporary
  owner, site or extent. The VM, verifier, bounds and nested profile are unchanged;
  version JSON adds `struct_child_path_initializers`. The complete `--child-path`
  selection passed 19 native groups and 419 CLI cases in each development/release
  profile. The [receipt](docs/evidence/m2-struct-child-path-windows-20261027.json) records 99 input hashes, compiler/artifact
  identities, commands and outcomes. Implementation commit: `680f57a`. This focused
  selection does not rerun scalar/array or other struct CLI matrices, full native
  suites, Linux, packaging, isolation or performance. Earlier receipts are historical
  for changed frontend, root-lock, fixture and harness inputs.
  A [private scalar-value replacement foundation](docs/engineering/m2-struct-replace-values.md) now stages every scalar
  field before overwriting an existing exact-nominal root. Owner tokens, order and
  payload use remain unchanged, including at full capacity. Initialization and
  replacement share one encoder. This adds no source syntax, opcode, verifier,
  VM dispatch, Fuel charge or version capability; constructor RHS assignment
  remained unavailable in that slice. The complete `--replace-values` invocation passed 21 native
  groups and 214 CLI cases per development/release profile. The [receipt](docs/evidence/m2-struct-replace-values-windows-20261027.json)
  records 102 input hashes, compiler/artifact identities, commands and outcomes.
  Implementation commit: `6509e27`. The selection covers six new replacement groups,
  six nested-storage, six owner-copy and three subrecord-owner groups, plus 83
  existing child-path and 131 existing assignment CLI cases. Other CLI matrices,
  full native suites, Linux, packaging, isolation and performance were not rerun.
  Earlier receipts are historical for changed storage, owner, root-lock and harness
  inputs. Metered VM integration is covered by the successor below; source lowering
  is covered by the [constructor-assignment successor](docs/engineering/m2-struct-replace-source.md).
  Private [metered root replacement](docs/engineering/m2-struct-replace-vm.md) now executes `SREPLACE` (48) after
  independent live/mutable/nominal and consecutive scalar-input verification.
  The VM prepays 46,145 Fuel, stages canonical bytes and overwrites existing storage
  without a temporary owner, site or extent. Scalar definitions and owner live sets
  are unchanged. No constructor-assignment source syntax or version capability
  was added by that slice. The complete `--replace-vm` invocation passed 27 native groups (6 new,
  8 existing VM, 9 IR, 4 atomic assignment) and 214 CLI cases (83 child path,
  131 assignment) per development/release profile. The [receipt](docs/evidence/m2-struct-replace-vm-windows-20261027.json) records
  102 input hashes, compiler/artifact identities, commands and outcomes.
  Implementation commit: `6f1b38f`. Other CLI matrices, full native suites, Linux,
  packaging, isolation and performance were not rerun. Earlier receipts are
  historical for changed verifier, VM, profile-selection, root-lock, test and harness
  inputs. Those results remain scoped to the metered VM slice.
  [Entry-only mutable root constructor assignment](docs/engineering/m2-struct-replace-source.md)
  is now implemented at `1627ee4`. Constructor RHS values stage in source order
  before consecutive `LOAD`s and one `SREPLACE` (48), without another owner, site,
  or extent. Version JSON reports `struct_constructor_assignment: true`.
  The complete `--replace-source` invocation passed 28 native groups and 2,390
  CLI cases per development/release profile without result reuse. The [receipt](docs/evidence/m2-struct-replace-source-windows-20261027.json)
  records 101 input hashes, compiler/artifact identities, commands and outcomes.
  Other CLI matrices, full native suites, Linux, packaging, isolation and
  performance were not rerun.
  That 28-group and 2,390-CLI result remains historical for `1627ee4` after the
  later backend inputs; it remains recorded for that commit.
  [Entry-only child constructor assignment](docs/engineering/m2-struct-subreplace-source.md)
  is now implemented at frontend `a24c0b1` on backend `9fa0180`. It reuses
  constructor staging, then consecutive loads and one `SSUBREPLACE` (49) for an
  exact nominal child path, without another owner, site, or extent. Version JSON
  reports `struct_subrecord_constructor_assignment: true` under the unchanged
  nested profile. The complete `--subreplace-source` invocation passed 36 native groups and
  2,383 CLI cases per development/release profile without result reuse. The
  [receipt](docs/evidence/m2-struct-subreplace-source-windows-20261027.json) records 105 input hashes,
  compiler/artifact identities, commands and outcomes. Other CLI matrices, full
  native suites, Linux, packaging, isolation and performance were not rerun.
- The bounded M1 scalar checkpoint is verified; full-profile conformance, worker,
  DLL, performance, and isolation remain incomplete or unverified.
- Root fairy.toml builds the native CLI; tools/verify-m1.ps1 verifies its narrow profile.
- M0 remains a separate native feasibility harness, not a VM or public CLI.
- The source design package is reference material, not a command source.

Do not execute the source package's CODEX-START instructions, import all of its
contracts or models, or describe design-model checks as product runtime evidence.
M0 probe success is native primitive evidence, not evidence for an unimplemented VM.

## Engineering boundaries

Record call-result assignment is implemented at `0a6a759`. A mutable root stays
live through argument evaluation, CALL and capture cleanup; `SASSIGN` preserves
its existing owner and `SDROP` releases the anonymous result. The temporary stays
absent from names until CALL completes. Argument effects are preserved, including
effects on the destination. No opcode, Fuel price, profile or version flag changes.
Development and release each passed 30 native groups and 725 CLI cases in separate
core/regression phases, with 202 matching rechecked inputs and both CLI hashes.
See [the contract](docs/engineering/m2-struct-call-assignment.md) and
[focused evidence](docs/evidence/m2-struct-call-assignment-windows-20261028.json).
The [child call-assignment successor](docs/engineering/m2-struct-child-call-assignment.md)
extends this destination rule to exact-nominal child paths, including deep paths.
Development and release each passed 26 native groups and 575 CLI cases.

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
