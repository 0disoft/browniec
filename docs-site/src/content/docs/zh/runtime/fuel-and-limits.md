---
title: Fuel 与执行限制
description: 了解 Fuel 的计量对象、为何数组与结构体程序需要更大的预算，以及 Fuel 耗尽时的行为。
---

可以把 `browniec run` 中的 <strong>Fuel</strong>（`--fuel N`）想象成预充值的代币：代码运行时，VM 每执行一条指令、一次循环步进或内存池初始化都会扣除固定数量的 Fuel。

## Fuel 是什么（以及它不是什么）

- <strong>确定性的操作预算</strong>：相同的程序在相同的 `--fuel` 下，始终执行完全相同的工作量，并在完全相同的位置停止。
- <strong>不是真实时间计时器</strong>：Fuel 统计的是逻辑上的 VM 工作单元，而不是毫秒时间。
- <strong>Windows 进程隔离</strong>：使用 `--isolated` 运行标量代码时，还会应用 AppContainer 和 Job 限制。

## 默认值（`256`）与数组/记录预算

如果省略 `--fuel`，CLI 默认使用 `256`（允许范围为 `0..16000000`）。

- 简单的标量规则（`answer.brc`、`branches.brc`）在 `256` 以内就能轻松完成。
- 循环程序（`loops.brc`）需要适当调高预算，例如 `--fuel 1000`。
- <strong>数组与记录</strong>：在 `main()` 运行前初始化 64 KiB 聚合内存池（arena）就要消耗 <strong>65,537 Fuel</strong>，因此请传入 `--fuel 100000`（如果涉及记录递归和切片重借用，请传入 `--fuel 1000000`）。

## Fuel 耗尽时会发生什么

当 Fuel 归零时：

1. 执行会干净地停止，不会返回部分完成的 `return_i32`。
2. CLI 会以退出码 <strong>`5`</strong> 退出。
3. 在 `--json` 模式下，`"status"` 为 `"error"`，`"return_i32"` 为 `null`，`"error.kind"` 为 `"fuel"`，并附带从零开始的源码字节偏移量 `byte_offset`：

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"error","return_i32":null,"error":{"kind":"fuel","byte_offset":188}}
```

## 其他执行上限

- <strong>调用栈深度</strong>：最多 `32` 层嵌套栈帧（`frame_limit`）。
- <strong>源码大小</strong>：`4096` 个 UTF-8 字节（`compile_limit`，退出码 `3`）。
- <strong>运行时陷阱</strong>：整数溢出（`overflow`）、除以零（`zero_divisor`）和越界访问（`bounds`）都会干净地停止执行，并返回退出码 `5`。
