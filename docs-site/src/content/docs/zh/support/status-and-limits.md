---
title: 当前支持范围与限制
description: 公开容量上限、Windows 与 Linux 支持现状，以及永久超出 Brownie C 范围的特性。
---

Brownie C 刻意保持严格的编译期与运行期边界，使 Guest 代码的求值保持小巧且可预测。以下是当前公开 CLI 的支持范围。

> <strong>验证基线</strong>：`2026-11-16` · 提交 [`f5e13f9`](https://github.com/0disoft/browniec/commit/f5e13f9)

## 当前可用功能

在 `browniec --version --json` 的输出中，`"core": true` 表示当前已启用的公开实验性子集（标量、定长数组、普通结构体、字节/文本字面量以及受检切片），并不代表语言功能已全部完成。

## 公开 CLI 容量上限

| 项目 | 当前上限 |
| --- | --- |
| 源码输入 | 1 个 UTF-8 编码的 `.brc` 文件，最大 `4,096` 字节（`1,024` 个 token） |
| 入口函数 | 无参数的 `fn i32 main()`（暂不支持 CLI `--input` 参数） |
| 函数与 IR | `16` 个函数、`128` 个全局寄存器、`256` 条指令 |
| 调用栈帧 | `32` 层嵌套栈帧 |
| 数组与结构体 | `16` 个聚合分配点、每个数组最多 `4,096` 个元素、`64 KiB` 内存池 |
| Fuel 预算 | 默认 `256`，上限 `16,000,000` |

## 平台与特性状态

- <strong>Windows 11 x64（`MSVC`）</strong>：主要开发与运行环境。
- <strong>Linux</strong>：`toolchain.json` 中包含锁定的交叉构建元数据，但原生 Linux 下的构建与运行尚未经过验证。
- Windows 支持对单文件标量 `check` 和 `run` 使用 AppContainer/Job 隔离。 `restricted: false` 和 `embed: false` 分别表示更广泛的受限执行和 C 嵌入仍待实现。
- <strong>不在规划范围内</strong>：JIT、GC、浮点数（`f32`/`f64`）、原始指针（`ptr`）、任意 C FFI 以及线程。
