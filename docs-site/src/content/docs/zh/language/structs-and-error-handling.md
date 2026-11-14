---
title: 结构体、Option/Result 与 ?
description: 学习 Brownie C 的结构体、字段简写（.x）、嵌套记录、Option<T>、Result<T, E> 以及 ? 错误传播。
---

当程序需要为坐标、报文头或校验结果建模时，可以将 `struct` 记录类型与内置的 `Option<T>` 和 `Result<T, E>` 结合使用。

## 1. 结构体与字段简写

使用 `struct` 定义记录类型，并使用 `Type { .field = value }` 构造实例：

```c
module main;

struct Point {
    i32 x;
    i32 y;
}

fn i32 main() {
    var i32 x = 50;
    var i32 y = 27;

    // .x 和 .y 分别是 .x = x 和 .y = y 的简写
    let Point p = Point { .x, .y };
    return p.x + p.y;    // 77
}
```

- 你可以在同一个构造器中混用显式写法 `.x = 20` 与简写 `.y`，只要所有字段按声明顺序出现即可。
- 普通结构体在赋值或传参时会按独立值进行拷贝，因此之后对源变量的修改不会影响已构造出的副本。

结构体也可以嵌套或从辅助函数中直接返回：

```c
struct Answer {
    bool ready;
    i32 value;
}

fn Answer make_answer(i32 v) {
    return Answer { .ready = true, .value = v };
}
```

## 2. `Option<T>` 与 `Result<T, E>`

虽然 Brownie C 不支持自定义 `enum` 声明，但内置的带标签包装类型可以很好地处理可选值与带类型的失败结果：

- <strong>`Option<T>`</strong>：`.some(value)` 或 `.none`
- <strong>`Result<T, E>`</strong>：`.ok(value)` 或 `.err(error)`

当预期的返回类型或变量类型已知时，可以省略类型前缀，直接写 `.some(77)` 或 `.err(false)`。（在当前公开 CLI 中，`Option<T>` 和 `Result<T, E>` 的类型参数支持 `i32` 与 `bool`。）

## 3. 使用 `?` 简洁传播错误

不必嵌套多层 `switch`，只需在表达式后加上 `?`，即可在成功时解包值，或在遇到 `.none` / `.err` 时提前返回：

```c
fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}
```

如果你只想对 `Result<T, E>` 做一个简单的布尔检查，也可以使用 `.is_ok`（`Option<T>` 需使用 `switch` 或 `?`）。

---

- 上一节：[控制流与 switch](../control-flow-and-switch/)
- 下一节：[数组、切片与 UTF-8](../arrays-slices-and-utf8/)
