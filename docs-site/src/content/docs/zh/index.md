---
title: Brownie C
description: 一个使用 Fairy C 实现的嵌入式规则与字节转换语言，配有带边界约束的虚拟机。
---

Brownie C 是一门小巧的<strong>嵌入式规则与字节转换语言及受限虚拟机（VM）</strong>，使用 Fairy C 实现。

通过目前的公开 `browniec` CLI，你可以检查单个 `.brc` 文件（最大 4096 个 UTF-8 字节）、查看生成的 IR，并在显式的 **Fuel** 操作预算下运行程序，以获取 `i32` 返回结果。

## 从哪里开始

- <strong>快速入门</strong>：[简介](./start/introduction/) · [安装与环境配置](./start/installation/) · [第一个程序](./start/first-program/)
- <strong>学习语言</strong>：[变量、类型与函数](./language/basics/) · [控制流与 switch](./language/control-flow-and-switch/) · [结构体、Option/Result 与 ?](./language/structs-and-error-handling/) · [数组、切片与 UTF-8](./language/arrays-slices-and-utf8/) · [借用、重借用与生命周期](./language/memory-and-resources/)
- <strong>示例</strong>：[公开 CLI 示例](./examples/cli-examples/)
- <strong>运行时、CLI 与支持状态</strong>：[Fuel 与执行限制](./runtime/fuel-and-limits/) · [宿主集成、隔离与嵌入](./runtime/host-isolation-embedding/) · [CLI 用法与常见错误](./cli/commands-and-errors/) · [当前支持范围与限制](./support/status-and-limits/)

## 它与 Fairy C 有什么区别

Brownie C 与 **Fairy C** 共享类 C 语法，而且 `browniec` 本身也是用 Fairy C 编写的。不过，与 Fairy C 不同的是，Brownie C 程序不会编译为原生可执行文件，也不能调用 C 函数——它们在一个受限的虚拟机中运行，在不接触文件系统或网络的情况下计算并返回一个 `i32` 数据值。
