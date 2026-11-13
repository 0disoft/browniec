---
title: 5. Borrows, Reborrowing, and Lifetimes
description: Understand shared ref vs exclusive ref mut borrows, block-scoped reborrowing, return origins, and excluded memory features in Brownie C.
---

Brownie C has no raw pointer arithmetic (`*ptr`) or garbage collector. Instead, compile-time rules around **`ref` (shared)** and **`ref mut` (exclusive)** borrows ensure data cannot be read and mutated simultaneously by conflicting aliases.

## 1. Shared Reads vs Exclusive Writes

- **`ref T` / `ref T[]`**: Read-only; many readers can borrow at once.
- **`ref mut T` / `ref mut T[]`**: Writable; only one active writer is allowed at a time.

```c
fn i64 sum(ref i64[] values) {
    return values[0] + values[1];
}

fn i32 main() {
    let i64[2] values = [21; 2];
    let ref i64[] part = ref values;
    if (sum(ref part) == 42) { return 42; }
    return 0;
}
```

While a shared view is alive, mutating the underlying owner is rejected at compile time.

## 2. Scoped Reborrowing

When you borrow a whole slice (`parent`), pass a narrower sub-slice (`child`) to a helper function to mutate, and then read `parent` again afterward, wrap the child borrow in its own `{ ... }` block:

```c
fn i32 set_answer(ref mut i32[] selected) {
    selected[0] = 42;
    return selected[0];
}

fn i32 main() {
    var i32[3] values = [0; 3];
    let ref mut i32[] parent = ref mut values;
    {
        let ref mut i32[] child = ref mut parent[1..2];
        let i32 answer = set_answer(ref mut child);
        if (child[0] != answer) { return 0; }
    }   // child borrow ends here
    return parent[1];   // parent can be read safely again (42)
}
```

## 3. Returning Borrowed Views (Origin Rules)

On the public reference path (`brownie.m2-reference/1`), functions taking `ref u8[]` parameters can return a sliced sub-view (`fn ref u8[]`) tied back to the caller's origin. Returning a reference to a local array inside the function is rejected so dangling views are impossible.

## 4. Excluded Features

To keep VM verification small and predictable, these features are intentionally absent from the public Brownie C CLI:

- Custom `resource` / `cleanup`, custom `enum`, and user generics
- Raw pointers (`ptr`), C FFI (`extern C`), and dynamic library loading
- Closures, threads, `region` arenas, and garbage collection

---

- Previous: [4. Arrays, Slices, and UTF-8](../arrays-slices-and-utf8/)
- Next: [Public CLI Examples](../../examples/cli-examples/)
