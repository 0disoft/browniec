---
title: Introduction
description: What Brownie C is for, how it differs from Fairy C, and what is publicly usable vs. internal or planned.
---

Brownie C is an embedded rule and byte-transformation language and VM runtime being built in **Fairy C**. Its purpose is to check and run small, deterministic programs under strict compile and runtime budgets without ambient access to the filesystem, network, or arbitrary C functions.

## What Brownie C Focuses On

- **Deterministic verification before execution**: Source syntax, types, array/slice borrows, and bytecode invariants are verified before VM dispatch.
- **Checked arithmetic and bounded execution**: Integer overflow, division by zero, and out-of-bounds indices fail cleanly with defined error kinds rather than crashing the host process.
- **Instruction-metered Fuel budgets**: `--fuel` meters VM operations deterministically so loops and array/record operations terminate when the budget runs out.
- **Data-only guest integer return**: A guest `main()` returns an `i32` result value (`return_i32`), kept distinct from the CLI's own process exit code (`0` on completed execution).

## Brownie C vs. Fairy C

| Aspect | Brownie C (`.brc`) | Fairy C (`.fy`) |
| --- | --- | --- |
| Role | Embedded rule and byte-transformation language + VM | Native systems programming language |
| Execution | Verifier + register bytecode VM inside `browniec` | Compiled via C11 to native executables |
| Implementation language | Written in Fairy C | Stage 0 compiler written in Go |
| Direct OS / C ABI access | Excluded (`ptr`, FFI, user `resource` disabled) | Supported via `unsafe extern C fn` and stdlib |
| Budgeting | Explicit instruction `--fuel` cap (default 256, max 16,000,000) | Native OS execution (no VM Fuel meter) |

## Public CLI vs. Internal Engine vs. Design Goals

To avoid confusion while reading the repository, separate what works in the public CLI today from internal engine components and future milestones:

1. **Available in the public CLI (`browniec`)**:
   - Single-file `.brc` checking (`check`), running (`run [--fuel N]`), and IR inspection (`inspect --ir`), with optional `--json` output.
   - Zero-argument `fn i32 main()` entry up to 4096 bytes of UTF-8 source.
   - Bounded scalars, `Option`/`Result` predicates and `?` propagation, fixed arrays (`T[N]`), plain nominal `struct`s, UTF-8/byte literals, and scalar/byte slices (`ref u8[]`, `ref mut u8[]`).
2. **Internal / private repository work (not exposed on the public CLI)**:
   - Internal `Engine` / `Instance` stepping primitives, guest `Buffer` allocation, private multi-source project compilation, and host-wire codecs exist inside `src/` and native test harnesses only. You cannot drive `Engine` or guest `Buffer` workflows directly from the public `browniec` CLI yet.
3. **Planned / unavailable today**:
   - `--isolated` (AppContainer/Job worker isolation), `--project` / policy / grant files, guest `--input` bytes, guest stdout/output sinks, and the C embedding API (only the `bc_get_abi_info_v2` bootstrap symbol is exported in internal native tests; `restricted` and `embed` report `false` in `--version --json`).
   - Also note: **Fuel is an instruction/operation counter, not a wall-clock timeout and not an OS-level security sandbox.**
