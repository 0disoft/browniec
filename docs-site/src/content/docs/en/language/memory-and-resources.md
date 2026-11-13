---
title: Memory, Arrays, and Borrows
description: How public Brownie C handles fixed arrays, plain records, UTF-8 byte literals, and checked slice borrows without pointers or GC.
---

Public Brownie C intentionally removes raw pointers (`ptr`), arbitrary heap allocations, user `resource` destructors, and garbage collection. Instead, it combines **value-copied records**, **arena-backed fixed arrays**, and **compile-time checked slice borrows**.

## Value Semantics and Fixed-Size Arenas

- **Plain structs** copy cleanly by value within register/frame bounds and cannot contain user `resource` cleanup hooks.
- **Fixed arrays (`T[N]`)** support up to **4096 elements** inside a bounded **65,536-byte (64 KiB)** runtime arena per invocation.
- Because preparing that 64 KiB array arena costs **65,537 Fuel** before `main()` starts executing, array and record programs require a larger explicit `--fuel` budget such as `--fuel 100000` or `--fuel 1000000`.

## Byte Literals, UTF-8 Checks, and Slice Views

Brownie C provides immutable byte/text literals (`b"..."`, `"..."`) and slice views (`ref u8[]`, `ref mut u8[]`, and scalar element slices) with runtime bounds checking:

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

Slice views check length (`.len`), indexing (`view[i]`), sub-ranges (`[lo..hi]`), and shared/mutable parameter passing or reborrowing across calls (`examples/mutable-slice-reborrow.brc`):

```c
fn void touch(ref mut i32[] values) {
    values[0] = 42;
}

fn i32 forward(ref mut i32[] values) {
    let ref mut i32[] alias = ref mut values;
    touch(alias);
    return alias[0];
}
```

## Public CLI vs. Private `Buffer` Work

When reading Brownie C's repository docs, note an important distinction:

- **Public CLI**: Supports scalar/array/struct values, immutable byte/text literals, and shared/mutable array slices (`ref T[]`, `ref mut T[]`) under explicit Fuel budgets.
- **Private / internal repository paths**: Features such as dynamic guest `Buffer` values (`bytes::empty`, `bytes::copy`), generic `Result<Buffer, u8>` joins, and multi-file anchored compilation exist in `src/` and internal native tests only. They are not enabled on the public `browniec` CLI yet.
