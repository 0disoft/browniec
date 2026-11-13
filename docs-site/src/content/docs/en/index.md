---
title: Brownie C
description: Embedded rule and byte-transformation language with a deterministic bounded virtual machine implemented in Fairy C.
---

Brownie C is an experimental embedded rule and byte-transformation language with a compiler, bytecode verifier, and bounded virtual machine implemented in **Fairy C**.

In the public `browniec` CLI today, you can compile, verify, and run a single `.brc` source file (up to 4096 UTF-8 bytes) under an explicit deterministic **Fuel** budget and inspect its generated private IR.

## Quick Links

- **Getting Started**: [Introduction](./start/introduction/) · [Installation and Setup](./start/installation/) · [First Program](./start/first-program/)
- **Learn the Language**: [Language Basics](./language/basics/) · [Memory, Arrays, and Borrows](./language/memory-and-resources/)
- **CLI & Status**: [CLI Usage and Common Errors](./cli/commands-and-errors/) · [Current Support and Limitations](./support/status-and-limits/)

## How Brownie C Relates to Fairy C

Brownie C's syntax resembles a strict, bounded subset of **Fairy C**, and its own runtime and CLI are written in Fairy C (`browniec`). However, Brownie C programs do not compile to native executables or call C libraries directly—they run inside a bounded bytecode VM that returns an `i32` data result.
