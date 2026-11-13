---
title: First Program
description: Check, inspect, and execute your first .brc rule file with the browniec CLI.
---

Brownie C takes a single `.brc` file (up to 4096 UTF-8 bytes) directly—no package directory or manifest is needed for the public CLI.

## 1. A 5-Line Example (`examples/answer.brc`)

Every public `.brc` entry defines `module main;` and a zero-argument `fn i32 main()`:

```c
module main;

fn i32 main() {
    return 6 * 7;
}
```

## 2. Check and Run

First check syntax, types, and verification rules:

```powershell
./build/browniec.exe check examples/answer.brc
```

It prints `checked` and exits `0`. Now run it in the VM:

```powershell
./build/browniec.exe run examples/answer.brc
```

Output:

```text
return_i32=42
```

Add `--json` for machine-readable output:

```powershell
./build/browniec.exe run examples/answer.brc --json
```

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

Notice that **`return 42;` does not set the OS exit code to 42.** The CLI exits `0` because the run succeeded, while `42` is returned inside `return_i32`.

## 3. Peek at the Compiled IR

To inspect the generated VM instructions without running anything:

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

## 4. Giving Loops More `--fuel`

The default Fuel budget is `256`. Running a loop like `examples/loops.brc` with default Fuel stops partway through with a `fuel` error, while passing `--fuel 1000` finishes cleanly:

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## Common Beginner Gotchas

- **Expecting `return 42;` to be the process exit code**: Guest returns are data (`return_i32`); non-zero process exit codes (`2`..`7`) indicate errors.
- **Forgetting `--fuel` on arrays**: Array initialization costs `65,537` Fuel before `main()` runs, so pass `--fuel 100000` or higher.
- **Exceeding 4096 bytes or passing `--isolated`**: Public CLI rejects oversized files and unimplemented flags instead of silently ignoring them.
