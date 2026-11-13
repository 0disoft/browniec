---
title: CLI Usage and Common Errors
description: Public browniec CLI commands, JSON schemas, process exit codes, and error kinds.
---

The public `browniec` CLI supports checking, inspecting, and executing single `.brc` files up to 4096 UTF-8 bytes.

## Public Commands

| Command | Purpose |
| --- | --- |
| `browniec --version [--json]` | Print active experimental profile names and capability metadata (`browniec.version/v1`) |
| `browniec --help` | Print CLI usage summary |
| `browniec check SOURCE [--json]` | Lexical, syntax, type, Flow, and bytecode verification checks without executing |
| `browniec run SOURCE [--fuel N] [--json]` | Compile, verify, and run `fn i32 main()` under Fuel budget `N` (default `256`, range `0..16000000`) |
| `browniec inspect SOURCE --ir [--json]` | Compile/verify and print private non-reloadable IR diagnostics (`inspect_ir: true`) |

## Text vs. `--json` Output

- **Text mode**: Keeps stdout empty; `check`, `run`, and errors write to stderr (for example, `checked`, `return_i32=42`, or `browniec: unavailable at byte 0`).
- **`--json` mode**: Writes one JSON object plus a trailing newline to stdout and leaves stderr empty.
  - `check` / `run` emit `"schema":"browniec.result/v1"` with `"command"`, `"profile"`, `"status"` (`"checked"`, `"completed"`, or `"error"`), numeric `"return_i32"` on completed runs, and `"error"` (`{"kind": ..., "byte_offset": ...}`) on failures.

## Process Exit Codes

| Code | Meaning |
| --- | --- |
| `0` | Normal completion of `check`, `inspect`, or `run` (even when `return_i32` is non-zero) |
| `2` | CLI command shape, missing argument, or option parsing error |
| `3` | Lexical, syntax, type, Flow, or compile-limit failure |
| `4` | Policy, grant, entry, host-binding rejection, or `unavailable` feature flag (for example `--isolated`) |
| `5` | Guest trap or quota failure (`fuel`, `overflow`, `zero_divisor`, `bounds`, `frame_limit`, `array_limit`, `allocation`) |
| `6` | Internal compiler or VM invariant verification failure |
| `7` | Input file read or output-sink IO failure (`input_io`) |

## Common Errors and Fixes

| Error `kind` / Symptom | Cause & Fix |
| --- | --- |
| `fuel` (exit `5`) on array or loop code | Default `--fuel` is `256`, while array backing setup alone costs `65,537` Fuel. Re-run with `--fuel 1000` (loops), `--fuel 100000` (simple arrays), or `--fuel 1000000` (helper record/slice benchmarks). |
| `unavailable` (exit `4`) | Passed an unimplemented flag such as `--isolated`. Unsupported options are rejected explicitly rather than ignored. |
| `compile_limit` (exit `3`) | Exceeded single-file limits (`4096` UTF-8 bytes, `1024` tokens, `16` functions, `128` registers, `256` instructions, `16` array/record/slice sites). |
| `overflow` / `zero_divisor` / `bounds` (exit `5`) | Arithmetic overflow, division by zero, or out-of-range array/slice index. |
| `frame_limit` (exit `5`) | Call nesting exceeded the `32`-frame VM stack ceiling. |
