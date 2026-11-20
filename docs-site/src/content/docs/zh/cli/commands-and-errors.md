---
title: CLI 用法与常见错误
description: 公开 browniec 命令、退出码以及常见错误的快速排查方法。
---

公开 CLI 每次处理一个源文件。`check` 只检查，`run` 调用 `main()`，`eval-i32` 调用 `evaluate(i32)`。`inspect` 编译并验证代码，无需运行来宾程序。

## 公开命令

<!-- cli-output:start -->
| 命令 | 输出选项 | 通道 | 模式 |
| --- | --- | --- | --- |
| `browniec --version` | — | `stdout` | — |
| `browniec --version` | `--json` | `stdout` | `browniec.version/v1` |
| `browniec check SOURCE` | — | `stderr` | — |
| `browniec check SOURCE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE` | — | `stderr` | — |
| `browniec check --project FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec eval-i32 SOURCE N [--fuel N]` | — | `stderr` | — |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec inspect SOURCE --ir` | — | `stdout` | — |
| `browniec inspect SOURCE --ir` | `--json` | `stdout` | `browniec.ir/v1` |
| `browniec inspect SOURCE --limits` | `--json` | `stdout` | `browniec.limits/v1` |
<!-- cli-output:end -->

表格列出成功时的输出。选项列中的破折号表示默认文本模式。文本错误写入 stderr。使用 JSON 选项时，结果或源代码错误均以单个对象写入 stdout。

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
