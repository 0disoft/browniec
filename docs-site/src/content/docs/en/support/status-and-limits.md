---
title: Current Support and Limitations
description: Public capacity caps, Windows vs. Linux status, and features permanently outside Brownie C's scope.
---

Brownie C keeps strict compile and runtime boundaries on purpose so guest evaluation stays small and predictable. Here is what the public CLI supports today.

## What Works Today

In `browniec --version --json`, `"core": true` reflects the active public experimental subsets (scalars, fixed arrays, plain structs, byte/text literals, and checked slices)—not full language completion.

## Public CLI Capacities

| Item | Current Cap |
| --- | --- |
| Source input | 1 UTF-8 `.brc` file up to `4,096` bytes (`1,024` tokens) |
| Entry point | Zero-argument `fn i32 main()` (no CLI `--input` flag yet) |
| Functions & IR | `16` functions, `128` global registers, `256` instructions |
| Call frames | `32` nested frames |
| Arrays & structs | `16` aggregate sites, up to `4,096` elements per array, `64 KiB` arena |
| Fuel budget | Default `256`, max `16,000,000` |

## Platform & Feature Status

- **Windows 11 x64 (`MSVC`)**: Primary development and execution environment.
- **Linux**: Pinned cross-build metadata exists in `toolchain.json`, but native Linux builds and execution remain unverified.
- **Pending**: `--isolated` OS workers (`restricted: false`), C embedding (`embed: false`), `--project`, guest `--input`/output sinks, and CLI exposure for internal `Engine`/`Buffer` work.
- **Out of scope**: JIT, GC, floating point (`f32`/`f64`), raw pointers (`ptr`), arbitrary C FFI, and threads.
