# Validation

- Status: accepted evidence policy; M0 verified; bool/branch, loop, tagged, `?`, switch-expression, i64, and unsigned receipts are verified historical evidence; explicit widening historically verified; integer operators historically verified; switch-arm statements implemented and verified; private entry-array IR/VM and source-array reads/writes/copy initializers implemented and focused-harness verified
- Current implementation: M0 primitives and experimental M1 scalar source CLI/VM with i32/i64/u8/u32/usize/bool values, explicit widening, branches, loops, shallow Option/Result, switch statements and expressions, and scalar `?` propagation; private function-owned array IR/native dispatch with separate recursive frame tokens, let/var scalar arrays in lexical scopes of ordinary functions, indexed reads/writes, copy initializers, length access, lexical cleanup including `?` failure, and whole-array assignment are implemented

## Validation source of truth

This file defines evidence expectations for Brownie C. `tools/verify-m0.ps1` verifies
the native M0 primitives. `tools/verify-m1.ps1` builds and verifies the experimental
scalar `browniec` CLI, native compiler/verifier/VM, and black-box source cases.

Do not report a proposed command as executed. Do not treat a design package, static
link check, Python model, or source fixture as proof of the Brownie VM.

## Evidence levels

| Level | What it can establish |
| --- | --- |
| Document check | Links, required sections, terminology, and status consistency |
| Independent model | Small expected examples for layout, quota, ordering, or codec rules |
| Native unit probe | A shim or VM primitive behaves under recorded inputs |
| Source end-to-end | .brc source compiles, verifies, runs, and publishes as specified |
| OS integration | Actual Windows isolation, cancellation, IPC, and cleanup behavior |
| Performance measurement | A named workload meets or misses a measured budget |

Higher-level behavior requires its own evidence. A passing lower level is useful
context, never automatic acceptance of the next level.

## Current documentation checks

No link checker or Markdown linter is configured. A reviewer may run
git diff --check for whitespace and patch integrity. Markdown links and status
language should be checked without claiming a product test.

Historical design-package note: the external package reported 746 passing design
checks on Windows with Python 3.14.6. C/C++ header syntax and layout checks were
skipped because cc and c++
were unavailable. That result is design-package evidence only.

The package contains 29 .brc examples and 32 acceptance cases recorded as not
executed. None proves parser, compiler, verifier, VM, allocator, ABI, or sandbox behavior.

## Toolchain provisioning

`python -B tools/verify-toolchain.py` passed 11 Windows native provisioning cases on
Python 3.14.6. The [receipt](docs/evidence/toolchain-portable-windows-20261025.json)
covers executable import and reuse, corrupt input and cache rejection before execution,
compiler/SDK-lock rejection, exact-revision source reproduction, unavailable-source
preservation, Windows/Linux host-selection logic, unsupported-host rejection, and
sanitized child environment without parent mutation. Direct Python setup and the
PowerShell wrapper also passed existing-cache reuse.

Static manifest and `fairy.lock` checks run before cache or receipt initialization;
later fetch, build, SHA-256, or compiler-identity failures preserve an existing valid
compiler and remove owned scratch. The Windows compiler retains SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.
The [Linux cross-build](docs/evidence/toolchain-linux-cross-build-20261025.json)
passed a repeat build and owned-source cleanup with Go 1.27.1, `GOOS=linux`,
`GOARCH=amd64`, `CGO_ENABLED=0`, the reviewed revision, and trimpath flags. Its
SHA-256 is `5c9e50e6b6ea45060a1b1511ab4b7c11fb9d6cc3939f65337970a6dfdc417b9b`;
ELF64/x86-64 and Go metadata were checked. No Linux compiler process was executed:
the WSL availability probe did not complete and was cancelled. No usable Linux
runtime was established for this session. Linux
setup, import, Brownie CLI build/runtime, and full harness portability remain
`UNVERIFIED`.

Full VM development/release regression was not repeated because the VM source, SDK,
and Windows compiler hash were unchanged. The previous
[2026-10-24 Windows receipt](docs/evidence/toolchain-windows-20261024.json) remains
historical evidence from the earlier PowerShell setup path. Authenticated HTTPS
acquisition, empty module-cache downloads, clean-machine installation, and automatic
update discovery remain unverified or outside this scope.

## Required milestone evidence

M0 has recorded native primitive evidence for:

- fallible storage and rollback;
- signed little-endian codec including i64 MIN and MAX;
- checked arithmetic including i64 MIN/MAX edge cases;
- generation reuse rejection without pointer dereference;
- runtime status return instead of a Fairy native trap;
- a one-shot real-target allocator failure with no leaked target heap allocation;
- typed owner rejection before payload access, including stale and retired tokens;
- scalar array frame copies and exclusive view updates.

The expanded run passed six native executions: development and release normal
baselines, development and release instrumented normal runs, and development and
release instrumented allocator-failure runs plus leak checks. It also produced the four exact
negative compiler diagnostics:

| Fixture | Diagnostic |
| --- | --- |
| use after move | `E1101` |
| grow with a live shared view | `E2101` |
| escape a local view | `E2102` |
| exclusive alias | `E2101` |

The run used Fairy source `4ce1264273be6051ee560173e94690e1b99c9eaf`, SDK
`0.0.0-stage0.86`, language `fairyc-language/20`, MSVC tools `14.51.36231`, `cl`
`19.51.36248.0`, Windows SDK `10.0.26100.0`, and Go `1.27.1`. The compiler build
identity is SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.
Exact transcript and artifact details belong to `build/m0/receipt.json` and
`docs/evidence/m0-windows-20261023.json`.

The [M1 requirements audit](docs/engineering/m1-checkpoint-audit.md) closes the
bounded scalar checkpoint by checking the identities of existing executed evidence.
Full-profile conformance remains incomplete. M2 has private scalar-array layout,
codec, caller-backed storage, owner/copy primitives, and entry-only array IR/VM.
Whole-array reassignment, aggregate guest calls, and borrow integration remain open. M3
through M5 remain not started.
M0's empty runtime-`PATH` execution does not
establish clean-machine packaging or Windows isolation.

M1 has scalar expressions, initialized locals, direct functions, and bool/branch,
loop, and shallow tagged slices implemented and historically verified. The
propagation slice is historically verified for the same one-level scalar wrappers.
The bool/branch slice adds canonical bool
values without integer conversion, typed operator rules, short-circuit `&&` and
`||`, if/else chains, standalone lexical blocks, early returns, forward-only jumps,
and definite initialization across CFG joins. It keeps `var` storage and
short-circuit result slots in the same bounded 128-cell global register file and
charges Fuel for executed `LOAD`, `STORE`, and branch instructions.

The loop slice adds `while`, classic `for`, optional header clauses, conservative
header purity, `break`/`continue`, per-iteration lexical reinitialization, and
metered forward-only branch plus backward-edge control flow. For return-completeness
checking, the compiler conservatively treats every loop as possibly zero-trip,
including a literal-true or omitted condition, so a following function return
remains required. The verifier checks backedge initialization conservatively from
the forward graph; it does not claim a termination proof.

The tagged slice adds one-level `Option<i32|bool>` and
`Result<i32|bool, i32|bool>` values, context-required constructors, exhaustive
`switch` statements with immutable scalar bindings, one i64 cell per wrapper, and
`MAKE`/`CASE`/`MATCH_FAIL` verification. It excludes nested wrappers. Its historical
contract covers switch statements; the later switch-expression increment owns
expression-position arms.

The propagation slice adds postfix `?` to expressions in functions returning
`Option<T>` or `Result<T, E>`. It evaluates the operand once, yields the
some/ok scalar payload on success, and returns the enclosing `.none` or `.err`
on failure. Option success types may differ; Result success types may differ while
the error type must match exactly. Families cannot mix, scalar-returning functions
including `main` reject `?`, and classic `for` headers remain pure scalar.
Postfix binding is tighter than unary and binary operators. Untaken paths skip
propagation, and an evaluated failure skips remaining expression, argument, loop,
and post work. Lowering uses existing CASE, JUMP, MAKE, RETURN, and MATCH_FAIL
instructions: a success costs two Fuel and a failure four, excluding operand and
outer use.

The [tagged receipt](docs/evidence/m1-tagged-windows-20261023.json) is historical
and records 33
native groups and 423 black-box CLI cases for both development and
release, together with toolchain, source, artifact, and harness identities. Coverage
includes constructor context, wrapper copy and call behavior, depth-one rejection,
switch exhaustiveness and arm order, `_` bindings, subject-once evaluation, terminal
joins, exact CASE initialization, wrapper type/variant corruption, internal
`MATCH_FAIL`, tag packing edges, Fuel, and prior scalar/branch/loop regressions.

The [tagged contract](docs/engineering/m1-tagged.md) owns the detailed wrapper and
switch-statement rules. The [propagation contract](docs/engineering/m1-propagation.md)
owns `?` typing, placement, lowering, and Fuel. The [switch-expression contract](docs/engineering/m1-switch-expressions.md)
adds expression-position exhaustive arms, restricted local declarations and
assignments, typed value joins, and direct-return arms. It admits one final
expression without a semicolon or `return EXPR;` in an enclosing function, at least
one yielding arm, and one exact result type across yielding arms. A single typed
join slot is loaded only after a value arm's forward jump; direct-return arms do
not join. The existing verifier proves that slot is initialized before its shared
`LOAD`, and the final variant mismatch targets `MATCH_FAIL`. No VM opcode is added.
Switch-expression arm nesting consumes two expression-depth levels per arm and one
for its subject; 16 nested switches are admitted and 17 are rejected. Classic `for`
headers reject switch expressions. Executed instructions use the existing Fuel
schedule; the compact non-propagating switch example costs 7 Fuel and fails at 6.
The switch expression creates no guest heap allocation and makes no performance claim.

The i64 slice adds scalar tag 9 at the existing local, function, argument, return,
assignment, loop, and switch-join positions. Unsuffixed decimals default to i32;
typed context or an already typed left integer operand admits i64, with no implicit
conversion or suffix. This left-to-right rule admits `n64 + 1` and `n64 == 1` but
rejects context-free `1 == n64`. That increment used negative accumulation and a sentinel to admit i64 MIN and
MAX without signed overflow; the unsigned increment replaces this scanner with
checked full-width unsigned accumulation. Arithmetic and comparisons use existing opcodes and i64 cells;
overflow, zero divisor, and MIN divided or remaindered by -1 become guest outcomes.
Wrappers remain one-level i32/bool payloads, and i64-returning functions reject
`?`. `main` remains a zero-argument i32 function, so `return_i32` and the
`brownie.m1-scalar/1` CLI profile are unchanged.

The unsigned slice adds `u8` tag 10, `u32` tag 11, and 64-bit guest `usize` tag 12
at the same source positions. The types remain distinct, even when a value fits
both `u32` and `usize`. Unsuffixed decimals still default to i32; typed context
admits unsigned literals without lookahead inference or implicit promotion. There
are no suffixes, and unary minus is forbidden for unsigned values, including `-0`.
Same-type arithmetic is
checked to the operand type's full unsigned range. Underflow and overflow produce
the guest `overflow` error, and a zero divisor produces `zero_divisor`. Unsigned
ordering decodes the stored cell as unsigned. Existing i64 constants and register
cells retain reversible packing that stores the upper half as negative bit
patterns, using checked conversions split at 2^63. The unsigned increment added no
opcode or guest heap allocation and kept the existing frame, cap, and Fuel policy.
Wrappers remain i32/bool payloads,
and unsigned-returning functions reject `?`.

The widening slice adds `EXPR as TYPE` with postfix `?`, then unary, then `as`,
then binary precedence. Casts associate left to right. Only seven domain-preserving
pairs are admitted: `u8` to `i32`, `i64`, `u32`, or `usize`; `u32` to `i64` or
`usize`; and `i32` to `i64`. Identity casts, narrowing, signed-to-unsigned,
`usize` to `i64`, bool/integer, and wrapper or aggregate casts are rejected
regardless of the current value. There is no implicit conversion or promotion.
The cast source receives no type from the target or surrounding context, so `1 as
i64` starts from an i32 source and works, while `1 as u8` and `2147483648 as i64`
are rejected.

Opcode 26, `WIDEN`, names a new destination value register whose type metadata
holds the target tag, the source register index in operand A, and zero in operand B
and all reserved bytes. Compiler and verifier
enforce the same seven-pair table. The verifier requires a readable initialized
non-slot source in the same function, a unique destination, and the existing CFG
rules. The VM copies the encoded i64 cell exactly; all seven source domains fit that
cell. Each executed cast costs one Fuel, including every step of a chain. Each cast
uses one instruction and one new value register, without guest heap allocation or
frame growth. Existing caps are unchanged. `let u8 b = 42; return b as i32;` costs
3 Fuel and fails at 2.

Casts are admitted in the existing scalar positions, including constructor payloads
whose final payload is i32/bool. `x? as i64` propagates first. Classic `for` headers
may widen but still reject calls, `?`, and switch expressions. Wrappers remain
i32/bool only, with no automatic payload mapping. The CLI profile and `return_i32`
JSON field are unchanged.

The [unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json) records
59 native groups and 1,159 CLI cases in both development and release: 760 prior
cases plus 399 unsigned cases. The total includes two codec native groups and
eight unsigned scalar native groups. It remains historical after explicit widening.
The [widening receipt](docs/evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each development and release profile:
1,159 prior cases plus 113 widening cases and eight additional native groups.
Both profiles used identical fixtures; all 54 frozen verification inputs remained
unchanged. The receipt records source commit `8acc675`, artifact hashes, compiler
identity, and the widening example's result of 42.

The [integer-operator contract](docs/engineering/m1-integer-operators.md) adds
fixed-width integer bitwise operations and checked shifts. The
[receipt](docs/evidence/m1-integer-operators-windows-20261023.json) records
75 native groups and 1,898 CLI cases in each development and release profile,
including eight new native groups, 292 bitwise cases, and 334 shift cases. Both
profiles used identical fixtures; all 78 frozen verification inputs are unchanged.
Source commits are `dcb6de2` and `80c7e18`. Coverage includes signed and unsigned
pattern edges, invalid counts, checked left-shift overflow, arithmetic negative
right shifts, exact types, precedence, eager evaluation, first error, IR corruption,
and exact Fuel boundaries. These operations add no guest heap or frame growth.

The widening receipt is historical after integer operators. The
[arm-statement contract](docs/engineering/m1-switch-arm-statements.md) adds blocks,
branches, loops, and lexical transfers within expression arms. Its
[receipt](docs/evidence/m1-switch-arm-statements-windows-20261023.json) records
81 native groups and 1,969 CLI cases in each development and release profile,
including six new native groups and 71 new cases. Both profiles used identical
fixtures; all 81 frozen inputs remained unchanged. Source commits are `ea2b915`
and `aa131b6`. The integer-operator receipt is now historical. Coverage includes typed
value joins, terminal and partial-return paths, nearest-loop ownership, for-post
ordering, while-condition transfers, skipped operands/arguments, propagation,
scope rejection, inherited independent depth budgets, Fuel, and corrupt join stores.

The switch-expression and i64 receipts are historical after the unsigned increment.
The switch-expression receipt records 41 native groups and 580 CLI cases in each
verified profile. The [i64 receipt](docs/evidence/m1-i64-windows-20261023.json)
records 49 native groups and 760 CLI cases in each profile. The propagation receipt
remains historical at 37 native groups and 510 CLI cases. The unsigned receipt
remains historical for its 59/1,159 subset.
The [loop receipt](docs/evidence/m1-loops-windows-20261023.json) is
historical for its 26-group/332-case slice; the [branch receipt](docs/evidence/m1-branches-windows-20261023.json)
is historical for 20/248, and the [function receipt](docs/evidence/m1-functions-windows-20261023.json)
and earlier locals/expression receipts are likewise historical for their narrower
slices. The arm-statement increment expands the scalar checkpoint; full-profile
conformance remains unverified. Full array integration, structs, and borrows remain M2 work.
Workers, DLL ABI, Windows isolation, and performance remain unverified. M0 was not
rerun for unchanged inputs. No new CI job or performance measurement was added.
M2 must cover arrays, structs, borrows, Buffer, input, output, and UTF-8.
The [M2 layout foundation](docs/engineering/m2-array-layout.md) has a separate
focused native harness and [receipt](docs/evidence/m2-array-layout-windows-20261023.json).
Its six groups per profile test compact scalar layouts, corrupt metadata,
overflow-safe alignment/size planning, arena quota ceilings, and checked offsets.
These are primitive tests only, not source-array or allocator evidence. Scalar M1
execution code is unchanged; its prior receipt remains the recorded runtime evidence.
The successor [M2 storage slice](docs/engineering/m2-array-storage.md) adds four
scalar-codec and five caller-backed-storage native groups per profile, recorded
in its own [receipt](docs/evidence/m2-array-storage-windows-20261023.json). This
tests real byte initialization and access without source-array or VM integration.
Allocator failure, owner generations, frame cleanup and aggregate Fuel remain open.
The [owner-lifetime slice](docs/engineering/m2-array-owners.md) adds five native
groups per profile with its own [receipt](docs/evidence/m2-array-owners-windows-20261023.json).
That later evidence covers Instance-local token generation/reuse, retirement,
typed descriptor lookup, bounded suffix reclamation and whole-table clear.
Backing ownership, source borrows, frame cleanup and aggregate Fuel remain open.
The [copy receipt](docs/evidence/m2-array-copy-windows-20261023.json) records four
additional native groups per profile for independent scalar-array values,
old-plus-new payload quota preflight, complete bool validation, rejected-copy
state preservation and survival after source release. Owner tests remain the
historical five-group receipt; only the new copy function changes that module.
The [array-IR contract](docs/engineering/m2-array-ir.md) adds five native verifier
groups and reruns 11 branch/loop groups in each profile. Its
[receipt](docs/evidence/m2-array-ir-windows-20261024.json) covers exact lifetime sets
at joins/backedges, scalar operand types, mutability and entry-only array access.
That receipt is historical after the [array-VM increment](docs/engineering/m2-array-vm.md).
Its [VM receipt](docs/evidence/m2-array-vm-windows-20261024.json) records 12 native
groups per profile (five IR, six VM, one allocation) and four instrumented allocator
executions. The forced allocation request is exactly 320 bytes. The fresh
scalar regression passed 81 native groups and 1,969 CLI cases per profile
after the shared VM change. Array dispatch/Fuel and allocator-NULL containment
are implemented. This VM receipt is historical after the source compiler change.

The [source-array contract](docs/engineering/m2-array-source.md) adds immutable
scalar arrays and exact `usize` indexed reads in outermost `main`. The
[source receipt](docs/evidence/m2-array-source-windows-20261024.json) records
18 native groups and 67 CLI cases per profile in development and release.
Coverage includes six scalar element types, scope/type rejection, early-return
cleanup, nested reads and loops, bounds, quota, and exact Fuel boundaries.
The subsequent full scalar regression passed 81 native groups and 1,969 CLI
cases in each development and release profile, recorded in the same source
receipt. All recorded source inputs, native artifacts, CLI receipts, and the
pinned compiler identity were rechecked. Dedicated instrumented allocator runs
were not repeated here; their earlier array-VM receipt remains historical.
M0 was reused after verifying all 18 recorded inputs and the compiler unchanged.
Linux execution, isolation, DLL delivery, and performance remain unverified.
Whole-array reassignment, aggregate guest calls, and borrow integration remain open.
The [source-write contract](docs/engineering/m2-array-write.md) adds mutable
arrays and indexed assignment through the existing AWRITE instruction. Its
[receipt](docs/evidence/m2-array-write-windows-20261024.json) records nine native
groups, 67 read CLI cases, and 61 write CLI cases per profile in development and
release. The read receipt above is now historical. Scalar CLI regression passed
all 1,969 cases per profile against the same verified binaries. The 81-group
scalar native rerun and private IR/VM native reruns are
skipped for this frontend slice; the recorded backend/verifier and fixture inputs
are unchanged. M0 inputs and compiler are also unchanged. Dedicated allocator
instrumentation, Linux, isolation, DLL, and performance checks were not repeated.

The [copy-initializer contract](docs/engineering/m2-array-copy-source.md) adds
new array bindings copied from a bare visible array of exactly matching type and
length, preserving the source with independent bytes. Its
[receipt](docs/evidence/m2-array-copy-source-windows-20261025.json) records
12 native groups, 67 read CLI cases, 61 write CLI cases, and 58 copy CLI cases per
profile in development and release. The earlier write receipt is now historical.
Scalar CLI regression passed all 1,969 cases per profile against those same
verified binaries. Backend/verifier and private IR/VM fixture
inputs are unchanged, as are the M0 inputs and compiler. Their native reruns and
the full 81-group scalar native rerun were skipped. No allocator instrumentation,
Linux, isolation, DLL, clean-machine, or performance check was added.

The [length contract](docs/engineering/m2-array-length.md) adds `NAME.len` as an
exact `usize` scalar constant without changing the VM or verifier. Its
[receipt](docs/evidence/m2-array-length-windows-20261025.json) records 15 native
groups, 226 array CLI cases (67 reads, 61 writes, 58 copies, 40 lengths), and
1,969 scalar CLI cases per profile in development and release. The current
backend inputs match the verifier-bitset receipt; earlier source receipts remain
historical. The full 84-group scalar native suite, dedicated allocator
instrumentation, Linux, isolation, DLL, and performance checks were skipped.

The [lexical-array contract](docs/engineering/m2-array-scopes.md) admits declarations
in nested `main` scopes with reverse cleanup on normal exits, arm yields, loop
transfers, and returns. The [scope receipt](docs/evidence/m2-array-scopes-windows-20261025.json)
records 19 native groups, 270 array CLI cases, and 1,969 scalar CLI cases per
development/release profile, including four new native groups and 44 scope CLI
cases. Native four-byte arena tests exercise 42 repeated array lifetimes;
malformed IR without cleanup is rejected independently. The VM/backend inputs
are unchanged from the length receipt, while compiler loop metadata changes.
The full 84-group scalar native suite, dedicated allocator instrumentation,
Linux, isolation, DLL, and performance checks are skipped.

The [whole-array assignment contract](docs/engineering/m2-array-assignment.md)
adds private `AASSIGN` opcode 38 and exact-shape mutable array assignment without
another payload reservation. The [receipt](docs/evidence/m2-array-assignment-windows-20261025.json)
records 16 native groups, 329 array CLI cases, and 1,969 scalar CLI cases per
development/release profile. Checks cover unchanged destination bytes on failed
bool/type/length/token preflight, full storage/owner capacity, self-assignment,
exact Fuel, and independent IR rejection at the assignment instruction. Changed
owner, IR, verifier, and array-dispatch inputs receive fresh checks; scalar VM,
codec, layout, and M0 inputs are compared with the prior receipts. The full scalar
native suite, M0 rerun, allocator instrumentation, Linux, isolation, DLL, and
performance checks are skipped.

The [private array-frame foundation](docs/engineering/m2-array-frames.md) adds
function-owned catalog metadata and separate tokens for recursive VM frames.
The [frame receipt](docs/evidence/m2-array-frames-windows-20261025.json) records
24 native groups, 329 array CLI cases, and 1,969 scalar CLI cases per
development/release profile. It covers recursive parent preservation, shared
owner/payload quotas, frame 31 with catalog ID 15, exact Fuel, and helper cleanup
rejection. Changed IR/verifier/VM and array IR fixture inputs receive fresh checks;
prior receipts remain historical for those inputs. Source arrays remain entry-only.
The full 84-group scalar native suite, M0 rerun, allocator instrumentation, Linux,
isolation, DLL, and performance measurements are skipped.

The [helper-local contract](docs/engineering/m2-array-helpers.md) extends source
arrays to scalar and shallow wrapper-returning functions and cleans visible
arrays on `?` failure returns. The
[helper receipt](docs/evidence/m2-array-helpers-windows-20261025.json) records
16 native groups (six helper, six read-source, four scalar propagation),
426 array CLI cases, and 1,969 scalar CLI cases per development/release profile.
It covers all element and shallow wrapper types, recursive/mutual calls, shared
quotas, incomplete initializers, pending writes, and independent rejection of
missing failure cleanup. IR/verifier/VM and primitive sources match the prior
frame inputs; changed compiler/local-table/array-source/propagation inputs
receive fresh source checks. The full 84-group scalar native suite, M0/private
array unit reruns, allocator instrumentation, Linux, isolation, DLL, and
performance checks are skipped.

The [array signature foundation](docs/engineering/m2-array-signatures.md) records
element and length metadata for parameter declarations while explicitly rejecting
their compilation before any body lowering. Its focused command is
`pwsh -NoProfile -File tools/verify-m2-array-signatures.ps1`; this is not array
call, copy-transaction, verifier, or recursive parameter execution evidence. The
[signature receipt](docs/evidence/m2-array-signatures-windows-20261025.json)
records 16 native groups and 2,133 CLI cases per development/release profile
(1,969 scalar, 67 array-read, 97 helper-local). IR/verifier/VM hashes match the
previous helper inputs. Other native suites, allocator instrumentation, Linux,
isolation, DLL, and performance checks are skipped for this metadata slice.

The [atomic argument-copy foundation](docs/engineering/m2-array-arguments.md)
preflights the entire copy batch before changing bytes or owner state. Its focused
command is `pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice arguments`.
It does not establish source argument capture, immutable parameters, call-shape
verification, VM Fuel accounting, or recursive parameter execution.
The [argument-copy receipt](docs/evidence/m2-array-arguments-windows-20261025.json)
records 18 native groups per development/release profile: seven batch-copy,
five owner, four single-copy, and two assignment-storage groups. Failed late
arguments preserve every byte and owner field. Cases cover exact combined peaks,
alignment, retired slots, deferred holes, stale/provisional tokens, all scalar
elements, and eight independent copies. CLI and other native suites, allocator
instrumentation, Linux, isolation, DLL, and performance checks are skipped; all
29 source inputs outside `array_owners.fy` match the prior signature receipt.

The [private array-call contract](docs/engineering/m2-array-calls.md) connects
exact-shape immutable argument snapshots to distinct callee owners through the
atomic batch-copy helper. It adds independent parameter/call metadata checks,
frame-specific bindings and prepaid Fuel. The focused command is
`pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice calls`. That checkpoint
retained the source gate; the subsequent source-parameter increment removes it.
The [call receipt](docs/evidence/m2-array-calls-windows-20261025.json) records
29 native groups and 2,395 CLI cases (426 array, 1,969 scalar) per development/
release profile. Fresh checks cover nine private call groups, four function,
five array IR, six array VM and five recursive-frame groups. It includes exact
670/669 Fuel, eight array arguments, 24 sequential calls, recursive frame
preservation, combined quota failures, and no partial token publication.
Changed IR/verifier/VM inputs receive fresh execution; 25 other source hashes
match the prior argument-copy receipt. The full scalar and other private-array/
M0 native suites, allocator instrumentation, Linux, isolation, DLL,
clean-machine packaging, and performance measurements are skipped.

The [source array-parameter contract](docs/engineering/m2-array-parameters.md)
removes the source gate and connects exact-shape names to immutable callee
parameters. The focused command is
`pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice parameters`. Mutable
arguments are captured before later argument effects; anonymous lexical entries
carry normal, nested-call, return, propagation, and loop-transfer cleanup.
The [parameter receipt](docs/evidence/m2-array-parameters-windows-20261025.json)
records 28 native groups and 2,475 CLI cases per development/release profile
(426 existing array, 80 parameter, 1,969 scalar). The native selections passed;
completed outputs were retained while a CLI fixture name collision was corrected.
The affected CLI matrix and all remaining steps passed individually. The aggregate
harness was not rerun after that correction and the final receipt-guard tightening.
Both artifact hashes, all 18 CLI receipt hashes and generated fixture hashes were
validated. Thirty unchanged backend source inputs match the private call receipt;
this is historical-input comparison rather than a rerun of those native suites.
The full scalar and other private-array/M0 native suites, allocator instrumentation,
Linux execution, isolation, DLL, clean-machine packaging, and performance checks
remain skipped for this slice.

The historical [array result signature foundation](docs/engineering/m2-array-result-signatures.md)
records exact scalar-array return shapes in 16 bounded slots. At that checkpoint,
compilation rejected all array results with `type` at the function name before
creating IR or lowering any parameter catalog/body; even unused helpers were gated. This is not result
copy, ownership, verifier, VM, or source return execution evidence.
The [result-signature receipt](docs/evidence/m2-array-result-signatures-windows-20261025.json)
records 16 native groups and 2,242 CLI cases per development/release profile:
six new result-signature, six parameter-signature and four scalar-function groups;
96 result-signature, 80 parameter, 97 helper-local and 1,969 scalar CLI cases.
All eight CLI receipt hashes, generated fixture hashes, binary identities and
current inputs were checked after execution. Thirty-one unchanged backend hashes
match the parameter receipt, and the standard-library lock entry is unchanged.
The prior parameter receipt is historical for the changed frontend/signature/CLI
inputs. Full scalar/private-array native suites, other array CLI matrices, M0,
allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and
performance remain skipped. Checks were completed as individual recorded steps.

The [private array-result increment](docs/engineering/m2-array-results.md) adds
independent result shape/lifetime verification and native owner transfer. Private
ARET (39) requires the callee's sole live array; an array CALL defines an empty
exact-shape caller destination. All checks and Fuel admission precede the two
token assignments. Return performs no allocation, reservation or payload copy.
The [result receipt](docs/evidence/m2-array-results-windows-20261025.json) records
43 native groups and 2,571 CLI cases per development/release profile. Development
combines 41 plus two disjoint edge groups; release checks the same 43 identities
together. CLI cases are 426 existing array, 80 parameter, 96 result-signature,
and 1,969 scalar. Native cases cover all element types, maximum lengths, 32 frames,
24-call reuse, exact Fuel, original-argument independence, deferred holes, and
unchanged tokens/owners/bytes on malformed return preflight. The current input,
binary, CLI receipt, and generated fixture hashes are rechecked after execution.
Source results were gated at that checkpoint. Full scalar/other private-array and M0 native suites,
allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and
performance checks are skipped. Twenty-nine earlier source hashes match the
signature receipt, while changed runtime inputs receive fresh native evidence.
The aggregate results slice was added and syntax-checked; executed commands were
the individual native/build/CLI steps, without a redundant aggregate rerun.

The [source result increment](docs/engineering/m2-array-result-source.md) connects
named exact-shape returns and let/var call-result initializers to verified owner
transfer. Other visible arrays/captures are dropped before ARET; pending result
names stay invisible during argument evaluation and early exits. The
[source receipt](docs/evidence/m2-array-result-source-windows-20261025.json) records
26 native groups and 2,690 CLI cases per profile: 119 new result, 96 signature,
80 parameter, 426 existing array and 1,969 scalar cases. Development combines
18 passing unchanged groups from the first selection with eight passing updated
source-result groups after correcting a mutual-call fixture; release selects all
26 identities together. Exact Fuel, 16-site/16-owner/32-frame limits and the 64KiB
arena have source-level evidence. Unchanged runtime hashes are compared with the
private-result receipt. Aggregate tooling is syntax-checked, not invoked. Full
scalar/private-array native suites, M0, allocator instrumentation, Linux, isolation,
DLL, clean-machine packaging and performance remain skipped. Direct return calls,
aggregate scalar expressions, result assignment RHS and for headers remain unsupported.

M3 must use a fake in-memory typed host adapter without live keys or network services.
M4 requires real Windows AppContainer, Job, bounded IPC, I/O leases, and the broker
publication barrier. Compile untrusted source only inside the restricted worker.
M5 requires actual DLL export/call, clean-machine packaging, and full metrics.

## Review obligations

Three reviewed counterexamples must remain explicit acceptance tests:

1. Before cancellation, broker messages must obey the protocol phase. Reject the
   illegal sequence RESULT, HOST_REQUEST, exit 0, EOF. After cancellation, only
   bounded legitimate late messages may be drained, without adapter dispatch or
   output publication.
2. Structural depth, tagged wrapper depth, and total traversal budget are tested
   independently. A 16-level struct accepted alone must not become invalid only
   because it is wrapped twice in Option.
3. Buffer growth computes a rounded preferred candidate, then retries the minimum
   rounded requirement when that candidate exceeds any applicable reservation
   ceiling, while still reserving old plus new peak and owner metadata.

## Reporting and release

Every final report must list executed checks, actual results, skipped checks and
reasons, artifact/toolchain identity, and remaining risk. Acceptance of a design does
not mean implementation. Release evidence must be tied to the shipped binary and its
supported profile.
