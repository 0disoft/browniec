---
title: Public CLI Examples
description: Walk through five runnable .brc examples covering branches, ? propagation, UTF-8 byte checks, structs, and mutable slices.
---

Reading small working programs is the fastest way to get comfortable with Brownie C. Each example below lives in `examples/` and runs directly with `./build/browniec.exe`.

## 1. Branching, Short-Circuit Logic, and Recursion (`examples/branches.brc`)

Short-circuit `||` and `&&` skip evaluating `1 / 0`, while recursive `factorial(5)` produces `120`:

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

```powershell
./build/browniec.exe run examples/branches.brc --json
```

Output: `"status":"completed"`, `"return_i32":42`.

## 2. `Option` and `Result` Propagation (`examples/propagation.brc`)

Using `?` unwraps `.some` / `.ok` inline or returns early if a step is `.none` or `.err`:

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

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

Output: `"return_i32":42`.

## 3. UTF-8 Byte Validation (`examples/array-utf8.brc`)

Builds a 3-byte UTF-8 sequence in `var u8[3]` and checks it with `text::valid_utf8`:

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

Because array programs pay `65,537` Fuel up front to initialize the 64 KiB arena, pass `--fuel 100000`:

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

Output: `"return_i32":42`.

## 4. Helper Records (`helper-records.brc`) and Mutable Slices (`mutable-slice-reborrow.brc`)

Recursive struct construction and slice reborrowing consume more Fuel than simple array reads (`helper-records.brc` runs out of Fuel at `--fuel 100000`, and completes cleanly at `--fuel 1000000`):

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

Both return `"return_i32":42` with exit status `0`.
