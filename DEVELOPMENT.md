# Development

- Status: Bounded M1 and public M2 scalar/aggregate/scalar-slice subsets; full runtime/delivery pending (2026-11-03)
- Current repository content: Fairy C frontend, private IR/verifier/VM, CLI, tests, and M0 probes

Current capability omissions and full-profile work are tracked in the
[remaining-work audit](docs/product/04-remaining-work.md); use the
[roadmap](docs/product/01-roadmap.md) for implementation order. Dated increment
receipts are scoped evidence, not an accumulated full-suite pass.

## Current reality

The root fairy.toml builds `src/main.fy` into `build/browniec.exe` on Windows. Use
an installed MSVC x64 toolchain and Windows SDK for that Brownie build. The build
toolchain uses Fairy C provisioned from the reviewed [toolchain.json](toolchain.json)
manifest with Python 3.10+. No globally installed Fairy C compiler is required.
See the [toolchain setup contract](docs/engineering/toolchain-setup.md) for the full
input, validation, and evidence boundary.

From the repository root, provision or reuse the pinned compiler:

```text
python3 tools/setup-toolchain.py
```

Use the Python 3.10+ launcher available on the host; on Windows, `py -3` can invoke
the same script. With no arguments, setup verifies and reuses
`build/toolchain/fairyc.exe` when its SHA-256 and complete compiler identity match.
An invalid cache fails without replacement. A missing cache builds the exact source
revision in `toolchain.json` in isolated scratch. A local `../fairyc` checkout supplies
that revision when present; the reviewed HTTPS Git URL is the fallback. The checkout's
current HEAD, changes, and imports are not used as the compiler.

To import an exact executable that was verified elsewhere, supply its path:

```text
python3 tools/setup-toolchain.py --compiler-file path/to/fairyc.exe
```

To force a source build from an explicit local checkout, use:

```text
python3 tools/setup-toolchain.py --source-repository ../fairyc
```

`--compiler-file` and `--source-repository` are mutually exclusive. The source option
builds the pinned exact revision rather than reusing or importing an existing binary.
Source bootstrap requires `go1.27.1` to be installed separately, plus Git, access
to the selected repository, and its Go module dependencies. Setup performs no
system-wide installation and does not install Go or Git; a successful run provisions
only the selected host binary under `build/toolchain`. Source-bootstrap Go and Git
child processes use a sanitized environment with Go toolchain switching disabled; the
parent environment is unchanged.

Setup checks the candidate SHA-256 before executing it, then checks the full
`--version` identity: compiler version, revision, SDK, language, runtime ABI, and
unmodified status. It also requires the SDK and language adoption in `fairy.lock` to
agree with the manifest. Those static checks precede cache and receipt initialization.
Afterward, only a validated candidate atomically replaces the cache. A failed fetch,
build, hash, or compiler-identity check leaves a valid existing compiler intact,
writes a failed setup receipt, and removes its own scratch directory.

The Windows host writes `build/toolchain/fairyc.exe`. The Linux host writes
`build/toolchain/fairyc`; the manifest pin for Linux was produced by a Windows
Go 1.27.1 cross-build with CGO disabled at the exact revision. Its SHA-256 is
`5c9e50e6b6ea45060a1b1511ab4b7c11fb9d6cc3939f65337970a6dfdc417b9b`; see the
[cross-build receipt](docs/evidence/toolchain-linux-cross-build-20261025.json).
Native Linux source bootstrap, binary import, execution, and Brownie CLI build/runtime remain
`UNVERIFIED`; no usable local Linux runtime is currently available. On Linux, use
`python3 tools/setup-toolchain.py`; no actual Linux setup execution is claimed here.

The Windows compatibility wrapper remains available for existing automation:

```powershell
pwsh -NoProfile -File tools/setup-toolchain.ps1
```

It forwards `-CompilerFile` and `-SourceRepository` to the Python implementation.
The [portable Windows receipt](docs/evidence/toolchain-portable-windows-20261025.json)
records 11 passing `python -B tools/verify-toolchain.py` cases, including cache reuse,
failure rejection, source reproduction, host selection, unsupported-host rejection,
and unchanged parent-environment behavior. `tools/verify-toolchain.ps1` is the Windows
wrapper. The older [2026-10-24 Windows receipt](docs/evidence/toolchain-windows-20261024.json)
is retained as historical evidence for the previous setup path.

This manifest covers reproducible project adoption. `fairy.lock` records SDK and
source identity; it is not a compiler installer. There is no automatic update
discovery or ZIP download endpoint. Git tracks the manifest and Python setup tools;
the generated compiler cache remains ignored.

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
./build/browniec.exe run examples/unsigned.brc --json
./build/browniec.exe run examples/widening.brc --json
./build/browniec.exe run examples/bitwise.brc --json
./build/browniec.exe run examples/switch-arm-statements.brc --json
pwsh -NoProfile -File tools/verify-m1.ps1
```

M1 verification needs PowerShell 7 and Python 3 for the build/test driver, not for the
produced runtime. The switch-expression receipt is historical after the i64
increment and records 41 native groups and 580 CLI cases. The
[i64 receipt](docs/evidence/m1-i64-windows-20261023.json) is historical after the
unsigned increment and records 49 native groups and 760 CLI cases in each profile.
The loop, branch, function, local, tagged, and propagation receipts also remain
historical. The [unsigned receipt](docs/evidence/m1-unsigned-windows-20261023.json) records
59 native groups and 1,159 CLI cases in both development and release, including 399
unsigned cases, and remains historical after explicit widening. The
[widening receipt](docs/evidence/m1-widening-windows-20261023.json) records
67 native groups and 1,272 CLI cases in each profile, including 113 widening cases.
Verification retains
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
3. Build the bounded scalar source-to-VM path, including i32, i64, u8, u32, usize, and bool values, explicit widening, branches, loops, shallow tagged values, switch statements and expressions, and scalar `?` propagation.
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
[i64](docs/engineering/m1-i64.md) and
[unsigned](docs/engineering/m1-unsigned.md) contracts and the
[widening](docs/engineering/m1-widening.md) and
[integer-operator](docs/engineering/m1-integer-operators.md) contracts. The i64,
unsigned, and widening receipts remain historical for their slices. The
[integer-operator receipt](docs/evidence/m1-integer-operators-windows-20261023.json)
is historical and records 75 native groups and 1,898 CLI cases in each
development and release profile, including 626 new bitwise/shift cases.
The [arm-statement contract](docs/engineering/m1-switch-arm-statements.md) adds
structured statements inside switch-expression arms. Its
[receipt](docs/evidence/m1-switch-arm-statements-windows-20261023.json) records the
current verified subset: 81 native groups and 1,969 CLI cases in each development
and release profile, including 71 new arm-statement cases.

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
