---
title: Memory, Arrays, and Borrows
description: Work with fixed arrays, plain structs, byte literals, and checked slice borrows without pointers or GC.
---

Brownie C has no raw pointers (`ptr`), user `resource` destructors, or garbage collector. Instead, you work with **copyable plain structs**, **fixed arrays in a 64 KiB arena**, and **bounds-checked slice borrows**.

## 1. Plain Structs and the 64 KiB Array Arena

- **Plain `struct`s** copy by value within register and frame limits.
- **Fixed arrays (`T[N]`)** hold up to **4096 elements** inside a bounded **65,536-byte (64 KiB)** runtime arena.

Because preparing that 64 KiB arena before `main()` starts costs **65,537 Fuel**, array and record programs require a larger explicit budget such as `--fuel 100000` or `--fuel 1000000` instead of the default `256`.

## 2. Byte Literals and Checked Slices

Brownie C supports `b"..."` / `"..."` literals along with `ref u8[]` and `ref mut T[]` slice views (with `.len`, `[i]` indexing, `[lo..hi]` sub-slices, and built-in UTF-8 checks):

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

You can also pass mutable slices into helpers and reborrow them (`examples/mutable-slice-reborrow.brc`), while the compiler rejects overlapping conflicting borrows before running the VM:

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

## 3. Public CLI vs. Internal `Buffer` Work

If you browse the engineering docs, you may see mentions of guest `Buffer` types (`bytes::empty`, `bytes::copy`). Those live in internal repository paths and tests right now and are not yet exposed on the public `browniec` CLI.
