---
title: CLI 用法与常见错误
description: 公开 browniec 命令、退出码以及常见错误的快速排查方法。
---

公开的 `browniec` CLI 直接针对单个 `.brc` 文件工作，提供四个核心命令：`--version`、`check`、`run` 和 `inspect`。

## 公开命令

| 命令 | 用途 |
| --- | --- |
| `browniec --version [--json]` | 打印当前启用的配置档以及默认/最大 Fuel 设置 |
| `browniec check file.brc [--json]` | 检查语法、类型与借用规则，不执行代码 |
| `browniec run file.brc [--fuel N] [--json]` | 在 Fuel 预算 `N` 下运行 `fn i32 main()`（默认 `256`，最大 `16000000`） |
| `browniec inspect file.brc --ir [--json]` | 打印生成的私有 IR 诊断信息，不执行代码 |

文本模式下，状态行（`checked`、`return_i32=77`）会写入 stderr，stdout 保持为空。加上 `--json` 后，会在 stdout 输出单条 JSON 对象（`browniec.result/v1`），而 stderr 保持为空。

## 退出码

- <strong>`0`</strong>：执行成功完成（即使 Guest 代码返回的 `return_i32` 非零）
- <strong>`2`</strong>：CLI 参数无效，或 `--fuel` 超出 `0..16000000` 范围
- <strong>`3`</strong>：编译/类型/借用检查失败，或超出 `compile_limit`
- <strong>`4`</strong>：未实现的标志参数（`--isolated` → `unavailable`）
- <strong>`5`</strong>：运行时陷阱或配额耗尽（`fuel`、`overflow`、`zero_divisor`、`bounds`、`frame_limit`）
- <strong>`6`</strong>：编译器或虚拟机内部不变量错误
- <strong>`7`</strong>：源文件 IO 读取失败（`input_io`）

## 常见错误与解决方法

1. <strong>在循环或数组程序中遇到 `fuel` 错误（退出码 `5`）</strong>：请记住，在 `main()` 运行之前，数组初始化就要消耗 `65,537` Fuel。请传入 `--fuel 100000` 或 `--fuel 1000000`。
2. <strong>使用 `--isolated` 时返回 `unavailable`（退出码 `4`）</strong>：这是目前的预期行为——操作系统级工作进程隔离尚未启用（`restricted: false`）。
3. <strong>处理较大文件时出现 `compile_limit`（退出码 `3`）</strong>：公开 CLI 的输入上限为 `4096` 个 UTF-8 字节、`1024` 个 token、`16` 个函数以及 `256` 条指令。
4. <strong>运行时陷阱（退出码 `5`）</strong>：结合 `--json` 查看 `error.kind` 和 `byte_offset`，定位 `overflow`、`zero_divisor` 或越界 `bounds` 错误。
