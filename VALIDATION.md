# Validation

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
- Status: accepted evidence policy; M0 verified; bool/branch, loop, tagged, `?`, switch-expression, i64, and unsigned receipts are verified historical evidence; explicit widening historically verified; integer operators historically verified; switch-arm statements implemented and verified; private entry-array IR/VM and source-array reads, writes, copy initializers, parameters, results, and assignment forms implemented; in-place repeated-literal assignment verified; private entry-owned struct IR/verifier verified historically; private struct VM verified with native 38/38 and CLI 115 in both profiles; declaration-only source structs historically verified in development and release (23 native groups and 2,208 CLI cases per profile); bounded source struct construction and field reads form a verified historical read baseline; entry-only one-level scalar-field writes have historical focused development/release validation; entry-only scalar-record copy initialization and whole-record assignment are verified stepwise in development and release; bounded nested constructors, multi-segment scalar paths, and whole-root copies have results that are historical after child-binding compiler changes; whole-record child binding initializers have historical receipts; subrecord declaration initializer receipts are historical after assignment changes; atomic subrecord assignment is verified in development and release; constructor child subrecord paths verified in development and release; private scalar-value record replacement verified; metered atomic root replacement verified; private frame-local record VM verified in development and release (46 native groups and 2,383 CLI cases per profile); immutable by-value source record parameters are verified in development and release (51 native groups and 2,318 CLI cases per profile); private record-result IR/verifier verified in development and release (39 native groups and 2,317 CLI cases per profile), with its kind 11 VM gate historical and superseded; private record-result VM ownership transfer is verified for its source-gated inputs; bounded source record results are verified in development and release at `bb401a4` (14 native groups and 2,438 CLI cases per profile), with 219 rechecked inputs and a focused 70-case-per-profile checker metadata repair; direct nominal record constructor returns are verified in development and release at `0a7b539`; exact-nominal subrecord return paths are implemented at `d4aa643`; development and release each passed 25 native groups and 579 CLI cases with 205 matching input hashes; record calls in constructor child fields are implemented at `c4cd6ab`, verified in development and release
- Root constructor assignment: verified in development and release; child constructor assignment is verified in development and release.
- Child record call-result assignment: implemented at `63be9e5` and verified in
  development and release, with 26 native groups and 575 CLI cases per profile.
- Constructor child record calls: implemented at `c4cd6ab` and verified in
  development and release, each with 23 native groups and 529 CLI cases across
  separate core/regression phases and 211 verified input identities. See the
  [Windows receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json).
- Private function-owned record IR/verifier and frame-local record VM execution
  are verified in development and release.
- Current implementation: M0 primitives and experimental M1 scalar source CLI/VM with i32/i64/u8/u32/usize/bool values, explicit widening, branches, loops, shallow Option/Result, switch statements and expressions, and scalar `?` propagation; private function-owned array IR/native dispatch with separate recursive frame tokens, let/var scalar arrays in lexical scopes of ordinary functions, indexed reads/writes, copy initializers, length access, lexical cleanup including `?` failure, by-value parameters, source results, and bare-name, call-result, and repeated-literal assignment are implemented; private entry-owned struct IR/verifier and metered VM dispatch exist; source struct declarations attach immutable layouts; bounded entry construction, record bindings, one-level scalar field reads/writes, bare-name record copy initialization, and whole-record assignment lower to `SINIT`, `SREAD`, `SWRITE`, `SCOPY`, `SASSIGN`, and atomic `SSUBASSIGN`; helper-local records are implemented; for-header record writes/copies remain rejected; bounded nested constructors, multi-segment scalar paths, and whole-root copies are implemented, and child fields also accept whole visible bindings of the exact nominal type; the nested result is historical after that compiler change, subrecord declaration extraction is also implemented; immutable nominal by-value record parameters with bare binding arguments are verified in development and release, while bounded bare-name record returns and exact-nominal `let`/`var` call initializers are now implemented through the existing record-result IR and VM at `bb401a4`; direct nominal record constructor returns are verified in development and release at `0a7b539`; exact-nominal subrecord return paths are implemented at `d4aa643`; development and release each passed 25 native groups and 579 CLI cases with 205 matching input hashes; exact-nominal record calls in constructor child fields are implemented at `c4cd6ab`, verified in development and release; record borrows remain unavailable; private record-result VM transfer is verified for its original source-gated inputs
- Nominal record-result signature metadata is implemented and verified for its
  original baseline (22 native groups and 2,317 CLI cases per profile). A nominal
  result stores ID + 1 in `return_records`. Its former blanket pre-IR rejection is
  historical and superseded by [bounded source record results](docs/engineering/m2-struct-result-source.md).
  See [the signature contract](docs/engineering/m2-struct-result-signatures.md).
- Private record-result IR/verifier metadata is implemented at `dc1574b` and verified in development and release.
  `record_results` stores a callee-owned shape site + 1, `SRET` requires one live
  exact-nominal record, and a record-result CALL writes to `144 + site`. Its kind 11
  runtime gate is historical and superseded by [record-result VM transfer](docs/engineering/m2-struct-result-vm.md).
  Its blanket source gate is historical and superseded by
  [bounded source record results](docs/engineering/m2-struct-result-source.md).
  See [the IR contract](docs/engineering/m2-struct-results-ir.md).
- Bounded source record results are verified in development and release at
  `bb401a4` with tooling `78a1fb4`. A bare visible
  exact-nominal `return name;` and an exact-nominal `let`/`var` call initializer
  reach `SRET` (50). Result anchors are reserved before bodies by reusing a
  matching formal or adding a dead function-owned site. Development and release
  each passed 14 native groups and 2,438 CLI cases. See [the source
  contract](docs/engineering/m2-struct-result-source.md) and [Windows
  receipt](docs/evidence/m2-struct-result-source-windows-20261028.json).
- Direct nominal record constructor returns are implemented at `0a7b539` and verified in development and release. A record-result `return` followed by an
  exact nominal type and `{` consumes that constructor prefix and evaluates all
  fields in declaration order. The anonymous immutable result site and `SINIT`
  are created only after field evaluation finishes, so nested returns and loop
  transfers leave no pending owner or name. The shared reverse mixed finisher
  then emits `SRET`. Transfer adds no payload extent, while the constructor still
  needs the result extent and a reconstructed parameter keeps its old formal copy
  live until cleanup. No opcode, VM charge, profile, or version field changes.
  See [the constructor contract](docs/engineering/m2-struct-return-constructors.md).
  The [Windows receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json)
  records 26 passed native groups per profile (6 new and 20 regressions) and 532
  passed CLI cases (144 new and 388 regressions) in separate phase invocations.

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
DLL, clean-machine packaging and performance remain skipped. Direct return calls
were still unsupported at that checkpoint.

The [direct-return increment](docs/engineering/m2-array-return-calls.md) enables
exact-shape `return FUNCTION(arguments);` through the shared call parser and
return cleanup. The [focused receipt](docs/evidence/m2-array-return-calls-windows-20261025.json)
records 12 native groups and 509 CLI cases per development/release profile: four
new plus eight existing source-result native groups, and 117 direct-return, 119
source-result, 80 parameter, 96 result-signature and 97 helper-local CLI cases.
Exact Fuel, nested argument returns/loop exits, shared quota ceilings, capture
ordering and cleanup have direct evidence. Unchanged runtime inputs are compared,
not rerun. Other array/scalar CLI matrices, full native suites, M0, allocator
instrumentation, Linux, isolation, DLL, clean-machine packaging and performance
remain skipped. The expanded aggregate harness is syntax-checked, not invoked.
At that checkpoint, aggregate scalar expressions, result assignment RHS and for headers remained unsupported.

The [literal-return increment](docs/engineering/m2-array-return-literals.md) enables
`return [value; N];`, using the declared element context and evaluating the fill
once before initialization. The [focused receipt](docs/evidence/m2-array-return-literals-windows-20261025.json)
records 16 native groups and 628 CLI cases per development/release profile: four
new, four direct-return and eight source-result groups; 119 literal, 117 direct,
119 source-result, 80 parameter, 96 signature and 97 helper-local CLI cases.
Nested fill exits, capture cleanup, exact Fuel, all six element types and shared
quotas have direct evidence. Other array/scalar CLI matrices, full native suites,
M0, allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and
performance remain skipped. The aggregate harness was syntax-checked, not invoked.

The [call-assignment increment](docs/engineering/m2-array-call-assignment.md) enables
direct function-call RHS for existing mutable arrays. A temporary receives the
result, then AASSIGN preserves destination storage and ADROP releases the temporary.
The [focused receipt](docs/evidence/m2-array-call-assignment-windows-20261025.json)
records 15 native groups (four new, three assignment, eight source-result) and
609 CLI cases (115 new, 59 assignment, 119 source-result, 117 direct-return,
119 literal-return, 80 parameter) per development/release profile. The initial
Fuel fixture was corrected and all 15 native groups rerun. Exact Fuel, quota caps,
capture order, self-input, early exits and missing-drop rejection have evidence.
The expanded aggregate harness is syntax-checked, not invoked. Unchanged backend
inputs are compared. Full native suites, other array/scalar CLI matrices, M0,
allocator instrumentation, Linux, isolation, DLL, clean-machine packaging and
performance remain skipped.

The [in-place literal assignment](docs/engineering/m2-array-literal-assignment.md)
increment adds typed AFILL (40), preflighted owner fill, and the source form
`a = [value; N];`. The [Windows receipt](docs/evidence/m2-array-literal-assignment-windows-20261025.json)
records 36 unique native groups and 2,693 CLI cases per development/release
profile. The final 36 combine 17 reused backend identities with 19 fresh frontend
groups in each profile; the aggregate harness was syntax-checked but not invoked.
Development reuses backend from `b5e0c98`, while release reuses the same identities
from its earlier 36-group selection. Reuse validation matched 28 unchanged source
and test files to their `b5e0c98` Git blobs and confirmed matching SDK and compiler
identities.

The 2,693 CLI cases comprise 724 array cases and 1,969 scalar cases. The array
total includes 115 new, 59 assignment, 115 call-assignment, 119 source-result,
117 direct-return, 119 literal-return, and 80 parameter cases. The example returns
42 in both profiles. Full-capacity fills, exact Fuel, unchanged metadata, rejected
preflight, and early exits have direct coverage.

AFILL writes only after owner, metadata, type, and encoding checks; effects from
evaluating the fill are not rolled back on later rejection. It writes B payload
bytes with eight scratch bytes and allocates no temporary owner, extent, or catalog
site. The final lowering separates array statement, copy, and index handling into
helpers. Scalar and composed-fill cases return 42 at depth 10; depth 11 reports
`compile_limit`. Two permanent CLI cases cover the composed boundary. The pre-fix
binary reproduces `0xC00000FD` at depth 10. These are correctness checks, not
stack-byte measurements. Other native/array CLI suites, M0, allocator
instrumentation, Linux, isolation, DLL, clean-machine packaging, and performance
remain skipped; aggregate tooling was only syntax-checked.

The [private struct-layout contract](docs/engineering/m2-struct-layout.md) adds
planner-only ordering, padding, and dependency checks for 0..32 acyclic records.
Its Windows receipt records eight new struct groups and six unchanged array-layout
regression groups per profile (14 each), with development and release both passed.
This evidence covers private planning only: no source structs, storage, IR, VM,
Fuel, allocation, CLI artifact, or wrapper budget coupling.

The [private struct-storage contract](docs/engineering/m2-struct-storage.md) adds
scalar-only record preparation, complete initialization, and indexed field access
in the shared caller-backed arena. Its Windows receipt records 20 native groups per
profile: eight storage groups, eight unchanged layout groups, and four unchanged
scalar-codec groups. Development and release both passed. This covers private
scalar storage only: no source structs, by-value copies, ownership, IR, VM, Fuel,
or allocator integration.

The [private struct-copy contract](docs/engineering/m2-struct-copy.md) adds
by-value record copy initialization and assignment. Its focused selection covers
28 native groups per profile: eight new copy groups, eight fresh storage groups,
eight struct-layout groups, and four scalar-codec groups. Development and release
both passed all 28 on a fresh full selection after moving snapshot staging into
caller-owned scratch. The original return-based staging failed five release
assertions; its results are superseded by the final receipt. Copy reserves
the old-plus-new peak including alignment padding, then publishes a zero-padded
snapshot of up to 128 record bytes from caller-owned scratch with the cursor
advancing last. Assignment validates both complete extents, snapshots all fields,
and overwrites existing storage without reserving an extent. A corrupt late bool
leaves every byte and the cursor unchanged. This covers private primitive
behavior only: no source structs, nested record storage, ownership, IR, VM, Fuel,
or allocator integration.

The [private nested-storage contract](docs/engineering/m2-struct-nested-storage.md)
adds initialization of selected acyclic records from depth-first scalar leaf
inputs and scalar field-path reads/writes in the shared caller-backed arena. The
`--nested` selection passed 18 native groups per profile: six
nested-storage, eight struct-layout, and four scalar-codec groups. Development and release both passed. Every public boundary
replans the full catalog and checks arena state; field access additionally checks
root alignment and the complete published root extent.
Selected roots are capped at 128 bytes, use at most 128 leaves and depth 16, and
are traversed iteratively into initialization-owned zeroed 128-byte scratch before
backing or cursor publication; the backing bytes and arena remain caller-provided.
Valid unselected records may be larger. Nested copy/assignment has the private
successor below; ownership, IR, VM, Fuel, and source struct grammar remain open.

The [private nested-copy contract](docs/engineering/m2-struct-nested-copy.md)
adds by-value nested-record copy initialization and assignment. The
`--nested-copy` selection passed 24 native groups per profile: six new
nested-copy, six nested-storage, eight struct-layout, and four scalar-codec
groups. Development and release both passed. Copy replans the full
catalog once, validates the complete source extent, reserves the old-plus-new
peak including padding, and publishes from caller-local zeroed scratch with the
cursor advancing last. Assignment validates both complete extents, snapshots all
scalar leaves, and overwrites existing storage without reserving an extent or
changing the cursor. Both normalize padding, preserve integer bits, and check
every bool before backing writes; self and both partial overlap directions use
prewrite values. Selected roots stay within 128 bytes, 128 leaves, and depth 16.
The earlier 18-group nested-storage receipt is historical for changed inputs.
Full CLI, scalar storage/copy native suites, M0, Linux, isolation, DLL,
packaging, performance, and allocator instrumentation were not rerun.

The [shared struct-owner contract](docs/engineering/m2-struct-owners.md) extends
the 16-slot owner table to nested records. Record owners use element 0 and store
record bytes, id, and alignment; arrays and records share slots, allocation order,
the caller-owned arena, generations, release, and clear. Record creation preflights
a free slot and catalog layout, then publishes the descriptor after staged
initialization. Record field access rechecks the token and current immutable
catalog layout; array-only APIs reject record tokens. Generation max retires to
zero, and dead middle extents retain bytes and descriptors until suffix release.
The `--owners` selection passed 34 native groups per profile: six struct
owners, five array owners, four array copy, two assignment storage, seven argument
copies, four fill, and six array VM groups. Development and release both passed
the full selection with matching identities and stable input/compiler hashes.
The trusted caller must bind one immutable catalog and backing region to the table
lifetime; catalog identity hashes and cross-Instance capabilities are not provided,
and same-id same-size schema substitution is outside the contract. No struct-owner
copies/assignment, source structs, borrows, struct IR/VM, or Fuel are added.
Earlier receipts are historical for changed owner, harness, and root-lock inputs.
Existing nested-storage and source CLI files are unchanged. Full CLI, other native
suites including call/result VM, M0, Linux, isolation, DLL, packaging, performance,
and allocation instrumentation were not rerun.

The [private struct-owner copy/assignment contract](docs/engineering/m2-struct-owner-copy.md)
adds record-owner copy and assignment. The `--owner-copy` selection passed
17 native groups per profile: six new struct-owner-copy, six struct-owner, and
five array-owner groups. Development and release both passed the full selection. Copy
derives metadata from a live descriptor, preflights one shared slot, and publishes
the new record owner only after nested old-plus-new copy succeeds; the copy
survives source release. Assignment requires the exact record id, delegates to
nested snapshot assignment, and changes no descriptor, extent, cursor, or
generation. Failures preserve bytes and table metadata. The shared 128-byte,
128-leaf, depth-16, and 16-owner bounds remain. The trusted caller still binds one
immutable catalog and backing region; no catalog identity, cross-Instance, borrow,
or mutability capability is added. Existing other 38 source files and old test
fixtures are unchanged. The previous 34-group owner receipt is historical for
changed owner and harness inputs. Full CLI, other native suites including array VM
and call/result VM, M0, Linux, isolation, DLL, packaging, performance, and
allocation instrumentation were not rerun.

The [private struct IR contract](docs/engineering/m2-struct-ir.md) adds
entry-owned record bindings and verifier rules for opcodes 41..46: `SINIT`,
`SCOPY`, `SREAD`, `SWRITE`, `SDROP`, and `SASSIGN`. Each eight-byte instruction
uses `op, dst, a, b, 0, 0, 0, 0`. Initialization consumes every depth-first scalar
leaf in consecutive registers with exact types; reads and writes use flattened
leaf ordinals. The full catalog is replanned under 32 definitions, 16 fields per
record, depth 16, selected-root 128 bytes, 128 leaves, and 16 bindings. Prepared
tags use 2048 bytes of algorithmic scratch, which is not a stack measurement.

Record lifetimes occupy bits 16..31 beside array bits 0..15. Forward joins and
backedges require exact combined live sets, and scalar returns require no live
aggregates. Array returns retain the existing sole-live-array transfer rule. Struct instructions are limited to entry. Calls into entry are
rejected whenever bindings exist, including calls in otherwise unused functions.
Copy and assignment require the exact nominal record ID; assignment also requires
mutable destination storage. Scalar registers never hold owner tokens. Existing
array calls and results retain independent verifier support.

The VM verifies first, then executes these entry-only instructions through the
private [struct VM](docs/engineering/m2-struct-vm.md). The former unavailable
kind-11 boundary no longer describes the runtime. The declaration-only source
contract remains historical: declarations without record bindings attach
immutable layout metadata and emit no struct opcodes. The bounded
[source struct-value contract](docs/engineering/m2-struct-values.md) is the
historical read baseline: entry construction and one-level scalar field reads
through `SINIT` and `SREAD`. The
[source struct-field write contract](docs/engineering/m2-struct-write.md) adds
one-level `NAME.FIELD = EXPR;` through `SWRITE`. The binding and field
resolve before a single exact-typed RHS, and the write reuses the existing record
extent. Bare-name record copies and whole-record assignment are owned by the
later source-copy contract described below. Inline nested constructors and scalar
paths are owned by the [nested contract](docs/engineering/m2-struct-source-nested.md),
and whole visible child bindings by its [successor](docs/engineering/m2-struct-child.md);
at that baseline, struct parameters/results, borrows, catalog identity, and
allocator integration were unsupported. Source record parameters and bounded
record results now have successors; record borrows remain unsupported. The read baseline's focused checks are recorded below as historical
evidence; field-write validation passed in both profiles for the earlier inputs.

The `python -B tools/verify-m2-struct-layout.py --ir` selection passed 46 native
groups per development and release profile: 9 new struct-IR groups and 37
regressions comprising array IR (5), array calls (9), array results (6),
array-result VM (6), branches (5), and loops (6). The [native receipt](docs/evidence/m2-struct-ir-windows-20261026.json)
records both profiles and the unchanged pinned compiler/input identities.

The focused repeated-literal assignment CLI suite passed 115 cases per profile,
including the prior composed depth-10 success and depth-11 compile-limit boundary.
The [CLI receipt](docs/evidence/m2-struct-ir-cli-windows-20261026.json) records
both native CLI artifact hashes, commands, input hashes and all 230 outcomes.
Full CLI matrices were not rerun. These native 46 and CLI 115 results are
historical for changed runtime, test, harness, and root-lock inputs. The previous
struct-owner-copy receipt is likewise historical for changed inputs; unchanged
primitive source evidence remains valid for its original scope.

The [private function-owned record IR foundation](docs/engineering/m2-struct-function-ir.md)
adds a 16-byte owner array for static record sites. Active owners must name
declared functions and unused owner bytes must be zero. Every opcode 41..49 must
target the active function, with copy, assign, and subassign sources owned by that
same function. Each function starts with records dead while existing cleanup,
joins, backedges, and entry reentry checks remain unchanged. No opcode, Fuel,
dispatch, version capability, or source form changes at this checkpoint. The
entry-frame-only kind-5 boundary is historical; the
[frame-local record VM](docs/engineering/m2-struct-function-vm.md) now executes
verified helper IR. Source helper records, parameters, and results remain
rejected. The complete `--function-ir` invocation passed 31 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](docs/evidence/m2-struct-function-ir-windows-20261027.json) records 106 input hashes,
compiler/artifact identities, commands and outcomes. Other CLI matrices, full
native suites, Linux, packaging, isolation and performance were not rerun. That
31-group result remains historical for its original runtime and test inputs.

The [private frame-local record VM](docs/engineering/m2-struct-function-vm.md)
gives each of 32 guest frames sixteen record token slots over the same 16 shared
owners and payload arena, using array-style `frame * 16 + site` indexing. It adds
no opcode, Fuel, frontend, or version change. Frame entry allocates no separate
table or arena; `SINIT`/`SCOPY` reserve shared owners and payload and require dead
destination tokens, while writes and assignments require live mutable
destinations. Drops clear frame tokens; dead middle extents stay charged until
suffix reclamation. The complete `--function-vm` invocation passed 46 native groups and
2,383 CLI cases per development/release profile without result reuse. The
[receipt](docs/evidence/m2-struct-function-vm-windows-20261027.json) records 109 input hashes,
compiler/artifact identities, commands and outcomes. Implementation commit:
`80ed712`. Other CLI matrices, full native suites, Linux, packaging,
isolation and performance were not rerun. The 13 smoke groups ran as one native invocation and cover all opcodes
at frames 0, 1, and 31; frame-32 and
`usize`-maximum rejection; Fuel before mutation with all 512 token, owner,
payload, and register snapshots; mixed array/record quotas; stale generations;
depth-15 recursion at exactly 1,400,064 Fuel; repeated calls; frame-limit failure
after records are dropped; and helper record cleanup before an array result
transfer. At that checkpoint, source helper records and record
parameters/results remained unavailable; the source successors implement helper
records, record parameters, and bounded record results, while record borrows
remain unsupported. The 512-slot token array carries no measured allocation,
stack, or speed claim.

The original [private struct VM contract](docs/engineering/m2-struct-vm.md)
described opcodes 41..46 as entry-only. Its `struct_vm::State` held sixteen
binding tokens while sharing the existing array owner table and one payload
buffer. That contract prepared capacity 0..65,536 and charged `1 + capacity` before
allocation; pure scalar preparation and instruction prices are unchanged. Copies
are independent, assignment allocates no extent, and dead middle holes stay
charged until suffix release. Field ordinals use the existing owner field-path
APIs with 128 leaves, depth 16, and at most 4,096 traversal iterations.
The [frame-local successor](docs/engineering/m2-struct-function-vm.md) replaces
that entry-only token layout; the shared owner/payload rules and Fuel charges
below remain current.

Every struct opcode prepays before path traversal, owner validation, staging, or
token/register mutation. The fixed charges are `SINIT` 46,145, `SCOPY` 42,049,
`SREAD`/`SWRITE` 41,281, `SDROP` 65, and `SASSIGN` 60,545. These are algorithmic
accounting units, not measured CPU instructions, stack bytes, or throughput.
Insufficient Fuel preserves the tested complete state snapshots; a successful
step returns remaining Fuel; runtime failures abort the invocation. Corrupt bools,
stale tokens, and nominal-ID substitutions are covered.

The `python -B tools/verify-m2-struct-layout.py --vm` selection passed 38/38
native groups in each development and release profile: struct VM (8), struct IR
(9), array VM (6), array calls (9), and array-result VM (6). The
[native receipt](docs/evidence/m2-struct-vm-windows-20261026.json) records commands,
matching test identities, stable input hashes, and the pinned Fairy C compiler
`4ce1264273be` and SDK. The existing focused CLI suite passed 115 cases per profile;
its [receipt](docs/evidence/m2-struct-vm-cli-windows-20261026.json) records native
CLI artifact hashes, commands, input hashes and all 230 outcomes. Full native
suites and full scalar/array CLI matrices were not rerun. M0, Linux, OS isolation,
DLL, packaging, allocation instrumentation, and performance remain outside this
focused execution check.

The [declaration-only source struct contract](docs/engineering/m2-struct-source.md)
admits bounded top-level structs with forward references, scalar or by-value named
fields, source-span name resolution, declaration-order padding, and a shared
function/type namespace. The compiler attaches immutable layouts while leaving
the record binding catalog empty, so declarations emit no struct opcodes and add
no payload allocation or Fuel charge. That contract remains the historical
declaration-only slice.

Development and release each passed 23 native groups and 2,208 CLI cases: 124
source struct cases, 115 array-literal-assignment cases, and 1,969 scalar cases.
The [receipt](docs/evidence/m2-struct-source-windows-20261026.json) records stepwise
completion: the initial aggregate invocation completed development and release
native checks/build, then used an incorrect release artifact path. Remaining
release CLI checks ran directly against `build/browniec.exe`. The corrected
aggregate harness was syntax-checked, not rerun. The repeatable selection is:

```powershell
python -B tools/verify-m2-struct-source.py
```

The [bounded source struct-value contract](docs/engineering/m2-struct-values.md)
is the historical read baseline and adds entry-only scalar-field construction and
one-level scalar field reads. Fields appear exactly once in declaration order
with an optional final comma.
Each typed field expression is evaluated left to right and staged before
consecutive loads and `SINIT`; the binding becomes visible only after
initialization. Record bindings select `brownie.m2-struct-read/1`, while
declaration-only programs keep their existing profile. Construction is limited
to selected roots of at most 128 bytes and 16 fields, with up to 16 record
sites, the shared 16-entry owner table, 65,536-byte payload cap, and existing
Fuel. Nested construction and scalar paths are handled by the
[nested successor](docs/engineering/m2-struct-source-nested.md); whole visible
child bindings are owned by its [child-binding successor](docs/engineering/m2-struct-child.md).
That construction slice left struct parameters/results and borrows unsupported.
Source record parameters and bounded record results now have successors; record
borrows remain unsupported. The
[field-write successor](docs/engineering/m2-struct-write.md) adds mutable
one-level scalar assignment, and the later [source-copy successor](docs/engineering/m2-struct-source-copy.md)
adds bare-name copy initialization and whole-record assignment.

The full `python -B tools/verify-m2-struct-values.py` invocation passed 28 native
groups and 2,352 CLI cases per development/release profile: 144 struct-value,
124 declaration, 115 array-literal-assignment, and 1,969 scalar cases. Native
groups cover new values (5), declarations (5), struct VM (8), functions (4), and
loops (6). Three additional CLI cases per profile cover early return/continue
during initialization and a type declared after `main`. The
[receipt](docs/evidence/m2-struct-values-windows-20261026.json) binds matching
artifacts and stable source/compiler hashes. Full native suites, full array CLI
matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation, and
performance were not run. The declaration-only
receipt above remains historical evidence for declarations without record
bindings; it does not cover `SINIT`, `SREAD`, or the read profile.

The [source struct-field write contract](docs/engineering/m2-struct-write.md)
adds entry-only `NAME.FIELD = EXPR;` for a mutable scalar leaf. The existing
value harness is extended with `--write`:

```powershell
python -B tools/verify-m2-struct-values.py --write
```

The selection is 24 native groups per profile: 5 struct-write, 5 struct-values,
8 struct VM, and 6 switch-arm-statement groups. Each profile also covers 2,472 CLI
cases: 120 write, 144 constructor/read, 124 declaration, 115 array-literal, and
1,969 scalar cases.

The complete `--write` invocation passed in development and release: 24 native
groups and 2,472 CLI cases per profile. Cases include exact scalar types,
immutable-field rejection, single RHS evaluation, nested writes and final
member expressions, early return/continue/break cleanup, full owner pressure,
and composed RHS depth 10 success/depth 11 `compile_limit`. The basic example
returns 42 with 128,782 Fuel using a private 4-byte arena, or 194,314 Fuel with
the CLI's 65,536-byte capacity; one Fuel unit less fails. The receipt records
matching test selections, stable source/compiler hashes, both native artifacts,
commands, and outcomes. Full native suites, full array CLI matrices, M0, Linux,
isolation, DLL, packaging, allocation instrumentation, and performance were not
run. These are focused native checks, not full source conformance. The later
source-copy compiler change makes the read and write receipts historical for the
current inputs.

The [source struct-copy contract](docs/engineering/m2-struct-source-copy.md)
adds entry-only bare-name `let|var P q=p;` initialization and `p=q;` assignment
for exact nominal scalar-record types. `SCOPY` creates an independent owner and
extent; `SASSIGN` reuses a mutable destination's existing extent and accepts
self-assignment. Immutable source bindings are accepted. Helper-local records and
record statements in `for` initializer/post clauses remain rejected. Programs
with nonempty record bindings and opcode 42 or 46 select
`brownie.m2-struct-copy/1` before opcode 44 write and read fallback, and version
JSON adds `struct_copy_profile`.

Development and release each passed 39 native groups: 6 source-copy, 5
struct-write, 5 struct-values, 8 struct-VM, 9 struct-IR, and 6 switch-arm groups.
Each profile passed 2,582 CLI cases: 110 copy, 120 write, 144 values, 124
declarations, 115 array-literal assignment, and 1,969 scalar cases.

The complete selection is available as:

```powershell
python -B tools/verify-m2-struct-values.py --copy
```

The [receipt](docs/evidence/m2-struct-source-copy-windows-20261026.json) records
stepwise execution. The initial aggregate invocation completed development
native/build, then stopped at a CLI fixture profile mismatch. After correcting
only Python fixtures (profile, Fuel cap, and obsolete copy-rejection cases), all
development CLI suites passed individually. Unchanged native source/test inputs,
root lock, compiler and build were reused. Release ran the full 39-group native
selection, build, and all six CLI suites. The complete aggregate harness was not
rerun. Input hashes, reuse provenance, artifact identities and commands are
recorded. Full native suites, full array CLI matrices, M0, Linux, isolation, DLL,
packaging, allocation instrumentation and performance were not run.

The [source nested-struct contract](docs/engineering/m2-struct-source-nested.md)
adds inline named child constructors, multi-segment scalar read/write paths, and
whole-root copies for entry-owned nested records. The constructor cursor walks
the record tree iteratively; scalar leaves are staged left to right before one
`SINIT` for the root. Children add no site, owner, or extent. Paths resolve to
depth-first scalar-leaf ordinals, including leaves in preceding nested siblings.
A bound record with a nested field selects `brownie.m2-struct-nested/1` ahead of
the copy, write, and read profiles; unused nested declarations do not promote a
flat, array, or scalar program. Version JSON adds `struct_nested_profile`.

Source staging allows 16 scalar leaves in total, record nesting and path length
16, and selected roots 128 planned bytes. The existing 16 record sites,
shared 16 owners, 65,536-byte payload cap, 128 registers, 256 instructions, and
private VM bounds remain; the private VM still accepts 128 leaves. Traversal is
iterative; scalar expression depth limits are unchanged.

The nested contract's `python -B tools/verify-m2-struct-values.py --nested`
invocation passed on its corrected inputs in development and release. Each profile passed
36 native groups: 6 nested, 6 source-copy, 5 write, 5 values, 8 struct VM and 6
switch-arm groups. Each passed 2,710 CLI cases: 128 nested, 110 copy, 120 write,
144 values, 124 declarations, 115 array-literal assignment and 1,969 scalar.

The [receipt](docs/evidence/m2-struct-source-nested-windows-20261027.json) records
91 source/tool hashes, compiler and artifact identities, commands and outcomes.
Those input hashes are historical after the child-binding compiler change.

The [child binding initializer contract](docs/engineering/m2-struct-child.md)
admits a whole visible record binding as an inline child value when the field and
binding have the same nominal identity. At that field, each source scalar leaf is
copied with `SREAD` and `STORE` into the parent's staging before a later sibling
expression can mutate the source. The snapshot is independent; the source stays
live and its normal cleanup remains. No `SCOPY`, temporary owner, site, or extent
is created. Only the new parent root consumes an owner and extent, and its name
becomes visible after the complete initializer and `SINIT`. Opcodes, verifier,
VM ownership, the `brownie.m2-struct-nested/1` profile, and all existing quotas
are unchanged. Version JSON adds `struct_child_binding_initializers: true`.

The implementation is commit `ed63d1550ffd820e2ad197fe1be9d6b2e0b197a0`. The 88-case
child CLI harness passed in both development and release. It covers immutable and
mutable sources and targets, all six scalar types at their extremes, sibling
mutation after a child snapshot, nested child bindings, whole-root copies and
cleanup, the full owner table, and depth 2/8/16 checks. Depth 16 was check-only
because its runtime cost exceeds the CLI's 1,000,000 Fuel cap. Source leaves were
checked at 16 admitted and 17 `compile_limit`. The minimal i32 program succeeds
at 174,997 Fuel with an eight-byte private arena and fails at 174,996; with the
CLI arena it succeeds at 240,525 and fails at 240,524. Seven payload bytes fail
with `array_limit`.

The complete `python -B tools/verify-m2-struct-values.py --child` invocation passed
on the final source in development and release. Each profile passed 21 native
groups (5 child, 6 nested, 5 values, 5 write) and 2,798 CLI cases.
The CLI components are 88 child, 128 nested, 110 copy,
120 write, 144 values, 124 declarations, 115 array-literal assignment, and 1,969
scalar cases. The [combined receipt](docs/evidence/m2-struct-child-windows-20261027.json)
records 90 input hashes, compiler and CLI artifact hashes, commands, and outcomes.
All input hashes and the compiler hash were rechecked before archival; the final
release binary matches its recorded CLI hash. The two profiles select the same
21 native identities. No previous test results were reused for this invocation.

Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance were not run. Full-profile
conformance remains incomplete.

The [subrecord declaration successor](docs/engineering/m2-struct-extract.md)
admits exact-nominal record paths in `let`/`var` initializers. Scalar endpoints
remain scalar expressions. Each extraction emits one `SREAD` per selected leaf
into consecutive registers and one `SINIT`, with no temporary owner or staging
instructions. Source and destination remain independent live owners. The private
verifier, VM, quotas, and nested profile are unchanged. At that extraction
checkpoint, helper records, struct parameters/results, and borrows were
unsupported. Helper records, source record parameters, and bounded record results
now have successors; record borrows remain unsupported.
`python -B tools/verify-m2-struct-values.py --extract` is the combined selection;
development and release each passed 26 native groups and 2,915 CLI cases stepwise.
The groups are 5 extraction, 5 child, 6 nested, 5 values, and 5 write. CLI counts
are 117 extraction, 88 child, 128 nested, 110 copy, 120 write, 144 values, 124
declarations, 115 array-literal assignment, and 1,969 scalar. Development reuses
its unchanged native result after correcting two CLI-only expectations from
`syntax` to `type` for scalar/missing record endpoints. All final CLI selections
and the complete release native selection ran afterward. The original aggregate
did not complete as one invocation. The
[receipt](docs/evidence/m2-struct-extract-windows-20261027.json) records 92 input
hashes, compiler/artifact hashes, actual commands, and native reuse provenance.
All input and compiler hashes, the reused native report hash, and the final
release binary hash were rechecked before archival. Both profiles select the same
26 native identities. Implementation commit: `f65a1d7`. The earlier child-binding receipt is
historical for changed compiler, fixture, and tool inputs.

The [subrecord assignment successor](docs/engineering/m2-struct-subassign.md)
admits exact-nominal paths and bare bindings with a mutable destination. It reads
all source leaves before writing existing target storage, adding no site, owner,
or payload. Whole bare-name assignment retains `SASSIGN`. Partial assignment uses
only existing `SREAD`/`SWRITE`, so fatal errors abort the invocation without a
transactional rollback guarantee. Existing bounds, verifier/VM rules, and the
nested profile remain. Version JSON adds `struct_subrecord_assignment`.
`python -B tools/verify-m2-struct-values.py --subassign` is the combined selection;
the complete invocation passed in development and release without reusing prior
results. Each profile passed 15 native groups (5 assignment, 5 extraction, 5 write)
and 3,044 CLI cases: 129 assignment, 117 extraction, 88 child, 128 nested, 110 copy,
120 write, 144 values, 124 declarations, 115 array-literal assignment, and 1,969
scalar. The [receipt](docs/evidence/m2-struct-subassign-windows-20261027.json)
records 91 harness input hashes plus four CLI generator fixture hashes, compiler
and artifact hashes, commands, and outcomes. All hashes were checked before
archival; the added fixtures match the implementation-commit Git blobs. The
final release binary matches its CLI hash and both profiles select the same
15 native identities. Implementation commit: `666da70`. The extraction receipt
is historical for changed compiler, fixture, and tool inputs.

The [atomic successor](docs/engineering/m2-struct-subassign-atomic.md) emits
`SSUBASSIGN` (47) with independently checked live bindings, target mutability,
nominal record endpoints, and leaf ordinals. It prepays 131,072 Fuel and stages
at most 128 canonical bytes before publishing any target byte. Invalid source bools,
metadata, ranges, tokens, or insufficient Fuel leave the destination unchanged.
Existing owners/sites/storage are reused; no scalar register is allocated.
Sixteen-leaf and 128-byte source records now execute in the CLI allowance.
Version JSON adds `struct_subrecord_assignment_atomic` under the nested profile.
`python -B tools/verify-m2-struct-values.py --atomic` is the combined selection;
the complete invocation passed in development and release without reusing prior
results. Each profile passed 26 native groups (4 atomic, 5 source assignment,
8 existing VM, 9 existing IR) and 3,046 CLI cases: 131 assignment, 117 extraction,
88 child, 128 nested, 110 copy, 120 write, 144 values, 124 declarations, 115
array-literal assignment, and 1,969 scalar. The
[receipt](docs/evidence/m2-struct-subassign-atomic-windows-20261027.json) records
99 input hashes, compiler/artifact identities, commands, and outcomes. All input
and compiler hashes were rechecked before archival, and the final release binary
matches its CLI hash. Both profiles select the same 26 native identities.
Integration commit: `5589803`. The
[foundation receipt](docs/evidence/m2-struct-atomic-foundation-windows-20261027.json)
records nine groups per profile at `2b5917c`, before integration; those results
are separate from the final 26-group selection. The earlier per-leaf receipt is
historical for changed verifier, VM, compiler, fixture, and tool inputs.

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

Source [helper-local records](docs/engineering/m2-struct-function-source.md) are implemented at `98a4525` for ordinary scalar, wrapper-returning, and array-returning helpers. Constructor, copy, and subrecord-extraction paths use `ir::record_in` with the lowering function. Existing record forms run in callee frames under the shared sixteen sites and owners, 128-byte roots, sixteen-leaf staging, and 32 VM frames. Array-returning helpers drop local records in reverse mixed array-record order before `ARET`, preserving the returned array. Version JSON reports `struct_helper_locals: true`; opcodes, Fuel, and profile strings are unchanged.

Development and release each passed 48 native groups and 2,860 CLI cases, including 89 helper-local record cases. The native report was retained after correcting the aggregate expected count from 47 to 48; CLI matrices ran individually, including a fresh nested matrix after updating an obsolete root-replacement expectation. Release completed the `--function-source --profile release` aggregate. The [receipt](docs/evidence/m2-struct-function-source-windows-20261027.json) records 153 input hashes, compiler and artifact identities, and equal native identities across profiles. At `98a4525`, source record parameters/results and borrows were unavailable; [record parameters](docs/engineering/m2-struct-parameters-source.md) and a [bounded record-result subset](docs/engineering/m2-struct-result-source.md) now have successors, while record borrows remain unavailable. Full native suites, other struct/array matrices, Linux, packaging, DLL, isolation, and performance were not run.

The [record-parameter signature foundation](docs/engineering/m2-struct-parameter-signatures.md) recognizes bare nominal parameter types and stores each record ID separately from scalar tags and array lengths. The bounded signature table adds 128 bytes. Its rejection before IR, array catalog preparation, and body lowering was the source gate at that checkpoint; the [source parameter successor](docs/engineering/m2-struct-parameters-source.md) removes it. The historical signature evidence does not establish executable source record calls. Record results now have a separate [bounded source successor](docs/engineering/m2-struct-result-source.md); record borrows remain unavailable. That increment added no opcode, Fuel charge, profile, or version capability.

Development and release each passed 16 native groups and 2,226 CLI cases: 88 signature-gate, 89 helper-record, 80 array-parameter, and 1,969 M1 cases. Development ran individual commands; release completed `--parameter-signatures --profile release`. The [receipt](docs/evidence/m2-struct-parameter-signatures-windows-20261027.json) records compiler/artifact identities, 181 input hashes, and equal native identities across profiles. This is focused signature verification; full native/array suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation, and performance were not run.

The private [record-parameter IR foundation](docs/engineering/m2-struct-parameters-ir.md) adds immutable callee-owned record sites and 128 zero-tag parameter placeholders. CALL arguments distinguish scalar registers, array sites, and record sites; record arguments require exact nominal identity, caller ownership, liveness, and an immutable source or explicit snapshot. Parameter lifetimes occupy bits 16..31, participate in joins/backedges, and must be dropped before scalar or array returns. Its initial VM availability gate is superseded by the metered record-call successor below, and its source-gate claim is superseded by the current source parameter lowering.

The complete `--parameter-ir` aggregate passed 28 native groups (7 new record-parameter, 9 array-call, 6 record function-IR, 6 source signature) and 2,226 CLI cases per development/release profile without result reuse. The [receipt](docs/evidence/m2-struct-parameters-ir-windows-20261027.json) records 182 input hashes, compiler/artifact identities, commands and outcomes. Matching native identities, all input hashes, and the current compiler/release binary were rechecked before archival. Implementation: `9b43e0d`. Full native suites, other CLI matrices, M0, Linux, packaging, DLL, isolation, allocation instrumentation and performance were not run.

The private [mixed argument-copy foundation](docs/engineering/m2-call-argument-copies.md) now stages 0..8 array/record arguments as one transaction. It checks every source against the original owner table, normalizes record padding, validates nested bools, and admits all owner/payload reservations before publishing bytes or tokens. Failed batches preserve all backing bytes and owner metadata. That storage-only increment changed no VM gate, source grammar, Fuel or capabilities; the VM integration is described below.

The complete `--call-copies` aggregate passed 70 native groups (9 new, 61 affected) per development/release profile without result reuse. The [receipt](docs/evidence/m2-call-argument-copies-windows-20261027.json) records 62 input hashes and matching native identities. All inputs, compiler and unchanged SDK identities were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, packaging, DLL, isolation, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed owner/storage, root-lock and harness inputs.

The [private record-call VM](docs/engineering/m2-struct-call-vm.md) executes verified record-parameter IR through one mixed array/record copy transaction. It prepays the complete CALL before frame admission or payload/token changes, binds aggregate tokens, then publishes scalar arguments and the child return frame. Array-only/scalar-only prices are unchanged; record calls add 2,048 batch Fuel plus 43,008 per record and existing array work. The kind 11 VM gate is removed. That slice's statement that source record parameters remained rejected is historical and superseded by the current source lowering; opcodes, other charges, profiles and version capabilities are unchanged.

Implementation: `97bf1e2`. Development and release each passed 47 unique native groups in two separate invocations: [core, 21 groups](docs/evidence/m2-struct-call-vm-core-windows-20261027.json) followed by [regressions, 26 groups](docs/evidence/m2-struct-call-vm-regressions-windows-20261027.json). This is stepwise verification, not a single combined aggregate run. Both receipts have the same 58 input hashes, compiler and SDK identities, and disjoint test selections; all were rechecked before archival. No CLI build/matrix, full native suite, M0, Linux, isolation, DLL, packaging, allocation instrumentation or performance measurement was run. Earlier receipts remain historical for changed VM, root-lock, test and harness inputs.

Source [record parameters](docs/engineering/m2-struct-parameters-source.md) are implemented at `d0ca7e7` and verified in development and release. A call argument is one bare visible record binding with the exact formal nominal type; constructors, paths, casts, and aggregate expressions are rejected. Mutable inputs receive an anonymous `SCOPY` capture before later arguments evaluate. Record sites are predeclared after the catalog scan and bound by owning function plus record-formal ordinal within the 16 static sites, with no extra 128-byte signature site map. The callee formal is immutable and by value. Record results were unavailable at that checkpoint and now have a [bounded source successor](docs/engineering/m2-struct-result-source.md); record borrows, `ref`, and `var` parameters remain unavailable.

The source slice reuses the existing record-aware `array_source::release_from` and array-result finisher. Those paths already supported record drops, so no new cleanup behavior is claimed. A scalar return drops every visible record formal before `RET`; an array return preserves the selected array result and drops all other visible records before `ARET`. Source record values were never returned at this checkpoint; the result successor adds a separate bare-name `SRET` finisher.

Development and release each passed 51 unique native groups and 2,318 CLI cases. The [core receipt](docs/evidence/m2-struct-parameters-source-core-windows-20261028.json) records 14 native groups and 180 CLI cases; the [regression receipt](docs/evidence/m2-struct-parameters-source-regressions-windows-20261028.json) records 37 native groups and 2,138 CLI cases. The CLI selections comprise 114 source parameter, 66 signature, 80 array parameter, 89 helper-local record and 1,969 M1 cases per profile. These are two separate phase runs with disjoint native selections, matching profiles, and identical 206 input hashes, compiler and SDK identities; all inputs were rechecked before archival. Native stress tests use 16,000,000 Fuel; the CLI retains its 1,000,000 ceiling, with four costly fixtures expected to pass `check` and report `fuel` on `run`. Other native/CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

Development and release each passed 22 native groups and 2,317 CLI cases. The [Windows receipt](docs/evidence/m2-struct-result-signatures-windows-20261028.json) records the original baseline, executed commands, compiler/SDK and CLI identities, input hashes, and outcomes. The native selection comprises 6 new record-result, 6 record-formal, 6 array-result and 4 scalar-function groups. CLI coverage comprises 72 new record-result, 66 record-formal, 114 source record-parameter, 96 array-result and 1,969 M1 cases per profile. All 209 input hashes, the compiler, SDK and final release CLI were checked before archival. Full native suites, other CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [private record-result IR/verifier](docs/engineering/m2-struct-results-ir.md) adds a `u8[16]` `record_results` table, `SRET` (50), and record CALL destinations at `144 + site`. Metadata requires a non-entry function with zero `return_types` and `array_results`; SRET requires the sole live exact-nominal callee record. The existing dense argument schema is unchanged. At `dc1574b`, a verified program with record-result metadata reported kind 11 at offset 0 before Fuel or payload work, and malformed IR still reported kind 5 first. That slice added no source return, owner transfer, Fuel, profile, or version capability. Its kind 11 gate is historical and superseded by the [record-result VM successor](docs/engineering/m2-struct-result-vm.md).

The private record-result VM now executes verified `SRET` (50) through a 42,113-Fuel prepayment. It checks bounds, exact nominal metadata, an empty parent destination, every child array token, every other child record token, owner generation and metadata, and the complete planned record through a 128-byte scratch snapshot. Validation covers every scalar leaf, including nested canonical bools, without writing payload. Success clears the child token and publishes the same token in the caller; owner descriptors, arena order, generations, and payload stay unchanged. The VM handles `SRET` before generic record dispatch and publishes the return frame and PC only after success. Development and release each passed 34 native groups and 2,317 CLI cases. See the [Windows receipt](docs/evidence/m2-struct-result-vm-windows-20261028.json).

The record-result IR slice's evidence remains 39 unique native groups and 2,317 CLI cases per profile. The [core receipt](docs/evidence/m2-struct-results-ir-core-windows-20261028.json) records 21 native groups (8 new record-result, 6 array-result, 7 record-parameter), CLI builds and all 2,317 cases; the [regression receipt](docs/evidence/m2-struct-results-ir-regressions-windows-20261028.json) records 18 native-only groups (6 array-result VM, 8 record-call VM, 4 scalar-function), with no build or CLI rerun. CLI coverage is 72 record-result signature, 66 record-formal signature, 114 source record-parameter, 96 array-result signature and 1,969 M1 cases per profile. These were two separate phase invocations across implementation commit `dc1574b`, with disjoint native selections and matching 212 input hashes, compiler and SDK identities. All inputs and the final release CLI were rechecked before archival. Full native/CLI suites, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.

The [bounded source record-result successor](docs/engineering/m2-struct-result-source.md)
is verified in development and release at implementation `bb401a4` with tooling
`78a1fb4`. A bare visible exact-nominal `return name;` and an exact-nominal
`let`/`var` call initializer now lower through CALL at `144 + site` and `SRET`
(50). Before bodies, result anchors reuse a matching nominal formal or reserve a
dead function-owned record site. The internal record-result context is `255`;
`return_types` stays zero. The finisher drops other visible records and arrays in
reverse mixed lexical order before `SRET`. Development and release each passed 14
native groups and 2,438 CLI cases. The [Windows receipt](docs/evidence/m2-struct-result-source-windows-20261028.json)
records 219 rechecked input hashes, matching native identities, compiler/SDK and
artifact identities, commands, outcomes, and repair provenance.

The core aggregate ran first. One result-signature CLI checker then showed a
metadata-only defect: its `for source, kind` loop overwrote the global `kind`
label and emitted `browniec.m2-4-cli/v1` even though all 70 checks passed. After
the aggregate, the checker renamed that loop variable to `error_kind`. The 70
result-signature cases were rerun for each profile against the retained,
hash-checked binaries; sources, exits, result JSON, and version output matched.
Native groups, builds, and the other CLI selections were not rerun. The receipt
records this as a focused stepwise repair, not one unchanged aggregate run.

The [record layout dependency refactor](docs/engineering/struct-layout-traversal.md)
replaces repeated readiness passes with iterative DFS and preserves complete
metadata validation, checked layout arithmetic and conservative VM Fuel prices.
Development and release each passed 24 focused native groups and 166 source
record-result CLI cases. The [Windows receipt](docs/evidence/struct-layout-traversal-windows-20261028.json)
records the current input and compiler/artifact hashes. The dense fixture's
dependency-field count drops from 4,352 to 512 by loop analysis; elapsed-time
performance, full suites, Linux, M0, packaging and isolation were not measured or
rerun. Earlier receipts remain evidence for their original inputs.

The [copy-batch owner validation refactor](docs/engineering/call-owner-validation.md)
validates the original table once before preflight, while private per-argument
lookups retain token checks and record metadata validation. Public owner entry
points still validate the complete table. Development and release each passed
27 owner/copy native groups and 194 parameter CLI cases. The [Windows receipt](docs/evidence/call-owner-validation-windows-20261028.json)
records commands and exact input/compiler/SDK/artifact identities. Full suites,
Linux, M0, packaging, isolation and elapsed-time benchmarks were not run.

### Direct nominal record return calls

[Direct nominal record return calls](docs/engineering/m2-struct-return-calls.md)
are implemented at `c23e6e4` for a bounded source form. A
`return callee(...);` may return a nominal record when `callee` returns the exact
nominal type declared by the enclosing function and its name does not collide
with a visible local. The compiler reserves a dead function-owned destination
before argument evaluation, keeps the destination out of the local binding
table, and uses the shared CALL/SRET finisher to release other live arrays and
records before owner transfer.

Development and release each passed 18 native groups: six core groups and twelve
regression groups. The [Windows receipt](docs/evidence/m2-struct-return-calls-windows-20261028.json)
records the four separate phases, executed commands, compiler/SDK and artifact
identities, 196 matching rechecked input hashes, outcomes, and skips. Both CLI
artifact hashes were rechecked against retained binaries. The phase runs are not
one aggregate invocation.

Each profile also passed 505 CLI cases: 152 direct record-return, 166 named
result, 70 result-signature, and 117 direct array-return cases. Development core
was first run directly with `fairyc test --native --capture-output --json
--locked --file tests/m2/struct_return_calls.fy` before the harness was written.
The later harness run covers that phase in addition to the other three. The
native exact-form fixture establishes that the named and direct forwarding forms
produce identical IR and the same exact runtime boundary in a four-byte payload
arena: 171,728 Fuel succeeds and 171,727 fails. The prior named-result receipt
is historical for its changed compiler, fixture, and harness inputs. This focused
selection does not cover full native or CLI suites, M0, Linux, isolation, DLL,
packaging, allocation instrumentation, or performance.

### Direct nominal record constructor returns

[Direct nominal record constructor returns](docs/engineering/m2-struct-return-constructors.md)
are implemented at `0a7b539` and verified in development and release. A record-result
`return` whose next token is `{` after an identifier enters the constructor path.
`record_values::constructor` checks and consumes the exact nominal type name and
opening brace. The shared constructor helper evaluates fields from left to right
in declaration order, allowing nested constructors and existing exact-nominal
child binding or path staging. Only after all field expressions and the
terminator finish does the compiler allocate one immutable anonymous
function-owned site and emit `SINIT`. The shared `record_results::finish` path
then performs reverse mixed cleanup and emits `SRET`.

The deferred publication is the safety boundary for early exits. A nested return
inside a field expression has no pending record owner or constructor name to
clean up, and a `break` or `continue` also leaves before publication. On normal
completion, earlier locals and formals stay live through field evaluation and
`SINIT` and are released by the finisher. Transfer adds no payload extent, but
the constructor requires its result extent. A four-byte factory can therefore
fit a four-byte payload quota, while reconstructing a four-byte parameter keeps
the old formal copy and the new result live together until cleanup: eight
callee payload bytes, plus caller originals and any captures in the shared quota.

General return expressions, parenthesized constructor returns, general aggregate
arguments, parenthesized child calls, and call-result field selection remain
unsupported. Exact-nominal record calls in constructor child fields now have a
[successor contract](docs/engineering/m2-struct-child-calls.md); exact-nominal
subrecord paths and child call-result assignment also have successors below.
There is no new opcode, VM charge, profile, or version field.

The fixture at `tests/m2/struct_return_constructors.fy` has six native groups,
including eleven successful programs, eleven type rejections, and the
direct-versus-named IR and payload quota checks. The harness has separate
`--phase core|regressions` and `--profile development|release` selections. Core
selects the six new groups; regressions selects eight named source-result, six
direct return-call, and six result-signature groups. That is 26 native groups per
profile. The regression phase also runs 532 CLI cases per profile: 144
constructor-return, 152 direct return-call, 166 named source-result, and 70
result-signature cases. These are four separate phase/profile invocations, not one
aggregate run.

Development and release each passed all 26 native groups and 532 CLI cases.
The [Windows receipt](docs/evidence/m2-struct-return-constructors-windows-20261028.json)
records 199 matching rechecked input hashes, identical compiler/SDK identities
and both retained CLI hashes. Development core ran before the implementation
commit with the same source changes; the other three phases ran after it. Earlier receipts remain historical for their original compiler, fixture,
and harness inputs. The focused harness does not cover full native or CLI suites,
M0, Linux, isolation, DLL embedding, packaging, allocation instrumentation, or
performance.

### Record calls in constructor child fields

[Record calls in constructor child fields](docs/engineering/m2-struct-child-calls.md)
are implemented at `c4cd6ab` and verified in development and release. An
exact-nominal child field may now use a bare call,
such as `R { .p = make(args) }`. `compiler::record_child_call` reuses the exact
record-result destination and normal `call_value` argument evaluation. It then
emits `SREAD` and `STORE` for every returned scalar leaf through the shared
`struct_value_source::stage_part`, followed by `SDROP`, before any later field
or the parent's `SINIT`, `SREPLACE`, or `SSUBREPLACE`.

A new parent binding and the anonymous child destination are absent from the
local name table during argument evaluation. An existing replacement parent
stays visible and live; early-exit cleanup may drop it. Existing cleanup handles
early `return`, `?`, `break`, and `continue`; argument effects are not rolled
back. A pending constructor parent occupies no payload during the child call.
A live eight-byte replacement parent plus a four-byte child needs twelve bytes
before captures, formals, or other locals are counted. A fresh four-byte parent
and four-byte child have nonoverlapping lifetimes: four bytes succeeds and
three reports `array_limit`.

The shared `record_constructor` reaches this path from declarations, root and
child replacement, and direct constructor returns. Existing child binding and
path staging delegates to `stage_part` without an owner. Scalar calls are
unchanged. General aggregate arguments outside the exact-record-formal call position,
parenthesized child calls, and
call-result field selection remain unsupported. No opcode, VM rule, Fuel price,
profile, or version field changes.

The fixture at `tests/m2/struct_child_calls.fy` has six native groups with
fifteen successful and twelve type-rejection programs. It checks instruction
order, rejects a missing `SDROP` mutation, and exercises the four/three-byte
quota boundary. The new CLI matrix has 154
cases: 27 fixture programs through `check` and `run`, 48 scalar-boundary programs
through both commands, and two repeated-assignment boundaries through both.
The native selection is 23 groups per profile: six new, five child-path, six
constructor-return, and six child-call-assignment regressions. The regression
CLI totals 529 cases: 154 new, 83 child path, 144 constructor return, and 148
child call-assignment.

Development and release each passed all 23 native groups (6 core,
17 regressions) and 529 CLI cases (154 + 83 + 144 + 148) in four separate phase
invocations. Development core ran before implementation commit
`c4cd6ab4a317aedfe46af9266b10eee9de30a9e3` with the same implementation files
uncommitted; development regressions, release core, and release regressions
ran after it. All four phases rechecked the same 211 raw input hashes before
final formatting, with identical compiler/SDK identities and confirmed hashes
for both retained executables.

After all four phases, removing sixteen spaces from otherwise empty checker
line 63 was validated as an exact reversible byte change with an identical
Python AST, recorded in `postVerificationFormatting` with verified/current
hashes; product tests were not rerun.

The [Windows receipt](docs/evidence/m2-struct-child-calls-windows-20261028.json)
archives all four phases. This focused selection does not cover
full native or CLI suites, M0, Linux, isolation, DLL embedding, packaging,
allocation instrumentation, or performance.

### Exact-nominal subrecord return paths

[Exact-nominal subrecord return paths](docs/engineering/m2-struct-return-paths.md)
are implemented at `d4aa643` and verified in development and release. A bare
`return outer.child;` returns an independent exact-nominal record copy; deep
paths resolve to a depth-first leaf range. `record_values::extracted` emits one
`SREAD` per consecutive leaf into consecutive registers, allocates one
immutable anonymous site, and emits one `SINIT`. The source remains live through
creation and initialization: there is no staging store/load pair, `SCOPY`, or
temporary owner. `record_results::finish` then drops other mixed arrays and
records in reverse lexical order and emits `SRET`.

A four-byte source record and its four-byte extracted result require eight
payload bytes together; seven bytes fail. Existing `SREAD`, `SINIT`, and
`SRET` Fuel charges apply. No opcode, charge, profile string, or version field
changes. Record borrows, general or parenthesized return expressions, and
`call().child` returns remain unsupported.

The fixture has six native groups: 12 positive programs, 12 negative programs,
direct-versus-named IR equivalence, and the payload boundary. Core selects six
new groups. Regressions select 19 (5 extract, 8 named result, 6 call
assignment), for 25 native groups per profile. The regression phase runs 579 CLI
cases per profile (148 return-path, 117 extract, 166 named result, 148 call
assignment). Development and release each passed all 25 native groups and 579
CLI cases in four separate phase invocations, with 205 identical inputs
rechecked across them. Development core ran before `d4aa643` with its
implementation files uncommitted; the other three phases ran after it. Earlier
receipts remain historical for their original inputs. Full suites, M0, Linux,
isolation, DLL, packaging, allocation instrumentation, and performance remain
outside this selection.

M3 must use a fake in-memory typed host adapter without live keys or network services.
M4 requires real Windows AppContainer, Job, bounded IPC, I/O leases, and the broker
publication barrier. Compile untrusted source only inside the restricted worker.
M5 requires actual DLL export/call, clean-machine packaging, and full metrics.

### Record call-result assignment

Implemented at `0a6a759`, `root = callee(...);` accepts an exact-nominal result
for an existing mutable root in ordinary function statements and statement-bearing
value arms. The destination stays live while arguments and CALL execute. Normal
capture cleanup precedes `SASSIGN` and `SDROP` of the anonymous result. Early
returns, propagation and loop transfers never drop a pending result. Parenthesized
RHS calls and for-header aggregate writes remain rejected.
The [child call-assignment successor](docs/engineering/m2-struct-child-call-assignment.md)
now supports exact-nominal child paths; for-header aggregate writes and
parenthesized RHS calls remain rejected.

The [contract](docs/engineering/m2-struct-call-assignment.md) and
[receipt](docs/evidence/m2-struct-call-assignment-windows-20261028.json) track
passed development/release verification: six new native groups plus 24 regressions, and 725 CLI
cases per profile (148 assignment, 144 constructor-return, 166 named-result,
152 direct-return and 115 array call-assignment). Core/regression and development/
release selections are separate invocations. Earlier receipts remain historical
for their original inputs. Full suites, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance are outside this selection.

The four phases share 202 matching rechecked input hashes and the same compiler/
SDK identities. Both CLI hashes match retained executables. Development core ran
before implementation commit `0a6a759` with the same implementation files in the
working tree; the other phases ran after that commit.

### Child record call-result assignment

[Exact-nominal child call-result assignment](docs/engineering/m2-struct-child-call-assignment.md)
is implemented at `63be9e5`. The shared `compiler::record_call_assignment`
handles both a mutable root and a mutable exact-nominal child path. It reserves
a dead anonymous result site before argument evaluation, uses the existing
left-to-right call path, and emits capture cleanup after CALL. A child destination
then uses `SSUBASSIGN` (47) with source leaf zero and `SDROP`; the destination
root and owner stay live, neighboring bytes stay in place, and the returned
temporary is released.

Early returns, `?`, `break`, and `continue` cannot drop an unpublished
result because the temporary is absent from locals. Arguments can mutate the
destination root before the normal assignment, and those changes are not
rolled back. The existing `SSUBASSIGN` charge is 131,072 Fuel. No opcode, VM
rule, Fuel price, profile, or version field changes.

The fixture has six native groups with twelve successful and twelve negative
programs; the negatives comprise eleven type errors and one syntax error for
`make().p`. It covers deep paths, neighbor preservation, scalar extrema,
mutable argument effects, early transfers, inner-loop captures, repeated
assignment, IR equivalence to an explicit scoped temporary and child copy, the
eight-versus-seven payload boundary for `struct R { P p; }` plus a returned
`P`, and verifier corruption that removes `SDROP` or corrupts the target
leaf.

Development passed all 26 native groups (6 core, 20 regressions) and all 575 CLI
cases (148 new, 148 root, 131 atomic subassignment, 148 return paths). The
development artifact was retained, and 208 inputs stayed unchanged. The initial
core attempt passed five groups and failed the trailing-field case because the
fixture expected a type error where the parser reported syntax. The fixture-only
repair changed that expectation; no production code changed, and the six-group
core was fully rerun without result reuse.

Development and release each passed 26 native groups (6 core, 20 regressions)
and 575 CLI cases in four separate phase invocations. All 208 input hashes
matched; compiler and SDK identities matched, and the retained development and
release executable hashes were confirmed. Development core ran before
`63be9e5` with the implementation files uncommitted; the other three phases ran
after it. The [Windows receipt](docs/evidence/m2-struct-child-call-assignment-windows-20261028.json)
records the provenance, commands, identities, and outcomes.

## M2 record call results as arguments

Implemented at `7671f25`; development and release each passed 29 native groups
(7 new and 22 regressions) and 588 CLI cases (154 new, 114 source parameters,
166 source results, 154 constructor child calls).

The [source contract](docs/engineering/m2-struct-result-arguments.md) covers
bare exact-nominal result calls used as record arguments, nested calls,
array/wrapper-returning consumers, evaluation before later argument effects,
and mixed capture cleanup on normal and early exits. The native fixture checks
byte-for-byte IR equivalence to a named temporary, missing-drop verifier
rejection, and the eight-versus-seven payload boundary. No opcode, VM, Fuel,
profile or version-field change is involved.

The four focused phases share 214 tracked input identities. Development core
ran from baseline `7f758e4` with the implementation uncommitted; the remaining
phases used `7671f25`. The
[Windows receipt](docs/evidence/m2-struct-result-arguments-windows-20261028.json)
retains commands, input and compiler/SDK identities, outcomes and both CLI
binary hashes, all rechecked before archival. Prior receipts remain historical for their original inputs.

Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging,
allocation instrumentation and elapsed-time performance are outside this
focused verification.

## M2 subrecord paths as arguments

Implemented at `9650f12` and verified in development and release, each with
27 native groups and 570 CLI cases. Both combined invocations rechecked the
same 217 inputs, compiler and SDK identities, and retained CLI binary hashes. The
[source contract](docs/engineering/m2-struct-path-arguments.md) covers bare
exact-nominal subrecord paths used as record arguments. Consecutive SREAD values
feed SINIT before the anonymous capture becomes visible to cleanup; later
argument effects cannot change the captured value. Root, snapshot, and formal
are live together: twelve payload bytes pass for three four-byte records,
eleven reports array_limit. Source-site and shared-owner budgets are unchanged.

The focused harness selects 27 native groups per profile: six new path-argument,
seven result-argument, eight source-parameter, and six subrecord-return groups.
The CLI selections total 570 cases: 154 new, 154 result-argument, 114 source
parameter, and 148 subrecord-return cases. Development and release use separate
combined invocations. Commands, matching input/compiler/SDK identities, native
outcomes and both CLI hashes are retained in the
[Windows receipt](docs/evidence/m2-struct-path-arguments-windows-20261028.json).
Previous receipts remain historical for their original inputs.

Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.

## M2 record constructors as arguments

Implemented at `bd9db83` and verified in development and release, each with
26 native groups and 874 CLI cases. Both combined invocations rechecked the
same 220 input hashes and matching compiler/SDK identities. The
[source contract](docs/engineering/m2-struct-constructor-arguments.md) covers a
bare exact-nominal constructor used as a record argument. Fields stage before
LOAD/SINIT and anonymous capture publication. A four-byte argument and formal
need eight payload bytes; seven reports array_limit. An early return during a
pending scalar field needs zero payload bytes; a child call result can stage
and drop within four bytes before an early return skips its pending parent.

The combined harness selects 26 native groups per profile: six new, eight source
parameter, six constructor-return, and six constructor child-call groups.
The 874 CLI cases comprise 154 new, 114 source parameter, 154 result-argument,
154 path-argument, 144 constructor-return, and 154 constructor child-call cases.
Legacy direct-constructor rejections now reject parenthesized constructors;
all affected CLI selections passed before the native harness began.
The [Windows receipt](docs/evidence/m2-struct-constructor-arguments-windows-20261028.json)
retains commands, input/compiler/SDK identities, both profile outcomes and
retained executable hashes. Previous receipts remain historical for their inputs.

Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.

## M2 array call results as arguments

Implemented at `03795b9602eaa160e633d750a91c98743b23dc97` and verified in development and release.
Both combined invocations rechecked 223 identical input hashes and matching
compiler/SDK identities. The
[source contract](docs/engineering/m2-array-result-arguments.md) covers a bare
exact-shape array-result call as an array argument. The destination remains
unnamed until CALL completion and delimiter validation. Existing mixed capture
cleanup handles normal calls, early scalar/array returns, question-mark exits,
and loop transfers. No opcode, VM, Fuel price, profile, or version-field change.

Each profile passed 29 native groups and 507 CLI cases:
six new, eight array-parameter, eight array-result, and seven record-result
argument groups; 154 new, 80 array-parameter, 119 array-result, and 154
record-result argument CLI cases. The native fixture checks IR equality with a
named temporary, missing-ADROP verifier rejection, an eight-versus-seven payload
boundary, and zero payload when a nested argument returns before the result CALL.

Development and release ran as separate combined profile invocations. The
[Windows receipt](docs/evidence/m2-array-result-arguments-windows-20261028.json)
retains commands, matching input/compiler/SDK identities, native outcomes,
and retained executable hashes. Older receipts remain historical for their inputs.
The formerly rejected bare array-call argument in the record-result fixture now
uses a parenthesized array call; the modified CLI matrix passed before native checks.

Full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.

## M2 repeated array literals as arguments

Implemented at `ea6854f1e97cb6c2c6f85cdeee44d1800e078497` and verified in development and release.
The two combined invocations rechecked 226 identical input hashes and matching
compiler/SDK identities. See the [Windows receipt](docs/evidence/m2-array-literal-arguments-windows-20261028.json). See the
[source contract](docs/engineering/m2-array-literal-arguments.md) for single filler
evaluation, delayed owner publication, mixed cleanup and exact shape rules.
Each profile passed 20 native groups (6 new, 8 array-parameter, 6
array-result-argument) and 344 CLI cases (110 new, 80 array-parameter, 154
array-result-argument) per development/release profile. Full suites, M0, Linux,
isolation, DLL, packaging, allocation instrumentation and performance are excluded.

## M2 direct array call-result reads

Implemented at `b8220890cb2c7a7aed6579c35c572e69ee43cc2a` and verified in development and release.
Both invocations rechecked 229 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-array-call-reads-windows-20261028.json). See the
[source contract](docs/engineering/m2-array-call-reads.md) for evaluation order,
result lifetime, index-expression cleanup and effectful length queries.
Each profile passed 18 native groups (4 new, 8 source-array-result, 6
literal-argument) and 335 CLI cases (106 new, 119 source-array-result, 110
literal-argument) per profile. Full suites, M0, Linux, isolation, DLL, packaging,
allocation instrumentation and performance are excluded.

## M2 direct record call-result scalar reads

Implemented at `aee98856f2890f7fafe2c657712c1cadbff8250b` and verified in development and release.
Both invocations rechecked 232 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-call-reads-windows-20261028.json). See the
[source contract](docs/engineering/m2-struct-call-reads.md) for exact nominal
results, existing scalar field-path resolution and immediate root release.
Each profile passed 16 native groups (4 new, 8 source-record-result, 4
array-read) and 374 CLI cases (102 new, 166 source-record-result, 106 array-read)
per profile. Full suites, M0, Linux, isolation, DLL, packaging, allocation
instrumentation and performance are excluded.

## M2 returned subrecords as arguments

Implemented at `7284da8c98f21500af44a2d97537497a8604cfb5` and verified in development and release.
Both invocations rechecked 235 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-call-path-arguments-windows-20261028.json). See the
[source contract](docs/engineering/m2-struct-call-path-arguments.md) for exact
nominal extraction, root release before child creation and mixed cleanup.
Each profile passed 17 native groups (4 new, 6 named-path-argument, 7
record-result-argument) and 410 CLI cases (102 new, 154 named-path-argument, 154
record-result-argument) per profile. Full suites, M0, Linux, isolation, DLL,
packaging, allocation instrumentation and performance are excluded.

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

## Returned-subrecord declaration initializers

Implemented at `e38f00ac92a7729efa8417982a8f096b0145838d` and verified in development and release.
Both invocations rechecked 238 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-call-path-declarations-windows-20261028.json).
`let Point p = make().child;` and `var` resolve an exact-nominal child, snapshot
its scalar leaves, drop the anonymous root, then create an independent child.
The destination name is published only after CALL and path/delimiter validation.
Bare whole-result declarations retain direct ownership transfer. No opcode, VM,
Fuel price, profile or version capability changes.

Each profile passed 22 native groups (5 new, 5 named
extraction, 8 record-result source, 4 returned-subrecord arguments) and 537 CLI
cases (152 new, 117 extraction, 166 result source, 102 returned-subrecord
arguments). Run `python -B tools/verify-m2-struct-call-path-declarations.py
--profile development` and repeat with `--profile release`.
See [the source contract](docs/engineering/m2-struct-call-path-declarations.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this slice. Previous
receipts remain historical for their original inputs.

## Returned-subrecord assignment values

Implemented at `297116966cfedd0ed2eed8c93c0ef522da0ed1fd` and verified in development and release.
Both invocations rechecked 241 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-call-path-assignment-windows-20261028.json).
Each profile passed 16 native groups and 440 CLI cases per development
and release profile: four new returned-subrecord assignment groups, six root
call-assignment regressions, and six child call-assignment regressions. The CLI
selection is 144 new cases plus 148 root-assignment and 148 child-assignment cases.


Run `python -B tools/verify-m2-struct-call-path-assignment.py --profile development`
and repeat with `--profile release`. Full suites, M0, Linux, isolation, DLL
embedding, packaging, allocation instrumentation, and elapsed-time performance are
outside this focused selection. Earlier receipts remain historical for their
original inputs.

## Returned-subrecord direct returns

Implemented at `c78930046a330cc940be20bfcfd4c5350047cbc5` and verified in development and release.
Both invocations rechecked 244 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-call-path-returns-windows-20261028.json).
`return make().child;` resolves the declared exact nominal result, snapshots
its leaves, drops the unnamed returned root, then creates the child. Existing
reverse mixed cleanup precedes SRET. Bare whole-call return transfer is unchanged.
No opcode, VM, Fuel price, profile or version changes.

Each profile passed 16 native groups (4 new, 6 named return paths,
6 bare return calls) and 444 CLI cases (144 new, 148 named paths, 152 bare calls).
Run `python -B tools/verify-m2-struct-call-path-returns.py --profile development`
and repeat with `--profile release`. See [the source contract](docs/engineering/m2-struct-call-path-returns.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.
Earlier receipts remain historical for their original inputs.

## Returned-subrecord constructor fields

Implemented at `c0d621745cd88b0de30e9c8a727e99e87dbc946e` and verified in development and release.
Both invocations rechecked 247 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-struct-child-call-paths-windows-20261028.json).
`Box { .child = make().child }` resolves the exact-nominal endpoint and stores
only its scalar leaves in existing parent staging slots. The returned root is
released before later fields; no independent source child is created. Pending
parents stay unnamed and dead; replacement destinations remain live until the
existing atomic overwrite. No opcode, VM, Fuel, profile or version change.

Each profile passed 16 native groups (4 new, 6 bare
child calls, 6 constructor returns) and 442 CLI cases (144 new, 154 bare child
calls, 144 constructor returns). Run `python -B tools/verify-m2-struct-child-call-paths.py
--profile development` and repeat with `--profile release`.
See [the source contract](docs/engineering/m2-struct-child-call-paths.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.
Earlier receipts remain historical for their original inputs.

## Private Buffer growth admission

Implemented at `3f99138e98f9fc4779f70efa47bab6956fae756a` and verified in development and release.
Both invocations rechecked 250 identical input hashes and matching compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-buffer-growth-windows-20261028.json).
This foundation plans 64-byte-rounded capacities and reserves old-plus-new
payload and both logical 64-byte owner records. Object, Instance and Engine
ceilings each permit minimum-capacity fallback; allocator OOM is separate.
Exact pending snapshots are revalidated before commit/cancel arithmetic.
The trusted caller must publish/drop allocations in the documented order.
No allocation, byte copying, owner-token checks, guest Buffer syntax or VM
integration is supplied by this accounting-only increment.

Each profile passed 8 native groups and 8 CLI sentinels. CLI sentinels exercise unchanged scalar/array/record behavior and
continued rejection of Buffer syntax, not Buffer execution.
Run `python -B tools/verify-m2-buffer-growth.py --profile development` and repeat
with `--profile release`. See [the foundation](docs/engineering/m2-buffer-growth.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocation
instrumentation and elapsed-time performance are outside this focused selection.
Previous receipts remain historical for their original inputs.

## Private native Buffer storage

Verified in development and release: each passed 15 native groups (7 storage
plus 8 admission) and 8 CLI sentinels. Both invocations rechecked 253 identical
inputs and compiler/SDK identities. See the
[Windows receipt](docs/evidence/m2-buffer-storage-windows-20261028.json).
`buffer_storage::prepare_growth` reserves old-plus-new payload/owner charges,
allocates an exact-capacity owning native Buffer, and copies initialized bytes.
The original root remains live until the caller replaces it and commits.
Discarded replacements must be dropped before cancellation. Preparation failures
cancel after helper cleanup; quota/overflow/state/no-growth failures precede allocation.

The native groups exercise real allocation, copying, owning-root replacement,
explicit commit, abandonment/cancellation and data preservation. CLI sentinels
cover unchanged scalar/array/record behavior and continued Buffer syntax rejection.
Run `python -B tools/verify-m2-buffer-storage.py --profile development` and repeat
with `--profile release`. See [the storage contract](docs/engineering/m2-buffer-storage.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocator-failure
injection, allocation instrumentation and elapsed-time performance are not included.
Earlier receipts remain historical evidence for their original inputs.

## Private Buffer owner descriptors

Verified in development and release: each passed 23 native groups and 8 CLI
sentinels. Both invocations rechecked 256 identical inputs and compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-buffer-owners-windows-20261028.json).
A fixed table of 16 private descriptors validates slot/generation identity before
native backing metadata or payload access. Read/write require exact initialized
length and capacity plus index bounds. Release clears metadata and advances the
generation; MAX retires the slot at zero. This does not own native roots or charge
the descriptor table to an Instance. The caller supplies the correct table/root.

The verified selection is 8 descriptor groups, 7 native storage groups and
8 growth groups, plus 8 CLI compatibility/syntax-gate sentinels per profile.
Run `python -B tools/verify-m2-buffer-owners.py --profile development` and repeat
with `--profile release`. See [the contract](docs/engineering/m2-buffer-owners.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocator-failure
injection, allocation instrumentation and elapsed-time performance are not included.
Earlier receipts remain historical evidence for their original inputs.

## Private Buffer replacement transactions

Verified in development and release: each passed 31 native groups and 8 CLI
sentinels. Both invocations rechecked 259 identical inputs and compiler/SDK
identities. See the [Windows receipt](docs/evidence/m2-buffer-replacement-windows-20261029.json).
Preparation checks identity, native metadata and generation headroom before
reserving and copying. It snapshots all 16 descriptors and every ledger field.
Commit rechecks both snapshots and published capacity/length before advancing
the same slot generation and finishing accounting. Cancel retains old tokens.
Root publication/drop ordering and correct native root association remain caller
obligations; this does not make native root publication atomic with completion.

The verified selection is 8 replacement groups plus the existing 23 descriptor,
storage and admission groups, and 8 CLI compatibility/syntax-gate sentinels.
Run `python -B tools/verify-m2-buffer-replacement.py --profile development` and
repeat with `--profile release`. See [the contract](docs/engineering/m2-buffer-replacement.md).
Full suites, M0, Linux, isolation, DLL embedding, packaging, allocator-failure
injection, allocation instrumentation and elapsed-time performance are not included.
Earlier receipts remain historical evidence for their original inputs.

## Native Buffer allocator-failure probe

Development and release each passed 5 native executable scenarios: normal minimum
and preferred growth, abandoned replacement cancellation, minimum allocation OOM,
and preferred allocation OOM. Both OOM cases require Allocation to reach the
caller before an explicit retry, with old data/token retained, all pending fields
cleared, usage restored, and observed peaks retained. Retry commits the expected
capacity and next token generation. Every process reports zero live allocations
at the instrumented FY system-heap seam after native scope cleanup.

Run `python -B tools/verify-m2-buffer-failure.py` (Windows MSVC). The standalone
project builds byte-identical copies of the four production Buffer modules with
a test-only forced-include allocator header. Root sources and fairy.lock are
unchanged. The archive rechecks 11 selected inputs, 5 generated source files,
the generated SDK lock and both retained instrumented executables. See the
[contract](docs/engineering/m2-buffer-failure.md) and
[Windows receipt](docs/evidence/m2-buffer-failure-windows-20261029.json).

This is focused native allocator evidence, not new guest Buffer/CLI support,
whole-process leak proof, or a full M0/native/CLI regression result.
Provider inconsistency injection, Linux, isolation, DLL embedding, packaging and
elapsed-time performance were not run. Earlier receipts retain their original inputs.

## Native Buffer append within admitted capacity

Development and release each passed 9 native executable scenarios: 4 append cases
and the 5 allocator scenarios. Nonempty append advances initialized length and
generation in the existing slot. Empty append preserves the token. Capacity,
current usage, peaks and all pending ledger fields stay unchanged. Capacity,
identity, native metadata, exhausted generation, pending/corrupt accounting and
policy-limit rejections are checked before calling SDK append.

Run `python -B tools/verify-m2-buffer-failure.py`. The expanded probe builds
byte-identical copies of 5 production modules and reports allocator schema v2.
Each append scenario reports exactly 1 allocation attempt for initial creation,
1 final free and 0 live allocations; append causes no extra FY heap allocations.
The five prior minimum/preferred/abandon/OOM cases remain selected, now with total
attempt/free counts checked. The archive rechecks 12 inputs, 6 generated sources,
the generated SDK lock and both instrumented executable hashes. See the
[contract](docs/engineering/m2-buffer-append.md) and
[Windows receipt](docs/evidence/m2-buffer-append-windows-20261029.json).

This is private native API evidence. Guest Buffer syntax/VM ownership, grow-and-
append as one transaction, Provider inconsistency injection, full M0/native/CLI
suites, Linux, isolation, DLL embedding, packaging and elapsed-time performance
remain outside this check. Earlier receipts retain their original inputs.

## Native Buffer close accounting

Development and release each passed 13 native executable scenarios: 4 close cases
and 9 append/allocator regressions. Begin checks token/native metadata and clean
accounting, invalidates the token and retains the entire charge. After leaving
the owning root's scope, finish rechecks table and ledger snapshots, then returns
payload capacity plus the logical 64-byte owner charge. Peaks remain unchanged.
Duplicate completion, pending/corrupt accounting, bad backing, changed snapshots
and malformed Plans are rejected without partial accounting updates. MAX generation
retires its slot. Empty-root close returns its 64-byte charge without allocation.

Run `python -B tools/verify-m2-buffer-failure.py`. The shared probe now copies
6 production modules. Every close process reports 1 initial allocation attempt,
1 final free and 0 outstanding FY heap allocations; closing adds no allocations.
The empty-root subcase reuses the process and introduces no native allocation.
The archive rechecks 13 inputs, 7 generated sources, SDK lock and both instrumented
executables. See [the contract](docs/engineering/m2-buffer-close.md) and
[Windows receipt](docs/evidence/m2-buffer-close-windows-20261029.json).

The API cannot prove native root destruction or enforce exclusive lifetime ordering.
Guest VM cleanup, physical table/Plan memory admission, Provider fault injection,
full M0/native/CLI suites, Linux, isolation, DLL embedding, packaging and elapsed-time
performance were not run. Earlier receipts retain their original inputs.

## Private Buffer grow-and-append preparation

Development and release each passed 20 focused native scenarios: seven new
preparation cases plus thirteen lifecycle/allocator regressions. Run
`python -B tools/verify-m2-buffer-failure.py`. Root `fairyc check --locked` passes.
The successful preferred case also closes the published replacement and releases
its usage after native destruction. Every process reports `live=0`; both new
320/384-byte OOM cases fail once and succeed on explicit retry. The archive checks
13 selected inputs, 7 generated sources, SDK lock and both retained executables.
See [contract](docs/engineering/m2-buffer-grow-append.md) and
[Windows receipt](docs/evidence/m2-buffer-grow-append-windows-20261029.json).

This is private runtime preparation. Guest syntax, VM integration, borrow
enforcement and whole-Instance cleanup remain unfinished. Native root publication
still precedes metadata commit and is not atomic with it. Provider fault injection,
full native/CLI suites, M0, Linux, isolation, DLL embedding, packaging and elapsed-time
performance were not run. Earlier receipts retain their original inputs.

## Private Buffer truncate and clear

`fairyc check` passed with a lock refresh, followed by
`python -B tools/verify-m2-buffer-failure.py`: development and release each passed
24 native scenarios (4 truncate, 20 existing regressions). All 48 processes exit
with `live=0`. Each new truncate process records one initial native allocation
and one final free, with no extra allocation during shortening or clear.

The new cases cover `keep` -> `ke` -> `ke!` -> clear -> `new`, close after native
destruction, stale tokens, unrelated-slot preservation, Bounds through
`usize::MAX`, invalid identity/backing/table, generation exhaustion and no-op at
`MAX`, clear to `MAX`, all nine malformed ledger fields without mutation, and
current quota rejection even on shortening/no-op. Capacity and all ledger fields
stay unchanged until explicit close. Clear is logical, not secure erasure.

See [the contract](docs/engineering/m2-buffer-truncate.md) and
[Windows receipt](docs/evidence/m2-buffer-truncate-windows-20261029.json),
which records 14 input hashes, eight generated sources, seven byte-identical production
modules and two retained binaries. No source/test changes followed the pass.
Provider fault injection, full native/CLI suites, M0, Linux, isolation, DLL
embedding, packaging and elapsed-time performance were not run. This private API
does not complete guest syntax, VM integration, borrow enforcement or
whole-Instance cleanup; unexpected SDK mutation on `Provider` is not rolled back.

## Private Buffer resize within retained capacity

Root `fairyc check` passed with a lock refresh (66 sources, 542 MIR functions).
`python -B tools/verify-m2-buffer-failure.py` then passed 28 native scenarios
per development/release profile: four new resize cases plus 24 regressions.
All 56 processes exit with `live=0`. Each new process reports one initial native
allocation and one final free, with no extra allocation for resizing.

Coverage includes preserved prefixes and zeroed suffixes after shrink,
truncate and clear; append reuse and close after native destruction; invalid
token/backing/table; over-capacity requests including `usize::MAX`; generation
exhaustion/no-op/last growth; all nine malformed ledger fields and current quotas.
Capacity, all ledger fields and unrelated slots remain unchanged by resize.

See [the contract](docs/engineering/m2-buffer-resize.md) and
[Windows receipt](docs/evidence/m2-buffer-resize-windows-20261029.json), recording
15 input hashes, nine generated sources, eight byte-identical production modules
and two binaries. Provider fault injection, full native/CLI
suites, M0, Linux, isolation, DLL embedding, packaging and elapsed-time performance
were not run. Guest syntax, VM integration, borrow enforcement and whole-Instance
cleanup remain unfinished; unexpected SDK mutation is not rolled back.

## Private Buffer grow-and-resize preparation

Root `fairyc check` passed with a lock refresh (66 sources, 544 MIR functions).
`python -B tools/verify-m2-buffer-failure.py` then passed 35 native scenarios per
development/release profile: seven grow-resize cases plus 28 regressions. Coverage
includes preferred/minimum growth, both one-shot OOM/retry sizes, abandonment,
growth after truncation and preflight rejection. Full suffix checks pass before
and after commit; old data/token stay valid while pending. Preferred close reaches
0/32 usage after native destruction, preserving peaks; abandonment restores usage
after dropping the replacement and retains peaks. The final fixture confirms a
fresh-token zero read at index 256 and exactly `Token` for an old token with empty
backing; both profiles passed again after those assertions were added.

FY heap counts are two allocation attempts/two frees normally; three
attempts, one failure, two target-size attempts/two frees for OOM/retry; one initial
allocation/one free for preflight; all 70 processes exit with `live=0`.
See [the contract](docs/engineering/m2-buffer-grow-resize.md).
The regenerated [Windows receipt](docs/evidence/m2-buffer-grow-resize-windows-20261029.json)
records the final 16 input hashes, ten generated sources (eight byte-identical
production modules plus `main.fy` and `grow_resize.fy`) and two binaries.
Provider fault injection, full native/CLI suites, M0, Linux, isolation, DLL embedding,
packaging and elapsed-time performance were not run. Guest syntax, VM integration,
borrow enforcement, atomic native publication and whole-Instance cleanup remain
unfinished.

## Private empty Buffer registration

Root `fairyc check` passed with a lock refresh (67 sources, 548 MIR functions).
`python -B tools/verify-m2-buffer-failure.py` then passed 39 native scenarios per
development/release profile: `create-success`, `create-preflight`, `create-state`
and `create-slots`, plus 35 regressions. Coverage includes multiple registrations,
close/re-register accounting and peaks, current quotas, allocated-root rejection,
all nine malformed ledger fields, insufficient existing-table coverage, checked
addition overflow, exact-`MAX` admission and full/retired slots. Registering slot 2
at generation `MAX` then closing retires it at generation zero; further creation
rejects it. Slot and extreme-usage fixtures are synthetic, with no 16 real roots
or giant allocation.

Each new process allocates payload once for its seeded 256-byte root and frees it
once; empty registrations add no allocation.
All 78 processes exit with `live=0`. See [the contract](docs/engineering/m2-buffer-create.md).
The archived [Windows receipt](docs/evidence/m2-buffer-create-windows-20261029.json)
records 18 input hashes, twelve generated sources (nine byte-identical
production modules plus `main.fy`, `grow_resize.fy` and `create.fy`) and two binaries.
Provider fault injection, full native/CLI suites, M0, Linux,
isolation, DLL embedding, packaging and elapsed-time performance were not run.
Guest syntax, VM integration, borrow enforcement, whole-Instance integration and
physical table-memory admission remain unfinished.

## Private Buffer bulk copy-out

Root `fairyc check` passed with a lock refresh (67 sources, 549 MIR functions).
`python -B tools/verify-m2-buffer-failure.py` then passed 43 native scenarios
per development/release profile: `copy-out-success`, `copy-out-bounds`,
`copy-out-identity` and `copy-out-pending`, plus 39 regressions.
All 86 processes exited with `live=0`.

The authoritative `copy_out.fy` success fixture copies all six binary source
bytes (`0..6`) and subrange `1..4`, checks surrounding output canaries and counts,
and accepts empty output at initialized length. Binary coverage includes NUL,
255 and 128. Prefix coverage belongs to the identity case: after append makes
the source seven bytes long, generation `MAX` reads its first six bytes.
Invalid/stale tokens return exactly `Token` before missing-backing checks;
bad backing metadata and malformed table state return `State`.
Rejected identity/state and `MAX`/oversized/end range calls preserve output.

A real `prepare_resize` keeps old-root bytes readable while pending, without
changing reserved usage. Dropping the replacement before cancel restores
Instance/Engine usage 320/352 and retains peaks 768/800; the old root remains
readable after cancellation. FY heap counts are one initial allocation/one free
for each of the first three new cases and two allocations/two frees for the
pending case. Copy-out itself adds no allocation and leaves token/generation,
owner metadata and ledger unchanged.

See [the contract](docs/engineering/m2-buffer-copy-out.md) and the archived
[Windows receipt](docs/evidence/m2-buffer-copy-out-windows-20261029.json).
The receipt records 19 input hashes, 13 generated sources (nine byte-identical
production modules plus `main.fy`, `grow_resize.fy`, `create.fy` and `copy_out.fy`)
and two binaries. Final source and test inputs were unchanged after the pass.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider fault injection were not run.
Native root association and non-aliasing remain trusted caller obligations;
guest Buffer/VM integration and guest borrow enforcement remain unfinished.

## Private Buffer writes within initialized length

Root `fairyc check` passed with a lock refresh (68 sources, 550 MIR functions).
`python -B tools/verify-m2-buffer-failure.py` then passed 47 native scenarios per
development/release profile: `write-success`, `write-bounds`, `write-identity`
and `write-state`, plus 43 regressions. All 94 processes exited with `live=0`.

The authoritative `write.fy` fixture writes `[0,254,129]` at index 1, preserving
input and the outside prefix/suffix, then writes `[255,0,128,1,2,3]` across the
whole initialized range. Exact counts, empty input at the end and full copy-out
verify binary content. Rejected `MAX`/oversized/end ranges preserve the root.
Invalid/stale identity returns exactly `Token` before missing-backing checks;
bad backing metadata and malformed table state return `State`.
Generation `MAX` permits content writes without advancing generation.

The state case rejects corruption of each of the nine ledger fields without
changing content or the supplied ledger. Instance quota rejects a content write;
Engine and object quotas reject empty writes. A real pending replacement rejects
both content and empty writes with `State`, preserving old-root content,
the prepared prefix and reserved usage. Dropping the replacement before cancel
restores Instance/Engine usage 320/352 while retaining peaks 768/800.
FY heap counts are one initial allocation/one free for each of the first three
new cases and two allocations/two frees for the state case.
Writes themselves add no allocation and leave length, capacity, token/generation,
table and ledger unchanged.

See [the contract](docs/engineering/m2-buffer-write.md) and the archived
[Windows receipt](docs/evidence/m2-buffer-write-windows-20261029.json).
The receipt records 21 input hashes, 15 generated sources (ten byte-identical
production modules plus `main.fy`, `grow_resize.fy`, `create.fy`, `copy_out.fy`
and `write.fy`) and two binaries. Final inputs were unchanged after the pass.
Full native/CLI suites, M0, Linux, DLL embedding, isolation, packaging,
elapsed-time performance and Provider fault injection were not run.
Native input non-aliasing and root association remain trusted caller obligations.
The pending-write guard belongs to `within_length`; raw `owners::write` remains
a lower-level API whose trusted callers must follow the transaction protocol.
Guest Buffer/VM integration and guest borrow enforcement remain unfinished.
