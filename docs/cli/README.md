# CLI Tool

- Status: Experimental native scalar/array/record/scalar-slice CLI (2026-11-06)
- Native runtime: direct bounded `.brc` source execution
- Command owner: [command contract](command-contract.md)

## Available now

```text
browniec --version [--json]
browniec --help
browniec check SOURCE [--json]
browniec run SOURCE [--input FILE|--stdin] [--fuel N] [--json|--json-v2]
browniec check --project FILE [--json|--json-v2]
browniec check --project FILE --policy FILE --run FILE [--json|--json-v2]
browniec run --project FILE [--input FILE|--stdin] [--fuel N] [--json|--json-v2]
browniec run --project FILE --policy FILE --run FILE [--input FILE|--stdin] (--json|--json-v2)
```

SOURCE is one local UTF-8 code file, at most 4096 bytes. With explicit binary guest
input, Windows selects `pub fn i32 main(ref u8[] data)` in `module main`. Otherwise
the entry is zero-argument `fn i32 main`. Fuel defaults to 256 and accepts 0..16000000; aggregate runs need an
explicit larger budget, usually `--fuel 100000` or `--fuel 1000000`.

The public frontend/VM supports six scalars, branches/loops, shallow i32/bool tags,
explicit widening, fixed scalar arrays, nominal scalar/nested records, aggregate
parameters/results and shared/exclusive scalar-slice parameters. Whole/ranged/
named-slice/temporary-array CALL borrows and array/view UTF-8 checks are available.
See the [documentation index](../README.md) for owning language increment contracts.
Local types can be omitted for existing scalar and complete tagged expressions:
`let name = value;` or `var name = value;`. See the [implemented boundary](../engineering/local-inference.md);
the [owned aggregate successor](../engineering/aggregate-inference.md) adds repeated
arrays, nominal constructors, copies, aggregate CALLs and record child paths.
Existing [reference/text initializers](../engineering/reference-inference.md),
shared aliases, explicit exclusive reborrows and shared-byte result bindings now
support inference with the same ownership and Fuel rules. The
[Option constructor successor](../engineering/option-constructor-inference.md)
infers `.some` from i32/bool payloads. Context-free `.none`/`.ok`/`.err` still need
type information; broader constructor context and general aggregate expressions
remain pending.

Retained byte/text/shared-byte result source is public under
`brownie.m2-reference/1`; general mutable/non-byte/Buffer/input results and
host-visible reference lifetimes remain open. Buffer native resources/leases/scanning are
not guest features. The [complete remaining-work audit](../product/04-remaining-work.md)
tracks general references, wider tags, module/visibility/inference syntax and the
runtime/delivery gaps.

## Planned surfaces

Windows project execution and explicit binary project input are described in
[project selection](configuration.md#project-selection). [Configured runs](configuration.md#configured-project-output)
also support the output capability and compile/run deadlines. Catalog flags, workers, cancellation controls, host suspension and the public DLL
remain pending. `--isolated` reports unavailable.

`core: true` in version JSON means this experimental native CLI exists; it does
not certify full `brownie.safe/0.3`. Restricted/embed remain false. Check/run use
the native frontend directly and do not launch Go, MSVC or a compiler subprocess.
The broad restricted path is a later delivery with its own actual OS evidence.

## Observable contract

[Configuration](configuration.md) owns input precedence and
[output/exit codes](output-and-exit-codes.md) owns framing. `return_i32` is guest
data, never the process exit code. Current stdout JSON is one bounded result;
configured project results can include `output_b64` for sealed guest output.

Command/profile changes must update help and the owning contracts together.
Never claim a native/OS/packaged capability from a design or private model, grant
ambient authority, publish failed guest output, or automatically replay external
effects after an unknown outcome.

Version JSON exposes `fuel_default` and `fuel_limit` from the same schedule as argument
validation. Existing lower budgets remain valid. See the
[public cost/limit contract](../engineering/public-fuel-limits.md) for the exact
price formulas, full-arity CALL rationale and verification scope.
