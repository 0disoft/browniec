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

## 公开 CLI 与内部/规划功能对比

目前的公开 `browniec` CLI 支持通过 `check`、`run [--fuel N]` 和 `inspect --ir` 处理单个 `.brc` 文件（最大 4096 个 UTF-8 字节），涵盖标量运算、带 `?` 的 `Option`/`Result`、定长数组、普通结构体、字节/文本字面量以及切片（`ref u8[]`、`ref mut T[]`）。

内部 `Engine`/`Instance` API、Guest 侧 `Buffer`、`--isolated` AppContainer/Job 工作进程、`--project`/`--input` 参数以及 C 嵌入 ABI（`embed: false`、`restricted: false`）目前属于仓库内部组件或规划中的里程碑。请记住，<strong>Fuel 统计的是 VM 操作数，它既不是真实时间的超时计时器，也不是操作系统级别的安全沙箱。</strong>
