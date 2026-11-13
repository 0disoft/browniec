---
title: Public CLI Examples
description: Small rule and byte-processing examples runnable directly with the public browniec CLI.
---

Every example below runs directly against the current single-file `browniec` CLI (tested with `./build/browniec.exe` on Windows).

## 1. Branching, Short-Circuit Logic, and Recursion (`examples/branches.brc`)

Demonstrates recursive rule functions and short-circuit `||` / `&&` avoiding a division-by-zero branch:

```c
module main;

fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn i32 main() {
    var i32 answer = 0;
    let bool ready = true || (1 / 0 == 0);
    if (ready && factorial(5) == 120) {
        answer = 42;
    } else {
        answer = 1 / 0;
    }
    return answer;
}
```

Run with default Fuel (`256`):

```powershell
./build/browniec.exe run examples/branches.brc --json
```

Observed output:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":42,"error":null}
```

## 2. `Option` and `Result` Propagation (`examples/propagation.brc`)

Shows `?` early return for `Option<T>` and `Result<T, E>` without unchecked unwraps:

```c
module main;

fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}

fn i32 main() {
    switch (positive(.some(42))) {
        case .some(ok): {
            switch (add(.ok(20), .ok(22))) {
                case .ok(value): {
                    if (ok) { return value; }
                    return 0;
                }
                case .err(_): { return 0; }
            }
        }
        case .none: { return 0; }
    }
}
```

Run command:

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

Result: `return_i32: 42`, `profile: "brownie.m1-scalar/1"`.

## 3. UTF-8 Byte Array Validation (`examples/array-utf8.brc`)

Constructs a 3-byte UTF-8 sequence in a mutable array and checks validity with `text::valid_utf8`:

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 42; }
    return 0;
}
```

Because programs with an array catalog prepare the 64 KiB backing arena (`65,537` Fuel before `main()`), pass `--fuel 100000`:

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

Observed output:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-write/1","command":"run","status":"completed","return_i32":42,"error":null}
```

## 4. Helper Records (`examples/helper-records.brc`) & Mutable Slices (`examples/mutable-slice-reborrow.brc`)

Record construction/selection and mutable slice reborrowing need larger Fuel budgets than simple array reads (for example, `examples/helper-records.brc` runs out of Fuel under `--fuel 100000` at byte offset `212`, and completes cleanly under `--fuel 1000000`):

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

Both complete with exit code `0` and `"return_i32":42` (under profiles `brownie.m2-struct-read/1` and `brownie.m2-array-write/1`).
