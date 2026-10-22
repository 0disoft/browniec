# Development

- Status: M0 native probes verified; Brownie runtime not implemented
- Current repository content: design documents, M0 Fairy C probes, and a verification harness

## Current reality

`probes/m0` contains the native primitive sources, `fairy.toml`, `fairy.lock`, a
test-only allocator probe header, and four negative borrow/move fixtures. The harness
is `tools/verify-m0.ps1`. There is no Brownie lexer, parser, checker, verifier, VM,
worker, DLL, or installed `browniec` command.

The M0 record uses Fairy source `4ce1264273be6051ee560173e94690e1b99c9eaf`, SDK
`0.0.0-stage0.86`, language `fairyc-language/20`, Windows x64 MSVC, MSVC tools
`14.51.36231`, `cl` `19.51.36248.0`, Windows SDK `10.0.26100.0`, and Go `1.27.1`.
The compiler was built from a clean checkout with SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`.
This is a dated record, not a permanent compiler pin. The harness validates the
requested checkout against the compiler build identity.

From the Brownie C repository root, build the requested Fairy compiler and run the
M0 harness:

```powershell
Push-Location ../fairyc
go build -mod=readonly -trimpath -o ../browniec/build/toolchain/fairyc.exe ./cmd/fairyc
Pop-Location
pwsh -NoProfile -File tools/verify-m0.ps1
```

The harness builds development and release variants, then runs them with an empty
runtime `PATH` and a cleared environment. It runs the normal baseline and the
instrumented normal and allocator failure paths, for six native executions total. It
also checks four negative borrow/move fixtures. Exact results are in
`build/m0/receipt.json` and `docs/evidence/m0-windows-20261023.json`.

## Bootstrap versus runtime

The fairyc toolchain may use Go to build the compiler or stage-0 infrastructure.
That does not make Go part of the produced Brownie VM.

The finished native executable must:

- start on a machine without a Go runtime;
- accept Brownie source directly;
- avoid launching MSVC, clang, gcc, Go, or another compiler while compiling or running;
- load no external bytecode or disk runtime code cache.

Build-machine prerequisites and end-user runtime prerequisites are separate records.
An empty runtime `PATH` in the harness does not prove that a clean machine can run
Brownie. Clean-machine validation and sandbox behavior belong to later milestones.

## Working sequence

1. Keep the recorded M0 signatures and rerun the native probes when their inputs change.
2. Record any M0 failure without promoting it to VM evidence.
3. Build one scalar source-to-VM path before broad language support.
4. Add arrays, structs, borrows, Buffer, and text through small end-to-end cases.
5. Add typed host suspension only after the pure path is stable.
6. Add Windows process isolation before exposing the restricted delivery level.
7. Add DLL export and clean-machine packaging before exposing embed delivery.

M0 and M1 are not blocked by the later Windows worker or DLL milestones.

## Command inventory

`tools/verify-m0.ps1` is runnable for the M0 probes. The proposed `browniec check`,
`run`, `inspect`, and `worker` commands, with `--project` and `--isolated` options
where applicable, describe intended CLI behavior only.

Documentation review may use repository-neutral tools such as a Markdown link check
or git diff --check when the parent task supplies them. These checks do not execute
the language or prove a runtime contract.

## Build and cache hygiene

The default retained output should be the final binary, the embed DLL when available,
and a small build receipt. Generated C, objects, response files, and link scratch
should be removed after success.

Failure diagnostics may be retained only in a bounded explicit bundle. Caches need a
size limit, eviction, and invocation-specific scratch files. Do not create idle
pollers, garbage-collection cycles, or background cache maintenance.

Developer toolchain installs, fairyc Go build caches, Brownie project outputs, OS page
cache, process memory, and VM ledgers are different measurements and must stay labeled.

## Dependency changes

Prefer existing project-owned or platform capability. Record the need, alternatives,
license, consumer impact, and removal path before adding a dependency.

Use major-version ranges and reproducible locks or build IDs for compatible updates.
Promote a new major only after a narrow compatibility check. Pre-stable Fairy
semantic changes require explicit source corpus review.

## Evidence handoff

Every milestone result should name the artifact, environment, commands, observed
result, skipped checks, and remaining risk. A failed probe stays failed; a missing
compiler is skipped, never passed. See VALIDATION.md and docs/design-baseline.md.
