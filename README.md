# Brownie C

- Direct UTF-8 repeated-byte literals: implemented at `3d569fa` and verified in
  development/release, each with 13 native groups and 380 CLI cases.
  `text::valid_utf8([value; N])` evaluates
  its u8 filler once before publishing one temporary array, then scans and drops
  it immediately. Pending filler exits create no owner; nested temporaries reuse
  capacity. Version JSON adds `array_utf8_literals: true`.
  See [the literal contract](docs/engineering/m2-array-utf8-literals.md) for verification and limits.

- Direct UTF-8 array-result calls: implemented and verified in development/release,
  each with 13 native groups and 356 CLI cases. `text::valid_utf8(make(...))` reuses ordinary
  CALL/ARET, scans once and immediately drops its anonymous result. Argument
  exits retain existing cleanup; no result payload copy is added. Version JSON
  adds `array_utf8_call_results: true`.
  See [the call-result contract](docs/engineering/m2-array-utf8-calls.md) for verification and limits.

- Source u8-array UTF-8 predicate: implemented and verified in development/release,
  each with 18 native groups and 256 CLI cases. `text::valid_utf8(bytes)` lowers to opcode 51
  without an array copy or extra owner. Named locals, parameters and array-result
  bindings are supported. Direct temporary calls were unavailable at that checkpoint;
  the successor above now accepts them. Buffer/text APIs remain unavailable. Version JSON adds `array_utf8_predicate: true`.
  See [the source contract](docs/engineering/m2-array-utf8-source.md) for verification and limits.

- Private u8-array UTF-8 opcode: implemented and verified in development/release,
  each with 25 native groups (6 new, 19 regressions) and 8 CLI sentinels.
  Opcode 51 independently verifies a live function-owned u8 array and bool
  result, prepays 33+4*length Fuel and preserves payload/ownership. Guest
  syntax and version capabilities were unchanged at that checkpoint; the source
  successor above now exposes the named-array predicate.
  See [the UTF-8 VM contract](docs/engineering/m2-array-utf8.md).

- Host shutdown descriptor sweep: implemented and verified in development/release,
  each with 99 native scenarios; all 198 processes exit with zero tracked live
  allocations. Existing owners are enumerated in descending slot order; failed
  preflight advances the pass, pending accounting pins its offer, and explicit
  retry revisits survivors. Native resources remain host-owned.
  See [the sweep contract](docs/engineering/m2-buffer-host-sweep.md).

- Explicit multi-root host shutdown visitation: implemented and verified in
  development/release, each with 95 native scenarios; all 190 processes exit
  with zero tracked live allocations. Independently writable roots close during
  partial lease cleanup; one shared pending close Plan blocks other closes
  until settled. Completion requires no live owners or pending accounting.
  See [the visitation contract](docs/engineering/m2-buffer-host-batch.md).

- Explicit single-root host shutdown: implemented and verified in development/
  release, each with 91 lifecycle/allocator scenarios; all 182 processes exit
  with zero tracked live allocations. One ownership-taking call drains sessions,
  destroys the selected native root and refunds its charge. Preflight errors
  return ownership; failed finish retains the Plan for accounting-only retry.
  Provider regressions also passed 16 processes. Full Instance wiring is pending.
  See [the host close contract](docs/engineering/m2-buffer-host-close.md).

- Buffer Provider inconsistency injection: verified in development and release,
  each with four injected faults and four no-fault controls; all 16 processes
  exit with zero tracked live allocations. Capacity/copy/append/resize failures
  preserve the old root/token and registry charge, clean unpublished storage,
  restore reservations, and allow explicit retry. Product Fairy sources unchanged.
  See [the provider probe](docs/engineering/m2-buffer-provider.md).

- Private UTF-8 registry storage admission: implemented and verified in development/
  release, each with 87 native scenarios (4 new, 83 regressions); all 174 processes
  exit with zero tracked live allocations. Each active Pool reserves 2,112 logical
  bytes against Instance/Engine limits before use. Failed shutdown keeps its charge;
  completed shutdown refunds once and preserves peaks. No new heap allocation.
  See [the admission contract](docs/engineering/m2-buffer-utf8-admission.md).

- Private UTF-8 registry shutdown: implemented and verified in development/release,
  each with 83 native scenarios (4 new, 79 regressions); all 166 processes exit
  with zero tracked live allocations. One-way Open/Closing/Closed state blocks
  admission and scan progress once shutdown starts; failures remain retryable.
  Explicit host hook only; automatic Instance teardown/VM wiring is pending.
  See [the shutdown contract](docs/engineering/m2-buffer-utf8-shutdown.md).

- Private host UTF-8 session registry: implemented and verified in development/
  release, each with 79 native scenarios (4 new, 75 regressions); all 158 processes
  exit with zero tracked live allocations. Sixteen fixed slots retain sessions,
  generation tickets reject stale operations, and batch cleanup retains failures
  for retry. No extra heap allocation; the explicit shutdown successor is above.
  Automatic Instance teardown and VM integration remain pending.
  See [the registry contract](docs/engineering/m2-buffer-utf8-pool.md).
- Private leased UTF-8 sessions: implemented and verified in development/release,
  each with 75 native scenarios (4 new, 71 regressions); all 150 processes exit
  with zero tracked live allocations. Sessions acquire a read lease, retain it
  on Fuel shortage and release it on completion, scan error, cancellation or
  explicit abandonment. Cleanup failures retain ownership; VM/guest wiring is pending.
  See [the session contract](docs/engineering/m2-buffer-utf8-session.md).
- Private Buffer read leases: implemented and verified in development and release,
  each with 71 instrumented native scenarios (4 new, 67 regressions); all 142
  processes exit with zero tracked live allocations. A leased owner permits reads
  and rejects descriptor-aware writes, resizing, replacement, close and release.
  Acquisition/release are explicit; guest borrow enforcement remains unfinished.
  See [the read-lease contract](docs/engineering/m2-buffer-read-lease.md).
- Private cooperative UTF-8 scan cancellation: implemented and verified in
  development and release, each with 67 native scenarios (4 new, 63 regressions);
  all 134 processes exit with zero tracked live allocations. A caller-supplied
  cancellation snapshot retires scan progress before Fuel or byte access, without
  changing Buffer storage or reservation accounting. VM/scheduler wiring is pending.
  See [the cancellation contract](docs/engineering/m2-buffer-utf8-cancel.md).
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
- Status: M1 scalar checkpoint verified; experimental M2 function-owned scalar arrays and source records implemented. Array parameters/results and record construction, field access, copies, extraction, and replacement are available. Immutable by-value record parameters are verified in development and release. Private record-result VM ownership transfer is verified for its original inputs. Bounded source record returns and typed call initializers are verified in development and release at `bb401a4` (14 native groups and 2,438 CLI cases per profile). Direct nominal record constructor returns are verified in development and release at `0a7b539`. Record calls in constructor child fields are implemented at `c4cd6ab` and verified in development and release. Record borrows, workers, DLL embedding, and full-profile conformance remain incomplete.
- Root constructor assignment: verified in development and release; child constructor assignment is verified in development and release.
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Source helper-local records: implemented at `98a4525`; verified in development and release.
- Source record parameters: implemented at `d0ca7e7`; development and release each passed 51 native groups and 2,318 CLI cases in separate core/regression phases.
- Record-result signatures: verified for their original baseline (22 native groups and 2,317 CLI cases per profile). Nominal results are recorded separately from scalar and array metadata. The former blanket pre-IR gate and "source record returns unavailable" status are historical, superseded by the [bounded source successor](docs/engineering/m2-struct-result-source.md).
- Record-result IR/verifier: implemented at `dc1574b` and verified in development and release. Private metadata uses callee-owned shape anchors and `SRET` checks a single live exact-nominal record; its kind 11 runtime gate is historical and superseded by the VM transfer successor. See [the IR contract](docs/engineering/m2-struct-results-ir.md).
- Record-result VM: ownership transfer is implemented at `68552f0` and verified for its source-gated inputs. `SRET` prepays 42,113 Fuel, validates the complete result without payload writes, clears the child token, and publishes it into the caller-owned destination. The [bounded source successor](docs/engineering/m2-struct-result-source.md) now emits a subset of these calls and returns and is verified in development and release. See [the VM contract](docs/engineering/m2-struct-result-vm.md).
- Direct record return calls: implemented at `c23e6e4`. `return make(...);` forwards
  an exact-nominal result through the existing CALL/SRET ownership transfer.
  Development and release each passed 18 native groups and 505 CLI cases in
  separate core/regression phases, with 196 matching rechecked inputs. See
  [the source contract](docs/engineering/m2-struct-return-calls.md).
- Direct record constructor returns: implemented at `0a7b539` and verified in
  development and release. `return Pair { ... };` stages fields in declaration
  order, creates one anonymous immutable result site only after evaluation, and
  transfers it with the existing `SRET`. See [the constructor
  contract](docs/engineering/m2-struct-return-constructors.md).
- Design date: 2026-10-23
- Record call-result assignment: implemented at `0a6a759`. `p = make(...);`
  retains the live mutable root through argument evaluation and CALL, copies
  the exact-nominal result with `SASSIGN`, then drops the anonymous result.
  Development and release each passed 30 native groups and 725 CLI cases.
  See [the contract](docs/engineering/m2-struct-call-assignment.md).
- Child record call-result assignment: implemented at `63be9e5`.
  `outer.child = make(...);`, including deep paths, copies the anonymous result
  into the existing child with `SSUBASSIGN` and releases the temporary with
  `SDROP`. Development and release each passed 26 native groups and 575 CLI
  cases. See [the contract](docs/engineering/m2-struct-child-call-assignment.md)
  and [Windows receipt](docs/evidence/m2-struct-child-call-assignment-windows-20261028.json).
- Constructor child record calls: implemented at `c4cd6ab` and verified in
  development and release, each with 23 native groups and 529 CLI cases across
  separate core/regression phases. See the [Windows
  receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json).
  An exact-nominal `R { .child = make(args) }` stages the returned child's scalar
  leaves and drops the temporary before later fields or the parent `SINIT`,
  `SREPLACE`, or `SSUBREPLACE`. See [the contract](docs/engineering/m2-struct-child-calls.md).
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

The native `browniec` compiles and runs the experimental scalar and source-array
pipelines, including records in ordinary helpers and recursive VM frames. The bool/branch increment extends its i32 functions with bool parameters,
results, and locals, `! == != < <= > >= && ||`, short-circuit evaluation,
`if`/`else if`/`else`, standalone lexical blocks, and early returns. `main` remains
zero-argument and returns i32. Parsing, scalar type checks, private bytecode
generation, CFG verification, and VM dispatch are Fairy C. Fuel bounds every
executed instruction. Direct calls and bounded VM recursion continue to work. The
loop increment adds `while`, classic `for`, `break`/`continue`, and metered
backedges with a bounded inductive initialization check. The tagged increment adds
shallow `Option<i32|bool>` and `Result<i32|bool, i32|bool>` values plus exhaustive
`switch` statements. The propagation increment adds postfix `?` for those scalar
wrappers, returning the payload on success and the enclosing wrapper on failure.
The switch-expression increment extends exhaustive `switch` to expression position,
with value yields or direct returns in exhaustive shallow-wrapper arms. The i64
increment adds full-width signed scalars in typed locals, functions, calls,
assignments, loops, and switch joins, with checked arithmetic and no implicit
conversions. The unsigned increment adds `u8`, `u32`, and 64-bit guest `usize` at
the same source positions, with checked arithmetic and unsigned ordering. Explicit
widening adds `EXPR as TYPE` for seven domain-preserving integer pairs, with no
implicit conversion or promotion. The [widening contract](docs/engineering/m1-widening.md)
owns that addition. [Integer operators](docs/engineering/m1-integer-operators.md)
add fixed-width `~`, `&`, `^`, `|`, and checked `<<`/`>>` for every integer type.
The [arm-statement increment](docs/engineering/m1-switch-arm-statements.md) adds
branches, blocks, loops, and lexical transfers inside expression arms. Full-profile
conformance remains unverified. The [source-array read increment](docs/engineering/m2-array-source.md)
adds immutable scalar-array declarations in the outermost `main` body and exact
`usize` indexed reads through the entry-array VM. The [source-array write
increment](docs/engineering/m2-array-write.md) adds mutable outermost declarations
and exact `usize` element assignment; focused verification passed in development and release. The
[source-array copy-initializer increment](docs/engineering/m2-array-copy-source.md)
adds `let|var T[N] dest = source;` for exact matching visible arrays and independent
snapshot semantics through the existing `ACOPY` IR/runtime; focused checks passed
in development and release. The [array-length increment](docs/engineering/m2-array-length.md)
adds `NAME.len` as an exact `usize` constant, including in pure scalar `for` headers.
The [lexical-scope increment](docs/engineering/m2-array-scopes.md) admits arrays in
`main` blocks, branches, loops, and switch arms, with cleanup at scope exits and
loop transfers. [Whole-array assignment](docs/engineering/m2-array-assignment.md)
adds `dest = source;` for exact matching arrays, overwriting existing mutable storage
without allocating another extent. The [private frame foundation](docs/engineering/m2-array-frames.md)
separates function ownership and recursive VM array tokens. The
[helper-local increment](docs/engineering/m2-array-helpers.md) extends source
arrays to scalar and shallow wrapper-returning helpers, including reverse cleanup
on `?` failure returns. [Source array parameters](docs/engineering/m2-array-parameters.md)
add immutable exact-shape arguments with left-to-right snapshots, forward/mutual
calls, and cleanup of pending captures on normal and early exits. Named array results
and typed call-result initializers are supported by the [source result increment](docs/engineering/m2-array-result-source.md).
[Direct return calls](docs/engineering/m2-array-return-calls.md) additionally admit
`return make(arguments);` with the same argument capture and ownership rules.
[Repeated return literals](docs/engineering/m2-array-return-literals.md) also admit
`return [value; N];`, evaluating the fill once in the declared element context.
[Call-result assignment](docs/engineering/m2-array-call-assignment.md) admits
`array = make(arguments);`, copying the result into existing mutable storage.
[Repeated-literal assignment](docs/engineering/m2-array-literal-assignment.md)
admits `array = [value; N];`, evaluating once and filling existing storage in place.
Borrows, slices, workers, and DLLs remain later work.
Source [helper-local records](docs/engineering/m2-struct-function-source.md) are implemented at `98a4525` for ordinary scalar, wrapper-returning, and array-returning helpers. Constructor, copy, and subrecord-extraction paths use `ir::record_in` with the lowering function. Existing record forms run in callee frames under the shared sixteen sites and owners, 128-byte roots, sixteen-leaf staging, and 32 VM frames. Array-returning helpers drop local records in reverse mixed array-record order before `ARET`, preserving the returned array. Version JSON reports `struct_helper_locals: true`; opcodes, Fuel, and profile strings are unchanged.

Development and release each passed 48 native groups and 2,860 CLI cases, including 89 helper-local record cases. The native report was retained after correcting the aggregate expected count from 47 to 48; CLI matrices ran individually, including a fresh nested matrix after updating an obsolete root-replacement expectation. Release completed the `--function-source --profile release` aggregate. The [receipt](docs/evidence/m2-struct-function-source-windows-20261027.json) records 153 input hashes, compiler and artifact identities, and equal native identities across profiles. At `98a4525`, source record parameters/results and borrows were unavailable; [record parameters](docs/engineering/m2-struct-parameters-source.md) and a [bounded record-result subset](docs/engineering/m2-struct-result-source.md) now have successors, while record borrows remain unavailable. Full native suites, other struct/array matrices, Linux, packaging, DLL, isolation, and performance were not run.

The [record-parameter signature foundation](docs/engineering/m2-struct-parameter-signatures.md) recognizes bare nominal parameter types and stores each record ID separately from scalar tags and array lengths. The bounded signature table adds 128 bytes. Its pre-lowering rejection was the source gate at that checkpoint; the [source parameter successor](docs/engineering/m2-struct-parameters-source.md) removes it. The signature receipt therefore remains historical for the gate implementation. Record results now have a separate [bounded source successor](docs/engineering/m2-struct-result-source.md); record borrows remain unavailable. That increment added no opcode, Fuel charge, profile, or version capability.

Development and release each passed 16 native groups and 2,226 CLI cases: 88 signature-gate, 89 helper-record, 80 array-parameter, and 1,969 M1 cases. Development ran individual commands; release completed `--parameter-signatures --profile release`. The [receipt](docs/evidence/m2-struct-parameter-signatures-windows-20261027.json) records compiler/artifact identities, 181 input hashes, and equal native identities across profiles. This is focused signature verification; full native/array suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation, and performance were not run.

The private [record-parameter IR foundation](docs/engineering/m2-struct-parameters-ir.md) adds immutable callee-owned record sites and 128 zero-tag parameter placeholders. CALL arguments distinguish scalar registers, array sites, and record sites; record arguments require exact nominal identity, caller ownership, liveness, and an immutable source or explicit snapshot. Parameter lifetimes occupy bits 16..31, participate in joins/backedges, and must be dropped before scalar or array returns. Its initial VM availability gate is superseded by the metered record-call successor below. Its source-gate claim is also historical and superseded by the current source parameter lowering.

The complete `--parameter-ir` aggregate passed 28 native groups (7 new record-parameter, 9 array-call, 6 record function-IR, 6 source signature) and 2,226 CLI cases per development/release profile without result reuse. The [receipt](docs/evidence/m2-struct-parameters-ir-windows-20261027.json) records 182 input hashes, compiler/artifact identities, commands and outcomes. Matching native identities, all input hashes, and the current compiler/release binary were rechecked before archival. Implementation: `9b43e0d`. Full native suites, other CLI matrices, M0, Linux, packaging, DLL, isolation, allocation instrumentation and performance were not run.

The private [mixed argument-copy foundation](docs/engineering/m2-call-argument-copies.md) stages 0..8 array/record arguments as one transaction. It checks every source against the original owner table, normalizes record padding, validates nested bools, and admits all owner/payload reservations before publishing bytes or tokens. Failed batches preserve all backing bytes and owner metadata. That storage-only increment changed no VM gate, source grammar, Fuel or capabilities. Its statement that source lowering remained unavailable was historical and is superseded by the source parameter slice.

The complete `--call-copies` aggregate passed 70 native groups (9 new, 61 affected) per development/release profile without result reuse. The [receipt](docs/evidence/m2-call-argument-copies-windows-20261027.json) records 62 input hashes and matching native identities. All inputs, compiler and unchanged SDK identities were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, packaging, DLL, isolation, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed owner/storage, root-lock and harness inputs.

The [private record-call VM](docs/engineering/m2-struct-call-vm.md) now executes verified record-parameter IR through one mixed array/record copy transaction. It prepays the complete CALL before frame admission or payload/token changes, binds aggregate tokens, then publishes scalar arguments and the child return frame. Array-only/scalar-only prices are unchanged; record calls add 2,048 batch Fuel plus 43,008 per record and existing array work. The kind 11 VM gate is removed. That slice's source-gate statement is historical; the current source successor emits the verified forms. Opcodes, other charges, profiles and version capabilities are unchanged.

Implementation: `97bf1e2`. Development and release each passed 47 unique native groups in two separate invocations: [core, 21 groups](docs/evidence/m2-struct-call-vm-core-windows-20261027.json) followed by [regressions, 26 groups](docs/evidence/m2-struct-call-vm-regressions-windows-20261027.json). This is stepwise verification, not a single combined aggregate run. Both receipts have the same 58 input hashes, compiler and SDK identities, and disjoint test selections; all were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, isolation, DLL, packaging, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed VM, root-lock, test and harness inputs.

Source [record parameters](docs/engineering/m2-struct-parameters-source.md) are implemented at `d0ca7e7` and verified in development and release. A formal is an immutable nominal record; at that checkpoint each argument was one bare visible record binding, and mutable sources are captured with `SCOPY` before later arguments evaluate. All formal sites are predeclared after the record catalog scan, then bound by owning function and record-formal ordinal within the unchanged 16 static sites. No extra 128-byte signature site map is introduced. The source path reuses the existing record-aware `release_from` cleanup and array-result finisher, including scalar-return drops before `RET` and non-result record drops before `ARET`. Record returns were unavailable at that checkpoint; the [source result successor](docs/engineering/m2-struct-result-source.md) adds the bounded subset.

Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](docs/evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](docs/evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [record-result signature foundation](docs/engineering/m2-struct-result-signatures.md)
stores a bare nominal result as record ID + 1 in a new 16-byte signature array and
keeps the scalar tag and array length at zero. At its original baseline, the
compiler rejected every scanned record result at the function name before IR,
aggregate catalogs, or bodies were lowered. `main` remains a zero-argument scalar
`i32` entry point. That increment added no IR, VM, opcode, Fuel, profile, or version
capability. Development and release each passed 22 native groups and 2,317 CLI cases. The [Windows receipt](docs/evidence/m2-struct-result-signatures-windows-20261028.json) records the original baseline, executed commands, compiler/SDK and CLI identities, input hashes, and outcomes. The native selection comprises 6 new record-result, 6 record-formal, 6 array-result and 4 scalar-function groups. CLI coverage comprises 72 new record-result, 66 record-formal, 114 source record-parameter, 96 array-result and 1,969 M1 cases per profile. All 209 input hashes, the compiler, SDK and final release CLI were checked before archival. Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The blanket gate in that receipt is historical and superseded by the
[bounded source result slice](docs/engineering/m2-struct-result-source.md). At
`bb401a4`, a bare visible exact-nominal `return name;` and an exact-nominal
`let`/`var` call initializer lower through the existing result IR and VM. Result
anchors reuse a matching formal or reserve a dead function-owned site before body
lowering. Development and release each passed 14 native groups and 2,438 CLI
cases. The result-signature checker's loop-label metadata was repaired after the
aggregate, followed by a 70-case per-profile CLI rerun against retained binaries.
Native, build, and other CLI selections were not rerun. The [Windows
receipt](docs/evidence/m2-struct-result-source-windows-20261028.json) records 219
rechecked input hashes and the stepwise repair.

The [direct constructor-return slice](docs/engineering/m2-struct-return-constructors.md)
adds `return Pair { ... };` for an exact-nominal record result. The compiler peeks
past the `return` and lets the shared constructor check consume the matching type
name and `{`. Fields evaluate from left to right into depth-first staging slots;
exact-nominal child bindings, child paths, and nested constructors use their
existing staging. Only after all fields and the terminator are complete does the
compiler allocate one immutable anonymous function-owned site and emit `SINIT`.
The parent owner and binding name are not published while a field expression
can return or transfer out of a loop. The shared reverse mixed finisher then drops other visible arrays
and records and emits `SRET`. Transfer adds no payload extent, though the result
root has its normal constructor extent; a reconstructed parameter keeps its old
formal copy and the new result live together until cleanup. General expressions
and parenthesized constructor returns remain unsupported. The [child call-assignment
successor](docs/engineering/m2-struct-child-call-assignment.md) adds an
exact-nominal child path as a call-result destination. There is no new opcode,
VM charge, profile, or version flag. The [constructor child-call
successor](docs/engineering/m2-struct-child-calls.md) now accepts an
exact-nominal record call as a child field value, verified in development and
release in the [Windows
receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json). General aggregate arguments outside the exact-record-formal call position,
  parenthesized child calls, and call-result
field selection remain unsupported. The [Windows
receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json) records
199 matching rechecked inputs and both retained CLI identities. Earlier receipts
remain historical for their original inputs. Development and release each passed
26 native groups (6 new plus 20 named-result, direct-call, and
signature regressions) and 532 CLI cases (144 new, 152 direct return-call, 166
named source-result, and 70 result-signature).

The [subrecord return-path successor](docs/engineering/m2-struct-return-paths.md)
accepts `return outer.child;` for an exact-nominal record result, including deep
paths. The shared extractor emits consecutive `SREAD` operations into consecutive
registers, allocates one anonymous immutable site, and emits one `SINIT`; the
source stays live through creation. The shared finisher then performs reverse mixed
cleanup and emits `SRET`. There is no temporary owner, staging store/load sequence,
new opcode, Fuel charge, profile, or version field. This slice is implemented at
`d4aa643` and verified in development and release. Each profile passed 25 native
groups and 579 CLI cases across four separate phases; 205 inputs matched. Record
borrows, general or parenthesized expressions, and `call().child` returns remain
unsupported. Earlier receipts remain historical for their original inputs.

A [private struct-layout planner](docs/engineering/m2-struct-layout.md) now plans
acyclic record metadata, and a [scalar-only storage slice](docs/engineering/m2-struct-storage.md)
initializes and accesses selected scalar records in caller-backed arena bytes.
A [private copy/assignment slice](docs/engineering/m2-struct-copy.md) appends
independent scalar records and overwrites existing storage, including self and
partial overlap. A [private nested-storage slice](docs/engineering/m2-struct-nested-storage.md)
initializes selected acyclic records from depth-first scalar leaves and reads or
writes scalar field paths; selected roots are capped at 128 bytes while
unselected valid records may be larger. A [private nested copy/assignment
slice](docs/engineering/m2-struct-nested-copy.md) appends nested records by value
and overwrites existing extents without changing the cursor, including self and
partial overlap. A shared [struct-owner foundation](docs/engineering/m2-struct-owners.md)
now puts record descriptors in the existing 16-slot table, verifies catalog layout
on access, and rejects record tokens in array APIs. A [private struct-owner
copy/assignment slice](docs/engineering/m2-struct-owner-copy.md) appends independent
record owners and requires exact record identity for assignment. Its 17-group
Windows selection passed development and release; the previous 34-group owner receipt is historical for changed
inputs. A [private entry-owned struct IR and verifier](docs/engineering/m2-struct-ir.md)
adds opcodes 41..46 for initialization, copy, scalar leaf access, drop, and exact-ID
assignment; record lifetimes use bits 16..31 beside array lifetimes. The original
[private struct VM](docs/engineering/m2-struct-vm.md) contract executed those
private instructions with fixed prepaid Fuel charges, sixteen entry tokens, and
the shared array owner table and payload arena. Development and release each
passed all 38 selected native groups and the existing 115-case CLI suite for that
slice. A
[function-owned record IR foundation](docs/engineering/m2-struct-function-ir.md)
assigns each static record site to one function and verifies all opcodes 41..49
against that owner, including same-function copy/assign/subassign sources. A
[frame-local record VM](docs/engineering/m2-struct-function-vm.md) now executes
verified helper IR in up to 32 guest frames. Each frame owns sixteen record token
slots over the same 16 shared owners and payload arena, using the same indexing as
arrays. Opcodes, Fuel, frontend lowering, and version are unchanged. The 13-group
smoke suite passed in one native invocation. The complete `--function-vm` invocation passed 46 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](docs/evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
compiler/artifact identities, commands and outcomes. Implementation commit:
`80ed712`. Other CLI matrices, full native suites, Linux, packaging,
isolation and performance were not rerun. Frame entry
allocates no separate table or arena, while `SINIT`/`SCOPY` reserve shared owners
and payload and require dead destination tokens. Writes and assignments require
live mutable destinations. Drops clear frame tokens; dead middle extents stay
charged until suffix reclamation. Source helper records were unsupported at
`80ed712`; the [source helper successor](docs/engineering/m2-struct-function-source.md)
enables those declarations. At `80ed712`, record parameters/results and borrows
were unsupported; the [record-parameter successor](docs/engineering/m2-struct-parameters-source.md)
and [record-result successor](docs/engineering/m2-struct-result-source.md) now
implement their bounded source subsets, while record borrows remain unsupported.
The 512-slot token array carries no measured
allocation, stack, or speed claim. The earlier
`--function-ir` 31-group and 2,383-CLI result remains historical for its original
scope at `3380b10`; its
[receipt](docs/evidence/m2-struct-function-ir-windows-20261027.json) records those
inputs and outcomes. Its test file changed one of six function-IR groups to expect
helper execution; the other five are unchanged. A
[declaration-only source struct slice](docs/engineering/m2-struct-source.md)
parses forward-referencing scalar and nested named fields into immutable layouts.
Both profiles passed 23 native groups and 2,208 CLI cases each for that
declaration-only slice, recorded in the
[stepwise receipt](docs/evidence/m2-struct-source-windows-20261026.json).
The [bounded source struct-value slice](docs/engineering/m2-struct-values.md)
is the historical read baseline: entry-only scalar-field construction with exact
declaration order and one-level scalar field reads. Typed field expressions are
staged left to right, then consecutive loads feed `SINIT`; the compiler declares
the binding after emitting that initializer, and a runtime failure aborts.
Read-only record programs select
`brownie.m2-struct-read/1`, while declaration-only programs keep their existing
profile. For that baseline, development and release each passed 28 native groups
and 2,352 CLI cases, plus three supplemental cases, recorded in the
[historical receipt](docs/evidence/m2-struct-values-windows-20261026.json). That
baseline left nested construction, field chains, struct parameters/results, and
borrows unsupported; successors implement all three named capabilities, while
record borrows remain unavailable. A
[source struct-field write slice](docs/engineering/m2-struct-write.md) adds
entry-only `NAME.FIELD = EXPR;` for one mutable scalar leaf. It resolves the
binding and field before a single exact-typed RHS, emits `SWRITE` after the
expression and terminator, and mutates the existing record extent without a new
copy, owner, or payload extent. For-header writes remain rejected; condition
reads and body writes are accepted. Programs with nonempty record bindings and
opcode 44 select `brownie.m2-struct-write/1`; version JSON adds
`struct_write_profile`.
The full `--write` selection passed 24 native groups and 2,472 CLI cases per
development/release profile; the
[historical receipt](docs/evidence/m2-struct-write-windows-20261026.json) records
both artifacts and the executed checks. The later source-copy compiler change
makes both the read and write receipts historical for the current inputs. A
[source struct-copy slice](docs/engineering/m2-struct-source-copy.md) adds
entry-only `let|var P q=p;` initialization and `p=q;` assignment for exact nominal
scalar-record types. `SCOPY` creates an independent owner and extent; `SASSIGN`
reuses a mutable destination's existing extent, including for self-assignment.
Programs with nonempty record bindings and opcode 42 or 46 select
`brownie.m2-struct-copy/1` ahead of the write and read profiles, and version JSON
adds `struct_copy_profile`. Development and release each passed 39 native groups
and 2,582 CLI cases, including 110 new copy cases. The
[stepwise receipt](docs/evidence/m2-struct-source-copy-windows-20261026.json)
records development native/build reuse after CLI fixture corrections. The complete
aggregate harness was not rerun.
The [source nested-struct slice](docs/engineering/m2-struct-source-nested.md)
adds inline named child constructors, multi-segment scalar read/write paths, and
whole-root copies for entry-owned nested records. The constructor cursor walks the
record tree iteratively in source order. Each scalar leaf's tag comes directly
from the cursor, and its staging slot is allocated immediately before that
expression is parsed; no tag array is returned. Leaves stage left to right before
consecutive loads and one `SINIT` for the root. Child constructors add no owner, site, or
extent, so a root still occupies one site and one extent. Paths resolve to
depth-first scalar-leaf ordinals, including leaves in preceding nested siblings.
Source staging is limited to 16 scalar leaves total, record nesting and path
length to 16, and a selected root to 128 planned bytes; the existing 16 sites, shared 16 owners,
65,536-byte arena, and scalar limits remain. A bound record with a nested field
selects `brownie.m2-struct-nested/1` ahead of the copy, write, and read profiles;
unused nested declarations do not promote another program. Development and release
each passed 36 native groups and 2,710 CLI cases, including 128 nested cases,
through the complete `--nested` harness on the corrected source. The
[receipt](docs/evidence/m2-struct-source-nested-windows-20261027.json) records
inputs, artifacts, commands and the corrected release regression; it is historical
for the current child-binding compiler inputs. Implementation commits: `576d062`
and `716c14b`.
The [child binding initializer slice](docs/engineering/m2-struct-child.md) admits
`R { .i = i }` when the child field's nominal type exactly matches a visible
whole record binding. The compiler emits one `SREAD` and `STORE` per source scalar
leaf into the parent's staging at that field, before a later sibling expression
can mutate the source. The resulting snapshot is independent; the source stays
live and its normal cleanup is unchanged. Child capture adds no `SCOPY`, temporary
owner, site, or extent, while the new parent root still consumes one owner and
extent. The existing leaf, depth, root, site, owner, arena, register, and
instruction limits remain. Programs stay on `brownie.m2-struct-nested/1`, and
version JSON adds `struct_child_binding_initializers: true`. The complete
`--child` harness passed 21 native groups and 2,798 CLI cases, including 88 child
cases, in each development/release profile. The
[receipt](docs/evidence/m2-struct-child-windows-20261027.json) records 90 input
hashes, compiler and CLI artifact hashes, commands, and outcomes. Implementation commit:
`ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.
[Subrecord declaration initializers](docs/engineering/m2-struct-extract.md) now
also accept `let I i = p.i` with an exact nominal record endpoint. The new value
owns an independent copy; changing either value does not affect the other.
The compiler uses consecutive `SREAD` results and one `SINIT`, with no temporary
owner or staging instructions. Subrecord assignment is handled by its
[successor](docs/engineering/m2-struct-subassign.md). Version JSON adds `struct_subrecord_initializers: true` under the
existing nested profile. Development and release each passed 26 native groups
and 2,915 CLI cases stepwise. Development reuses its unchanged native result after
two CLI-only diagnostic fixes; final CLI matrices and release native groups ran
afterward. The [receipt](docs/evidence/m2-struct-extract-windows-20261027.json)
records 92 input hashes, compiler/artifact hashes, commands, and reuse provenance.
Implementation commit: `f65a1d7`. Earlier child-binding and
nested receipts are historical for changed compiler and fixture inputs.
The [historical per-leaf assignment slice](docs/engineering/m2-struct-subassign.md)
admitted
`p.i = q.i`, `p.i = i`, and `i = p.i` for exact nominal types and mutable
existing destinations. Source leaves are captured before writes; self/sibling
copies preserve value semantics. Assignment uses the existing target storage
without a temporary owner and retains the nested profile. Fatal errors abort the
invocation without transactional rollback. Version JSON adds
`struct_subrecord_assignment`. The complete `--subassign` invocation passed 15
native groups and 3,044 CLI cases in each development/release profile. The
[receipt](docs/evidence/m2-struct-subassign-windows-20261027.json) records 91
harness input hashes plus four CLI fixture hashes, compiler/artifact hashes,
commands, and outcomes. Implementation commit: `666da70`. The extraction receipt
is historical for changed compiler and fixture inputs.
[Atomic subrecord assignment](docs/engineering/m2-struct-subassign-atomic.md)
replaces per-field lowering with one checked `SSUBASSIGN` instruction. It stages
at most 128 canonical bytes before changing the destination, retains existing
owners/storage, and uses no new scalar registers. The assignment charge is
131,072 Fuel, so 16 scalar leaves now fit the CLI allowance. Failure leaves the
selected destination unchanged; earlier statements and external effects are not
rolled back. Version JSON adds `struct_subrecord_assignment_atomic` under the
existing nested profile. The complete `--atomic` invocation passed 26 native
groups and 3,046 CLI cases per development/release profile. The
[receipt](docs/evidence/m2-struct-subassign-atomic-windows-20261027.json) records
99 input hashes, compiler/artifact identities, commands, and outcomes. Integration
commit: `5589803`; foundation: `2b5917c`. The per-leaf receipt is historical for
changed verifier/VM/compiler inputs.
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

The declaration-only contract and its receipt remain historical evidence for
declarations without record bindings.
The earlier nested-storage 18-group receipt is historical for changed
inputs; nested-copy 24-group checks passed development and release. The copy
receipt passes 28 groups per profile in development and release. The planner's
earlier 14-group and storage's 20-group receipts remain historical for changed
inputs.
The [array parameter signature foundation](docs/engineering/m2-array-signatures.md)
records element types and exact lengths; the subsequent source increment removes
its original compilation gate.
The [atomic argument-copy foundation](docs/engineering/m2-array-arguments.md)
preflights a complete batch of independent storage copies before mutation.
[Private array calls](docs/engineering/m2-array-calls.md) connect those copies to
the verifier and VM, with immutable exact-shape parameters and independent frame
owners. The source parameter increment supplies argument capture and cleanup.
The [array result signature foundation](docs/engineering/m2-array-result-signatures.md)
records exact return shapes; its original source gate is removed by the source result increment.
The [private array-result increment](docs/engineering/m2-array-results.md)
adds independent verification and owner transfer between VM frames. Returning
the callee's sole live array copies no payload and needs no additional owner;
source return lowering now connects typed call initializers and bare-name returns to it.

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe run examples/branches.brc --json
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
./build/browniec.exe run examples/tagged.brc --json
./build/browniec.exe run examples/propagation.brc --json
./build/browniec.exe run examples/switch-expression.brc --json
./build/browniec.exe run examples/i64.brc --json
./build/browniec.exe run examples/unsigned.brc --json
./build/browniec.exe run examples/widening.brc --json
./build/browniec.exe run examples/bitwise.brc --json
./build/browniec.exe run examples/switch-arm-statements.brc --json
# array source requires explicit fuel for arena preparation
./build/browniec.exe run examples/array-read.brc --fuel 100000 --json
# return_i32 is 42; process exit is 0
./build/browniec.exe run examples/array-write.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice write
python -B tools/record-m2-array-write-evidence.py
# The recorder can later add all 1,969 scalar CLI cases with --scalar-regression.
./build/browniec.exe run examples/array-copy.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice copy
python -B tools/record-m2-array-write-evidence.py --slice copy --scalar-regression
# After a completed matching receipt, docs-only updates can reuse it:
python -B tools/record-m2-array-write-evidence.py --slice copy --reuse-scalar-regression
./build/browniec.exe run examples/array-length.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice length
python -B tools/record-m2-array-write-evidence.py --slice length --scalar-regression
./build/browniec.exe run examples/array-scopes.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice scopes
python -B tools/record-m2-array-write-evidence.py --slice scopes --scalar-regression
./build/browniec.exe run examples/array-assignment.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice assignment
python -B tools/record-m2-array-write-evidence.py --slice assignment --scalar-regression
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice frames
python -B tools/record-m2-array-write-evidence.py --slice frames --scalar-regression
./build/browniec.exe run examples/array-helpers.brc --fuel 100000 --json
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice helpers
python -B tools/record-m2-array-write-evidence.py --slice helpers --scalar-regression
```

See [Development](DEVELOPMENT.md) to provision the pinned compiler and for build
prerequisites. The [toolchain setup contract](docs/engineering/toolchain-setup.md)
records host outputs, validation, and verification evidence. This CLI is for trusted
local source only; Windows isolation is not implemented.

## Product intent

The first expected workloads are application data validation, byte transforms, and
rule evaluation. They are starting assumptions, not evidence that Brownie C should
replace a general-purpose language such as Python.

The planned brownie.safe/0.3 profile provides:

- bool, u8, i32, i64, u32, and 64-bit usize
- scalar arrays with 1 to 4096 elements
- limited acyclic plain structs
- ref and ref mut, static ref str, and explicit text byte views
- Option and Result, including transferable Buffer values
- checked arithmetic, fallible owned Buffer operations, and explicit output staging

The profile excludes user resources, generics, enums, raw pointers, FFI, JIT,
dynamic strings, Map, closures, and guest garbage collection for this first slice.
Those limits describe the profile, not the language forever.

## Delivery boundary

| Level | Intended capability | Current state |
| --- | --- | --- |
| core | Source compile, verify, and native VM CLI | Experimental i32/i64/u8/u32/usize/bool expressions, explicit widening, branches, loops, shallow tagged values, switch statements and expressions, `?` propagation, source arrays, declaration-only source struct layouts, function-owned struct IR execution, helper-local record construction/read/write lowering, bare-name record copy initialization/whole-record assignment, bounded nested constructors/scalar paths/whole-root copies, whole-record child binding initializers, subrecord declaration initializers, atomic subrecord assignment, immutable by-value record parameters with bare binding, constructor, subrecord path, or exact-result call arguments, bounded bare-name, direct-call, and direct-constructor record results with exact-nominal `let`/`var` call initializers, and exact-nominal record calls in constructor child fields (verified in development and release); private record-result IR/verifier metadata is verified for its original inputs (39 native groups and 2,317 CLI cases per profile), and source record parameters passed 51 native groups and 2,318 CLI cases per development/release profile in two separate phase runs. Bounded source record results passed 14 native groups and 2,438 CLI cases per development/release profile at `bb401a4`, followed by a focused 70-case-per-profile checker metadata repair. Direct constructor returns are verified in development and release at `0a7b539`. Exact-nominal subrecord return paths are implemented at `d4aa643` and verified in development and release; each profile passed 25 native groups and 579 CLI cases. Nested results are historical after the child compiler change, the child feature passed the complete combined harness in development and release; scalar M1 and array reads verified, focused array and struct VM checks recorded, the struct construction/read and field-write baselines recorded historically, and source-copy checks verified stepwise in development and release |
| restricted | Windows worker plus parent broker | Not implemented; M4 |
| embed | Trusted native host through a DLL ABI | Not implemented; M5; no public C export |

The native VM is source-only. Bytecode is private compiler output; there is no
external bytecode input or disk runtime code cache. Program values are immutable
and reusable, Instance values are one-shot, and an Engine is owner-thread bound.

Untrusted source requires an independently OS-tested restricted worker. The embed
path is for trusted native hosts only. Passing a VM check does not prove the truth
of a policy result, the safety of an external effect, or the absence of native bugs.

## Documentation map

- [Architecture](ARCHITECTURE.md): system shape and trust boundaries
- [Development](DEVELOPMENT.md): current build reality and future workflow
- [Validation](VALIDATION.md): evidence rules and unimplemented checks
- [M0 probes](probes/m0/README.md): native signatures, build and verification
- [Direct functions](docs/engineering/m1-functions.md): calls, VM frames, and bounds
- [M1 scalar slice](docs/engineering/m1-scalar-slice.md): current grammar, limits, and CLI
- [M1 bool and branches](docs/engineering/m1-branches.md): typing, scopes, CFG, slots, and branch Fuel
- [M1 loops](docs/engineering/m1-loops.md): while/for, transfer, backedges, and loop limits
- [M1 shallow tagged values](docs/engineering/m1-tagged.md): Option/Result, switch, packing, and CASE verification
- [M1 `?` propagation](docs/engineering/m1-propagation.md): payload extraction, wrapper failure, precedence, and Fuel
- [M1 switch expressions](docs/engineering/m1-switch-expressions.md): expression-position arms, typed joins, and verifier boundaries
- [M1 i64 scalars](docs/engineering/m1-i64.md): literal context, checked arithmetic, limits, and evidence
- [M1 unsigned scalars](docs/engineering/m1-unsigned.md): `u8`, `u32`, `usize`, representation, and limits
- [M1 explicit widening](docs/engineering/m1-widening.md): seven integer pairs, precedence, lowering, and Fuel
- [M1 integer operators](docs/engineering/m1-integer-operators.md): fixed-width bitwise operations, checked shifts, and precedence
- [M1 arm statements](docs/engineering/m1-switch-arm-statements.md): branches, loops, transfers, typed joins, and inherited depth budgets
- [M1 checkpoint audit](docs/engineering/m1-checkpoint-audit.md): scalar exit requirements and remaining profile limits
- [M2 array layout](docs/engineering/m2-array-layout.md): historical layout foundation for compact scalar payloads, arena preflight, and checked offsets
- [M2 array storage](docs/engineering/m2-array-storage.md): scalar codecs, repeated initialization, and element access in caller-owned backing bytes
- [M2 array owners](docs/engineering/m2-array-owners.md): typed descriptors, generation checks, independent copies, explicit release and bounded reclamation
- [M2 array IR](docs/engineering/m2-array-ir.md): historical private entry-array instructions and independent lifetime/CFG verification
- [M2 array VM](docs/engineering/m2-array-vm.md): historical native array dispatch, owned payload storage, Fuel, and runtime failures
- [M2 source array reads](docs/engineering/m2-array-source.md): current grammar, lifetimes, caps, profiles, and verification for `let T[N] name = [EXPR; N];` and `name[EXPR]`
- [M2 source array writes](docs/engineering/m2-array-write.md): mutable declarations, element assignment, evaluation order, profiles, and verification for `var T[N] name = [EXPR; N];` and `name[EXPR] = VALUE;`
- [M2 source array copy initialization](docs/engineering/m2-array-copy-source.md): matching visible arrays, independent storage, resources, profiles, and verification for `let|var T[N] dest = source;`
- [M2 source array length](docs/engineering/m2-array-length.md): exact `usize` length constants, pure scalar composition, resources, and focused verification for `NAME.len`
- [M2 lexical array scopes](docs/engineering/m2-array-scopes.md): nested declarations, reverse cleanup, loop transfers, and bounded storage reuse
- [M2 whole-array assignment](docs/engineering/m2-array-assignment.md): exact-shape copies into existing mutable storage, preflight, private IR, and Fuel
- [M2 private array function frames](docs/engineering/m2-array-frames.md): function ownership, recursive frame tokens, shared quotas, and parameter work sequencing
- [M2 helper-local arrays](docs/engineering/m2-array-helpers.md): function-local source declarations, recursion, and cleanup on wrapper propagation
- [M2 array parameter signatures](docs/engineering/m2-array-signatures.md): bounded shape metadata and the historical gate replaced by source parameter lowering
- [M2 atomic array argument copies](docs/engineering/m2-array-arguments.md): exact-shape copy batches with no partial publication on failure
- [M2 private array calls](docs/engineering/m2-array-calls.md): mixed parameter metadata, immutable caller snapshots, independent frame copies and metered CALLs
- [M2 source array parameters](docs/engineering/m2-array-parameters.md): immutable exact-shape source parameters, left-to-right captures, forward/mutual calls and cleanup on early exits
- [M2 array result signatures](docs/engineering/m2-array-result-signatures.md): exact return-shape metadata and the historical source gate
- [M2 source array results](docs/engineering/m2-array-result-source.md): named returns, typed call initializers, capture cleanup and ownership transfer
- [M2 direct array-return calls](docs/engineering/m2-array-return-calls.md): exact-shape forwarding, nested early exits and shared return cleanup
- [M2 repeated array-return literals](docs/engineering/m2-array-return-literals.md): typed single-evaluation fills, exact lengths and shared ownership transfer
- [M2 array call-result assignment](docs/engineering/m2-array-call-assignment.md): ordered calls, temporary cleanup and copies into existing var storage
- [M2 repeated-literal assignment](docs/engineering/m2-array-literal-assignment.md): preflighted in-place fills without additional owners or array storage
- [M2 private array results](docs/engineering/m2-array-results.md): verified result lifetimes, zero-copy owner transfer, recursive frames and prepaid return work
- [M2 private struct layout](docs/engineering/m2-struct-layout.md): verified planner-only record catalog, declaration-order offsets, dependency bounds, and Windows receipt
- [M2 private struct storage](docs/engineering/m2-struct-storage.md): scalar-only record preparation, complete initialization, and indexed field access in shared caller-backed arena bytes
- [M2 private struct copy and assignment](docs/engineering/m2-struct-copy.md): scalar-record snapshots, padding normalization, old-plus-new quota, and overlap-safe assignment
- [M2 private nested struct storage](docs/engineering/m2-struct-nested-storage.md): iterative depth-first initialization, scalar field paths, selected-root quota, and shared arena staging
- [M2 private nested struct copy and assignment](docs/engineering/m2-struct-nested-copy.md): iterative snapshots, padding normalization, old-plus-new quota, and overlap-safe nested assignment
- [M2 shared struct owners](docs/engineering/m2-struct-owners.md): shared record/array descriptors, catalog-bound field access, generation-safe release, and mixed-arena reuse
- [M2 private struct-owner copy and assignment](docs/engineering/m2-struct-owner-copy.md): independent record owners, exact-ID assignment, shared descriptor pressure, and source-release survival
- [M2 private struct IR](docs/engineering/m2-struct-ir.md): entry-owned bindings, opcodes 41..46, flattened scalar leaves, combined lifetimes, and independent verification
- [M2 private function-owned record IR](docs/engineering/m2-struct-function-ir.md): static function ownership for record sites, opcodes 41..49, and development/release verification
- [M2 private frame-local record VM](docs/engineering/m2-struct-function-vm.md): 32 guest-frame token slots over shared owners and payload, unchanged opcodes and Fuel, development/release verification
- [M2 source helper-local records](docs/engineering/m2-struct-function-source.md): function-owned source declarations, recursive frame isolation, mixed cleanup, and `struct_helper_locals` capability
- [M2 record parameter signatures](docs/engineering/m2-struct-parameter-signatures.md): nominal signature metadata and the historical source gate before executable argument lowering
- [M2 private record parameter IR](docs/engineering/m2-struct-parameters-ir.md): zero-tag formal placeholders, exact nominal mixed-call verification, lifetime invariants, and the historical VM availability gate
- [M2 private record-call VM](docs/engineering/m2-struct-call-vm.md): prepaid mixed argument copying and frame publication; its source-gate claim is historical
- [M2 source record parameters](docs/engineering/m2-struct-parameters-source.md): immutable by-value formals, bare binding arguments, predeclared sites, mutable-source captures, reused record cleanup, limits, and verified two-phase Windows evidence
- [M2 record result signatures](docs/engineering/m2-struct-result-signatures.md): nominal ID metadata, zero scalar/array fields, the historical pre-IR compilation gate, bounds, and focused Windows evidence
- [M2 record-result IR/verifier](docs/engineering/m2-struct-results-ir.md): callee-owned shape anchors, `SRET`, record CALL destinations, exact lifetimes, the historical VM availability gate, and focused Windows evidence
- [M2 private record-result VM](docs/engineering/m2-struct-result-vm.md): prepaid `SRET` transfer into caller-owned destinations, complete snapshot validation, zero extra owners or payload, unchanged limits, and focused Windows evidence
- [M2 source record results](docs/engineering/m2-struct-result-source.md): bare exact-nominal returns, typed call initializers, result anchor reuse, pending-destination cleanup, mixed reverse drops, unchanged limits, and verified stepwise development/release evidence
- [M2 direct record constructor returns](docs/engineering/m2-struct-return-constructors.md): exact-nominal constructor operands, declaration-order staging, deferred site allocation, `SINIT`/`SRET`, constructor-only payload extent, rejected forms, and focused development/release evidence
- [M2 exact-nominal subrecord return paths](docs/engineering/m2-struct-return-paths.md): consecutive leaf reads, one independent result site, reverse mixed cleanup, unchanged limits, and verified development/release evidence
- [M2 child record call-result assignment](docs/engineering/m2-struct-child-call-assignment.md): shared root/child argument evaluation, `SSUBASSIGN` and `SDROP`, live destination ownership, deep paths, limits, and verified development/release evidence
- [M2 record calls in constructor child fields](docs/engineering/m2-struct-child-calls.md): exact-nominal child result sites, scalar-leaf staging, `SDROP` before later fields and parent publication, unchanged limits and Fuel, verified development/release evidence
- [M2 record call results as arguments](docs/engineering/m2-struct-result-arguments.md): nested exact-nominal result captures, left-to-right evaluation, shared cleanup, and focused Windows evidence.
- [M2 subrecord paths as arguments](docs/engineering/m2-struct-path-arguments.md): exact-nominal snapshots, left-to-right evaluation, shared cleanup, and focused Windows evidence.
- [M2 record constructors as arguments](docs/engineering/m2-struct-constructor-arguments.md): deferred owner publication, ordered field staging, mixed cleanup, and focused Windows evidence.
- [M2 array call results as arguments](docs/engineering/m2-array-result-arguments.md): exact-shape captures, mixed cleanup, nested calls, quota boundaries, and focused Windows evidence.
- [M2 private struct VM](docs/engineering/m2-struct-vm.md): shared owners and payload, private execution semantics, fixed Fuel charges, and current check status
- [M2 declaration-only source structs](docs/engineering/m2-struct-source.md): historical bounded parser, forward named fields, immutable layouts, name rules, and stepwise verification
- [M2 bounded source struct values](docs/engineering/m2-struct-values.md): historical entry construction and one-level reads, ordered typed staging, `SINIT`/scalar-leaf access, mixed cleanup, bounds, and recorded verification
- [M2 source struct field writes](docs/engineering/m2-struct-write.md): entry-only one-level `SWRITE`, target-before-RHS resolution, single typed evaluation, for-header rejection, profiles, and recorded verification
- [M2 source struct copy initialization and assignment](docs/engineering/m2-struct-source-copy.md): exact-name `SCOPY`/`SASSIGN` lowering, independent copies, mutable destination reuse, lifetimes, profiles, and stepwise development/release verification
- [M2 source nested structs](docs/engineering/m2-struct-source-nested.md): inline child constructors, depth-first scalar paths, whole-root copies, iterative traversal, limits, profiles, and historical development/release verification
- [M2 child binding initializers](docs/engineering/m2-struct-child.md): whole visible record bindings as child values, ordered leaf capture, independent snapshots, unchanged ownership and Fuel, profiles, and verification status
- [M2 constructor child paths](docs/engineering/m2-struct-child-path.md): exact nominal subrecord snapshots without intermediate owners
- [M2 metered root replacement](docs/engineering/m2-struct-replace-vm.md): independent verification, prepaid atomic replacement and existing ownership
- [M2 scalar-value record replacement](docs/engineering/m2-struct-replace-values.md): private staged overwrite without another owner or extent
- [M2 entry-only root constructor assignment](docs/engineering/m2-struct-replace-source.md): source-order staging, consecutive loads, one `SREPLACE`, existing ownership, and verified results retained for its original commit
- [M2 entry-only child constructor assignment](docs/engineering/m2-struct-subreplace-source.md): exact nominal child staging, one `SSUBREPLACE`, existing ownership, and development/release verification
- [Product specification](docs/product/02-spec.md): observable first-profile behavior
- [Roadmap](docs/product/01-roadmap.md): M0 through M5 delivery gates
- [Design baseline](docs/design-baseline.md): source provenance, evidence, and findings

The private [record-result IR/verifier](docs/engineering/m2-struct-results-ir.md)
passed 39 unique native groups and 2,317 CLI cases per development/release profile
for its original inputs.
The [core receipt](docs/evidence/m2-struct-results-ir-core-windows-20261028.json)
records 21 native groups and all CLI cases; the separate
[regression receipt](docs/evidence/m2-struct-results-ir-regressions-windows-20261028.json)
records 18 native-only groups. That slice's kind 11 runtime gate is historical.
The [record-result VM successor](docs/engineering/m2-struct-result-vm.md) implements
verified token transfer for its source-gated inputs. The
[source result successor](docs/engineering/m2-struct-result-source.md) now lowers a
bounded subset; development and release each passed 14 native groups and 2,438
CLI cases, followed by a focused checker metadata repair and 70-case-per-profile
CLI rerun.

The expanded M0 run exercises arithmetic, codecs, storage, allocator, owner, and
frame primitives on Windows x64. Exact commands and results belong to
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`. Running with an
empty runtime `PATH` does not establish clean-machine packaging or a sandbox.

The function/local, branch, loop, tagged, propagation, switch-expression, and i64
receipts are historical for their narrower slices. The switch-expression receipt
records 41 native groups and 580 CLI cases; the i64 receipt records 49 native groups
and 760 CLI cases in each development and release profile. The
[unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json) remains
historical at 59 native groups and 1,159 CLI cases in both development and release,
including 399 unsigned cases. The
[widening receipt](docs/evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each profile, including 113 widening cases.
That receipt is historical after the integer-operator increment. The
[integer-operator receipt](docs/evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each profile, including 626 new cases.
That receipt is historical after arm statements. The
[arm-statement receipt](docs/evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each profile, including 71 new cases.
The M2 IR and VM receipts are historical after the source compiler changes. The
[source-array receipt](docs/evidence/m2-array-source-windows-20261024.json) records
18 native groups and 67 CLI cases per profile. The subsequent full scalar regression
also passed 81 native groups and 1,969 CLI cases per profile in development and
release. That read receipt remains previous proof and is historical after the write
compiler changes. The [write receipt](docs/evidence/m2-array-write-windows-20261024.json)
records nine native groups, 67 read CLI cases, and 61 write CLI cases per profile
in development and release. The scalar CLI regression also passed all 1,969 cases per profile on those same binaries.
The read and write receipts remain historical after the copy compiler change. Copy
[evidence](docs/evidence/m2-array-copy-source-windows-20261025.json) records
12 native groups, 67 read CLI cases, 61 write CLI cases, and 58 copy CLI cases in
each development and release profile. Scalar CLI regression also passed all
1,969 cases per profile on the same binaries. The recorder can reuse matching
completed scalar CLI receipts after documentation-only changes instead of rerunning
the 1,969 tests. That integration also skips the 81-group scalar native rerun
because the VM and verifier are unchanged. The prior
[source-parameter receipt](docs/evidence/m2-array-parameters-windows-20261025.json)
records 28 focused native groups and 2,475 CLI cases per development/release
profile (426 existing array, 80 parameter, 1,969 scalar). Completed outputs were
combined stepwise; the aggregate harness was not rerun after the fixture correction.
Thirty unchanged backend source hashes match the private call receipt; this is
a comparison, not a rerun of their full native suites. The prior
[result-signature receipt](docs/evidence/m2-array-result-signatures-windows-20261025.json)
records 16 native groups and 2,242 CLI cases per profile (96 result-signature,
80 parameter, 97 helper-local, 1,969 scalar) on both Windows builds. This covers
metadata and honest rejection at that historical checkpoint.
Thirty-one unchanged backend hashes match the parameter receipt, which remains
historical for the changed frontend and fixture inputs. The current
[private result receipt](docs/evidence/m2-array-results-windows-20261025.json)
records 43 native groups and 2,571 CLI cases per development/release profile.
It covers zero-copy owner transfer, recursive frame limits, caller argument
independence, deferred-hole cleanup, and exact Fuel. The subsequent
[source result receipt](docs/evidence/m2-array-result-source-windows-20261025.json)
records 26 native groups and 2,690 CLI cases per profile, including 119 new
source-result cases. Development combines 18 unchanged groups from the first
selection with eight passing source-result groups after a corrected mutual-call
fixture; release selects all 26 together. Earlier receipts remain historical
for changed inputs. The focused [direct-return receipt](docs/evidence/m2-array-return-calls-windows-20261025.json)
records 12 native groups and 509 CLI cases per profile, including 117 new direct-return
cases. Other array/scalar CLI matrices and full native suites were not rerun for
that increment. The subsequent [literal-return receipt](docs/evidence/m2-array-return-literals-windows-20261025.json)
records 16 native groups and 628 CLI cases per profile, including 119 new literal
cases. It is focused evidence; the unchanged backend and omitted matrices are not
rerun. The subsequent [call-assignment receipt](docs/evidence/m2-array-call-assignment-windows-20261025.json)
records 15 native groups and 609 CLI cases per profile, including 115 new cases.
Its focused selection covers existing assignment and source-result behavior;
other array/scalar CLI matrices and full native suites were not rerun.
The [in-place fill receipt](docs/evidence/m2-array-literal-assignment-windows-20261025.json)
records 36 unique native groups and 2,693 CLI cases per profile, including 115
new fill cases. The CLI total is 724 array cases plus 1,969 scalar cases. The
final 36 combine 17 reused backend identities with 19 fresh frontend groups in
each profile; development reuses backend from `b5e0c98`, release reuses the same
identities from its earlier 36-group selection, and the aggregate harness was not
rerun. Reuse validation matched 28 unchanged source and test files to their
`b5e0c98` Git blobs and confirmed matching SDK and compiler identities.

The final lowering separates array statement, copy, and index handling into
helpers. Scalar and composed fills return 42 at depth 10; depth 11 is the
`compile_limit` boundary. Two permanent CLI cases cover the composed boundary.
The pre-fix binary reproduces `0xC00000FD` at depth 10. These checks make no
stack-byte or performance claim. No full-profile conformance,
DLL ABI, Windows isolation,
clean-machine packaging, or performance target is claimed.

The [private struct IR receipt](docs/evidence/m2-struct-ir-windows-20261026.json)
passes 46 groups per development/release profile, including 9 new struct groups
and 37 control-flow/array regressions. The focused
repeated-literal assignment CLI suite passed 115 cases in each development and
release profile, including the prior composed depth-10/11 boundary. Full CLI
matrices were not rerun.

The [struct VM native receipt](docs/evidence/m2-struct-vm-windows-20261026.json)
passes 38 groups in each development and release profile. The
[focused CLI receipt](docs/evidence/m2-struct-vm-cli-windows-20261026.json) passes
115 cases per profile. The earlier 46-group IR and 115-case CLI receipts remain
historical for changed runtime, test, harness, and root-lock inputs.
