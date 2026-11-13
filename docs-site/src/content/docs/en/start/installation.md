---
title: Installation and Setup
description: How to provision the pinned Fairy C compiler toolchain and build browniec on Windows.
---

Brownie C does not publish prebuilt installers or external ZIP downloads yet. You build `build/browniec.exe` from the repository on Windows 11 x64 using the pinned Fairy C toolchain manifest (`toolchain.json`).

## Prerequisites

1. **MSVC x64 toolchain + Windows SDK**: Needed for the final native build step invoked by Fairy C.
2. **Python 3.10+**: Used by `tools/setup-toolchain.py` (`python3` or `py -3` on Windows).
3. **Go (`go1.27.1`) and Git** (only if building the pinned Fairy C binary from source instead of importing an already verified `--compiler-file`). If a local `../fairyc` checkout is present at the exact pinned revision, setup uses it automatically; otherwise it falls back to the reviewed HTTPS Git remote.

## 1. Provision the Pinned Fairy C Compiler

From the `browniec` repository root:

```powershell
python3 tools/setup-toolchain.py
```

On Windows, you can run `py -3 tools/setup-toolchain.py` if `python3` is not mapped. This populates and SHA-256 verifies `build/toolchain/fairyc.exe`. You do not need a globally installed `fairyc` on `PATH`.

- To import a previously verified binary: `python3 tools/setup-toolchain.py --compiler-file path/to/fairyc.exe`
- Note: Linux setup metadata exists in `toolchain.json`, **but native Linux setup, build, and Brownie CLI execution remain unverified.**

## 2. Build `browniec.exe`

Once `build/toolchain/fairyc.exe` is ready, build the root `fairy.toml` package:

```powershell
./build/toolchain/fairyc.exe build
```

This writes `./build/browniec.exe`.

## 3. Verify the Build

Check the experimental profile banner and machine-readable metadata:

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

Observed `--version` output:

```text
Brownie C experimental: brownie.m1-scalar/1, brownie.m2-array-read/1, brownie.m2-array-write/1, brownie.m2-array-copy/1, brownie.m2-struct-read/1, brownie.m2-struct-write/1, brownie.m2-struct-copy/1, brownie.m2-struct-nested/1
```

Observed `--version --json` includes `"schema":"browniec.version/v1"`, `"core":true`, `"restricted":false`, `"embed":false`, `"fuel_default":256`, `"fuel_limit":16000000`, and `"inspect_ir":true`. Notice that `restricted: false` and `embed: false` indicate isolation and C embedding are not enabled yet, and `core: true` only covers the documented experimental public subsets—not the full target language profile.

## Next Step

Run your first `.brc` program in [First Program](../first-program/).
