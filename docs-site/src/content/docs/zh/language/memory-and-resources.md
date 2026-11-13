---
title: 借用、重借用与生命周期
description: 理解 Brownie C 中的共享借用 ref 与独占借用 ref mut、块作用域重借用、返回值来源规则以及被排除的内存特性。
---

Brownie C 没有原始指针算术（`*ptr`），也没有垃圾回收器。取而代之的是围绕 <strong>共享借用（`ref`）</strong> 与 <strong>独占借用（`ref mut`）</strong> 的编译期规则，确保同一份数据不会同时被互相冲突的别名读取和修改。

## 1. 共享读取与独占写入

- <strong>`ref T` / `ref T[]`</strong>：只读借用；允许同时存在多个读者。
- <strong>`ref mut T` / `ref mut T[]`</strong>：可写借用；同一时间只允许存在一个活跃写者。

```c
fn i64 sum(ref i64[] values) {
    return values[0] + values[1];
}

fn i32 main() {
    let i64[2] values = [70, 7];
    let ref i64[] part = ref values;
    if (sum(ref part) == 77) { return 77; }
    return 0;
}
```

只要共享视图还处于活跃状态，任何修改底层所有者的操作都会在编译期被拒绝。

## 2. 作用域重借用（Scoped Reborrowing）

当你借用了整个切片（`parent`），需要把其中更窄的子切片（`child`）传给辅助函数进行修改，之后又要再次读取 `parent` 时，请把子借用放进独立的 `{ ... }` 代码块中：

```c
fn i32 set_answer(ref mut i32[] selected) {
    selected[0] = 77;
    return selected[0];
}

fn i32 main() {
    var i32[3] values = [0; 3];
    let ref mut i32[] parent = ref mut values;
    {
        let ref mut i32[] child = ref mut parent[1..2];
        let i32 answer = set_answer(ref mut child);
        if (child[0] != answer) { return 0; }
    }   // child 借用在此结束
    return parent[1];   // 之后可以再次安全读取 parent (77)
}
```

## 3. 返回借用视图（来源规则）

在公开的引用路径（`brownie.m2-reference/1`）上，接收 `ref u8[]` 参数的函数可以返回关联到调用方来源的子切片视图（`fn ref u8[]`）。返回函数内部局部数组的引用会被拒绝，从而彻底杜绝悬垂视图。

## 4. 被排除的特性

为了让虚拟机验证保持小巧且可预测，公开 Brownie C CLI 刻意未包含以下特性：

- 自定义 `resource` / `cleanup`、自定义 `enum` 以及用户泛型
- 原始指针（`ptr`）、C FFI（`extern C`）以及动态库加载
- 闭包、线程、`region` 内存池以及垃圾回收

---

- 上一节：[数组、切片与 UTF-8](../arrays-slices-and-utf8/)
- 下一节：[公开 CLI 示例](../../examples/cli-examples/)
