---
title: 安装与环境配置
description: 在 Windows 上配置锁定的 Fairy C 工具链并构建 browniec.exe。
---

Brownie C 目前尚未提供预编译安装包。你可以通过仓库内置的辅助脚本配置锁定版本的 Fairy C 编译器，然后从源码构建 `build/browniec.exe`。

## 前置条件

1. Windows 11 x64 上的 <strong>MSVC x64 工具链 + Windows SDK</strong>。
2. <strong>Python 3.10+</strong>（`python3` 或 `py -3`），用于运行 `tools/setup-toolchain.py`。
3. <strong>Go（`go1.27.1`）和 Git</strong>：如果你选择从源码引导编译锁定版本的 `fairyc` 编译器，而不是通过 `--compiler-file path/to/fairyc.exe` 直接指定已有二进制文件，则需要安装它们。

## 1. 克隆并进入源码仓库

如果本地尚未获取源码，请先从 [browniec GitHub 仓库](https://github.com/0disoft/browniec)克隆并进入仓库根目录：

```powershell
git clone https://github.com/0disoft/browniec.git
cd browniec
```

## 2. 配置 `fairyc` 并构建 `browniec.exe`

在 `browniec` 仓库根目录下执行：

```powershell
python3 tools/setup-toolchain.py
./build/toolchain/fairyc.exe build
```

该步骤会准备好 `build/toolchain/fairyc.exe`，并编译生成 `./build/browniec.exe`。

> <strong>注意：</strong>`toolchain.json` 中包含 Linux 工具链的哈希配置，但原生 Linux 下的构建与运行尚未经过验证。

## 3. 验证可执行文件

```powershell
./build/browniec.exe --version
./build/browniec.exe --version --json
```

`restricted_scalar: true` 表示 Windows 单文件标量隔离。更广泛的受限执行和 C 嵌入仍待实现。 版本 JSON 还会报告 `"fuel_default": 256` 和 `"fuel_limit": 16000000`。
