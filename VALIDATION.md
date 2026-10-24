# Validation

- Status: accepted evidence policy; M0 verified; bool/branch, loop, tagged, `?`, switch-expression, i64, and unsigned receipts are verified historical evidence; explicit widening historically verified; integer operators historically verified; switch-arm statements implemented and verified; private entry-array IR/VM and immutable source-array reads implemented and focused-harness verified
- Current implementation: M0 primitives and experimental M1 scalar source CLI/VM with i32/i64/u8/u32/usize/bool values, explicit widening, branches, loops, shallow Option/Result, switch statements and expressions, and scalar `?` propagation; private entry-function array IR/native dispatch and immutable outer-main scalar-array declarations and reads are implemented

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

`tools/verify-toolchain.ps1` checks the adopted `toolchain.json` compiler using
isolated Windows AMD64 fixtures. Its [receipt](docs/evidence/toolchain-windows-20261024.json)
records eight passing cases: executable import and reuse, corrupt imported and
cached files, version and SDK-lock mismatches, default exact-commit bootstrap with
byte-identical reproduction, and unavailable-source rejection preserving the
existing compiler. Setup checks hashes before candidate execution and removes its
temporary checkout on both success and failure.

For the preceding build-tooling increment, the locked source check passed.
The 35 inputs and compiler recorded by the array-VM receipt were unchanged then,
so full VM development/release regression was not repeated for that tooling change.
Authenticated HTTPS acquisition, empty
module-cache downloads, clean-machine installation and automatic update discovery
remain unverified or outside this scope.

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
Array writes/copies, aggregate guest calls, and borrow integration remain open. M3
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
Array writes/copies, aggregate guest calls, and borrow integration remain open.
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
