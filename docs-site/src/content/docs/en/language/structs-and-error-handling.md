---
title: Structs, Option/Result, and ?
description: Learn Brownie C structs, field shorthand (.x), nested records, Option<T>, Result<T, E>, and ? error propagation.
---

When programs model coordinates, headers, or validation results, combine `struct` records with built-in `Option<T>` and `Result<T, E>`.

## 1. Structs and Field Shorthand

Define records with `struct` and construct them with `Type { .field = value }`:

```c
module main;

struct Point {
    i32 x;
    i32 y;
}

fn i32 main() {
    var i32 x = 50;
    var i32 y = 27;

    // .x and .y are shorthand for .x = x and .y = y
    let Point p = Point { .x, .y };
    return p.x + p.y;    // 77
}
```

- You can mix explicit `.x = 20` and shorthand `.y` in the same constructor, provided every field appears in declaration order.
- Plain structs copy as independent values when assigned or passed around, so later mutations to source variables do not affect the constructed copy.

Structs can also nest or be returned from helper functions cleanly:

```c
struct Answer {
    bool ready;
    i32 value;
}

fn Answer make_answer(i32 v) {
    return Answer { .ready = true, .value = v };
}
```

## 2. `Option<T>` and `Result<T, E>`

While custom `enum` declarations are not in Brownie C, the built-in tagged wrappers handle optional values and typed failures:

- **`Option<T>`**: `.some(value)` or `.none`
- **`Result<T, E>`**: `.ok(value)` or `.err(error)`

When the expected return or variable type is known, omit the prefix and write `.some(77)` or `.err(false)`.

## 3. Clean Error Propagation with `?`

Rather than nesting multiple `switch` blocks, append `?` to unwrap success values and return early on `.none` or `.err`:

```c
fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

If you only need a quick boolean check on a `Result`, `.is_ok` is also supported.

---

- Previous: [Control Flow and Switch](../control-flow-and-switch/)
- Next: [Arrays, Slices, and UTF-8](../arrays-slices-and-utf8/)
