---
title: Fuel and Execution Limits
description: How Fuel metering works, why arrays/records require higher budgets, exhaustion results, and what Fuel does not guarantee.
---

Brownie C meters VM execution using a numeric **Fuel** budget supplied with `--fuel N` on `browniec run`.

## What Fuel Is (and What It Is Not)

- **Fuel is an instruction and operation counter**: Every VM instruction, arena setup step, array/record copy, and slice call deducts a deterministic Fuel cost.
- **Fuel is NOT a wall-clock timeout**: It counts logical VM work units, not milliseconds or real CPU wall time.
- **Fuel is NOT OS-level security isolation**: It bounds VM execution work, whereas OS sandboxing (such as AppContainer or Windows Job objects) belongs to future restricted worker delivery (`restricted: false` today).

## Default (`256`) and Ceiling (`16,000,000`)

`browniec --version --json` reports `"fuel_default": 256` and `"fuel_limit": 16000000`. Passing a `--fuel` value outside `0..16000000` fails CLI argument parsing (exit code `2`).

Why the budgets vary by program kind:

- **Short scalar rules**: Fit inside the default `256` budget (`examples/answer.brc`, `examples/branches.brc`).
- **Looping scalar rules**: Need explicit `--fuel`, such as `--fuel 1000` for `examples/loops.brc`.
- **Programs with arrays or records**: Preparing the default **65,536-byte backing arena** before `main()` runs costs **65,537 Fuel**. Any array program run with the default `256` exhausts Fuel immediately before user code completes.
- **Record / mutable-slice programs**: Helper records (`examples/helper-records.brc`) and slice reborrows (`examples/mutable-slice-reborrow.brc`) need larger explicit budgets such as `--fuel 1000000`.

## What Happens When Fuel Runs Out

When remaining Fuel hits zero before completion:

1. VM execution stops deterministically without returning a partial `return_i32`.
2. The CLI exits with **process exit code `5`**.
3. Under `--json`, status is `"error"`, `return_i32` is `null`, and `error.kind` is `"fuel"` with the zero-based source `byte_offset`:

```json
{"schema":"browniec.result/v1","profile":"brownie.m1-scalar/1","command":"run","status":"error","return_i32":null,"error":{"kind":"fuel","byte_offset":188}}
```

Running `examples/array-read.brc` at default `256` exhausts Fuel during setup at `"byte_offset":0`. Running `examples/helper-records.brc` at `--fuel 100000` exhausts Fuel inside the call tree at `"byte_offset":212`.

## Other Runtime and Compile Limits

- **Call stack depth**: `32` frames (`frame_limit`, exit `5`).
- **Source size & IR capacities**: `4,096` UTF-8 source bytes, `1,024` tokens, `16` functions, `128` global registers, `256` instructions (`compile_limit`, exit `3`).
- **Aggregate storage**: Up to `16` array/record/slice sites, `4,096` elements per array, `64 KiB` aggregate arena (`array_limit`, `bounds`, `allocation`, exit `5`).
- **Checked arithmetic traps**: Overflow (`overflow`) and zero divisor (`zero_divisor`) also halt execution with exit code `5`.
