# Roadmap

- Private Buffer writes within initialized length: implemented and verified in
  development and release, each with 47 native scenarios (4 new, 43 regressions);
  all 94 processes exit with zero tracked live allocations. Complete preflight
  includes ledger and current-quota checks even for empty input; this guarded
  path rejects pending growth with State. No allocation, resize, token/generation
  or accounting change. The Windows receipt is archived.
  See [the write contract](../engineering/m2-buffer-write.md).
- Private Buffer bulk copy-out: implemented and verified in development and
  release, each with 43 native scenarios (4 new, 39 regressions); all 86 processes
  exit with zero tracked live allocations. Copies initialized binary bytes into
  distinct caller-owned native output after token, full-table, exact backing
  metadata and overflow-safe range checks. No allocation, token/generation,
  metadata or ledger change. The Windows receipt is archived.
  See [the copy-out contract](../engineering/m2-buffer-copy-out.md).
- Empty Buffer registration: implemented and verified in development and release,
  each with 39 native scenarios (4 new, 35 regressions); all 78 processes exit
  with zero tracked live allocations. Each registration
  admits a 64-byte logical owner without payload allocation. Multiple empty roots
  and registration after final close share caller-managed accounting.
  See [the create contract](../engineering/m2-buffer-create.md).
- Buffer grow-and-resize preparation: implemented and verified in development and
  release, each with 35 native scenarios (7 new, 28 regressions); all 70 processes
  exit with zero tracked live allocations. Growth-only
  preparation preserves the old root and zeroes the unpublished replacement's
  new bytes. Publication and metadata commit remain explicit caller steps.
  See [the grow-and-resize contract](../engineering/m2-buffer-grow-resize.md).
- Buffer resize within retained capacity: implemented and verified in development
  and release, each with 28 native scenarios (4 new, 24 regressions); all 56
  processes exit with zero tracked live allocations.
  Shrinking preserves the prefix; growing zeroes newly exposed bytes. Capacity
  and accounting stay unchanged; equal length retains the token without SDK work.
  See [the resize contract](../engineering/m2-buffer-resize.md).
- Buffer truncate and clear: implemented and verified in development and release,
  each with 24 native scenarios (4 new, 20 regressions); all 48 processes exit
  with zero tracked live allocations. Shortening advances generation once;
  equal length retains the token. Capacity and accounting stay unchanged.
  See [the truncate contract](../engineering/m2-buffer-truncate.md).
- Buffer grow-and-append preparation: implemented and verified in development
  and release, each with 20 native scenarios (7 new, 13 lifecycle/allocator
  regressions). Growth-only preparation appends into an unpublished replacement
  and commits its initialized length/capacity after caller publication. The old
  root remains live for self-append and rollback; publication is still explicit.
  See [the grow-and-append contract](../engineering/m2-buffer-grow-append.md).
- Buffer close accounting: implemented and verified in development and release,
  each with 13 native scenarios (4 close, 9 append/allocator regressions).
  Begin retires the token while keeping its charge; after native root destruction,
  finish validates snapshots and releases payload plus logical owner usage.
  Native destruction order remains the trusted caller's responsibility.
  See [the close contract](../engineering/m2-buffer-close.md).
- Buffer append within admitted capacity: implemented and verified in development
  and release, each with 9 native scenarios (4 append, 5 allocator regressions).
  Nonempty append updates initialized length and token generation without changing
  capacity/accounting. Instrumented append cases allocate only the initial root.
  Guest Buffer syntax and VM integration remain future work.
  See [the append contract](../engineering/m2-buffer-append.md).
- Buffer allocator-failure probe: verified in development and release, each with
  5 native scenarios. Forced 320/384-byte allocation failures preserve the original
  data, token, inactive Plan and restored usage; explicit retries then commit.
  Every scenario exits with zero outstanding allocations at the instrumented
  FY system-heap seam. Runtime sources are unchanged by this verification slice.
  See [the failure probe](../engineering/m2-buffer-failure.md).
- Buffer replacement transactions: implemented and verified in development and
  release, each with 31 native groups (8 replacement, 23 regressions) and 8 CLI
  sentinels. Both invocations rechecked 259 identical inputs.
  Private preparation keeps the original token live; completion rechecks full
  descriptor/accounting snapshots before updating generation and final charges.
  Owning-root publication remains an explicit trusted caller step.
  See [the replacement contract](../engineering/m2-buffer-replacement.md).
- Buffer owner descriptors: implemented and verified in development and release,
  each with 23 native groups (8 descriptors, 7 storage, 8 admission) and 8 CLI
  sentinels. Both invocations rechecked 256 identical inputs.
  Private table-local slot/generation tokens guard initialized byte access;
  release invalidates tokens and exhausted generations retire their slots.
  Native root association and lifetime remain trusted caller responsibilities.
  Guest Buffer syntax, borrow tracking and VM integration remain future work.
  See [the descriptor contract](../engineering/m2-buffer-owners.md).
- Native Buffer storage: implemented and verified in development and release,
  each with 15 native groups (7 storage, 8 admission) and 8 CLI sentinels.
  Both invocations rechecked 253 identical inputs.
  Private replacement allocation copies initialized bytes while preserving the
  original root. Publication/commit and discard/cancel remain explicit caller steps.
  Guest Buffer syntax, owner tokens and VM integration remain future work.
  See [the storage contract](../engineering/m2-buffer-storage.md).
- Buffer growth admission: implemented at `3f99138` and verified in
  development and release, each with 8 native groups and 8 CLI sentinels. Both
  invocations rechecked 250 identical inputs.
  Private capacity planning and begin/commit/cancel accounting include old-plus-new
  payload and owner charges, with minimum-capacity fallback at quota ceilings.
  Guest Buffer syntax, allocation, move/borrow and VM integration remain future
  work. See [the foundation](../engineering/m2-buffer-growth.md).
- Returned subrecords in constructor fields: implemented at `c0d6217` and verified in
  development and release, each with 16 native groups and 442 CLI cases. Both
  combined invocations rechecked 247 identical inputs.
  `Box { .child = make().child }` stages only the selected exact-nominal leaves
  and releases the returned root before later fields. Declarations, replacement
  and constructor returns share this path. See [the source contract](../engineering/m2-struct-child-call-paths.md).
- Returned subrecords as direct returns: implemented at `c789300` and verified in
  development and release, each with 16 native groups and 444 CLI cases. Both
  combined invocations rechecked 244 identical inputs.
  `return make().child;` and deeper exact-nominal paths release the returned
  parent before creating the child, then use existing mixed return cleanup.
  See [the source contract](../engineering/m2-struct-call-path-returns.md).
- Returned subrecords as assignment values: implemented at `2971169` and verified in
  development and release, each with 16 native groups and 440 CLI cases. Both
  combined invocations rechecked 241 identical inputs.
  See [the source contract](../engineering/m2-struct-call-path-assignment.md).
- Returned subrecords as declaration initializers: implemented at `e38f00a` and verified in
  development and release, each with 22 native groups and 537 CLI cases. Both
  combined invocations rechecked 238 identical inputs.
  `let Point p = make().child;` and `var` create an independent exact-nominal
  child after releasing the returned root. Pending names remain invisible until
  CALL, path and delimiter validation finish. See [the source contract](../engineering/m2-struct-call-path-declarations.md).
- Returned subrecords as arguments: implemented at `7284da8` and verified in
  development and release, each with 17 native groups and 410 CLI cases. Both
  combined invocations rechecked 235 identical inputs.
  `take(make().child)` snapshots the exact-nominal child, releases the returned
  root before child creation, and reuses existing mixed argument cleanup.
  See [the source contract](../engineering/m2-struct-call-path-arguments.md).
- Direct record call-result scalar reads: implemented at `aee9885` and verified in
  development and release, each with 16 native groups and 374 CLI cases. Both
  combined invocations rechecked 232 identical inputs.
  `make().x` and deeper scalar field paths read the returned value, then
  immediately release its anonymous root through existing SREAD/SDROP.
  See [the source contract](../engineering/m2-struct-call-reads.md).
- Direct array call-result reads: implemented at `b822089` and verified in
  development and release, each with 18 native groups and 335 CLI cases. Both
  combined invocations rechecked 229 identical inputs.
  `make()[INDEX]` and `make().len` release the anonymous result after producing
  the scalar; index-expression exits use existing mixed cleanup.
  See [the source contract](../engineering/m2-array-call-reads.md).
- Repeated array literals as arguments: implemented at `ea6854f` and verified in
  development and release, each with 20 native groups and 344 CLI cases. Both
  combined invocations rechecked 226 identical inputs.
  `take([EXPR; N])` evaluates the filler once before publishing an anonymous
  immutable capture. Existing mixed cleanup handles calls and early exits.
  See [the source contract](../engineering/m2-array-literal-arguments.md).
- Array call results as arguments: implemented at `03795b9` and verified in
  development and release, each with 29 native groups and 507 CLI cases. Both
  combined invocations rechecked 223 identical inputs.
  `take(make_array())` and nested exact-shape calls join the existing mixed
  argument capture cleanup after CALL. Element type and length must match;
  visible local callee shadowing is rejected. See [the source contract](../engineering/m2-array-result-arguments.md)
  and the [Windows receipt](../evidence/m2-array-result-arguments-windows-20261028.json).
- Record constructors as arguments: implemented at `bd9db83` and verified in
  development and release, each with 26 native groups and 874 CLI cases. Both
  combined invocations rechecked 220 identical inputs.
  `take(Point { .x = 42 })` stages fields in declaration order before creating
  an anonymous immutable capture; existing mixed cleanup handles calls and early
  exits. See [the source contract](../engineering/m2-struct-constructor-arguments.md) and the
  [Windows receipt](../evidence/m2-struct-constructor-arguments-windows-20261028.json).
- Subrecord paths as arguments: implemented at `9650f12` and verified in
  development and release, each with 27 native groups and 570 CLI cases.
  The two successful combined profile invocations rechecked 217 identical inputs.
  An exact-type
  `take(outer.child)` or deeper path stages scalar leaves into an independent
  immutable snapshot before later arguments run. Existing mixed capture cleanup
  handles calls and early exits. See [the source contract](../engineering/m2-struct-path-arguments.md)
  and the [Windows receipt](../evidence/m2-struct-path-arguments-windows-20261028.json).
- Record call results as arguments: implemented at `7671f25`. A bare exact-type
  `take(make())` or nested `id(id(make()))` uses an anonymous argument capture
  after the inner CALL, then shared reverse mixed cleanup. Development and
  release each passed 29 native groups and 588 CLI cases in separate
  core/regression phases, with 214 matching rechecked inputs.
  See [the source contract](../engineering/m2-struct-result-arguments.md) and the
  [Windows receipt](../evidence/m2-struct-result-arguments-windows-20261028.json).
- Status: Accepted delivery sequence; M0 verified; named M1 slices through unsigned have verified historical receipts; explicit widening historically verified; integer operators historically verified; switch-arm statements implemented and verified, 2026-10-23; private entry-array IR/VM verified by its native harness, 2026-10-24; source-array reads, writes, copy initializers, parameters, results, and assignment forms implemented; in-place repeated-literal assignment verified; private scalar struct layout and storage implemented and verified; private scalar struct copy/assignment implemented and verified; private nested struct storage implemented and verified; private nested struct copy/assignment implemented and verified; shared struct-owner foundation implemented and verified; private struct-owner copy/assignment implemented and verified; private entry-owned struct IR/verifier verified historically; private struct VM implemented and verified, native 38/38 and CLI 115 in both profiles; declaration-only source structs historically verified stepwise in development and release (23 native groups and 2,208 CLI cases per profile); bounded entry scalar-field construction and reads are a verified historical read baseline; entry-only one-level scalar-field writes have historical focused development/release validation; entry-only scalar-record copy initialization and whole-record assignment are verified stepwise in development and release; bounded nested constructors, multi-segment scalar paths, and whole-root nested copies are implemented, with their result historical after child-binding compiler changes; whole-record child binding initializers have historical receipts; subrecord declaration initializer receipts are historical after assignment changes; atomic subrecord assignment is verified in development and release; constructor child subrecord paths verified in development and release; private scalar-value record replacement verified; metered atomic root replacement verified; private frame-local record VM verified in development and release (46 native groups and 2,383 CLI cases per profile); immutable by-value source record parameters verified in development and release (51 native groups per profile target); private record-result VM ownership transfer verified for its source-gated inputs; bounded source record results verified in development and release (14 native groups and 2,438 CLI cases per profile); direct nominal record constructor returns verified in development and release at `0a7b539`; exact-nominal subrecord return paths verified in development and release at `d4aa643`; constructor child record calls implemented at `c4cd6ab`, verified in development and release
- Root constructor assignment: verified in development and release; child constructor assignment is verified in development and release.
- Record-result signatures: nominal metadata verified for its original baseline
  (22 native groups and 2,317 CLI cases per profile). Its blanket pre-IR gate is
  historical and superseded by bounded source record-result lowering.
- Bounded source record results: verified in development and release at `bb401a4`
  (14 native groups and 2,438 CLI cases per profile), with a focused 70-case
  signature-checker rerun after the core aggregate.
- Direct nominal record constructor returns: implemented at `0a7b539` and verified
  in development and release. See [the source contract](../engineering/m2-struct-return-constructors.md).
- Exact-nominal subrecord return paths: implemented at `d4aa643` and verified in
  development and release. Each profile passed 25 native groups and 579 CLI
  cases. See [the source contract](../engineering/m2-struct-return-paths.md).
- Exact-nominal child record call-result assignment: implemented at `63be9e5`.
  Development and release each passed 26 native groups and 575 CLI cases. See
  [the source contract](../engineering/m2-struct-child-call-assignment.md) and
  [Windows receipt](../evidence/m2-struct-child-call-assignment-windows-20261028.json).
- Exact-nominal record calls in constructor child fields: implemented at
  `c4cd6ab` and verified in development and release. Each profile passed
  23 native groups and 529 CLI cases in separate core/regression phases, with
  211 verified input identities. See [the source
  contract](../engineering/m2-struct-child-calls.md) and [Windows
  receipt](../evidence/m2-struct-child-calls-windows-20261028.json).
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Current progress: M1 scalar checkpoint verified; M2 function-owned scalar arrays cover lexical storage, copy, length, helper locals, by-value parameters, source results, direct returns, repeated return literals, call-result assignment, and in-place repeated-literal assignment; private scalar struct layout, storage, and copy/assignment exist; private nested struct storage is verified; private nested struct copy/assignment is verified; shared struct-owner foundation is verified; private struct-owner copy/assignment is verified; private entry-owned struct IR and metered VM execution exist; declaration-only source struct layouts are historical verified evidence; bounded entry scalar-field construction and one-level reads are the historical verified read baseline; entry-only one-level field writes are supported with historical verification, and bare-name record copies plus whole-record assignment are verified stepwise in development and release; bounded nested constructors, multi-segment scalar paths, and whole-root copies are implemented, and child fields now accept exact-type whole visible bindings with development/release verification; their nested result is historical after the child compiler change; subrecord declaration extraction has historical receipts; atomic subrecord assignment is verified in development and release; immutable by-value record parameters are verified in development and release; private record-result VM ownership transfer is verified for its original inputs; bounded source record returns and typed call initializers are verified in development and release (14 native groups and 2,438 CLI cases per profile); direct nominal record constructor returns are verified in development and release at `0a7b539`; record borrows, Buffer, and text remain open; full-profile conformance incomplete; M3-M5 not started; constructor child subrecord paths verified in development and release; private frame-local record VM verified in development and release (46 native groups and 2,383 CLI cases per profile); exact-nominal subrecord return paths are implemented and verified in development and release at `d4aa643`, with 25 native groups and 579 CLI cases per profile; exact-nominal record calls in constructor child fields are implemented at `c4cd6ab`, verified in development and release

This roadmap orders learning and evidence. It is not a release promise. M0 has a
native harness and recorded evidence. The scalar CLI/VM now exist; the worker
and DLL do not.

## Guiding rules

Build the smallest real native path before expanding documents or platform support.
M0 and M1 must not wait for the Windows restricted worker or DLL milestones.

Every milestone must produce a runnable artifact, observed evidence, skipped checks,
and a short record of unresolved risk. A model or fixture does not satisfy a native gate.

## M0: native feasibility probes

Goal: prove that the smallest required Fairy native boundary is real and safe enough
to continue.

M0 now has Fairy C sources for checked signed i32/i64 and unsigned u8/u32/usize
arithmetic, exact 8-byte little-endian i64/usize codecs, storage planning and quota
rollback, typed owner generations, and scalar frame copies. The test allocator forces
the target allocator to return `NULL` and checks for leaked target allocations at exit.

The harness builds development and release variants and executes them with an empty
runtime `PATH` and cleared environment. The final expanded run passed six native
executions and four negative compiler checks: `E1101` use after move, `E2101` grow
with a live shared view, `E2102` local view escape, and `E2101` exclusive alias.
Exact inputs, outputs, and artifact identity are in `build/m0/receipt.json` and
`docs/evidence/m0-windows-20261023.json`.

M0 is native primitive evidence only. It does not implement `.brc` parsing, a VM, a
public CLI, a Windows worker, a DLL, or clean-machine packaging. An empty runtime
`PATH` is a harness condition, not proof of sandboxing.

Exit condition is met for the named scalar and storage boundary. M1 starts from an
unimplemented Brownie language pipeline.

## M1: scalar source to native VM

Status: bounded scalar checkpoint verified. The [requirements audit](../engineering/m1-checkpoint-audit.md)
confirms the scalar exit condition using unchanged executed evidence; it does not
claim full-profile conformance. The first [scalar slice](../engineering/m1-scalar-slice.md) runs i32
expressions, initialized locals/assignment, and direct functions through the native
source pipeline. The [bool/branch slice](../engineering/m1-branches.md) adds canonical
bool values, short-circuit operators, if/else chains, standalone blocks, early
returns, typed var slots, forward-only jumps, and definite initialization at CFG
joins. Its [dated receipt](../evidence/m1-branches-windows-20261023.json) records 20
native groups and 248 CLI cases in each of development and release and remains
historical. The [loop slice](../engineering/m1-loops.md) adds `while`, classic `for`,
`break`/`continue`, and metered backedges. Its
[receipt](../evidence/m1-loops-windows-20261023.json) records 26 native groups and
332 CLI cases in each profile and remains historical. The
[tagged slice](../engineering/m1-tagged.md) adds shallow `Option<i32|bool>`,
`Result<i32|bool, i32|bool>`, and exhaustive `switch` statements. Its historical
[receipt](../evidence/m1-tagged-windows-20261023.json) records 33 native groups and
423 CLI cases in each profile. The [propagation slice](../engineering/m1-propagation.md)
adds postfix `?` for those wrappers, with payload success and enclosing-wrapper
failure. Its [receipt](../evidence/m1-propagation-windows-20261023.json)
uses 37 native groups and 510 CLI cases per profile;
verification passed and the receipt is now historical. The
[switch-expression slice](../engineering/m1-switch-expressions.md) adds exhaustive
expression-position arms, restricted value-arm statements, typed joins, and direct
returns. Its [receipt](../evidence/m1-switch-expressions-windows-20261023.json)
records 41 native groups and 580 CLI cases per profile and remains historical. The
[i64 slice](../engineering/m1-i64.md) adds checked full-width signed scalars in the
existing source positions. Its [receipt](../evidence/m1-i64-windows-20261023.json)
is historical and records 49 native groups and 760 CLI cases in each profile. The
[unsigned slice](../engineering/m1-unsigned.md) adds `u8`, `u32`, and 64-bit guest
`usize` with checked arithmetic and reversible signed-cell representation. Its
[receipt](../evidence/m1-unsigned-windows-20261023.json) records 59 native groups
and 1,159 CLI cases in both development and release and remains historical. The
[widening slice](../engineering/m1-widening.md) adds `EXPR as TYPE` for seven
domain-preserving integer pairs with explicit precedence, verifier checks, and one
Fuel per executed cast. Its
[receipt](../evidence/m1-widening-windows-20261023.json) records 67 native groups
and 1,272 CLI cases in each profile, including 113 widening cases.
The [integer-operator increment](../engineering/m1-integer-operators.md) adds
fixed-width complement, AND/XOR/OR, and checked shifts with arithmetic signed right
shift. All initial scalar types, explicit widening, and these integer operators
are implemented. The [arm-statement increment](../engineering/m1-switch-arm-statements.md)
adds structured control flow inside expression arms. The scalar checkpoint remains
distinct from full-profile conformance. The source-array and bounded struct
slices now follow in M2; borrows, Buffer, full struct support, and text remain
later work.
The [integer-operator receipt](../evidence/m1-integer-operators-windows-20261023.json)
records 75 native groups and 1,898 CLI cases in each profile, including 626 new cases.
That receipt is historical after arm statements. The
[arm-statement receipt](../evidence/m1-switch-arm-statements-windows-20261023.json)
records 81 native groups and 1,969 CLI cases in each profile, including 71 new cases.

Goal: run real .brc source through lexer, parser, type checking, Flow analysis,
private code generation, independent verification, and the native VM.

The first usable slice includes i32/i64/u8/u32/usize/bool functions, explicit
widening, branches, loops, shallow scalar Option/Result, switch statements,
question-mark propagation, checked arithmetic, and bounded Fuel. It produces a small
CLI path for local engineering use.

Exit condition: the same source and input produce the expected guest value through
the actual native binary. Guest nonzero is data. Compile or runtime failure returns
an explicit diagnostic and does not crash the host.

## M2: aggregates, borrows, and bytes

Status: started; scalar-array layout/storage, owner/copy primitives, and private
entry-array IR/VM are implemented and verified. Immutable scalar-array declarations
and indexed reads in outermost `main` passed focused source verification. Source
arrays now extend through lexical scopes, helper locals, by-value parameters,
named and direct returns, repeated return literals, call-result assignment, and
in-place repeated-literal assignment. Focused verification for the last increment
is recorded.
The [layout foundation](../engineering/m2-array-layout.md) validates compact
widths, length 1..4096, aligned arena plans,
quota preflight, and checked offsets; it does not admit array source or allocate
payload storage. The [storage increment](../engineering/m2-array-storage.md) adds
little-endian scalar codecs, repeated initialization and checked element reads
and writes in caller-owned backing bytes, with nine native groups per profile.
These primitive receipts do not establish source arrays or aggregate execution.
The [owner-lifetime increment](../engineering/m2-array-owners.md) adds 16 bounded
typed descriptors, generation-safe token reuse, explicit release, suffix
reclamation and whole-table clear, with five native groups per profile.
The copy increment adds independent by-value array storage with destination
preflight and complete bool-source validation, verified in four additional native
groups per profile. That copy increment kept source grammar and the scalar VM unchanged.
The [private array IR/VM](../engineering/m2-array-vm.md) now runs entry-function
arrays through independent lifetime verification, owned payload storage and
metered dispatch. Its native harness passed 12 groups per profile plus four
instrumented allocator executions; the forced allocation request is exactly 320
bytes. The fresh scalar regression passed 81 native groups and 1,969 CLI
cases per profile after the shared VM change. Those IR and VM receipts are
historical after the source compiler changes.

The [source-array read increment](../engineering/m2-array-source.md) admits
`let T[N] NAME = [EXPR; N];` for the six scalar element types and `NAME[EXPR]`
reads. Declarations are immutable and limited to the outermost `main` body;
reads use exact `usize` and may appear in nested scopes and loops. The fill and
index are each evaluated once. Every return drops visible arrays in reverse
binding order after evaluating its result. The source profile is
`brownie.m2-array-read/1`, while the result schema is unchanged.

The [source-array write increment](../engineering/m2-array-write.md) adds
`var T[N] NAME = [EXPR; N];` and `NAME[EXPR] = VALUE;` in nested blocks, loops,
switch statements, and switch-expression arms. The index is exact `usize` and is
evaluated once before the exact scalar RHS. Both operands complete before
`AWRITE` checks bounds, so an RHS error or early return publishes no write. Any
mutable catalog entry selects `brownie.m2-array-write/1`, including after a later
verification or runtime failure. Bare array assignment, compound element
assignment, arrays in helpers or nested declarations, and writes in `for` headers
remain outside this slice. Array parameters, results, borrows, `len`,
slices, and aggregate calls also remain outside it.

The [source-array copy-initializer increment](../engineering/m2-array-copy-source.md)
adds `let|var T[N] DEST = SOURCE;` in the outermost `main` body. The source must
be a bare visible array binding with the exact destination element type and
length. `ACOPY` preserves the source and gives the destination independent bytes;
`let` or `var` selects only the new destination's mutability. Source and
destination descriptors share the 16-entry catalog, and their payloads share the
fixed 65536-byte arena. A program containing `ACOPY` selects
`brownie.m2-array-copy/1`, ahead of the mutable write profile. No new IR or VM
instruction is introduced. Whole-array reassignment, source expressions beyond a
bare binding, nested/helper declarations, for-header copies, parameters, results,
borrows, `len`, and slices remain outside the slice.

The [source receipt](../evidence/m2-array-source-windows-20261024.json) records
18 native groups and 67 CLI source cases in each development and release profile,
including six new source groups. The subsequent full M1 regression passed
81 native groups and 1,969 CLI cases per profile in development and release;
that fresh evidence is included in the same source receipt. The read receipt is
historical after the write compiler changes. The
[write receipt](../evidence/m2-array-write-windows-20261024.json) records nine
native groups, 67 read CLI cases, and 61 write CLI cases in each development and
release profile. Scalar CLI regression also passed 1,969 cases per profile on
the same binaries. The read and write receipts are historical after the copy
compiler change. The [copy receipt](../evidence/m2-array-copy-source-windows-20261025.json)
records 12 native groups per profile (six read, three write, three copy), 67 read
CLI cases, 61 write CLI cases, and 58 copy CLI cases in development and release.
Scalar CLI regression also passed all 1,969 cases per profile on the same binaries. When requested, `--scalar-regression` runs the 1,969 scalar CLI
cases per profile; `--reuse-scalar-regression` can instead check matching completed
receipts after documentation-only changes without repeating that matrix. The
81-group scalar native rerun is skipped because the VM and verifier are unchanged.
The [array-length increment](../engineering/m2-array-length.md) adds `NAME.len`
as an exact `usize` constant for visible entry-array bindings, including in pure
scalar `for` headers. This completes length access for the current fixed-array
source slice; parameters/results, borrows, slices, and whole-array reassignment
remain open. The [length receipt](../evidence/m2-array-length-windows-20261025.json)
records 15 native groups, 226 array CLI cases, and 1,969 scalar CLI cases in each
development and release profile. Earlier frontend receipts are historical.

The [lexical-array increment](../engineering/m2-array-scopes.md) admits arrays in
`main` blocks, branches, loops, and switch arms. Reverse cleanup at block exits,
loop transfers, arm yields, and returns allows scratch storage to be reused.
Its [receipt](../evidence/m2-array-scopes-windows-20261025.json) records 19 native
groups, 270 array CLI cases, and 1,969 scalar CLI cases per development/release
profile. The length receipt is historical after these frontend changes.
Helper arrays, aggregate calls, parameters/results, borrows, slices, and
whole-array reassignment remain open.

The [whole-array assignment increment](../engineering/m2-array-assignment.md)
adds exact-shape `DEST = SOURCE;` into mutable existing storage without reserving
another payload or owner. Private opcode 38 receives independent type/lifetime
verification and metered dispatch. The
[assignment receipt](../evidence/m2-array-assignment-windows-20261025.json) records
16 native groups, 329 array CLI cases, and 1,969 scalar CLI cases per
development/release profile. Earlier frontend and array-backend receipts remain
historical after the changed owner/IR/verifier/dispatch inputs. Helper arrays,
aggregate parameters/results, borrows, and slices remain open.

The [private array-frame foundation](../engineering/m2-array-frames.md) gives
array catalog entries explicit function ownership and recursive VM invocations
separate token slots. All frames continue to share 16 owners and one payload
arena. Source arrays remain confined to `main`; helper source declarations come
next, followed by exact-shape by-value parameters. Neither source feature is
implemented by this foundation.
The [frame receipt](../evidence/m2-array-frames-windows-20261025.json) records
24 native groups, 329 array CLI cases, and 1,969 scalar CLI cases per
development/release profile; prior IR/verifier/VM evidence is historical where
inputs changed.

The [helper-local array increment](../engineering/m2-array-helpers.md) now admits
the existing array grammar in scalar and shallow wrapper-returning functions.
Function-owned declarations and copies reuse the frame backend; `?` failure
lowering emits reverse local cleanup before returning the failure wrapper.
At that checkpoint array parameters/results, borrows, and slices remained open.
The [helper receipt](../evidence/m2-array-helpers-windows-20261025.json) records
16 native groups, 426 array CLI cases, and 1,969 scalar CLI cases per
development/release profile. The frame backend is unchanged; earlier frontend
receipts are historical where compiler and propagation inputs changed.

The [source parameter increment](../engineering/m2-array-parameters.md) adds
immutable exact-shape array parameters, ordered mutable captures, forward/mutual
calls, and cleanup on early exits. Its prior receipt records 28 native groups
and 2,475 CLI cases per development/release profile.
The [array result signature foundation](../engineering/m2-array-result-signatures.md)
recorded exact result shapes and rejected compilation before body or parameter
lowering at that historical checkpoint. Later source increments remove that gate.
Its [receipt](../evidence/m2-array-result-signatures-windows-20261025.json)
records 16 native groups and 2,242 CLI cases per development/release profile;
full native backend suites and later delivery milestones were not rerun.

The [private array-result increment](../engineering/m2-array-results.md) adds
result shape anchors, independent CALL/ARET verification, and callee-to-caller
owner transfer. It retains a single payload/owner through recursive returns,
with no return-time allocation or byte copy. Source result lowering was still
gated at that private checkpoint.
Its [receipt](../evidence/m2-array-results-windows-20261025.json) records 43 native
groups and 2,571 CLI cases per development/release profile. This is private
result execution evidence; it does not establish later source or delivery gates.

Subsequent [source returns](../engineering/m2-array-result-source.md),
[direct calls](../engineering/m2-array-return-calls.md) and
[repeated return literals](../engineering/m2-array-return-literals.md) connect
exact-shape arrays to typed call initializers and shared return cleanup. The
literal-return Windows receipt records 16 native groups and 628 CLI cases per
development/release profile. [Call-result assignment](../engineering/m2-array-call-assignment.md)
subsequently adds copies into existing mutable storage, verified by 15 native
groups and 609 CLI cases per profile in its focused selection. The
[in-place repeated-literal assignment](../engineering/m2-array-literal-assignment.md)
increment follows with typed AFILL (40), owner preflight before writes, and no
temporary catalog site, owner, or payload extent. The
[Windows receipt](../evidence/m2-array-literal-assignment-windows-20261025.json)
records 36 unique native groups and 2,693 CLI cases per profile. The final 36
combine 17 reused backend identities with 19 fresh frontend groups in each
profile; the aggregate harness was not rerun. Development reuses backend from
`b5e0c98`, and release reuses the same identities from its earlier 36-group
selection. Reuse validation matched 28 unchanged source and test files to their
`b5e0c98` Git blobs and confirmed matching SDK and compiler identities. The CLI
total is 724 array cases, including 115 new fill cases, plus 1,969 scalar cases.
The final lowering separates array statement, copy, and index handling into
helpers. Scalar and composed fills return 42 at depth 10; depth 11 reports
`compile_limit`. Two permanent CLI cases cover the composed boundary. The pre-fix
binary reproduces `0xC00000FD` at depth 10. No stack-byte or performance claim is
made.
Borrows, Buffer, I/O, isolation, and the remaining milestone evidence below
are still open.

The private [struct-layout planner](../engineering/m2-struct-layout.md) covers
0..32 acyclic records with 1..16 fields, declaration-order alignment, tail
padding, shared and forward child resolution, and a 16-level structural limit.
It adds no source syntax, storage, IR, VM, or allocation. Both development and
release passed its 14-group Windows receipt. The [scalar struct-storage
slice](../engineering/m2-struct-storage.md) then prepares a selected scalar
record, initializes all fields in caller-backed arena bytes, and reads or writes
one indexed field; that slice rejects nested roots. Both
profiles passed its 20-group Windows receipt. The [private copy/assignment
slice](../engineering/m2-struct-copy.md) appends independent scalar records and
overwrites existing storage, including self and partial overlap, with normalized
padding and no extra extent for assignment. Development and release each passed
its fresh 28-group Windows receipt after moving staging into caller-owned
scratch. The [private nested-storage slice](../engineering/m2-struct-nested-storage.md)
initializes selected acyclic records from depth-first scalar leaves and reads or
writes scalar field paths; selected roots stay within 128 bytes while the full
catalog is replanned at each boundary and unselected valid records may be larger.
The nested-storage 18-group Windows receipt passed development and release before
the shared-module change. The [private nested copy/assignment
slice](../engineering/m2-struct-nested-copy.md) appends selected records by value
and overwrites existing storage without a cursor change, including self and both
partial overlap directions. Its 24-group Windows receipt passed development and release, and
the earlier 18-group receipt is historical for changed inputs. A shared
[struct-owner foundation](../engineering/m2-struct-owners.md) now stores record
descriptors in the existing 16-slot table and rechecks catalog layout on access;
array APIs reject record tokens. The full 34-group Windows selection passed
development and release. A [private struct-owner copy/assignment
slice](../engineering/m2-struct-owner-copy.md) appends independent record owners
and requires exact record identity for assignment. Its 17-group Windows selection
passed development and release, and the previous 34-group owner receipt is historical for changed
inputs. A [private struct IR/verifier](../engineering/m2-struct-ir.md) checks
entry-owned initialization, copy, scalar leaves, mutation and drop. Its earlier
Windows selection passed 46 native groups per development/release profile, and
the focused repeated-literal assignment CLI suite passed 115 cases per profile;
those receipts are historical after changed runtime, test, harness, and root-lock
inputs. The original [private struct VM](../engineering/m2-struct-vm.md) contract
executed opcodes 41..46 with fixed prepaid Fuel, sixteen entry tokens, and the
shared array owner table and payload arena. Development and release each passed
all 38 native groups and the existing 115-case CLI suite for that private VM
slice. A
[function-owned record IR foundation](../engineering/m2-struct-function-ir.md)
assigns each static record site to one function, validates active and unused
owner metadata, and requires opcodes 41..49 to use that function, including same
function copy/assign/subassign sources. Per-function lifetimes start dead; existing
joins and cleanup rules are unchanged. The entry-frame-only kind-5 boundary was
the foundation's historical checkpoint; the
[frame-local successor](../engineering/m2-struct-function-vm.md) now executes
verified helper IR. Source helper records remain rejected. The complete
`--function-ir` invocation passed 31 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](../evidence/m2-struct-function-ir-windows-20261027.json) records 106 input hashes,
compiler/artifact identities, commands and outcomes. Other CLI matrices, full
native suites, Linux, packaging, isolation and performance were not rerun. A
[declaration-only source struct slice](../engineering/m2-struct-source.md)
attaches immutable layouts for bounded forward-referencing declarations while
emitting no struct operations. Its 23 native groups and 2,208 CLI cases per
profile remain historical evidence for that slice, recorded in the
[stepwise receipt](../evidence/m2-struct-source-windows-20261026.json). The
[bounded source struct-value slice](../engineering/m2-struct-values.md) is
the historical read baseline: entry-only scalar-field construction and one-level
scalar field reads. Every
field appears exactly once in declaration order, with an optional final comma;
left-to-right typed field expressions are staged before consecutive loads and
`SINIT`; the compiler declares the binding after emitting that initializer, and
a runtime failure aborts. Mixed lexical exits, loop
transfers, and returns release arrays and records in reverse order. Read-only
record programs select `brownie.m2-struct-read/1`; declaration-only programs
keep their existing profile. The slice is capped at selected roots of 128 bytes and
16 fields, with 16 record sites, the shared owner table, 65,536-byte payload cap,
and existing Fuel. That baseline left subrecord values, struct parameters/results,
and borrows unsupported; nested type declarations remain accepted and are handled by the
nested successor below. For that
baseline, both
profiles passed 28 native groups and 2,352 CLI cases through the focused harness,
plus three supplementary cases per profile. The
[receipt](../evidence/m2-struct-values-windows-20261026.json) records the executed
checks and their scope.

The [source struct-field write slice](../engineering/m2-struct-write.md) adds
entry-only one-level `NAME.FIELD = EXPR;` through `SWRITE`. The target
binding and field resolve before one exact-typed RHS; the write follows the
expression and terminator and reuses the existing extent without a copy, owner,
or payload allocation. Both for-header clauses remain rejected; condition reads
and body writes are accepted. Programs with nonempty record bindings and opcode
44 select `brownie.m2-struct-write/1`; version JSON adds `struct_write_profile`.
Development and release each passed 24 native groups and 2,472 CLI cases,
including RHS depth 10 success and depth 11 `compile_limit`. The
[receipt](../evidence/m2-struct-write-windows-20261026.json) records the complete
`--write` invocation and artifact identities. Full source structs,
wrapper element types, borrows, and Buffer remain open. The later source-copy
compiler change makes the read and write receipts historical for the current
inputs.

The [source struct-copy slice](../engineering/m2-struct-source-copy.md) adds
entry-only `let|var P q=p;` initialization and `p=q;` assignment for exact
nominal record types, including whole nested roots. Copy initialization creates an independent owner and
extent; assignment overwrites the mutable destination's existing extent and
accepts self-assignment. Immutable sources are accepted. Helper-local records and
record statements in `for` initializer/post clauses remain rejected. That slice
left constructor RHS assignment, aggregate expressions, struct parameters/results,
and borrows unsupported. Nested constructors, scalar paths, and child binding
initializers are handled by the successors below. Nonempty record
bindings plus opcode 42 or 46 select `brownie.m2-struct-copy/1` before the write
and read profiles; version JSON adds `struct_copy_profile`. Development and release
each passed 39 native groups and 2,582 CLI cases, including 110 new copy cases.
The [stepwise receipt](../evidence/m2-struct-source-copy-windows-20261026.json)
records development native/build reuse after CLI fixture corrections. The complete
aggregate harness was not rerun.

The [source nested-struct slice](../engineering/m2-struct-source-nested.md) adds
inline named child constructors, multi-segment scalar read/write paths, and
whole-root copies for entry-owned nested records. An iterative cursor walks the
constructor tree in source order; scalar leaves are staged left to right before
consecutive loads and one `SINIT` for the root. Child constructors add no site,
owner, or extent. Path segments resolve to depth-first scalar-leaf ordinals,
including leaves in preceding nested siblings. Source staging allows 16 scalar
leaves in total, record nesting and path length 16, and selected roots 128 bytes;
the private VM keeps its 128-leaf bound. A bound record with a nested field
selects `brownie.m2-struct-nested/1` ahead of the copy, write, and read profiles;
version JSON adds `struct_nested_profile`. Development and release each passed
36 native groups and 2,710 CLI cases, including 128 nested cases, through the
complete `--nested` harness on corrected inputs. The
[receipt](../evidence/m2-struct-source-nested-windows-20261027.json) records
source/tool hashes, artifacts, commands and the corrected release regression; it
is historical after the child-binding compiler change.

The [child binding initializer successor](../engineering/m2-struct-child.md)
admits a whole visible record binding as an inline child value when its nominal
type matches the field. It copies each source scalar leaf with `SREAD` and
`STORE` into the parent's staging before a later sibling expression can mutate the
source, so the snapshot is independent and the source stays live. Child capture
creates no `SCOPY`, temporary owner, site, or extent; only the new parent root
consumes an owner and extent. Existing quotas, opcodes, verifier, VM ownership,
and the `brownie.m2-struct-nested/1` profile remain. Version JSON adds
`struct_child_binding_initializers`. The complete `--child` harness passed 21
native groups and 2,798 CLI cases in each development/release profile. The
[receipt](../evidence/m2-struct-child-windows-20261027.json) records 90 input
hashes, compiler and CLI artifact hashes, commands, and outcomes.
Implementation commit: `ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`.

The [subrecord declaration successor](../engineering/m2-struct-extract.md)
adds `let I i = p.i` and deeper exact-nominal endpoints as independent owned
values. Consecutive `SREAD` results feed one `SINIT`; no temporary owner or
staging instructions are added. Source and destination keep separate lifetimes.
The nested profile and existing limits remain; version JSON adds
`struct_subrecord_initializers`. Development and release each passed 26 native
groups and 2,915 CLI cases stepwise. Development reuses unchanged native results
after two CLI-only diagnostic fixes; final CLI matrices and release native groups
ran afterward. The [receipt](../evidence/m2-struct-extract-windows-20261027.json)
records 92 input hashes, compiler/artifact hashes, commands, and reuse provenance.
Implementation commit: `f65a1d7`.
At `f65a1d7`, helper records, struct parameters/results, and borrows remained
open. Helper records, source parameters, and bounded record results now have
successor implementations; record borrows remain open.

The [subrecord assignment successor](../engineering/m2-struct-subassign.md)
adds exact-nominal `p.i = q.i`, `p.i = i`, and `i = p.i` with mutable existing
destinations. All source leaves are captured before target writes; no extra site,
owner, or payload is required. Existing opcodes, verifier/VM rules, bounds, and the
nested profile remain. Fatal errors abort the invocation without transactional
rollback. Version JSON adds `struct_subrecord_assignment`. The complete
`--subassign` invocation passed 15 native groups and 3,044 CLI cases in each
development/release profile. The
[receipt](../evidence/m2-struct-subassign-windows-20261027.json) records 91 harness
input hashes plus four CLI fixture hashes, compiler/artifact hashes, commands,
and outcomes. Implementation commit: `666da70`.
The extraction receipt is historical for changed inputs.

The [atomic assignment successor](../engineering/m2-struct-subassign-atomic.md)
uses one independently verified `SSUBASSIGN` instruction and 131,072 prepaid Fuel.
It stages canonical bytes before writing existing target storage, so failed
assignment leaves the selected destination unchanged. Earlier statements and
external effects are not rolled back. Sixteen source leaves now execute within
the CLI allowance without a temporary owner or new scalar registers. The nested
profile remains; version JSON adds `struct_subrecord_assignment_atomic`.
The complete `--atomic` invocation passed 26 native groups and 3,046 CLI cases
per development/release profile. The
[receipt](../evidence/m2-struct-subassign-atomic-windows-20261027.json) records
99 input hashes, compiler/artifact identities, commands, and outcomes. Integration
commit: `5589803`; foundation: `2b5917c`, with nine groups passed per profile
before integration. The per-leaf receipt is historical for changed inputs.

The [constructor child-path successor](../engineering/m2-struct-child-path.md)
admits `R { .i = p.i }` and deeper exact-nominal record endpoints. It snapshots
selected leaves before later sibling expressions and introduces no temporary
owner, site or extent. The VM, verifier, bounds and nested profile are unchanged;
version JSON adds `struct_child_path_initializers`. The complete `--child-path`
selection passed 19 native groups and 419 CLI cases in each development/release
profile. The [receipt](../evidence/m2-struct-child-path-windows-20261027.json) records 99 input hashes, compiler/artifact
identities, commands and outcomes. Implementation commit: `680f57a`. This focused
selection does not rerun scalar/array or other struct CLI matrices, full native
suites, Linux, packaging, isolation or performance. Earlier receipts are historical
for changed frontend, root-lock, fixture and harness inputs.

A [private scalar-value replacement foundation](../engineering/m2-struct-replace-values.md) now stages every scalar
field before overwriting an existing exact-nominal root. Owner tokens, order and
payload use remain unchanged, including at full capacity. Initialization and
replacement share one encoder. This adds no source syntax, opcode, verifier,
VM dispatch, Fuel charge or version capability; constructor RHS assignment
remained unavailable in that slice. The complete `--replace-values` invocation passed 21 native
groups and 214 CLI cases per development/release profile. The [receipt](../evidence/m2-struct-replace-values-windows-20261027.json)
records 102 input hashes, compiler/artifact identities, commands and outcomes.
Implementation commit: `6509e27`. The selection covers six new replacement groups,
six nested-storage, six owner-copy and three subrecord-owner groups, plus 83
existing child-path and 131 existing assignment CLI cases. Other CLI matrices,
full native suites, Linux, packaging, isolation and performance were not rerun.
Earlier receipts are historical for changed storage, owner, root-lock and harness
inputs. Metered VM integration is covered by the successor below; source lowering
is covered by the [constructor-assignment successor](../engineering/m2-struct-replace-source.md).

Private [metered root replacement](../engineering/m2-struct-replace-vm.md) now executes `SREPLACE` (48) after
independent live/mutable/nominal and consecutive scalar-input verification.
The VM prepays 46,145 Fuel, stages canonical bytes and overwrites existing storage
without a temporary owner, site or extent. Scalar definitions and owner live sets
are unchanged. No constructor-assignment source syntax or version capability
was added by that slice. The complete `--replace-vm` invocation passed 27 native groups (6 new,
8 existing VM, 9 IR, 4 atomic assignment) and 214 CLI cases (83 child path,
131 assignment) per development/release profile. The [receipt](../evidence/m2-struct-replace-vm-windows-20261027.json) records
102 input hashes, compiler/artifact identities, commands and outcomes.
Implementation commit: `6f1b38f`. Other CLI matrices, full native suites, Linux,
packaging, isolation and performance were not rerun. Earlier receipts are
historical for changed verifier, VM, profile-selection, root-lock, test and harness
inputs. Those results remain scoped to the metered VM slice.

[Entry-only mutable root constructor assignment](../engineering/m2-struct-replace-source.md)
is now implemented at `1627ee4`. Constructor RHS values stage in source order
before consecutive `LOAD`s and one `SREPLACE` (48), without another owner, site,
or extent. Version JSON reports `struct_constructor_assignment: true`.
The complete `--replace-source` invocation passed 28 native groups and 2,390
CLI cases per development/release profile without result reuse. The [receipt](../evidence/m2-struct-replace-source-windows-20261027.json)
records 101 input hashes, compiler/artifact identities, commands and outcomes.
Other CLI matrices, full native suites, Linux, packaging, isolation and
performance were not rerun.
That 28-group and 2,390-CLI result remains historical for `1627ee4` after the
later backend inputs; it remains recorded for that commit.

[Entry-only child constructor assignment](../engineering/m2-struct-subreplace-source.md)
is now implemented at frontend `a24c0b1` on backend `9fa0180`. It reuses
constructor staging, then consecutive loads and one `SSUBREPLACE` (49) for an
exact nominal child path, without another owner, site, or extent. Version JSON
reports `struct_subrecord_constructor_assignment: true` under the unchanged
nested profile. The complete `--subreplace-source` invocation passed 36 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](../evidence/m2-struct-subreplace-source-windows-20261027.json) records 105 input hashes,
compiler/artifact identities, commands and outcomes. Other CLI matrices, full
native suites, Linux, packaging, isolation and performance were not rerun.

A [private frame-local record VM](../engineering/m2-struct-function-vm.md) now
executes verified helper IR in up to 32 guest frames. Each frame has sixteen
record token slots over the same shared 16 owners and payload arena, indexed like
arrays; entering a frame allocates no separate table or arena. `SINIT` and
`SCOPY` reserve shared owners and payload and require dead destination tokens.
Writes and assignments require live mutable destinations. Drops clear frame
tokens, while dead middle extents stay charged until suffix reclamation. Opcodes,
Fuel, frontend lowering, and version are unchanged. The 13-group smoke suite
passed in one native invocation. The complete `--function-vm` invocation passed 46 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](../evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
compiler/artifact identities, commands and outcomes. Implementation commit:
`80ed712`. Other CLI matrices, full native suites, Linux, packaging,
isolation and performance were not rerun.
Source helper records were unsupported at `80ed712`; the
[source successor](../engineering/m2-struct-function-source.md) enables them. Record
parameters and bounded record results now have source successors; record borrows
remain unsupported. The 512-slot token array carries no measured allocation,
stack, or speed claim.

Source [helper-local records](../engineering/m2-struct-function-source.md) are implemented at `98a4525` for ordinary scalar, wrapper-returning, and array-returning helpers. Constructor, copy, and subrecord-extraction paths use `ir::record_in` with the lowering function. Existing record forms run in callee frames under the shared sixteen sites and owners, 128-byte roots, sixteen-leaf staging, and 32 VM frames. Array-returning helpers drop local records in reverse mixed array-record order before `ARET`, preserving the returned array. Version JSON reports `struct_helper_locals: true`; opcodes, Fuel, and profile strings are unchanged.

Development and release each passed 48 native groups and 2,860 CLI cases, including 89 helper-local record cases. The native report was retained after correcting the aggregate expected count from 47 to 48; CLI matrices ran individually, including a fresh nested matrix after updating an obsolete root-replacement expectation. Release completed the `--function-source --profile release` aggregate. The [receipt](../evidence/m2-struct-function-source-windows-20261027.json) records 153 input hashes, compiler and artifact identities, and equal native identities across profiles. At `98a4525`, source record parameters/results and borrows were unavailable; [record parameters](../engineering/m2-struct-parameters-source.md) and a [bounded record-result subset](../engineering/m2-struct-result-source.md) now have successors, while record borrows remain unavailable. Full native suites, other struct/array matrices, Linux, packaging, DLL, isolation, and performance were not run.

The [record-parameter signature foundation](../engineering/m2-struct-parameter-signatures.md) recognizes bare nominal parameter types and stores each record ID separately from scalar tags and array lengths. The bounded signature table adds 128 bytes. Its pre-lowering rejection was the source gate at that checkpoint and is superseded by the [source parameter successor](../engineering/m2-struct-parameters-source.md). The signature receipt remains historical for the gate. Source record returns and borrows remain unavailable. That increment added no opcode, Fuel charge, profile, or version capability.

Development and release each passed 16 native groups and 2,226 CLI cases: 88 signature-gate, 89 helper-record, 80 array-parameter, and 1,969 M1 cases. Development ran individual commands; release completed `--parameter-signatures --profile release`. The [receipt](../evidence/m2-struct-parameter-signatures-windows-20261027.json) records compiler/artifact identities, 181 input hashes, and equal native identities across profiles. This is focused signature verification; full native/array suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation, and performance were not run.

The private [record-parameter IR foundation](../engineering/m2-struct-parameters-ir.md) adds immutable callee-owned record sites and 128 zero-tag parameter placeholders. CALL arguments distinguish scalar registers, array sites, and record sites; record arguments require exact nominal identity, caller ownership, liveness, and an immutable source or explicit snapshot. Parameter lifetimes occupy bits 16..31, participate in joins/backedges, and must be dropped before scalar or array returns. Its initial VM availability gate is superseded by the metered record-call successor below; its source gate is also superseded by the current source parameter lowering.

The complete `--parameter-ir` aggregate passed 28 native groups (7 new record-parameter, 9 array-call, 6 record function-IR, 6 source signature) and 2,226 CLI cases per development/release profile without result reuse. The [receipt](../evidence/m2-struct-parameters-ir-windows-20261027.json) records 182 input hashes, compiler/artifact identities, commands and outcomes. Matching native identities, all input hashes, and the current compiler/release binary were rechecked before archival. Implementation: `9b43e0d`. Full native suites, other CLI matrices, M0, Linux, packaging, DLL, isolation, allocation instrumentation and performance were not run.

The private [mixed argument-copy foundation](../engineering/m2-call-argument-copies.md) now stages 0..8 array/record arguments as one transaction. It checks every source against the original owner table, normalizes record padding, validates nested bools, and admits all owner/payload reservations before publishing bytes or tokens. Failed batches preserve all backing bytes and owner metadata. That storage-only increment changed no VM gate, source grammar, Fuel or capabilities; the VM integration is described below.

The complete `--call-copies` aggregate passed 70 native groups (9 new, 61 affected) per development/release profile without result reuse. The [receipt](../evidence/m2-call-argument-copies-windows-20261027.json) records 62 input hashes and matching native identities. All inputs, compiler and unchanged SDK identities were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, packaging, DLL, isolation, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed owner/storage, root-lock and harness inputs.

The [private record-call VM](../engineering/m2-struct-call-vm.md) executes verified record-parameter IR through one mixed array/record copy transaction. It prepays the complete CALL before frame admission or payload/token changes, binds aggregate tokens, then publishes scalar arguments and the child return frame. Array-only/scalar-only prices are unchanged; record calls add 2,048 batch Fuel plus 43,008 per record and existing array work. The kind 11 VM gate is removed. Its statement that source record parameters remained rejected is historical and superseded by the current source lowering; opcodes, other charges, profiles and version capabilities are unchanged.

Implementation: `97bf1e2`. Development and release each passed 47 unique native groups in two separate invocations: [core, 21 groups](../evidence/m2-struct-call-vm-core-windows-20261027.json) followed by [regressions, 26 groups](../evidence/m2-struct-call-vm-regressions-windows-20261027.json). This is stepwise verification, not a single combined aggregate run. Both receipts have the same 58 input hashes, compiler and SDK identities, and disjoint test selections; all were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, isolation, DLL, packaging, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed VM, root-lock, test and harness inputs.

Source [record parameters](../engineering/m2-struct-parameters-source.md) are implemented at `d0ca7e7` and verified in development and release. At that checkpoint bare visible bindings of the exact nominal type were accepted; constructors, paths, casts, and aggregate expressions are rejected. Mutable sources are captured with `SCOPY` before later arguments evaluate. Record formal sites are predeclared after the catalog scan and bound by owning function plus record-formal ordinal inside the existing 16-site budget, without a second 128-byte signature map. Callee formals are immutable and by value. Record results were unavailable at that checkpoint and now have bounded source
successors; record borrows, `ref`, and `var` parameters remain unavailable.

The slice reuses the existing record-aware `array_source::release_from` and array-result finisher. No new record cleanup semantics are claimed. Scalar returns drop every visible formal, including record formals, before `RET`; array returns retain the selected result and drop other visible records before `ARET`. At that checkpoint no source path returned a record.

Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](../evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](../evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [record-result signature foundation](../engineering/m2-struct-result-signatures.md)
records bare nominal results as ID + 1 in a bounded 16-byte metadata array.
Scalar and array result fields remain zero, and the compiler rejects every scanned
record result at its function name before IR or body lowering. `main` remains a
zero-argument scalar `i32` entry point. This adds no runtime capability, opcode,
Fuel, profile, or version field. Development and release each passed 22 native groups and 2,317 CLI cases. The [Windows receipt](../evidence/m2-struct-result-signatures-windows-20261028.json) records the original baseline, executed commands, compiler/SDK and CLI identities, input hashes, and outcomes. The native selection comprises 6 new record-result, 6 record-formal, 6 array-result and 4 scalar-function groups. CLI coverage comprises 72 new record-result, 66 record-formal, 114 source record-parameter, 96 array-result and 1,969 M1 cases per profile. All 209 input hashes, the compiler, SDK and final release CLI were checked before archival. Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [private record-result IR/verifier foundation](../engineering/m2-struct-results-ir.md)
adds a `u8[16]` callee-owned shape table, `SRET` (50), and record CALL
destinations at `144 + site`. SRET requires one live exact-nominal record; joins
and backedges keep exact record lifetimes in bits 16..31. At `dc1574b`, the VM
verified first and then reported unavailable before Fuel or payload preparation.
That kind 11 runtime gate is historical and superseded by the
[record-result VM successor](../engineering/m2-struct-result-vm.md). The IR
slice's blanket source gate is historical and superseded by the [bounded source
successor](../engineering/m2-struct-result-source.md). Fuel, profiles, and
version capabilities were unchanged by the IR slice.

The [record-result VM successor](../engineering/m2-struct-result-vm.md) executes
verified `SRET` with a 42,113-Fuel prepayment. It checks bounds, exact metadata,
the empty caller destination, all other child tokens, owner metadata, and every
scalar leaf through a 128-byte scratch snapshot. Success clears the child token
and publishes the same token in the caller; owner descriptors, order, generations,
and payload do not change. Development and release each passed 34 native groups
and 2,317 CLI cases; see the [Windows receipt](../evidence/m2-struct-result-vm-windows-20261028.json).

The record-result IR slice's evidence remains 39 unique native groups and 2,317 CLI cases per profile. The [core receipt](../evidence/m2-struct-results-ir-core-windows-20261028.json) records 21 native groups (8 new record-result, 6 array-result, 7 record-parameter), CLI builds and all 2,317 cases; the [regression receipt](../evidence/m2-struct-results-ir-regressions-windows-20261028.json) records 18 native-only groups (6 array-result VM, 8 record-call VM, 4 scalar-function), with no build or CLI rerun. CLI coverage is 72 record-result signature, 66 record-formal signature, 114 source record-parameter, 96 array-result signature and 1,969 M1 cases per profile. These were two separate phase invocations across implementation commit `dc1574b`, with disjoint native selections and matching 212 input hashes, compiler and SDK identities. All inputs and the final release CLI were rechecked before archival. Full native/CLI suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [bounded source record-result successor](../engineering/m2-struct-result-source.md)
is verified in development and release at `bb401a4` with tooling `78a1fb4`. A
bare visible exact-nominal `return name;` and an exact-nominal `let`/`var` call
initializer lower through CALL at `144 + site` and `SRET` (50). Result anchors
reuse a matching nominal formal or reserve a dead function-owned site before any
body. Pending initializer names stay invisible through CALL and capture cleanup;
the finisher drops other mixed arrays and records in reverse lexical order.
Development and release each passed 14 native groups and 2,438 CLI cases. After
that aggregate, the result-signature checker's `kind` loop variable was renamed
to `error_kind` and all 70 cases were rerun per profile against retained binaries;
native, build, and other CLI selections were not rerun. The [Windows
receipt](../evidence/m2-struct-result-source-windows-20261028.json) records 219
rechecked inputs and the repair.

Direct record return calls are implemented at `c23e6e4`: an exact-nominal
`return make(...);` now shares argument evaluation and cleanup with other CALLs
and exits through SRET without another payload extent. Development and release
each passed 18 native groups and 505 CLI cases in separate core/regression phases;
196 matching input hashes and both CLI artifact hashes were rechecked. Earlier
receipts remain historical for their original inputs. See [the source
contract](../engineering/m2-struct-return-calls.md) for bounds and evidence.

[Direct nominal record constructor returns](../engineering/m2-struct-return-constructors.md)
are implemented at `0a7b539` and verified in development and release. A record-result
`return` that peeks `{` after its exact result type consumes the constructor
prefix through `record_values::constructor`. Fields and exact-nominal child
bindings or paths stage from left to right in declaration order. The compiler
creates one immutable anonymous function-owned site and `SINIT` only after all
field expressions and the terminator finish, so a nested return or loop transfer
cannot expose a pending owner or name. The shared reverse mixed finisher then
drops other visible arrays and records and emits `SRET`. Transfer adds no payload
extent, but construction requires the result extent; reconstructing a parameter
keeps the old formal and new result live until cleanup. No opcode, VM charge,
profile, or version field changes. General expressions, parenthesized constructor
returns, general aggregate arguments outside the exact-record-formal call position,
parenthesized child calls, and call-result
field selection remain unsupported. The [constructor child-call
successor](../engineering/m2-struct-child-calls.md) now accepts an exact-nominal
record call in a child field. The [child
call-assignment successor](../engineering/m2-struct-child-call-assignment.md)
now adds an exact-nominal child destination. Development and release each passed
26 native groups and 532
CLI cases through separate core/regression invocations. The [Windows
receipt](../evidence/m2-struct-return-constructors-windows-20261028.json) records
199 matching rechecked inputs and both retained CLI identities. Earlier receipts
remain historical for their original inputs.

The [constructor child-call slice](../engineering/m2-struct-child-calls.md)
stages each returned child's `SREAD`/`STORE` scalar leaves and emits `SDROP`
before later fields or parent `SINIT`/`SREPLACE`/`SSUBREPLACE`. Development and
release each passed 23 native groups and 529 CLI cases in four separate phase
invocations, with 211 verified input identities. A new parent
occupies no payload during the child call. An old replacement parent stays
visible and live until replacement or early-exit cleanup; argument effects are
not rolled back. No opcode, VM, Fuel, profile, or version change is involved.

The [subrecord return-path successor](../engineering/m2-struct-return-paths.md)
accepts a bare `return outer.child;` for an exact-nominal record result,
including deep paths. The shared extractor emits consecutive `SREAD` operations
into consecutive registers, allocates one anonymous immutable site, and emits one
`SINIT`; the source remains live through creation. The shared finisher then drops
other mixed arrays and records in reverse order before `SRET`. There is no
temporary owner or staging extent, and no opcode, Fuel charge, profile, or version
field changes. Development and release each passed 25 native groups and 579 CLI
cases in four separate phase invocations, with 205 identical inputs rechecked
across them. Development core ran before `d4aa643` with its implementation files
uncommitted; the other three phases ran after it. Earlier receipts remain
historical for their original inputs. Record borrows, general or parenthesized
expressions, and `call().child` returns remain unsupported.

Goal: connect arrays, plain structs, borrows, Buffer, input,
output, and UTF-8.

Record call-result assignment is implemented at `0a6a759`. An exact-nominal
`root = make(...);` keeps the mutable destination live, copies the returned value
into its existing owner, and releases the temporary result. The additional
result, captures and parameter copies still count toward peak quota use.
For-header aggregate writes remain unavailable. The [child call-assignment
successor](../engineering/m2-struct-child-call-assignment.md) now supports
exact-nominal child paths; development and release each passed 26 native groups
and 575 CLI cases.
Development and release each passed 30 native groups and 725 CLI cases in separate
core/regression phases; 202 matching input hashes and both CLI identities were rechecked.
See [the contract](../engineering/m2-struct-call-assignment.md) and
[focused receipt](../evidence/m2-struct-call-assignment-windows-20261028.json).

Required evidence includes source copy-initializer checks, complete record construction,
root conflict rejection, mutable views, returned borrows, Buffer growth and movement,
staged output, and chunked UTF-8 validation.

Exit condition: source end-to-end cases exercise normal and rejected paths without
using a Python model as the product runtime.

## M3: typed host suspension

Status: not started. Goal: run a fake in-memory host adapter with request and reply,
grants, timeouts,
pending state, and cancellation.

No live service credential or network call is needed. Tests cover malformed replies,
allocation failure before copy, late replies, duplicate replies, Engine poisoning,
and terminal snapshot stability.

## M4: restricted Windows worker

Status: not started. Goal: compile and run untrusted source inside an independently
tested worker.

Use actual Windows AppContainer and Job controls, private bounded IPC, a parent
broker, I/O leases, a publication barrier, and bounded cleanup. Preparation failure
must stop; it must not fall back to an unrestricted process.

Required negative cases include cancellation before late RESULT delivery, HOST_REQUEST
after cancellation, exit/EOF ordering, pending I/O completion, and output rejection.

## M5: embed and clean-machine delivery

Status: not started. Goal: expose the planned DLL ABI to a trusted native host and
verify packaging.

The milestone must prove actual symbol export and calls, public handle validation,
clean-machine execution without developer compilers, and full startup, allocation,
latency, and artifact measurements. The current Fairy pub path is not a public C export.

## First workload experiments

Before fixing performance targets, benchmark small data validation, byte transform,
and rule-evaluation workloads. Report reuse separately from cold compile, process
startup, host serialization, and build-cache cost.

Initial unmeasured targets are:

- reused small Instance setup p95 at or below 1 ms;
- 10 KiB pure compile plus verify p95 at or below 10 ms;
- empty Instance accounted memory at or below 32 KiB;
- zero heap allocation in a warm scalar loop;
- 100 retained edit builds at or below 32 MiB for project outputs.

These targets guide measurement; they are not current results or universal guarantees.

## Stop or revise

Narrow or stop a milestone if the native boundary cannot return failures without a
trap, a stale token can be dereferenced, quotas cannot be reserved before allocation,
cancellation can publish output, or the worker cannot be isolated on the actual OS.

Do not trade away these boundaries to meet a performance target or schedule.
