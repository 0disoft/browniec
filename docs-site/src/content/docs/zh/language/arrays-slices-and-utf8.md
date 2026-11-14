---
title: 数组、切片与 UTF-8
description: 学习 Brownie C 中的定长数组 T[N]、.len、只读/可变切片视图 ref T[] / ref mut T[]、text::valid_utf8 以及字节/文本字面量。
---

由于 Brownie C 专注于规则求值与字节处理，数组和切片视图是日常代码中的核心数据结构。

## 1. 定长数组（`T[N]`）与 `.len`

使用 `Type[Count]` 声明固定大小的数组，既可以列出具体元素 `[10, 20, 12]`，也可以使用重复语法 `[0; 4]`：

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

- `.len` 以 `usize` 类型返回数组长度。
- 相同元素类型与长度的可变数组（`var T[N]`）支持整组按值复制赋值（`values = other;`）。
- 越界读取或写入会安全触发 `bounds` 陷阱，而不会访问任意内存。

## 2. 切片视图（`ref T[]`、`ref mut T[]`）

你可以借用数组的全部或部分区域，而无需将其复制到新数组中：

```c
fn i32 update(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[4] values = [0; 4];
    let ref mut i32[] parent = ref mut values[1..4];   // 第 1、2、3 号元素
    return update(ref mut parent[1..2]);               // 写入 values[2]
}
```

- `ref T[]`：只读切片视图。
- `ref mut T[]`：独占可变切片视图。
- 半开区间切片支持 `arr[start..end]`、`arr[..end]` 和 `arr[start..]`。
- 也可以直接从函数返回的临时数组中借用切片并传入调用参数（例如 `update(ref mut make()[1..2])`）。

## 3. UTF-8 校验与字节/文本字面量

使用内置的 `text::valid_utf8` 检查字节数组是否包含有效的 UTF-8 序列：

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

你也可以将静态字节字面量（`b"..."`）和文本字面量（`"..."`）直接绑定为不可变的 `ref u8[]` 或 `ref str` 视图：

```c
let ref u8[] sig = b"OK";
let i32 first = sig[0] as i32;   // 79 ('O')
let bool same = text::equal(text::bytes("OK"), sig);
```

- 使用字节/文本字面量的程序会进入保留引用配置（`brownie.m2-reference/1`），因此需要传入更大的预算，例如 `--fuel 1000000`（默认的 `256` 不足以支付进入/退出开销）。
- 使用 `text::bytes("OK")` 可以从文本获取字节视图，使用 `text::equal(a, b)` 可以比较两个不可变字节视图。
- 两种字面量均支持 `\\`、`\"`、`\n`、`\r`、`\t`、`\0` 和 `\xHH` 转义，`"..."` 还额外支持 `\u{...}` Unicode 标量转义（`c"..."` C 字符串字面量会被拒绝）。

---

- 上一节：[结构体、Option/Result 与 ?](../structs-and-error-handling/)
- 下一节：[借用、重借用与生命周期](../memory-and-resources/)
