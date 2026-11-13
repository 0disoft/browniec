---
title: Brownie C
description: An embedded rule and byte-transformation language with a bounded VM implemented in Fairy C.
---

Brownie C is a small **embedded rule and byte-transformation language and bounded VM** implemented in Fairy C.

With the public `browniec` CLI today, you can check a single `.brc` file (up to 4096 UTF-8 bytes), inspect its generated IR, and run it under an explicit **Fuel** operation budget to get back an `i32` result.

## Where to Start

- **Getting Started**: [Introduction](./start/introduction/) · [Installation and Setup](./start/installation/) · [First Program](./start/first-program/)
- **Learn the Language**: [Variables, Types, and Functions](./language/basics/) · [Control Flow and Switch](./language/control-flow-and-switch/) · [Structs, Option/Result, and ?](./language/structs-and-error-handling/) · [Arrays, Slices, and UTF-8](./language/arrays-slices-and-utf8/) · [Borrows, Reborrowing, and Lifetimes](./language/memory-and-resources/)
- **Examples**: [Public CLI Examples](./examples/cli-examples/)
- **Runtime, CLI & Status**: [Fuel and Execution Limits](./runtime/fuel-and-limits/) · [Host Integration, Isolation, and Embedding](./runtime/host-isolation-embedding/) · [CLI Usage and Common Errors](./cli/commands-and-errors/) · [Current Support and Limitations](./support/status-and-limits/)

## How It Differs from Fairy C

Brownie C shares C-shaped syntax with **Fairy C**, and `browniec` itself is written in Fairy C. Unlike Fairy C, however, Brownie C programs do not compile to native executables or call C functions—they execute inside a bounded VM that returns an `i32` data value without touching files or the network.
