# Brownie C

- Status: experimental M1 scalar source CLI implemented; full M1 remains partial
- Design date: 2026-10-23
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

The native `browniec` now compiles and runs the experimental `brownie.m1-scalar/1`
subset: i32 functions with by-value arguments, initialized let/var locals, plain assignment,
integer literals, parentheses, unary minus, and
`+ - * / %`. Parsing, scalar type checks, private bytecode generation, independent
verification, and VM dispatch are Fairy C. Fuel bounds executed instructions.
Direct calls and bounded VM recursion work; branches, tagged values, other scalar
types, workers, and DLLs remain future work.

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
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
| core | Source compile, verify, and native VM CLI | Experimental i32 expressions/locals check/run; M1 partial; M2-M3 not implemented |
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
- [M1 scalar slice](docs/engineering/m1-scalar-slice.md): implemented grammar, limits, and CLI
- [Product specification](docs/product/02-spec.md): observable first-profile behavior
- [Roadmap](docs/product/01-roadmap.md): M0 through M5 delivery gates
- [Design baseline](docs/design-baseline.md): source provenance, evidence, and findings

The expanded M0 run exercises arithmetic, codecs, storage, allocator, owner, and
frame primitives on Windows x64. Exact commands and results belong to
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`. Running with an
empty runtime `PATH` does not establish clean-machine packaging or a sandbox.

The M1 Windows run passed twelve native test groups and 143 black-box CLI cases in each
of development and release. The [dated receipt](docs/evidence/m1-functions-windows-20261023.json)
records toolchain, source, and artifact identities. No full-profile conformance,
DLL ABI, Windows isolation, clean-machine packaging, or performance target is claimed.
