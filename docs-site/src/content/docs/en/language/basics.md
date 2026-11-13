---
title: Variables, Types, and Functions
description: Learn module main, let vs var bindings, scalar and bool types, bitwise ops, explicit as casts, and functions in Brownie C.
---

Brownie C shares Fairy C's clean C-like syntax while keeping the language surface focused on deterministic, verifiable VM execution.

## 1. Module Header and Bindings (`let`, `var`)

Every `.brc` source file begins with `module main;`. Use `let` for bindings that stay fixed and `var` for variables you reassign.

```c
module main;

fn i32 main() {
    let i32 base = 70;      // cannot be reassigned
    var i32 bonus = 5;      // mutable local variable
    bonus = bonus + 2;
    return base + bonus;    // 77
}
```

Every variable must have an initializer, and the type can be omitted when clear from the initializer (`let x = 10;`).

## 2. Supported Scalar Types and Explicit `as` Casts

The public CLI supports integers and booleans (floating-point `f32`/`f64` are deliberately excluded so behavior stays identical across hosts):

| Type | Description | Common Uses |
| --- | --- | --- |
| `i32`, `i64` | Signed integers | General arithmetic, 64-bit values |
| `u8`, `u32`, `usize` | Unsigned integers | Byte values (`u8`), array lengths & indexes (`usize`) |
| `bool` | Boolean (`true`, `false`) | Conditions and flags |

Different integer types never mix implicitly; use `as` for value-preserving widening casts:

```c
let u8 byte_val = 21;
let u32 wide = byte_val as u32;
let usize count = wide as usize;
let i64 big = byte_val as i64;
```

## 3. Operators and Runtime Safety Checks

- **Arithmetic**: `+`, `-`, `*`, `/`, `%`. Overflow and division by zero stop safely (`overflow`, `zero_divisor`) instead of wrapping silently.
- **Bitwise**: `&`, `|`, `^`, `~`, `<<`, `>>` on integer types (`u8`, `u32`, `i32`, etc.).
- **Logical**: `&&`, `||`, `!` with short-circuit evaluation.

```c
let u8 flags = 72;
let u8 selected = (flags & 127) | 5; // 77
```

## 4. Functions (`fn`), Recursion, and `_ = expr;`

Declare functions with `fn ReturnType name(Params)` (supporting recursion), or `fn void` when no value is returned:

```c
fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn void touch(ref mut i32 value) {
    *value += 1;
}
```

To intentionally discard a non-`void` expression's result, acknowledge it with `_ = expr;`.

---

Next: [Control Flow and Switch](../control-flow-and-switch/)
