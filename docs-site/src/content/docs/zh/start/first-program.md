---
title: 第一个程序
description: 使用 browniec CLI 检查、查看 IR 并运行你的第一个 .brc 规则文件。
---

Brownie C 可以直接处理单个 `.brc` 文件（最大 4096 个 UTF-8 字节）——使用公开 CLI 时无需包目录或清单文件。

## 1. 一个 5 行示例（`examples/answer.brc`）

每个公开的 `.brc` 入口文件都必须定义 `module main;` 以及无参数的 `fn i32 main()`：

```c
module main;

fn i32 main() {
    return 7 * 11;
}
```

## 2. 检查与运行

首先检查语法、类型以及验证规则：

```powershell
./build/browniec.exe check examples/answer.brc
```

它会输出 `checked` 并以退出码 `0` 退出。接下来在虚拟机中运行它：

```powershell
./build/browniec.exe run examples/answer.brc
```

输出：

```text
return_i32=77
```

加上 `--json` 可获取机器可读的输出：

```powershell
./build/browniec.exe run examples/answer.brc --json
```

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"completed","return_i32":77,"error":null}
```

请注意，<strong>`return 77;` 并不会把操作系统的进程退出码设为 77。</strong>因为程序运行成功，CLI 的退出码为 `0`，而 `77` 会作为数据放在 `return_i32` 字段中返回。

## 3. 查看编译后的 IR

如果只想查看生成的 VM 指令而不实际执行代码，可以运行：

```powershell
./build/browniec.exe inspect examples/answer.brc --ir
```

```text
Brownie C private IR diagnostics; not reloadable
profile=brownie.m1-scalar/1
entry=0 instructions=4 registers=3 literal_bytes=0
...
```

## 4. 为循环提供更多 `--fuel`

默认的 Fuel 预算是 `256`。如果用默认 Fuel 运行类似 `examples/loops.brc` 的循环程序，程序会在中途因 `fuel` 错误而停止；传入 `--fuel 1000` 则可以顺利完成：

```powershell
./build/browniec.exe run examples/loops.brc --fuel 1000 --json
```

## 新手常见误区

- <strong>误以为 `return 77;` 是进程退出码</strong>：Guest 代码的返回值是数据（`return_i32`）；非零进程退出码（`2`..`7`）表示发生了错误。
- <strong>使用数组时忘记调整 `--fuel`</strong>：在 `main()` 运行之前，数组初始化会消耗 `65,537` Fuel，因此请至少传入 `--fuel 100000`。
- <strong>源码超过 4096 字节或传入 `--isolated`</strong>：公开 CLI 会直接拒绝超大文件与尚未实现的参数，而不会静默忽略它们。
