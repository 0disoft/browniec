# Toolchain Setup

- Status: setup and portable Windows verification passed; Linux native execution remains unverified

`toolchain.json` is the reviewed compiler manifest, and `fairy.lock` records the
SDK and language adoption. Provisioning uses the repository's Python 3.10+ setup
script. It performs no system-wide installation and does not install Go or Git; a
successful run provisions the selected host compiler only under `build/toolchain`.
It does not update the manifest or modify the source checkout.

## Hosts and outputs

The selected host determines the target; callers cannot override it for another
platform. The manifest schema is `browniec.toolchain/v2` and records the compiler
version and revision, SDK identity/version/source digest, language, runtime ABI,
bootstrap recipe, and one executable plus SHA-256 and verification label for each
platform.

| Host | Manifest target | Output | Verification label |
| --- | --- | --- | --- |
| Windows AMD64 | `windows/amd64` | `build/toolchain/fairyc.exe` | `native-verified` |
| Linux AMD64 | `linux/amd64` | `build/toolchain/fairyc` | `cross-build-only` |

The Windows executable keeps the 2026-10-24 pinned SHA-256. The Linux executable has
SHA-256 `5c9e50e6b6ea45060a1b1511ab4b7c11fb9d6cc3939f65337970a6dfdc417b9b`. It was
cross-built on Windows with Go 1.27.1, `CGO_ENABLED=0`, the exact manifest revision,
and the reviewed module/trimpath/VCS flags. The repeat cross-build and owned-source
cleanup passed, and the [receipt](../evidence/toolchain-linux-cross-build-20261025.json)
records ELF64/x86-64 and Go build metadata. Native Linux bootstrap, binary import,
execution, and Brownie CLI build/runtime remain `UNVERIFIED`; there is currently no
usable local Linux runtime for those checks.

## Commands

Run from the repository root. Use the Python 3.10+ launcher available on the host.

```text
# Verify and reuse the selected host's cache; build the exact revision if missing.
python3 tools/setup-toolchain.py

# Import an exact local binary for the selected host.
python3 tools/setup-toolchain.py --compiler-file path/to/fairyc

# Force a source build from an explicit local checkout.
python3 tools/setup-toolchain.py --source-repository ../fairyc
```

`--compiler-file` and `--source-repository` are mutually exclusive. Without either
option, a valid cache is reused, an invalid cache fails, and a missing cache triggers
a source bootstrap. `--source-repository` always selects that source-build path; it
does not reuse the cache or import a binary.

Source bootstrap requires Go 1.27.1, Git, the selected source repository, and its Go
module dependencies. Setup fetches the exact manifest revision into its own isolated
scratch checkout, requires that checkout to be clean at the expected revision, and
does not modify the source checkout. Source-bootstrap Go and Git child processes
receive a copied, sanitized environment with Go toolchain switching disabled; setup
does not mutate the parent environment.

The Windows compatibility wrapper preserves the existing option names:

```powershell
pwsh -NoProfile -File tools/setup-toolchain.ps1
pwsh -NoProfile -File tools/setup-toolchain.ps1 -CompilerFile path/to/fairyc.exe
pwsh -NoProfile -File tools/setup-toolchain.ps1 -SourceRepository ../fairyc
```

The wrapper translates those options to `--compiler-file` and `--source-repository`
and otherwise delegates to the Python script. On Linux, invoke the Python script
directly:

```text
python3 tools/setup-toolchain.py
```

That path writes `build/toolchain/fairyc` and does not change the host selection.
This contract does not claim that the Linux invocation has been executed.

## Validation and replacement

Setup validates the manifest and requires its SDK identity, SDK version, language,
runtime ABI, and SDK source digest to agree with `fairy.lock` first. Invalid static
metadata is rejected before cache or receipt initialization. For every candidate,
setup checks the complete SHA-256 before executing the file, then runs `--version` and
requires exact compiler version, revision, SDK, language, runtime ABI, and
`modified: false` identity. A mismatch fails setup.

Only a fully validated candidate replaces the cache. Replacement is atomic, and a
failed fetch, build, hash, or identity check preserves a valid existing compiler.
After static validation, setup writes `build/toolchain/setup-receipt.json` and removes
only its own isolated scratch directory. It makes no system-wide installation and
does no automatic version update.

## Verification evidence

`python -B tools/verify-toolchain.py` passed 11 Windows native provisioning cases on
2026-10-25. The [receipt](../evidence/toolchain-portable-windows-20261025.json)
covers executable import/reuse, rejection before execution, exact source reproduction,
host selection logic, unsupported-host rejection, and sanitized child environment
without parent mutation. Direct Python setup and Windows-wrapper cache reuse also
passed. `tools/verify-toolchain.ps1` is the thin Windows wrapper.

The verifier is targeted provisioning coverage, not a portable port of the full
Brownie verification harness. The [2026-10-24 Windows receipt](../evidence/toolchain-windows-20261024.json)
is retained as historical evidence for the previous PowerShell setup path.

The setup contract does not establish a Linux Brownie CLI build, a Linux Brownie
runtime, full verification-harness portability, clean-machine packaging, authenticated
acquisition, or a production compiler channel.
