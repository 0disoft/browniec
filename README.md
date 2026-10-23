# Brownie C

- Status: experimental M1 scalar source CLI implemented; earlier slices and unsigned scalars have verified historical receipts; explicit integer widening historically verified; integer operators historically verified; switch-arm statements implemented and verified; full M1 remains partial
- Design date: 2026-10-23
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

The native `browniec` compiles and runs the experimental `brownie.m1-scalar/1`
pipeline. The bool/branch increment extends its i32 functions with bool parameters,
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
conformance remains unverified; arrays, structs, workers, and DLLs remain later work.

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
# return_i32 is 42; process exit is 0
pwsh -NoProfile -File tools/verify-m1.ps1
```

See [Development](DEVELOPMENT.md) for build prerequisites. This CLI is for trusted
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
| core | Source compile, verify, and native VM CLI | Experimental i32/i64/u8/u32/usize/bool expressions, explicit widening, branches, loops, shallow tagged values, switch statements and expressions, and `?` propagation; M1 partial |
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
No full-profile
conformance, DLL ABI, Windows isolation, clean-machine packaging, or performance
target is claimed.
