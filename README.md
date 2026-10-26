# Brownie C

- Status: M1 scalar checkpoint verified; M2 function-owned scalar arrays with helper declarations, by-value parameters, argument capture, copies, length access, lexical cleanup, source results, and bare-name, call-result, and repeated-literal assignment implemented; private entry-owned struct IR/verifier and metered VM dispatch implemented; declaration-only source struct layouts are historical verified evidence; bounded entry scalar-field construction and reads remain a verified historical read baseline; entry-only one-level scalar-field writes implemented with historical focused development/release validation; entry-only scalar-record copy initialization and whole-record assignment implemented and verified stepwise in development and release; bounded entry nested constructors, multi-segment scalar paths, and whole-root nested copies implemented with verified development/release results; full profile incomplete
- Design date: 2026-10-23
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

The native `browniec` compiles and runs the experimental scalar and source-array
pipelines, and the private VM executes entry-only struct instructions. The bool/branch increment extends its i32 functions with bool parameters,
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
assignment; record lifetimes use bits 16..31 beside array lifetimes. The
[private struct VM](docs/engineering/m2-struct-vm.md) executes those private
instructions with fixed prepaid Fuel charges, sixteen entry tokens, and the shared
array owner table and payload arena. Development and release each passed all 38
selected native groups and the existing 115-case CLI suite. A
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
[historical receipt](docs/evidence/m2-struct-values-windows-20261026.json). Nested
construction, field chains, struct parameters/results, and borrows remain
unsupported. A
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
inputs, artifacts, commands and the corrected release regression. Implementation
commits: `576d062` and `716c14b`.
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
| core | Source compile, verify, and native VM CLI | Experimental i32/i64/u8/u32/usize/bool expressions, explicit widening, branches, loops, shallow tagged values, switch statements and expressions, `?` propagation, source arrays, declaration-only source struct layouts, private entry-only struct IR execution, bounded entry scalar-field construction/read/write lowering, bare-name record copy initialization/whole-record assignment, and bounded nested constructors/scalar paths/whole-root copies with verified development/release results; scalar M1 and array reads verified, focused array and struct VM checks recorded, the struct construction/read and field-write baselines recorded historically, and source-copy checks verified stepwise in development and release |
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
- [M2 private struct VM](docs/engineering/m2-struct-vm.md): shared owners and payload, private execution semantics, fixed Fuel charges, and current check status
- [M2 declaration-only source structs](docs/engineering/m2-struct-source.md): historical bounded parser, forward named fields, immutable layouts, name rules, and stepwise verification
- [M2 bounded source struct values](docs/engineering/m2-struct-values.md): historical entry construction and one-level reads, ordered typed staging, `SINIT`/scalar-leaf access, mixed cleanup, bounds, and recorded verification
- [M2 source struct field writes](docs/engineering/m2-struct-write.md): entry-only one-level `SWRITE`, target-before-RHS resolution, single typed evaluation, for-header rejection, profiles, and recorded verification
- [M2 source struct copy initialization and assignment](docs/engineering/m2-struct-source-copy.md): exact-name `SCOPY`/`SASSIGN` lowering, independent copies, mutable destination reuse, lifetimes, profiles, and stepwise development/release verification
- [M2 source nested structs](docs/engineering/m2-struct-source-nested.md): inline child constructors, depth-first scalar paths, whole-root copies, iterative traversal, limits, profiles, and recorded development/release verification
- [Product specification](docs/product/02-spec.md): observable first-profile behavior
- [Roadmap](docs/product/01-roadmap.md): M0 through M5 delivery gates
- [Design baseline](docs/design-baseline.md): source provenance, evidence, and findings

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
