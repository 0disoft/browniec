---
title: 控制流与 switch
description: 学习 Brownie C 中的 if/else 语句和表达式、for 与 while 循环、break/continue 以及 switch 表达式。
---

规则引擎和字节处理器高度依赖清晰的分支结构与有界循环。在 Brownie C 中，`if` 和 `switch` 既可以作为语句使用，也可以作为产生值的表达式使用。

## 1. `if / else` 语句与表达式

条件必须放在圆括号 `(...)` 中，且求值结果必须是 `bool`：

```c
fn i32 sign(i32 n) {
    // 语句形式
    if (n < 0) { return -1; }

    // 表达式形式（最后一个表达式不加分号）
    return if (n > 0) { 1 } else { 0 };
}
```

当 `if` 用作表达式返回值时，也支持 `else if (...) { ... }` 链式分支，并且所有分支必须返回完全相同的类型。

## 2. 循环：`for`、`while`、`break`、`continue`

```c
fn i32 main() {
    var i32 total = 0;

    for (var i32 i = 0; i < 10; i = i + 1) {
        if (i == 3) { continue; }   // 跳过本次迭代
        total += i;
    }

    while (total < 77) {
        total += 1;
    }

    return total;                   // 77
}
```

请记住，VM 会使用 **Fuel** 对执行工作量进行计量——过长或无限循环会在耗尽 `--fuel` 预算后干净地退出，而不会导致程序挂起。

## 3. `switch` 语句与表达式

Brownie C 使用穷举式的 `switch` 块专门匹配 `Option<T>` 和 `Result<T, E>` 值（不支持任意整数或自定义 `enum`），不存在隐式穿透（fallthrough）漏洞：

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

- <strong>产生值的分支</strong>：分支块中可以先执行 `let`/`var` 绑定、赋值甚至嵌套的 `if` 或 `for` 语句，再通过末尾不带分号的表达式产生该分支的值。
- <strong>忽略载荷值</strong>：当你不需要错误值时，可以使用 `_`（例如 `case .err(_): { 0 }`）。
- <strong>混用提前 `return`</strong>：某个分支可以通过 `return ...;` 直接从外层函数返回，同时让其余分支产出表达式的值（只要作为表达式使用时至少有一个分支产出了值即可）。

---

- 上一节：[变量、类型与函数](../basics/)
- 下一节：[结构体、Option/Result 与 ?](../structs-and-error-handling/)
