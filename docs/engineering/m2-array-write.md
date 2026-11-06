# M2 Source Array Writes

This page records the write increment. Its receipt is historical after the later
[copy-initializer slice](m2-array-copy-source.md), which adds independent array copies.

The [2026-11-06 selected-place successor](array-place-assignment.md) now supersedes
this checkpoint's late bounds check, plain-write Fuel oracles and compound gate.
Owned-array source checks its target before RHS and supports all ten checked
integer compounds. The remaining statements and receipt below retain the
original increment's historical scope.

- Status: implemented and focused-harness verified in development and release
- Scope: mutable scalar-array declarations and indexed element writes in the outermost `main` body
- Evidence: [Windows write receipt](../evidence/m2-array-write-windows-20261024.json)

This slice extends the [source-array read contract](m2-array-source.md) with
`var` declarations and element assignment. It uses the private
[entry-array IR](m2-array-ir.md) and the existing [array VM](m2-array-vm.md)
`AWRITE` instruction.

## Grammar

```text
module main;

var TYPE '[' LENGTH ']' NAME '=' '[' FILL_EXPR ';' LENGTH ']' ';'
NAME '[' INDEX_EXPR ']' '=' VALUE ';'

TYPE ::= bool | u8 | i32 | i64 | u32 | usize
LENGTH ::= a decimal literal from 1 through 4096
```

Both length positions must contain the same literal. The fill and assigned
value must have the exact declared element type. `INDEX_EXPR` must produce exact
guest `usize`; unsuffixed decimal literals receive `usize` context, and other
integer types require an explicit cast.

`let` remains the immutable declaration form. Only a `var` array may be the
destination of an element assignment. Writes may appear in nested blocks, loops,
switch statements, and switch-expression arms that see the binding.

Bare array assignment, compound element assignment, arrays in helpers or nested
declarations, and element assignment in any classic `for` header remain rejected.

## Evaluation order

An element assignment evaluates its index expression exactly once, before it
evaluates the right-hand expression exactly once. The `AWRITE` instruction runs
after both operands succeed. Its bounds check therefore occurs after RHS
evaluation: an RHS error or early return precedes any bounds failure and prevents
execution of `AWRITE`. An index error also prevents RHS evaluation and `AWRITE`.

Visible arrays retain the read slice's lifetime behavior. A normal, early, or
switch-arm return evaluates its result first, drops visible arrays in reverse
binding order, and then emits `RETURN`. An early return from an index or RHS
follows that cleanup path without publishing an array write.

## Results and Fuel

The `browniec.result/v1` schema, diagnostic kinds, quotas, and accepted Fuel range
are unchanged. `AWRITE` costs `33 + 2*w` Fuel, where `w` is the element width,
in addition to evaluation of its index and RHS. Arena preparation and the other
array instruction costs retain the [VM schedule](m2-array-vm.md).

A program with any mutable array catalog entry reports
`brownie.m2-array-write/1` after successful compilation, including a later
verification or runtime failure. Scalar programs and programs with only immutable
arrays retain `brownie.m1-scalar/1` and `brownie.m2-array-read/1`
respectively. Version JSON preserves `profile` and `array_profile`, and adds
`array_write_profile`:

```json
{"schema":"browniec.version/v1","profile":"brownie.m1-scalar/1","array_profile":"brownie.m2-array-read/1","array_write_profile":"brownie.m2-array-write/1","core":true,"restricted":false,"embed":false}
```

## Example

`examples/array-write.brc` writes `20` and `22` and returns `42`:

```brownie
module main;

fn i32 main() {
    var i32[2] values = [0; 2];
    values[0] = 20;
    values[1] = 22;
    return values[0] + values[1];
}
```

## Verification

The focused command passed in development and release:

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice write
python -B tools/record-m2-array-write-evidence.py
```

Each profile passed nine native groups (six read and three write), 67 read CLI
cases, and 61 write CLI cases. The new groups cover all six scalar domains,
index/RHS snapshots and evaluation counts, nested writes, early-return cleanup,
rejected targets/headers, guest bounds and first faults, and exact Fuel. The
one-element i32 write/read example needs 65737 Fuel with the default arena;
65736 reports guest `fuel`. A failed one-shot run does not poison a fresh run.

The recorder checked source, compiler, artifact, and CLI receipt identities.
Its scalar regression passed all 1,969 CLI cases per profile against the same
verified binaries, using:

```powershell
python -B tools/record-m2-array-write-evidence.py --scalar-regression
```

A full 81-group scalar native rerun was skipped for this frontend increment:
the backend and verifier inputs are unchanged, and focused native tests exercise
the new parser. The receipt distinguishes current CLI coverage from earlier
native evidence.

The [read receipt](../evidence/m2-array-source-windows-20261024.json) remains
historical after the compiler changes. No Linux, isolation, DLL, allocator
instrumentation, or performance result is added by this slice.
