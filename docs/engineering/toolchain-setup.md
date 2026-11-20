# Toolchain Setup

## Windows release build

The unpatched preview.2 compiler sends the whole Brownie CLI to one MSVC
translation unit: 22,658,625 bytes and 2,198 generated functions. The optimized
compiler process exceeds Fairy C's 60-second command deadline before an
executable is published. The existing C partitioner's default 2 MiB groups
also time out on the eighth unit with this project.

The Windows pin now builds the same Fairy C revision with the
[release patch](../../tools/fairyc-windows-release.patch). Optimized console
builds use the existing function-boundary partition emitter with a 512 KiB
target per group and one shared header. Fairy C invokes MSVC with /O2 and links
once. Each invocation keeps its existing 60-second limit; the complete build
can take longer. Windows application builds configured by `fairy.windows.json`
also use the partitioner in development and release and link their declared native
sources and libraries with the generated objects. The default stack and SDK
remain unchanged. Diagnostic tests and Linux retain their existing build routes.

Current Windows compiler SHA-256:
`2ef3100b7726d49c8eff4fb1b3f8420d2561ccb718bca5c0db21eb7150d11089`.
Current patch SHA-256:
`57ad69258c4d682b449ac3b437ac2664ab32f47dfad603355a33618ae57ef4cc`.

With Git and Go 1.27.1 on PATH, bootstrap in the Brownie checkout and build:

    python -B tools/setup-toolchain.py --from-source
    ./build/toolchain/fairyc.exe build --release --locked
    ./build/browniec.exe run examples/answer.brc --json

Setup fetches the exact source commit and checks the patch SHA-256. In the
disposable checkout it creates a local version tag for Go metadata and applies
the patch. The public release tag can point to a different commit. Setup checks
the resulting executable SHA-256 before running or installing it. The compiler reports v0.1.0-preview.2+dirty and
modified: true. The unpatched preview ZIP is a historical artifact. A matching
rebuilt binary may be provisioned with --compiler-file. The SDK identity is
unchanged. The Brownie retained dispatcher also separates return handling
and bulk-work startup from the instruction loop; the unchanged dispatcher
still timed out at 512 KiB. Fuel debit, continuation order, and return
publication stay in their existing order.

The official release build passed in 191.1 seconds with 46 generated units
(maximum 524,218 bytes, plus a 670,726-byte shared header). The answer example
returned 77 with exit 0, one JSON line and empty stderr. The same binary passed
72 public Program checks; the compiler passed 13 provisioning cases. See the
[Windows release evidence](../evidence/windows-release-build-20261119.json).

## Historical Windows preview.2 adoption (2026-11-16)

Windows now uses compiler v0.1.0-preview.2 at
801c5d8caa64d19aab8925763d6bf07f65f26418 with SDK 0.0.0-stage0.87.
The SDK public version, language /20 and runtime ABI /0 are unchanged.
The executable SHA-256 is
7665c8203ae9ed8397b013770fc53e57eb37d1f3d4c236bcd77983e570bad836.
This is a local preview candidate, not a published GitHub release. Import it with:

    python -B tools/setup-toolchain.py --compiler-file ../fairyc/.cache/starter-smoke-C8Fn38/extracted/fairyc.exe

The manifest records the matching ZIP checksum and the actual Go 1.27.1 recipe:
-mod=readonly, -trimpath, and -ldflags=-s -w. Isolated source bootstrap fetches
the exact commit and local preview.2 tag, checks that the tag resolves to that
commit, and reproduces the executable checksum. The two embedded C inputs
internal/cstdlib/stage0_linux_directory.c and stage0_linux_directory_paths.c
retain the distribution checkout's CRLF. Only the isolated bootstrap checkout
receives this normalization. Git renormalization must leave its index identical
to the pinned commit and its status clean; no original Fairy C files are edited.
Earlier LF-only reconstruction attempts differed and are excluded from passes.

The root lock's SDK source digest is now
fysrc1-sha256-9358b8ed205e6dc34dd58b7639b070a94b0aabd7a9636381b6d6bbb4b9d2897b.
The M0 dependency selection produces an unchanged lock and passes locked check;
it does not import the same SDK module closure as the root. Neither result is an
SDK version bump. The old compiler and setup metadata remain under
build/toolchain-preview2-adoption/previous for rollback.

Linux retains its prior compiler identity, SDK digest, recipe, executable hash
and cross-build-only status as platform overrides. These are historical pins,
not preview.2 artifacts or new Linux verification. Setup uses the selected host's
identity and still rejects an SDK/lock mismatch; the retained Linux pin cannot
silently adopt the new Windows root lock. A separate Linux adoption is required.

Windows verification passed twelve provisioning cases, including file import,
reuse, rejection before execution, host-specific identity rejection, exact source
reproduction and environment sanitation. Root check and locked check pass with
375 sources / 4096 MIR functions. A fresh development Brownie CLI build returns
77 in a tool-free runtime environment. One focused root-append native group
passes in each development/release profile, covering 240 original-preflight
comparisons per profile over sixteen roots, growth, both source vector orders,
leases and rejection boundaries. Native mirrors use ten unchanged production
modules plus the unchanged test fixture; this is not the full runtime suite.

No Brownie production/test source, screen or keyboard input test, Linux build,
full release gate, remote tag, push or deployment is part of this adoption.
See the [Windows evidence](../evidence/toolchain-preview2-windows-20261116.json).

## Historical adoption (2026-10-31)

- Status: completed-with-known-baseline-failure; toolchain adoption and focused verification are complete

`toolchain.json` is the reviewed compiler manifest and the authority for current
hashes. It records compiler revision
`eb274643bfcfe746617121ddc6f130b018978b53`
(`v0.0.0-20261031093456-eb274643bfcf`) with SDK `0.0.0-stage0.87`. Language
`fairyc-language/20` and runtime ABI `fairyc-runtime/0` are unchanged.

`toolchain.json`, `fairy.lock`, and `probes/m0/fairy.lock` were adopted together
in commit `465e380`. The compiler, SDK, root lock, and M0 lock form one reviewed
state; mixing metadata from different states is a setup error.

The repository Python 3.10+ setup script provisions only the selected host compiler
under `build/toolchain`. It does not install Go or Git system-wide, rewrite the
manifest, install dependencies into the Brownie checkout, or modify the fairyc
source checkout.

## Adopted artifacts

The `browniec.toolchain/v2` manifest records the source recipe and one executable
per host.

| Host | Artifact | SHA-256 | Result |
| --- | --- | --- | --- |
| Windows AMD64 | `build/toolchain/fairyc.exe` | `9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a` | Installed; exact-source reproduction and 11 provisioning cases passed |
| Linux AMD64 | `build/toolchain-upgrade/fairyc` | `619511bb8f98f5bd9ec543cfb33f6367de15fc2389d41b27506790234f4f93d6` | Windows cross-build completed; ELF64/x86-64 and embedded Go metadata verified |

`build/toolchain/fairyc` is only the selected Linux-host setup output and is not
installed here. The retained Windows-built Linux artifact is
`build/toolchain-upgrade/fairyc`.

The SDK source digest is
`fysrc1-sha256-c531e88e52b684a34cf9688eda19e5cafcc5788e7a4bbf7e5121e86874a7246a`.
Its identity, version, language, runtime ABI, and digest agree with both locks.

## Executed installation

The Windows compiler was installed with this Python command:

```text
python -B tools/setup-toolchain.py --compiler-file build/toolchain-upgrade/fairyc.exe
```

The PowerShell setup wrapper was not run. Setup checked the full hash and compiler
identity before replacing the cache.

Go 1.27.1 with `CGO_ENABLED=0` completed isolated exact-source builds on Windows
and Linux using `-mod=readonly`, `-trimpath`, and `-buildvcs=true`. Windows source
reproduction matched the manifest identity and hash. Linux is cross-build and
static verification only: no native Linux test or Brownie CLI run was performed.

## Validation and M0

All 11 Windows provisioning tests passed, including exact isolated Windows source
reproduction, import and reuse, rejection before execution, host selection,
unsupported-host rejection, and sanitized child environments. Setup wrote
`build/toolchain/setup-receipt.json` and removed only its isolated scratch tree.

`probes/m0/fairy.lock` moved with the main lock. The M0 source and `fairyc check
--locked` checks passed with 17 sources and 203 MIR. M0 runtime was not tested.
No Brownie `.fy` source file was edited for this adoption, and no automatic toolchain
updater was added. The eventual major-track update preference is unchanged.

## Final verification

| Check | Development | Release |
| --- | --- | --- |
| Native Brownie tests | 9/9 passed | 9/9 passed |
| Full M1 CLI | `arm-depth-mixed-10` baseline failure, excluded | 1,969 passed |
| Five M2 CLI matrices | 526 passed | 526 passed |
| CLI total | 526 M2 passes; no M1 pass total | 2,495 passed |

The development M2 counts are `array-call-reads` 106, `struct-call-reads` 102,
`slice-parameter-source` 74, `alias` 120, and `sub` 124. Release uses the same
526 M2 cases: 1,969 M1 cases plus 526 M2 cases gives 2,495 passing CLI cases.
The development M1 failure is excluded from every pass total and is not a waiver.

The ignored orchestrator `python -B build/toolchain-upgrade/verify.py` built both
profiles and ran the matrices. The native runs were two direct commands per profile,
not the existing combined harness selections:

```text
build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/slice_frame_vm.fy
build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/mixed_call_vm.fy
build/toolchain/fairyc.exe test --native --capture-output --json --locked --release --file tests/m2/slice_frame_vm.fy
build/toolchain/fairyc.exe test --native --capture-output --json --locked --release --file tests/m2/mixed_call_vm.fy
```

These commands cover four `slice_frame_vm` groups and five `mixed_call_vm` groups,
nine groups per profile. During source-cache recovery, the immediately preceding
validated native reports were reused because tracked inputs and compiler were
unchanged. The release CLI commands were:

```text
python -B tools/check-m1-cli.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
python -B tools/check-m2-array-call-reads.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
python -B tools/check-m2-struct-call-reads.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
python -B tools/check-m2-array-slice-parameter-source.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
python -B tools/check-m2-array-slice-alias.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
python -B tools/check-m2-array-slice-sub.py --exe build/toolchain-upgrade/release/browniec.exe --profile release
```

Development repeats the five M2 commands with the development executable and
profile. Its full M1 run aborted at `arm-depth-mixed-10` with Windows exit
`0xC00000FD` (`3221225725`, stack overflow).

## Known baseline failure

The retained old image and rebuilt `eb274643bfcf` image both reproduced the same
failure. The old Brownie hash
`6c434257a03f997c7ca5ff2a1c1f5c5a702f070cd023a68ecd4912c952a7e9ca` matches the
[committed prior slice-frame evidence](../evidence/m2-array-slice-frame-vm-windows-20261031.json),
which identifies compiler `4ce1264273be`. All 80 Brownie `src/*.fy` files match
the current bytes; the 87-source check includes those 80 files plus seven SDK files.

The upgraded development image was also run with
`build\toolchain-upgrade\development\browniec.exe check build\m1\development\arm-depth-mixed-10.brc --json`.
It returned `3221225725` with no guest VM execution, isolating the failure to the
frontend parser path. `build/toolchain-upgrade/known-stack-failure.json` records the
exact source, old and rebuilt image hashes, both exits, the 80-file match, and
`checkOnly`. Exact old and rebuilt image hashes also live in the final evidence
instead of this document, because a fresh native rebuild changed the new image PE
hash while the compiler executable hash stayed identical.

The Brownie parser behavior was not changed by this adoption. No parser source
edit was made here. The later [parser stack containment](m1-parser-stack.md)
fixes the reproduced failures and records successful development/release CLI
checks separately. The adoption evidence retains its original result.

## Evidence

[Final Windows adoption record](../evidence/toolchain-upgrade-windows-20261031.json)
has status `completed-with-known-baseline-failure` and records the successful
builds, provisioning, M0 checks, native results, CLI counts, and known baseline
failure.

Historical references:
[2026-10-24 provisioning](../evidence/toolchain-windows-20261024.json) and
[2026-10-25 Linux cross-build](../evidence/toolchain-linux-cross-build-20261025.json).
They describe earlier toolchain states and do not provide evidence for this revision.
