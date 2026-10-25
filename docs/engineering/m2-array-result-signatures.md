# M2 Array Result Signature Foundation

- Status: signature metadata implemented; historical compiler gate superseded by [source lowering](m2-array-result-source.md)
- Scope: exact scalar-array return shapes in the bounded function signature pass
- Evidence: [Windows receipt](../evidence/m2-array-result-signatures-windows-20261025.json)

The signature scanner recognizes `fn ELEMENT[LENGTH] NAME(...)` for `bool`,
`u8`, `i32`, `i64`, `u32`, and `usize`, with integer lengths from 1 through 4096.
It reuses the existing array-length parser. Scalar and shallow wrapper results
retain their grammar. Wrapper-element arrays, multidimensional arrays, slices,
borrowed results, and computed lengths remain rejected.

`functions::Table.return_types[f]` retains the element tag.
`return_lengths[f]` is zero for a scalar/wrapper result or the exact nonzero
length for an array. All 16 slots start at zero; the last function uses slot 15.
This adds 16 `usize` entries (128 bytes on the current 64-bit target) to bounded
signature metadata, without adding an array payload or changing VM frames.
This is a layout count, not an allocation or performance measurement.

`main` must still have no arguments and return scalar `i32`. Even `i32[1] main`
is rejected. Function names, parameter positions, body spans, and the existing
16-function/eight-parameter limits retain their contracts.

## Historical compilation boundary

The following gate describes this foundation checkpoint, not the current compiler.
Source lowering now admits named returns and typed call initializers, retaining
shape validation and rejecting scalar uses. The signature CLI's invalid bodies
still fail, but diagnostics now point into bodies or earlier invalid source;
parameter catalog overflow reports `compile_limit` rather than the old gate.

After the complete signature scan, the compiler checks every result length
before constructing IR or lowering parameter catalogs and bodies. The first
array result produces the existing `type` error at its function name, even for
an unused helper or a declaration following `main`. Checking at most 16 entries
costs O(F) time and O(1) additional working space.

Recognizing an array result must not let its element tag masquerade as a scalar
return. No array-result program produces executable IR in this increment. A
shape-valid declaration previously failed as `syntax`; it now fails as `type`.
Malformed signatures still fail during scanning. The gate does not replace
lexical/syntax checks and does not introduce a new public diagnostic category.

This source is recognized by the signature pass but rejected by compilation:

```c
module main;
fn i32[2] make() { return 42; }
fn i32 main() { return 42; }
```

The gate also precedes invalid body identifiers and array parameter catalog
exhaustion. Existing [source array parameters](m2-array-parameters.md), scalar
functions, and shallow wrapper results continue to compile and run.

## Focused verification

Run the following for development, then repeat with `--release` on Fairy C
commands and `--profile release` on the CLI checks. Retain each profile's
binary before another build replaces `build/browniec.exe`.

```powershell
./build/toolchain/fairyc.exe check --locked
./build/toolchain/fairyc.exe test --native --capture-output --json --locked --file tests/m2/array_result_signatures.fy --file tests/m2/array_signatures.fy --file tests/functions.fy
./build/toolchain/fairyc.exe build --locked
python -B tools/check-m2-array-result-signatures.py --exe build/browniec.exe --profile development
python -B tools/check-m2-array-parameters.py --exe build/browniec.exe --profile development
python -B tools/check-m2-array-helpers.py --exe build/browniec.exe --profile development
python -B tools/check-m1-cli.py --exe build/browniec.exe --profile development
```

The six new native groups cover all element tags, zero sentinels, body/name and
parameter spans, the final metadata slot and function limit, malformed lengths,
`main`, and rejection before body/catalog lowering. Six parameter-signature and
four scalar-function groups provide the remaining focused native checks.
The new CLI matrix has 96 cases across `check` and `run`, both declaration
orders, minimum/maximum lengths, unsupported forms, gate ordering, and valid
scalar/wrapper/array-parameter controls. Guest processes use a cleared runtime
environment and tool-free PATH; this does not establish clean-machine packaging.

The receipt records actual outcomes and binary/input hashes. Earlier parameter
evidence remains historical for the changed compiler/scanner, signature fixture,
and helper/parameter CLI expectation inputs. Backend source comparisons do not
rerun their complete native suites.

Both development and release passed 16 native groups and 2,242 CLI cases each:
96 result-signature, 80 source-parameter, 97 helper-local, and 1,969 scalar cases.
The implementation baseline is `492dabd`; verification used Fairy C revision
`4ce1264273be` (SHA-256
`572395f7f1e425d613c5a69f50b30ed177cda37ca2b1638bd0c11cf79fcbcc77`),
Python 3.14.6 and Windows x64. All eight CLI receipts match the retained binaries,
and their generated fixture hashes were checked. Thirty-one unchanged backend
source hashes match the previous parameter receipt; the standard-library lock
entry is unchanged. Checks were completed individually, as recorded in the receipt.

| Profile | Native CLI SHA-256 |
| --- | --- |
| development | `5068705a04121f8331f3ec7bf573ac579cb80698fc2b83e6cc90d0b132e1a38c` |
| release | `47969805e9ed5dd22f91abb45fa9bdbceca61f0051ca17e8bdacdb6e6ba83358` |

The full scalar and private-array native suites, other array CLI matrices, M0,
allocator instrumentation, Linux execution, isolation, DLL, clean-machine
packaging, and performance measurements are outside this slice.

## Subsequent private VM increment

The [private result increment](m2-array-results.md) adds independently verified
result metadata, caller destinations and callee-to-caller owner transfer without
payload copies. It covers result lifetimes, recursive frames, cleanup, quota
peaks and prepaid Fuel. The signature receipt above is historical for the changed
backend inputs. Source return and destination initialization lowering still need
their own evidence before this compilation gate can be removed.
