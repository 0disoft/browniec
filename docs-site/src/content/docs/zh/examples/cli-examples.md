---
title: 公开 CLI 示例
description: 演练五个可运行的 .brc 示例，涵盖分支、? 错误传播、UTF-8 字节检查、结构体和可变切片。
---

阅读小巧且可运行的程序是熟悉 Brownie C 最快的方式。下面每个示例都位于 `examples/` 目录中，可以直接使用 `./build/browniec.exe` 运行。

## 1. 分支、短路逻辑与递归（`examples/branches.brc`）

短路求值 `||` 和 `&&` 会跳过 `1 / 0` 的求值，而递归函数 `factorial(5)` 会计算得到 `120`：

```c
module main;

fn i32 factorial(i32 n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

fn i32 main() {
    var i32 answer = 0;
    let bool ready = true || (1 / 0 == 0);
    if (ready && factorial(5) == 120) {
        answer = 77;
    } else {
        answer = 1 / 0;
    }
    return answer;
}
```

```powershell
./build/browniec.exe run examples/branches.brc --json
```

输出：`"status":"completed"`，`"return_i32":77`。

## 2. `Option` 与 `Result` 错误传播（`examples/propagation.brc`）

使用 `?` 可以在内联位置解包 `.some` / `.ok`，或在遇到 `.none` / `.err` 时提前返回：

```c
module main;

fn Option<bool> positive(Option<i32> value) {
    return .some(value? > 0);
}

fn Result<i32, bool> add(Result<i32, bool> left, Result<i32, bool> right) {
    return .ok(left? + right?);
}

fn i32 main() {
    switch (positive(.some(77))) {
        case .some(ok): {
            switch (add(.ok(30), .ok(47))) {
                case .ok(value): {
                    if (ok) { return value; }
                    return 0;
                }
                case .err(_): { return 0; }
            }
        }
        case .none: { return 0; }
    }
}
```

```powershell
./build/browniec.exe run examples/propagation.brc --json
```

输出：`"return_i32":77`。

## 3. UTF-8 字节校验（`examples/array-utf8.brc`）

在 `var u8[3]` 中构造一个 3 字节 UTF-8 序列，并用 `text::valid_utf8` 进行校验：

```c
module main;

fn i32 main() {
    var u8[3] bytes = [128; 3];
    bytes[0] = 234;
    bytes[1] = 176;
    if (text::valid_utf8(bytes)) { return 77; }
    return 0;
}
```

由于使用数组的程序需要先消耗 `65,537` Fuel 来初始化 64 KiB 内存池（arena），请传入 `--fuel 100000`：

```powershell
./build/browniec.exe run examples/array-utf8.brc --fuel 100000 --json
```

输出：`"return_i32":77`。

## 4. 辅助记录（`helper-records.brc`）与可变切片（`mutable-slice-reborrow.brc`）

递归构建结构体以及切片重借用比简单的数组读取消耗更多 Fuel（`helper-records.brc` 在 `--fuel 100000` 时会耗尽 Fuel，而在 `--fuel 1000000` 时可以顺利完成）：

```powershell
./build/browniec.exe run examples/helper-records.brc --fuel 1000000 --json
./build/browniec.exe run examples/mutable-slice-reborrow.brc --fuel 1000000 --json
```

两个示例都会以退出码 `0` 退出，并返回 `"return_i32":77`。

> <strong>注意（`examples/projects/hello`）：</strong>多文件目录 `examples/projects/hello`（含 `project.json`）属于未来或内部的包捆绑功能，不能直接传给当前的单文件公开 CLI。
