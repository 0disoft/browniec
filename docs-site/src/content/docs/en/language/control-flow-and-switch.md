---
title: 2. Control Flow and Switch
description: Learn if/else statements and expressions, for and while loops, break/continue, and switch expressions in Brownie C.
---

Rule engines and byte processors rely heavily on clear branching and bounded loops. In Brownie C, both `if` and `switch` can act either as statements or as value-producing expressions.

## 1. `if / else` Statements and Expressions

Conditions require parentheses `(...)` and must evaluate to `bool`:

```c
fn i32 sign(i32 n) {
    // Statement form
    if (n < 0) { return -1; }

    // Expression form (final expression without ;)
    return if (n > 0) { 1 } else { 0 };
}
```

When `if` produces a value, both branches must return the exact same type.

## 2. Loops: `for`, `while`, `break`, `continue`

```c
fn i32 main() {
    var i32 total = 0;

    for (var i32 i = 0; i < 10; i = i + 1) {
        if (i == 3) { continue; }   // skip this iteration
        total += i;
    }

    while (total < 77) {
        total += 1;
    }

    return total;                   // 77
}
```

Remember that the VM meters execution work with **Fuel**—long or infinite loops will hit your `--fuel` budget and exit cleanly instead of hanging.

## 3. `switch` Statements and Expressions

Brownie C uses exhaustive `switch` blocks to match `Option<T>` and `Result<T, E>` without fallthrough bugs:

```c
fn Result<i32, bool> answer(Option<i32> value) {
    return switch (value) {
        case .some(number): {
            let i32 next = number + 1;
            .ok(next)
        }
        case .none: { .err(false) }
    };
}
```

- **Value-producing arms**: An arm block may run `let`/`var` bindings, assignments, and even nested `if` or `for` statements before yielding its final unsemicolonized value.
- **Ignoring payloads**: Use `_` (`case .err(_): { 0 }`) when you do not need the error value.
- **Mixing early `return`**: One arm may exit the enclosing function with `return ...;` while the remaining arm yields the expression's value (as long as at least one arm yields a value when used as an expression).

---

- Previous: [1. Variables, Types, and Functions](../basics/)
- Next: [3. Structs, Option/Result, and ?](../structs-and-error-handling/)
