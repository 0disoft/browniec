# Roadmap

- Status: Accepted delivery sequence; M0 verified; named M1 slices through unsigned have verified historical receipts; explicit widening historically verified; integer operators historically verified; switch-arm statements implemented and verified, 2026-10-23; private entry-array IR/VM verified by its native harness, 2026-10-24; source-array reads, writes, copy initializers, parameters, results, and assignment forms implemented; in-place repeated-literal assignment verified; private scalar struct layout and storage implemented and verified; private scalar struct copy/assignment implemented and verified; private nested struct storage implemented and verified; private nested struct copy/assignment implemented and verified; shared struct-owner foundation implemented and verified; private struct-owner copy/assignment implemented and verified; private entry-owned struct IR/verifier verified historically; private struct VM implemented and verified, native 38/38 and CLI 115 in both profiles; declaration-only source structs historically verified stepwise in development and release (23 native groups and 2,208 CLI cases per profile); bounded entry scalar-field construction and reads are a verified historical read baseline; entry-only one-level scalar-field writes have historical focused development/release validation; entry-only scalar-record copy initialization and whole-record assignment are verified stepwise in development and release; bounded nested constructors, multi-segment scalar paths, and whole-root nested copies are implemented with verified development/release results; the earlier development pass and release failure are historical for pre-correction inputs
- Current progress: M1 scalar checkpoint verified; M2 function-owned scalar arrays cover lexical storage, copy, length, helper locals, by-value parameters, source results, direct returns, repeated return literals, call-result assignment, and in-place repeated-literal assignment; private scalar struct layout, storage, and copy/assignment exist; private nested struct storage is verified; private nested struct copy/assignment is verified; shared struct-owner foundation is verified; private struct-owner copy/assignment is verified; private entry-owned struct IR and metered VM execution exist; declaration-only source struct layouts are historical verified evidence; bounded entry scalar-field construction and one-level reads are the historical verified read baseline; entry-only one-level field writes are supported with historical verification, and bare-name record copies plus whole-record assignment are verified stepwise in development and release; bounded nested constructors, multi-segment scalar paths, and whole-root copies have verified development/release results; subrecord values, parameters/results, borrows, Buffer, and text remain open; full-profile conformance incomplete; M3-M5 not started

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
inputs. The [private struct VM](../engineering/m2-struct-vm.md) now executes
opcodes 41..46 with fixed prepaid Fuel, sixteen entry tokens, and the shared array
owner table and payload arena. Development and release each passed all 38 native
groups and the existing 115-case CLI suite for that private VM slice. A
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
and existing Fuel. Subrecord values, struct parameters/results, and borrows remain
unsupported; nested type declarations remain accepted and are handled by the
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
record statements in `for` initializer/post clauses remain rejected, while
constructor RHS assignment, aggregate expressions, subrecord values and copies,
struct parameters/results, and borrows remain unsupported. Nested constructors and
scalar paths are handled by the successor below. Nonempty record
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
source/tool hashes, artifacts, commands and the corrected release regression.

Goal: connect arrays, plain structs, borrows, Buffer, input,
output, and UTF-8.

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
