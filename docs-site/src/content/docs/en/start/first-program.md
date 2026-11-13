---
title: First Program
description: Check, inspect, and execute your first Brownie C rule file with the public CLI.
---

Brownie C operates on single `.brc` files up to **4096 bytes** of UTF-8 text. Unlike Fairy C packages, you pass the `.brc` file directly to `browniec check`, `browniec run`, or `browniec inspect`.

## 1. A Minimal Program (`examples/answer.brc`)

Every runnable public program defines `module main;` and a zero-argument `fn i32 main()`:

```c
module main;

fn i32 main() {
    return 6 * 7;
}
```

## 2. Check Syntax, Types, and Bytecode Verification

```powershell
./build/browniec.exe check examples/answer.brc
```

Expected output (written to stderr, exit code `0`):

```text
checked
```

Pass `--json` to emit structured JSON on stdout instead (with empty stderr):

```powershell
./build/browniec.exe check examples/answer.brc --json
```

## 3. Run Under the Bounded VM

Execute `examples/answer.brc`:

```powershell
./build/browniec.exe run examples/answer.brc
```

Expected output:

```text
return_i32=42
```

And with `--json`:

```powershell
./build/browniec.exe run examples/answer.brc --json
```

Observed JSON output:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

Notice that `return_i32=42` is returned as **guest data**, while the `browniec` process exits with status `0` because the run completed cleanly.

## 4. Inspect Generated Private IR

You can inspect the compiled register bytecode without executing it:

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

Observed output begins with:

```text
Brownie C private IR diagnostics; not reloadable
profile=brownie.m1-scalar/1
entry=0 instructions=4 registers=3 literal_bytes=0
```

## 5. Supplying More Fuel for Loops and Arrays

The default Fuel limit is **256**, which covers short scalar computations like `answer.brc`, but loops and arrays need an explicit `--fuel` budget (up to `16000000`). For example, `examples/loops.brc` needs a larger budget such as `--fuel 1000`:

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## Common Beginner Mistakes

- **Expecting `return 42;` to set the OS exit code**: The guest `i32` is reported as `return_i32`. Nonzero CLI exit codes (`2`..`7`) indicate usage errors, compile errors, traps, or IO failures.
- **Forgetting `--fuel` on loops or arrays**: Programs with arrays prepare a 64 KiB arena costing `65,537` Fuel before `main()` runs, so running them with the default `256` fails with a `fuel` error (exit code `5`).
- **Passing unsupported CLI flags**: Options such as `--isolated` or project/input flags are rejected rather than ignored.
- **Exceeding 4096 bytes**: Public single-file compilation rejects source files larger than 4096 bytes of UTF-8.
