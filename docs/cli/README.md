# CLI Tool

- Status: Experimental native scalar/array/record/scalar-slice CLI (2026-11-03)
- Native runtime: direct bounded `.brc` source execution
- Command owner: [command contract](command-contract.md)

## Available now

```text
browniec --version [--json]
browniec --help
browniec check SOURCE [--json]
browniec run SOURCE [--fuel N] [--json]
```

SOURCE is one local UTF-8 code file, at most 4096 bytes. The entry is zero-argument
`fn i32 main`. Fuel defaults to 256 and accepts 0..16000000; aggregate runs need an
explicit larger budget, usually `--fuel 100000` or `--fuel 1000000`.

The public frontend/VM supports six scalars, branches/loops, shallow i32/bool tags,
explicit widening, fixed scalar arrays, nominal scalar/nested records, aggregate
parameters/results and shared/exclusive scalar-slice parameters. Whole/ranged/
named-slice/temporary-array CALL borrows and array/view UTF-8 checks are available.
See the [documentation index](../README.md) for owning language increment contracts.

Returned-slice signatures/body-origin analysis remain private; every borrowed-
result declaration rejects publicly. Buffer native resources/leases/scanning are
not guest features. The [complete remaining-work audit](../product/04-remaining-work.md)
tracks general references, wider tags, module/visibility/inference syntax and the
runtime/delivery gaps.

## Planned surfaces

Project, policy, catalog, run grants, guest `--input`, output capabilities, inspect
and worker commands are not implemented. `--isolated` reports unavailable and
never launches an unrestricted fallback. Cancellation, deadlines, Engine/Instance
stepping, host suspension and the public DLL are also unavailable.

`core: true` in version JSON means this experimental native CLI exists; it does
not certify full `brownie.safe/0.3`. Restricted/embed remain false. Check/run use
the native frontend directly and do not launch Go, MSVC or a compiler subprocess.
The broad restricted path is a later delivery with its own actual OS evidence.

## Observable contract

[Configuration](configuration.md) owns input precedence and
[output/exit codes](output-and-exit-codes.md) owns framing. `return_i32` is guest
data, never the process exit code. Current stdout JSON is one bounded result;
staged guest output and `output_b64` are future capabilities.

Command/profile changes must update help and the owning contracts together.
Never claim a native/OS/packaged capability from a design or private model, grant
ambient authority, publish failed guest output, or automatically replay external
effects after an unknown outcome.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.
