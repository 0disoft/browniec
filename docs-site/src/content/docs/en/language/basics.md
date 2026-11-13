---
title: Language Basics
description: Supported Brownie C scalar and composite types, control flow, Option/Result handling, checked arithmetic, and language exclusions.
---

Brownie C shares a C-shaped surface syntax with a strict subset of Fairy C, tailored to small, deterministic rules inside a **4096-byte UTF-8 single-file** budget.

Every public CLI program starts with `module main;` and a zero-argument `fn i32 main()`.

## Bindings and Types

- **Bindings**: Use `let` for immutable variables and `var` for mutable variables. Types can be written explicitly or inferred on supported scalar, array, record, and constructor initializers.
- **Scalars**: `i32`, `u32`, `i64`, `u64`, `isize`, `usize`, and `bool`.
- **Fixed arrays and records**: Fixed arrays `T[N]` (`[21; 2]` or element lists) and plain nominal `struct` records holding copyable scalar/nested plain-record fields.
- **Tagged wrappers**: `Option<T>` (`.some(v)` / `.none`) and `Result<T, E>` (`.ok(v)` / `.err(e)`).

```c
module main;

struct Point { i32 x; i32 y; }

fn Option<i32> check_positive(i32 value) {
    if (value > 0) { return .some(value); }
    return .none;
}
```

## Functions, Control Flow, and Checked Arithmetic

- **Branches and loops**: `if` / `else` (usable as value expressions when branch types match), `switch` statements and expressions, `while`, and `for` loops with `break` and `continue`.
- **Void helpers and discards**: Helper functions returning `void` and explicit `_ = expr;` discards are supported.
- **Checked arithmetic**: Signed and unsigned integer overflow and division by zero fail cleanly at runtime (`overflow`, `zero_divisor`, process exit code `5`) instead of wrapping silently.
- **Result/Option propagation**: `?` unwraps `.some` / `.ok` or returns early on `.none` / `.err`, and `.is_ok` checks `Result` state without consuming it:

```c
fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

## What Is Excluded by Design

To keep compilation and VM verification deterministic and bounded, Brownie C intentionally excludes:

- Floating-point numbers (`f32`, `f64`)
- User-defined `resource` types, `enum` declarations, and user generics
- Raw pointers (`ptr`), arbitrary C FFI (`extern C`), and dynamic library loading
- Closures, threads, maps, regex, garbage collection, and JIT compilation
