---
title: Fuel and Execution Limits
description: What Fuel counts, why array/struct programs need bigger budgets, and how Fuel exhaustion behaves.
---

Think of **Fuel** (`--fuel N` on `browniec run`) as prepaid tokens spent by the VM as your code runs. Every instruction, loop step, and arena setup deducts a fixed amount of Fuel.

## What Fuel Is (and Is Not)

- **A deterministic operation budget**: The same program with the same `--fuel` always executes the same amount of work and stops at the same point.
- **Not a wall-clock timer**: Fuel counts logical VM work units, not milliseconds.
- **Not an OS security sandbox**: Fuel prevents runaway loops; OS-level worker isolation (`--isolated`) is a separate planned layer (`restricted: false` today).

## Default (`256`) vs. Array & Record Budgets

If you omit `--fuel`, the CLI uses `256` (accepted range is `0..16000000`).

- Simple scalar rules (`answer.brc`, `branches.brc`) finish well within `256`.
- Loops (`loops.brc`) need a modest bump such as `--fuel 1000`.
- **Arrays and records**: Setting up the 64 KiB aggregate arena before `main()` runs costs **65,537 Fuel**, so pass `--fuel 100000` (or `--fuel 1000000` for record recursion and slice reborrowing).

## What Happens When Fuel Runs Out

When Fuel reaches zero:

1. Execution stops cleanly without returning a partial `return_i32`.
2. The CLI exits with status **`5`**.
3. Under `--json`, `"status"` is `"error"`, `"return_i32"` is `null`, and `"error.kind"` is `"fuel"` with the zero-based source `byte_offset`:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"error","return_i32":null,"error":{"kind":"fuel","byte_offset":188}}
```

## Other Execution Caps

- **Call stack depth**: Up to `32` nested frames (`frame_limit`).
- **Source size**: `4096` UTF-8 bytes (`compile_limit`, exit `3`).
- **Traps**: Integer overflow (`overflow`), divide-by-zero (`zero_divisor`), and out-of-bounds access (`bounds`) all stop cleanly with exit status `5`.
