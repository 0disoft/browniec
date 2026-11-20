---
title: CLI Usage and Common Errors
description: Public browniec commands, exit codes, and quick fixes for common errors.
---

The public CLI checks and runs one source file at a time. `check` verifies without executing, `run` calls `main()`, and `eval-i32` calls `evaluate(i32)`. Inspection compiles and verifies without running the guest.

## Public Commands

<!-- cli-output:start -->
| Command | Output option | Channel | Schema |
| --- | --- | --- | --- |
| `browniec --version` | — | `stdout` | — |
| `browniec --version` | `--json` | `stdout` | `browniec.version/v1` |
| `browniec check SOURCE` | — | `stderr` | — |
| `browniec check SOURCE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check SOURCE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --catalog FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | — | `stderr` | — |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --catalog FILE --policy FILE --run FILE --host-replies FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run SOURCE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE` | — | `stderr` | — |
| `browniec check --project FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | — | `stderr` | — |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE [--input FILE\|--stdin] [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec check --project FILE --policy FILE --run FILE` | — | `stderr` | — |
| `browniec check --project FILE --policy FILE --run FILE` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec check --project FILE --policy FILE --run FILE` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec run --project FILE --policy FILE --run FILE [--input FILE\|--stdin] [--output FILE]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec eval-i32 SOURCE N [--fuel N]` | — | `stderr` | — |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json` | `stdout` | `browniec.result/v1` |
| `browniec eval-i32 SOURCE N [--fuel N]` | `--json-v2` | `stdout` | `browniec.result/v2` |
| `browniec inspect SOURCE --ir` | — | `stdout` | — |
| `browniec inspect SOURCE --ir` | `--json` | `stdout` | `browniec.ir/v1` |
| `browniec inspect SOURCE --limits` | `--json` | `stdout` | `browniec.limits/v1` |
<!-- cli-output:end -->

The table shows successful output. A dash in the option column means the default text mode. Text errors go to stderr. JSON options emit a single object to stdout, including source errors.

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
