# Toolchain Setup

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
