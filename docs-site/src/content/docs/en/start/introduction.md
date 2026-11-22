---
title: Introduction
description: Why Brownie C exists, what syntax it shares with Fairy C, and what works in the public CLI today.
---

Sometimes an application needs to evaluate a small rule or byte check without letting that code touch files, open sockets, or spin forever in an infinite loop.

Brownie C is a **bounded embedded rule and byte-transformation language + VM** built in Fairy C for exactly that kind of contained evaluation.

## What Makes Brownie C Different

- **Familiar Fairy C-like syntax**: Uses `let`/`var`, `if`/`switch`, `for`/`while`, plain `struct`s, and `Option`/`Result`.
- **Intentionally restricted**: Raw pointers (`ptr`), arbitrary C FFI, user `resource` types, floats, threads, and GC are excluded.
- **Checked math and `--fuel` metering**: Integer overflow, divide-by-zero, and out-of-bounds array accesses stop cleanly, while `--fuel` caps total VM operations.
- **Data return, not OS exit status**: Returning `77` from `fn i32 main()` reports `return_i32=77` while keeping the CLI process exit code at `0`.

## How Does It Compare to Lua and Python?

While Lua and Python are also used to run embedded scripts inside a host application, Brownie C takes a very different trade-off:

- **Static checking before anything runs**: Lua and Python check types dynamically at runtime, whereas Brownie C rejects mismatched integer types, missing `switch` cases, and conflicting `ref`/`ref mut` slice borrows before execution starts.
- **No GC, no floats, and no ambient I/O**: General-purpose scripting languages include garbage collection, floating-point math, and standard OS/file modules. Brownie C leaves those out so small integer and byte checks stay deterministic.
- **Built-in Fuel metering**: Instead of wiring custom interpreter hooks or watchdogs for infinite loops, Brownie C deducts `--fuel` on every VM operation and stops cleanly when the budget hits zero (while keeping in mind that Fuel is an operation counter, not a wall-clock timeout or OS sandbox).
- **Scope and maturity**: Lua and Python are mature ecosystems with rich libraries and host APIs, while Brownie C is an early single-file (up to 4096-byte) rule/byte-checking language with Windows single-file scalar isolation.

## Public CLI vs. What Is Still Internal or Planned

Today's public `browniec` CLI works on single `.brc` files (up to 4096 UTF-8 bytes) via `check`, `run [--fuel N]`, and `inspect --ir`, supporting scalars, `Option`/`Result` with `?`, fixed arrays, plain structs, byte/text literals, and slices (`ref u8[]`, `ref mut T[]`).

Windows supports AppContainer/Job isolation for single-file scalar `check` and `run`. Broader isolation and C embedding are tracked by `restricted: false` and `embed: false`.
