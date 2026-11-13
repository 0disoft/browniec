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

## Public CLI vs. What Is Still Internal or Planned

Today's public `browniec` CLI works on single `.brc` files (up to 4096 UTF-8 bytes) via `check`, `run [--fuel N]`, and `inspect --ir`, supporting scalars, `Option`/`Result` with `?`, fixed arrays, plain structs, byte/text literals, and slices (`ref u8[]`, `ref mut T[]`).

Internal `Engine`/`Instance` APIs, guest `Buffer`, `--isolated` AppContainer/Job workers, `--project`/`--input` flags, and the C embedding ABI (`embed: false`, `restricted: false`) are either internal repo components or planned milestones. Keep in mind that **Fuel counts VM operations—it is not a wall-clock timeout or an OS security sandbox.**
