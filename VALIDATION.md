# Validation

- Status: accepted evidence policy; M0 verified; bool/branch, loop, tagged, `?`, switch-expression, and i64 receipts are verified historical evidence; unsigned scalars implemented and verified
- Current implementation: M0 primitives and experimental M1 scalar source CLI/VM with i32/i64/u8/u32/usize/bool values, branches, loops, shallow Option/Result, switch statements and expressions, and scalar `?` propagation

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

Full M1 remains partial even though all initial scalar type names are now
implemented; M2 through M5 remain not started. M0's empty runtime-`PATH` execution does not
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
admits unsigned literals without lookahead, promotion, casts, or suffixes. Unary
minus is forbidden for unsigned values, including `-0`. Same-type arithmetic is
checked to the operand type's full unsigned range. Underflow and overflow produce
the guest `overflow` error, and a zero divisor produces `zero_divisor`. Unsigned
ordering decodes the stored cell as unsigned. Existing i64 constants and register
cells retain reversible packing that stores the upper half as negative bit
patterns, using checked conversions split at 2^63. No opcode, guest heap
allocation, frame, cap, or Fuel policy changes. Wrappers remain i32/bool payloads,
and unsigned-returning functions reject `?`.

The [unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json) records
59 native groups and 1,159 CLI cases in both development and release: 760 prior
cases plus 399 unsigned cases. The total includes two codec native groups and
eight unsigned scalar native groups.

The switch-expression and i64 receipts are historical after the unsigned increment.
The switch-expression receipt records 41 native groups and 580 CLI cases in each
verified profile. The [i64 receipt](docs/evidence/m1-i64-windows-20261023.json)
records 49 native groups and 760 CLI cases in each profile. The propagation receipt
remains historical at 37 native groups and 510 CLI cases. The unsigned receipt is the current record for this subset.
The [loop receipt](docs/evidence/m1-loops-windows-20261023.json) is
historical for its 26-group/332-case slice; the [branch receipt](docs/evidence/m1-branches-windows-20261023.json)
is historical for 20/248, and the [function receipt](docs/evidence/m1-functions-windows-20261023.json)
and earlier locals/expression receipts are likewise historical for their narrower
slices. Full M1 still needs explicit widening, remaining integer operators, and
richer value-arm statements. Arrays, structs, and borrows remain M2 work.
Workers, DLL ABI, Windows isolation, and performance remain unverified. M0 was not
rerun for unchanged inputs. No new CI job or performance measurement was added.
M2 must cover arrays, structs, borrows, Buffer, input, output, and UTF-8.
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
