# M2 Source Array Reads

- Status: implemented and focused-harness verified in development and release
- Scope: immutable scalar-array declarations and indexed reads in the outermost `main` body
- Implementation: [`compiler.fy`](../../src/compiler.fy), [`array_source.fy`](../../src/array_source.fy), and [`locals.fy`](../../src/locals.fy)
- Evidence: [Windows source-array receipt](../evidence/m2-array-source-windows-20261024.json)

The [private entry-array IR](m2-array-ir.md) and [array VM](m2-array-vm.md)
now have a narrow source path. A program can initialize one immutable scalar
array with a repeated scalar expression and read its elements with an exact
`usize` index. The compiler lowers those operations to the existing `AINIT`,
`AREAD`, and `ADROP` instructions. This page owns the admitted source syntax.
The older IR and VM pages retain their original scope and evidence.

## Grammar

```text
module main;

let TYPE '[' LENGTH ']' NAME '=' '[' FILL_EXPR ';' LENGTH ']' ';'
NAME '[' INDEX_EXPR ']'

TYPE ::= bool | u8 | i32 | i64 | u32 | usize
LENGTH ::= a decimal literal from 1 through 4096
```

Both `LENGTH` positions must contain the same positive literal value. The
repeated count is not inferred from the fill or from the destination. The fill
expression must have the exact declared scalar element type. A scalar function
call is allowed in the fill expression. `NAME` becomes visible only after the
array initialization has been compiled, so the initializer cannot refer to the
new array.

`INDEX_EXPR` must produce exact guest `usize`; there is no implicit integer
conversion. An unsuffixed decimal literal receives `usize` context in this
position. The index expression is evaluated once per read. This example returns
42:

```brownie
module main;

fn i32 fill() { return 21; }
fn usize index() { return 1; }

fn i32 main() {
    let i32[2] values = [fill(); 2];
    return values[index()] * 2;
}
```

Save the example as a local source file and use enough Fuel for array
preparation:

```powershell
./build/browniec.exe run examples/array-read.brc --fuel 100000 --json
```

The successful result keeps the existing schema:

```json
{"schema":"browniec.result/v1","profile":"brownie.m2-array-read/1","command":"run","status":"completed","return_i32":42,"error":null}
```

## Scope and lifetime

Arrays may be declared only in the outermost body of `main`, using immutable
`let` declarations. They may not appear in a helper, loop or `for` header, nested
block, switch arm, initializer, parameter list, or result type. `var` array
declarations are rejected.

After declaration, reads may appear in nested scopes and loops that still see the
binding. `break` and `continue` leave the entry arrays live. A normal, early, or
switch-expression-arm return evaluates its result first, emits drops for visible
arrays in reverse binding order, and only then emits `RETURN`. An early return
inside an initializer drops arrays visible before that declaration; the new array
has not been bound yet and is not dropped.

An array name cannot be used as a bare scalar or aggregate value. Element writes,
array copies, array parameters or results, array locals outside outermost
`main`, borrows, `len`, slices, and aggregate calls are not admitted. When any
array catalog entry exists, a source call to `main` is rejected during
compilation, including a call in an otherwise unused function. This prevents a
recursive entry frame from reusing the entry-only array bindings.

## Caps and runtime

The existing bounded resources remain in force. Array declarations add one
16-entry catalog. Arrays do not consume scalar value registers, but each array
name counts as a visible binding.

| Resource | Limit |
| --- | --- |
| UTF-8 source | 4096 bytes |
| Tokens | 1024 |
| Instructions | 256 |
| Constants | 128 |
| Functions | 16 |
| Arguments per function or call | 8 |
| Static call sites | 32 |
| VM frames | 32 |
| Global scalar register cells | 128 |
| Visible bindings per function | 64 |
| Structural, expression, or loop depth | 32 each |
| Array declarations per Program | 16 |
| Elements per array | 1 through 4096 |
| Payload arena | 65536 bytes by default |

The ordinary `run` path uses the fixed 65536-byte arena when a Program has an
array catalog. Preparation costs `1 + B` Fuel for arena ceiling `B`, so the
default arena requires 65537 Fuel before the first guest instruction. The CLI
default of 256 Fuel remains for scalar compatibility and cannot prepare an array
program. Use `--fuel 100000` or `--fuel 1000000` for the current examples; the
accepted maximum is 1000000 and remaining instruction costs still apply.

The admitted array instructions retain the [array VM](m2-array-vm.md) schedule:
initialization costs `49 + 2*w + n + 7`, a read costs `33 + w`, and a drop costs
49, where `w` is the element width and `n` is payload bytes. The fill expression
is evaluated once. Each read evaluates its index once, then performs checked
bounds access. Productive instructions and scalar calls retain their existing
Fuel costs.

A compiled Program is immutable and can be verified or run again. Each run creates
a fresh one-shot owner table and arena. A runtime failure ends that run, discards
its arena buffer, and publishes no result or staged output. There is no automatic
retry.

## Outcomes

A source program with at least one array declaration reports the
`brownie.m2-array-read/1` profile after compilation succeeds, including a later
verification or runtime failure. Scalar programs and failures before successful
compilation, including input and usage failures, retain `brownie.m1-scalar/1`.
The `browniec.result/v1` schema is unchanged.

Version JSON preserves `profile` and adds `array_profile`:

```json
{"schema":"browniec.version/v1","profile":"brownie.m1-scalar/1","array_profile":"brownie.m2-array-read/1","core":true,"restricted":false,"embed":false}
```

An array bounds failure is `bounds` with process exit 5. Arena or owner quota
failure is `array_limit`, allocation failure is `allocation`, and exhausted Fuel
is `fuel`; each exits 5. Syntax, type, and compile-limit rejections use exit 3.
An internal verification failure uses exit 6. Guest output staging and external
effects are outside this slice.

## Verification status

The focused native tests currently contain six source-array groups. They cover
the six scalar element types and length limits, one-time fill and index
evaluation, reverse-order drops on every return form, loop/read lifetimes, exact
`usize` indexing, rejected scope and unsupported forms, bounds and quota failures,
and exact Fuel boundaries. All six groups passed in development and release.

The executed focused command was:

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice source
```

That slice passed 18 native groups in each development and release profile: the
existing five IR, six VM, and one allocation groups plus six new source groups.
It also passed 67 black-box CLI source cases in each profile with a cleared
environment and tool-free runtime `PATH`. The receipt records the frozen source
hashes, compiler identity, and native CLI artifact hashes.

The full M1 scalar regression is scheduled after the focused source slice; its
81 native groups and 1,969 CLI cases per profile are not claimed by this page.
The existing IR and VM receipts are historical after the source compiler changes.
No performance, Linux, sandbox, worker, DLL, packaging, or clean-machine result
is added.

Remaining M2 source work includes writes, copies, array
parameters and results, borrows, aggregate calls, `len`, slices, and complete
frame and borrow lifetime analysis.
