---
title: Arrays, Slices, and UTF-8
description: Learn fixed arrays T[N], .len, mutable/shared slice views ref T[] / ref mut T[], text::valid_utf8, and byte/text literals in Brownie C.
---

Because Brownie C focuses on rule evaluation and byte processing, arrays and slice views are central to day-to-day code.

## 1. Fixed Arrays (`T[N]`) and `.len`

Declare fixed-size arrays as `Type[Count]`, using either explicit elements `[10, 20, 12]` or repeat syntax `[0; 4]`:

```c
module main;

fn i32 main() {
    var i32[4] values = [0; 4];
    let i32[3] fixed = [30, 40, 7];

    for (var usize i = 0; i < fixed.len; i = i + 1) {
        values[i] = fixed[i];
    }
    return values[0] + values[1] + values[2]; // 77
}
```

- `.len` returns the array length as `usize`.
- Matching mutable arrays (`var T[N]`) support whole-array copy assignment (`values = other;`).
- Out-of-bounds reads or writes trap cleanly with `bounds` instead of reading arbitrary memory.

## 2. Slice Views (`ref T[]`, `ref mut T[]`)

Borrow all or part of an array without copying it into a new array:

```c
fn i32 update(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[4] values = [0; 4];
    let ref mut i32[] parent = ref mut values[1..4];   // elements 1, 2, 3
    return update(ref mut parent[1..2]);               // writes values[2]
}
```

- `ref T[]`: Read-only slice view.
- `ref mut T[]`: Exclusive mutable slice view.
- Half-open ranges support `arr[start..end]`, `arr[..end]`, and `arr[start..]`.
- You can also borrow a slice directly from a temporary array returned by a function call (`update(ref mut make()[1..2])`).

## 3. UTF-8 Validation and Byte/Text Literals

Check whether a byte array holds valid UTF-8 with built-in `text::valid_utf8`:

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 77; }
    return 0;
}
```

You can also bind static byte (`b"..."`) and text (`"..."`) literals directly as immutable `ref u8[]` or `ref str` views:

```c
let ref u8[] sig = b"OK";
let i32 first = sig[0] as i32;   // 79 ('O')
let bool same = text::equal(text::bytes("OK"), sig);
```

- Programs using byte/text literals enter the retained-reference profile (`brownie.m2-reference/1`), so pass a larger budget such as `--fuel 1000000` (the default `256` is too small for entry/leave costs).
- Use `text::bytes("OK")` to obtain a byte view from text, and `text::equal(a, b)` to compare two immutable byte views.
- Both literal kinds support `\\`, `\"`, `\n`, `\r`, `\t`, `\0`, and `\xHH` escapes, while `"..."` also accepts `\u{...}` Unicode scalar escapes (`c"..."` C-string literals are rejected).

---

- Previous: [Structs, Option/Result, and ?](../structs-and-error-handling/)
- Next: [Borrows, Reborrowing, and Lifetimes](../memory-and-resources/)
