---
title: CLI Usage and Common Errors
description: Public browniec commands, exit codes, and quick fixes for common errors.
---

The public `browniec` CLI works directly on single `.brc` files with four core commands: `--version`, `check`, `run`, and `inspect`.

## Public Commands

| Command | Purpose |
| --- | --- |
| `browniec --version [--json]` | Print active profiles and default/max Fuel settings |
| `browniec check file.brc [--json]` | Check syntax, types, and borrows without executing |
| `browniec run file.brc [--fuel N] [--json]` | Run `fn i32 main()` under Fuel budget `N` (default `256`, max `16000000`) |
| `browniec inspect file.brc --ir [--json]` | Print generated private IR diagnostics without executing |

Text mode writes status lines (`checked`, `return_i32=42`) to stderr and leaves stdout empty. Adding `--json` emits one JSON object (`browniec.result/v1`) to stdout with empty stderr.

## Exit Codes

- **`0`**: Completed cleanly (even when guest `return_i32` is non-zero)
- **`2`**: Bad CLI flags or `--fuel` out of `0..16000000`
- **`3`**: Compile/type/borrow failure or `compile_limit` exceeded
- **`4`**: Unimplemented flag (`--isolated` → `unavailable`)
- **`5`**: Runtime trap or quota (`fuel`, `overflow`, `zero_divisor`, `bounds`, `frame_limit`)
- **`6`**: Internal compiler/VM invariant error
- **`7`**: Source file IO failure (`input_io`)

## Common Errors and Fixes

1. **`fuel` error (exit `5`) on loops or arrays**: Remember that array initialization costs `65,537` Fuel before `main()` runs. Pass `--fuel 100000` or `--fuel 1000000`.
2. **`unavailable` (exit `4`) with `--isolated`**: Expected today—OS worker isolation is not enabled yet (`restricted: false`).
3. **`compile_limit` (exit `3`) on larger files**: Public CLI input is capped at `4096` UTF-8 bytes, `1024` tokens, `16` functions, and `256` instructions.
4. **Runtime trap (exit `5`)**: Check `error.kind` and `byte_offset` with `--json` to spot `overflow`, `zero_divisor`, or out-of-range `bounds`.
