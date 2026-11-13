---
title: Language Basics
description: Learn Brownie C bindings, supported types, functions, control flow, Option/Result, and excluded features.
---

Brownie C borrows Fairy C's clean C-shaped syntax while keeping the language small enough to compile and check quickly inside a single `.brc` file (up to 4096 UTF-8 bytes).

Every public CLI program starts with `module main;` and a zero-argument `fn i32 main()`.

## 1. Bindings and Types

Use `let` for immutable variables and `var` for mutable ones. On supported initializers, you can let the compiler infer the type (`let x = 10;`).

- **Scalars**: `i32`, `u32`, `i64`, `u64`, `isize`, `usize`, `bool`.
- **Fixed arrays and records**: Fixed-length `T[N]` (`[21; 2]` or element lists) and plain `struct`s with copyable fields.
- **Optional & error values**: `Option<T>` (`.some(v)` / `.none`) and `Result<T, E>` (`.ok(v)` / `.err(e)`).

```c
module main;

struct Point { i32 x; i32 y; }

fn Option<i32> check_positive(i32 value) {
    if (value > 0) { return .some(value); }
    return .none;
}
```

## 2. Functions, Control Flow, and Checked Math

- **`if` and `switch`**: Work both as statements and as value-returning expressions when branches match types.
- **Loops**: `while` and `for` with `break` and `continue`.
- **`void` helpers & discards**: Helper functions can return `void`, and `_ = expr;` discards an expression cleanly.
- **Checked arithmetic**: Integer overflow and divide-by-zero halt cleanly (`overflow`, `zero_divisor`) instead of silently wrapping.

## 3. Working with `Option` and `Result`

Use `?` to unwrap `.some` / `.ok` or return early on `.none` / `.err`, and `.is_ok` to inspect a `Result` without consuming it:

```c
fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

## 4. What Is Intentionally Excluded

To keep verification deterministic and self-contained, Brownie C omits:

- Floats (`f32`, `f64`)
- User `resource` types, `enum` declarations, and user generics
- Raw pointers (`ptr`), arbitrary C FFI, and dynamic library loading
- Closures, threads, maps, regex, GC, and JIT
