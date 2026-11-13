---
title: 简介
description: 了解 Brownie C 的设计初衷、与 Fairy C 共享的语法，以及当前公开 CLI 支持的功能。
---

有时应用程序需要执行一段简短的规则校验或字节检查，但又不能让这段代码访问文件、打开网络连接或在死循环中一直卡住。

Brownie C 正是为这类受控求值场景而生的，它是一门用 Fairy C 构建的<strong>带边界约束的嵌入式规则与字节转换语言 + VM</strong>。

## Brownie C 的特点

- <strong>熟悉的类 Fairy C 语法</strong>：支持 `let`/`var`、`if`/`switch`、`for`/`while`、普通 `struct` 以及 `Option`/`Result`。
- <strong>刻意精简功能面</strong>：去除了原始指针（`ptr`）、任意 C FFI、用户自定义 `resource` 类型、浮点数、线程以及垃圾回收（GC）。
- <strong>安全检查的算术与 `--fuel` 计量</strong>：整数溢出、除以零和数组越界访问会安全终止，而 `--fuel` 用于限制 VM 的总操作量。
- <strong>返回数据而非 OS 退出码</strong>：在 `fn i32 main()` 中执行 `return 77;` 会报告 `return_i32=77`，同时保持 CLI 进程本身的退出码为 `0`。

## 与 Lua、Python 等解释型语言有何不同？

虽然 Lua 和 Python 也常被用来在宿主程序里嵌入小型脚本，但 Brownie C 做出了截然不同的取舍：

- <strong>在运行前检查类型、分支与借用</strong>：Lua 和 Python 在运行时进行动态类型检查，而 Brownie C 会在执行前就拦截整数类型混用、`switch` 分支遗漏以及 `ref`/`ref mut` 切片借用冲突。
- <strong>没有 GC、浮点数和默认 I/O</strong>：通用脚本语言通常自带垃圾回收器、浮点数运算和操作系统/文件模块；Brownie C 刻意省去这些特性，让整数与字节规则计算保持确定性。
- <strong>原生内置 Fuel 计量</strong>：在 Lua/Python 中限制死循环通常需要自行配置调试钩子或看门狗，而 Brownie C VM 会在每一步操作中扣除 `--fuel` 并在预算耗尽时安全停机（需注意 Fuel 是操作计数而非真实时间超时或 OS 沙箱）。
- <strong>定位与成熟度</strong>：Lua 和 Python 拥有成熟生态与丰富的第三方库，而 Brownie C 目前仍是专注于单文件（最大 4096 字节）小规模规则与字节校验的早期实现，C 嵌入 ABI 和操作系统级隔离仍在规划中。

## 公开 CLI 与内部/规划功能对比

目前的公开 `browniec` CLI 支持通过 `check`、`run [--fuel N]` 和 `inspect --ir` 处理单个 `.brc` 文件（最大 4096 个 UTF-8 字节），涵盖标量运算、带 `?` 的 `Option`/`Result`、定长数组、普通结构体、字节/文本字面量以及切片（`ref u8[]`、`ref mut T[]`）。

内部 `Engine`/`Instance` API、Guest 侧 `Buffer`、`--isolated` AppContainer/Job 工作进程、`--project`/`--input` 参数以及 C 嵌入 ABI（`embed: false`、`restricted: false`）目前属于仓库内部组件或规划中的里程碑。请记住，<strong>Fuel 统计的是 VM 操作数，它既不是真实时间的超时计时器，也不是操作系统级别的安全沙箱。</strong>
