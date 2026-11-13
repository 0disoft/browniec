---
title: 宿主集成、隔离与嵌入
description: 区分当前公开 CLI 可运行的功能、内部 Engine 代码中的组件，以及尚在规划中的特性。
---

在阅读 Brownie C 仓库代码时，你会看到 `Engine`、`Instance`、`Buffer`、`--isolated` 以及 C 嵌入 ABI 等组件。由于各项特性正在分阶段推进，分清哪些功能已经能在公开 CLI 中实际运行、哪些仍处于内部或规划阶段会很有帮助。

## 状态一览

| 领域 | 当前公开 CLI | 仓库内部代码（私有） | 规划中（当前 `unavailable`） |
| --- | --- | --- | --- |
| 编译与运行 | 单个 `.brc` 文件（`<= 4096` 字节），`fn i32 main()` | `Engine`、`Program`、`Instance`、单步配额、项目加载器 | 公开 `--project` CLI 与策略文件 |
| Guest 输入/输出 | 无（仅返回 `return_i32`） | 测试中的 `1 MiB` 输入 `Snapshot` 与 `output::emit` | CLI `--input`、`output_b64` 与输出接收器 |
| 字节缓冲区 | 定长数组、普通结构体、字节字面量、切片 | Guest `Buffer`（`bytes::empty`、`bytes::copy`） | 公开的 `Buffer` 编译支持 |
| 宿主调用与策略 | 默认禁止（无宿主调用） | Host-wire TLV 编解码器与策略 JSON 解析器 | VM 宿主调用分发与权限强制执行 |
| 操作系统隔离 | <strong>尚未启用</strong>（`--isolated` 返回退出码 `4`：`unavailable`） | AppContainer/Job 设计文档 | Windows `--isolated` 工作进程（`restricted: true`） |
| C 嵌入 ABI | <strong>尚未启用</strong>（`embed: false`） | `bc_get_abi_info_v2` 元数据与 64 槽位句柄测试 | 完整的 Engine/Program/Instance C 导出接口 |

## 两条实用原则

1. <strong>内部 `Engine` / `Buffer` API 尚不是公开 CLI 功能。</strong>在策略绑定与资源计量全部完善之前，它们仅限于内部模块和原生测试套件使用。
2. <strong>未支持的安全参数会遵循“故障关闭”（fail closed）。</strong>传入 `--isolated` 时程序会以退出码 `4`（`unavailable`）退出，而不会静默退回到非隔离模式继续运行。
