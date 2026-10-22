# Brownie C

- Status: accepted design baseline; M0 native primitives verified; Brownie VM not implemented
- Design date: 2026-10-23
- First delivery target: Windows 11 x64

Brownie C is a small, statically typed source language and JIT-free bytecode VM.
The implementation direction is primarily Fairy C. A native Brownie VM executable
accepts .brc source and runs it without starting Go, MSVC, or a C compiler.

This repository contains the design documents, the `probes/m0` Fairy C feasibility
sources, a test allocator header, and `tools/verify-m0.ps1`. It does not contain a
Brownie lexer, parser, type checker, verifier, VM, worker, DLL, or public `browniec`
command.

## Product intent

The first expected workloads are application data validation, byte transforms, and
rule evaluation. They are starting assumptions, not evidence that Brownie C should
replace a general-purpose language such as Python.

The first profile provides:

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
| core | Source compile, verify, and native VM CLI | M0 native primitives verified; M1-M3 not implemented |
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
- [Product specification](docs/product/02-spec.md): observable first-profile behavior
- [Roadmap](docs/product/01-roadmap.md): M0 through M5 delivery gates
- [Design baseline](docs/design-baseline.md): source provenance, evidence, and findings

The expanded M0 run exercises arithmetic, codecs, storage, allocator, owner, and
frame primitives on Windows x64. Exact commands and results belong to
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`. Running with an
empty runtime `PATH` does not establish clean-machine packaging or a sandbox.

ABI, Windows isolation, source execution, performance, and security claims remain
unverified until their milestones record reproducible evidence.
