---
title: Current Support and Limitations
description: Observed browniec capabilities, fixed public compile/runtime capacities, OS verification status, and out-of-scope features.
---

Brownie C is an active prototype targeting deterministic embedded rules and byte transformations. Check `--version --json` on your binary to see its exact delivery flags.

## Delivery Flags Reported Today

Observed on `browniec --version --json`:

- `"core": true`: Covers the currently shipped experimental public subsets (`brownie.m1-scalar/1`, `brownie.m2-array-*`, `brownie.m2-struct-*`, `brownie.m2-reference/1`), **not** full `safe/0.3` language completion.
- `"restricted": false`: AppContainer/Job-based `--isolated` worker execution is **not** available yet.
- `"embed": false`: The public C embedding library lifecycle is **not** available yet (only the bootstrap metadata symbol `bc_get_abi_info_v2` exists in internal native test harnesses).
- `"inspect_ir": true`, `"fuel_default": 256`, `"fuel_limit": 16000000`.

## Current Public Capacities

| Resource | Public CLI Ceiling Today |
| --- | --- |
| Source input | 1 UTF-8 file, up to `4,096` bytes (`1,024` tokens) |
| Entry signature | Fixed zero-argument `fn i32 main()` (no guest `--input` CLI flag yet) |
| Functions & IR | Up to `16` functions, `128` global value registers, `256` instructions |
| Call stack | `32` frames |
| Arrays / records | Up to `16` array/record/slice sites, max `4,096` elements per array, `64 KiB` aggregate arena |
| Fuel budget | Default `256`, max `16,000,000` |

## Platform Status

- **Windows 11 x64 (`MSVC` toolchain)**: Primary development and verification platform for `browniec.exe`.
- **Linux**: `toolchain.json` includes a pinned Linux cross-built `fairyc` compiler entry, but native Linux setup, build, and `browniec` execution remain **unverified**.

## Not Available Publicly Today

- Multi-file `--project`, policy files, capability grants, and external `--input` byte streams on the public CLI.
- Driving internal `Engine`, `Instance`, `step()`, guest `Buffer`, or staged guest output from the CLI.
- Permanent exclusions in the first profile: JIT, garbage collection, floating point (`f32`/`f64`), raw pointers (`ptr`), arbitrary C FFI, closures, threads, and external bytecode loading.
