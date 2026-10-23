# Development

- Status: M0 verified; experimental native M1 scalar CLI implemented; bool/branch, loop, tagged, `?`, and switch-expression slices have verified historical receipts; i64 implemented and verified with 49 native groups and 760 CLI cases
- Current repository content: Fairy C frontend, private IR/verifier/VM, CLI, tests, and M0 probes

## Current reality

The root fairy.toml builds `src/main.fy` into `build/browniec.exe` on Windows.
Use an installed MSVC x64 toolchain and Windows SDK at build time. The retained
M0 compiler artifact is `build/toolchain/fairyc.exe`: Fairy C `4ce12642`, SDK
`0.0.0-stage0.86`, language `fairyc-language/20`. Its SHA-256 and build identity
are recorded in the dated M0 and M1 evidence, not a permanent compatibility pin.

If no compiler artifact is available, build a selected clean Fairy checkout:

```powershell
Push-Location ../fairyc
go build -mod=readonly -trimpath -o ../browniec/build/toolchain/fairyc.exe ./cmd/fairyc
Pop-Location
```

An updated compiler is an explicit adoption: run the relevant compatibility checks
and record the resulting identity. Do not silently rebuild from a concurrently edited
checkout or claim it matches the historical receipts.

```powershell
./build/toolchain/fairyc.exe build
./build/browniec.exe run examples/answer.brc --json
./build/browniec.exe check examples/answer.brc --json
./build/browniec.exe run examples/branches.brc --json
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
./build/browniec.exe run examples/tagged.brc --json
./build/browniec.exe run examples/propagation.brc --json
./build/browniec.exe run examples/switch-expression.brc --json
./build/browniec.exe run examples/i64.brc --json
pwsh -NoProfile -File tools/verify-m1.ps1
```

M1 verification needs PowerShell 7 and Python 3 for the build/test driver, not for the
produced runtime. The switch-expression receipt is historical after the i64
increment and records 41 native groups and 580 CLI cases. The current
[i64 receipt](docs/evidence/m1-i64-windows-20261023.json) records 49 native groups
and 760 CLI cases in each profile. The loop, branch, function, local, tagged, and
propagation receipts remain historical. Verification retains
`build/m1/receipt.json` and per-profile records. The selected native binaries run
with a cleared environment and tool-free PATH. No measured latency budget follows.

The unchanged `probes/m0` and `tools/verify-m0.ps1` retain their separate native
primitive/OOM/borrow evidence. Rerun those when their inputs change; the M1 source
pipeline is not a reason to repeat the unchanged M0 suite.

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
3. Build the bounded scalar source-to-VM path, including i64 values, bool values, branches, loops, shallow tagged values, switch statements and expressions, and scalar `?` propagation.
4. Add arrays, structs, borrows, Buffer, and text through small end-to-end cases.
5. Add typed host suspension only after the pure path is stable.
6. Add Windows process isolation before exposing the restricted delivery level.
7. Add DLL export and clean-machine packaging before exposing embed delivery.

M0 and M1 are not blocked by the later Windows worker or DLL milestones.

## Command inventory

`browniec check SOURCE [--json]`, `run SOURCE [--fuel N] [--json]`,
`--version [--json]`, and `--help` are implemented for the scalar subset.
`inspect`, `worker`, `--project`, and guest input/policy configuration remain
unimplemented. `--isolated` fails explicitly; there is no unrestricted fallback.
See [M1 details](docs/engineering/m1-scalar-slice.md) and the
[branch](docs/engineering/m1-branches.md), [loop](docs/engineering/m1-loops.md), and
[tagged](docs/engineering/m1-tagged.md) contracts, plus the
[propagation](docs/engineering/m1-propagation.md) and
[switch-expression](docs/engineering/m1-switch-expressions.md) contracts and the
[i64](docs/engineering/m1-i64.md) contract. The current i64 receipt is
[m1-i64-windows-20261023.json](docs/evidence/m1-i64-windows-20261023.json).

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
