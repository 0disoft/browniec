---
title: 变量、类型与函数
description: 学习 Brownie C 中的 module main、let 与 var 绑定、标量与布尔类型、位运算、显式 as 类型转换以及函数定义。
---

Brownie C 沿用了 Fairy C 简洁的类 C 语法，同时将语言表面聚焦在确定性、可验证的虚拟机执行上。

## 1. 模块头与变量绑定（`let`、`var`）

每个 `.brc` 源文件都以 `module main;` 开头。使用 `let` 声明不可重新赋值的绑定，使用 `var` 声明可变变量。

```c
module main;

fn i32 main() {
    let i32 base = 70;      // 不能重新赋值
    var i32 bonus = 5;      // 可变局部变量
    bonus = bonus + 2;
    return base + bonus;    // 77
}
```

每个变量都必须带有初始化表达式；当能从初始化表达式中明确推断出类型时，可以省略类型标注（`let x = 10;`）。

## 2. 支持的标量类型与显式 `as` 转换

公开 CLI 支持整数和布尔类型（刻意排除了浮点数 `f32`/`f64`，以确保不同宿主平台上的行为完全一致）：

| 类型 | 说明 | 常见用途 |
| --- | --- | --- |
| `i32`、`i64` | 有符号整数 | 常规算术运算、64 位数值 |
| `u8`、`u32`、`usize` | 无符号整数 | 字节值（`u8`）、数组长度与下标（`usize`） |
| `bool` | 布尔值（`true`、`false`） | 条件判断与标志位 |

不同的整数类型之间绝不会隐式混用；请使用 `as` 进行保值宽化（widening）转换：

```c
let u8 byte_val = 21;
let u32 wide = byte_val as u32;
let usize count = wide as usize;
let i64 big = byte_val as i64;
```

目前 `as` 仅支持七种严格宽化转换组合（`u8 -> i32/i64/u32/usize`、`u32 -> i64/usize`、`i32 -> i64`）。同类型转换（`i32 as i32`）、窄化转换、`usize as i64`、`bool` 与整数互转，以及 `1 as u8`（因为 `as` 不会根据目标类型反推左侧字面量的类型）都会被编译器拒绝。

## 3. 运算符与运行时安全检查

- <strong>算术运算</strong>：`+`、`-`、`*`、`/`、`%`。溢出和除以零会安全终止（`overflow`、`zero_divisor`），而不会静默回绕。
- <strong>复合赋值</strong>：`+=`、`-=`、`*=`、`/=`、`%=`、`<<=`、`>>=`、`&=`、`^=`、`|=`，可用于 `var` 绑定或可变位置。
- <strong>一元运算符</strong>：`-`、`+`、`!`、`~`（注意：`u8`、`u32`、`usize` 等无符号整数不允许使用一元 `-`）。
- <strong>位运算</strong>：`&`、`|`、`^`、`~`、`<<`、`>>`，适用于整数类型（`u8`、`u32`、`i32` 等）。
- <strong>逻辑与比较运算</strong>：`&&`、`||`、`!`，支持短路求值。不支持链式比较（如 `0 < x < 10`）——请写成 `(0 < x) && (x < 10)`——且 `if`/`while` 的条件表达式必须是 `bool` 类型。
- <strong>整数字面量与注释</strong>：整数字面量目前仅支持十进制数字（暂不支持 `1_000`、`0xFF`、`0b1010`）。支持单行注释（`//`）和可嵌套的块注释（`/* ... */`）。

```c
let u8 flags = 72;
let u8 selected = (flags & 127) | 5; // 77
```

## 4. 函数（`fn`）、递归与 `_ = expr;`

使用 `fn ReturnType name(Params)` 声明函数（支持递归），当函数不返回值时使用 `fn void`：

```c
fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn void touch(ref mut i32 value) {
    *value += 1;
}
```

如果要明确丢弃一个非 `void` 表达式的返回值，请使用 `_ = expr;` 显式声明。

---

下一节：[控制流与 switch](../control-flow-and-switch/)
