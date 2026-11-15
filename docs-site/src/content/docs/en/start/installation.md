---
title: Installation and Setup
description: Provision the pinned Fairy C toolchain and build browniec.exe on Windows.
---

Brownie C does not ship a prebuilt installer yet. Instead, a helper script provisions the pinned Fairy C compiler inside the repo, and you build `build/browniec.exe` from there.

## Prerequisites

1. **MSVC x64 toolchain + Windows SDK** on Windows 11 x64.
2. **Python 3.10+** (`python3` or `py -3`) to run `tools/setup-toolchain.py`.
3. **Go (`go1.27.1`) and Git** if bootstrapping the pinned `fairyc` compiler from source instead of supplying `--compiler-file path/to/fairyc.exe`.

## 1. Clone the Repository

If you do not have the source locally yet, clone the [browniec GitHub repository](https://github.com/0disoft/browniec) and move into the repository root:

```powershell
git clone https://github.com/0disoft/browniec.git
cd browniec
```

## 2. Provision `fairyc` and Build `browniec.exe`

From the `browniec` repository root:

```powershell
python3 tools/setup-toolchain.py
./build/toolchain/fairyc.exe build
```

This prepares `build/toolchain/fairyc.exe` and compiles `./build/browniec.exe`.

> **Note:** Linux toolchain hashes exist in `toolchain.json`, but native Linux builds and execution of `browniec` remain unverified.

## 3. Verify the Binary

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

In `--version --json`, you will see `"fuel_default": 256`, `"fuel_limit": 16000000`, `"core": true`, and `"restricted": false` / `"embed": false` (reflecting that OS worker isolation and C embedding are not enabled yet).
