# M2 Lexical Array Lifetimes

- Status: implemented and focused-harness verified in development and release
- Evidence: [Windows scope receipt](../evidence/m2-array-scopes-windows-20261025.json)
- Scope: fixed scalar arrays in the lexical scopes of zero-argument `fn i32 main()`

## Source behavior

The existing `let|var T[N] name = [EXPR; N];` and exact-type/length copy
initializers are admitted in standalone blocks, `if` branches, `while`/`for`
bodies, switch-statement arms, and switch-expression arms within `main`.
The [read](m2-array-source.md), [write](m2-array-write.md),
[copy](m2-array-copy-source.md), and [length](m2-array-length.md) rules otherwise
apply unchanged. Array lengths remain literals from 1 through 4096.

Names remain local to their declaring scope. Sibling scopes may reuse a name;
redeclaring any currently visible name is rejected. Each executed declaration
evaluates its initializer again, once, before publishing the new binding. A copy
owns independent storage. No array reference or descriptor escapes a scope.

[The example](../../examples/array-scopes.brc) creates a two-element scratch
array for each of three loop iterations and returns 42.

## Cleanup and control flow

The compiler emits the existing `ADROP` in reverse binding order:

- A continuing block releases only its own array bindings before hiding its names.
- A yielding switch-expression arm evaluates its scalar result before releasing
  its local arrays. The result remains usable after that cleanup.
- `break` and `continue` release the arrays declared since entry to the nearest
  loop, including arrays in nested blocks or expression arms. Enclosing arrays
  stay live. A classic `for` executes its post step after continue cleanup.
- `return` evaluates its result first and then releases all visible arrays.
  A block already terminated by a transfer emits no second cleanup.

A `while` condition owns its loop transfers, including transfers inside
statement-bearing switch-expression arms. A transfer from an array initializer
releases already published arrays, without dropping the not-yet-created array.
Execution failures retain the existing VM error and owned-buffer cleanup behavior;
this feature adds no rollback of external effects.

The independent verifier still requires identical live-array sets at CFG joins
and loop backedges and no live arrays at returns. No verifier, VM, allocator,
opcode, or JSON profile change is needed. Source programs retain the existing
read/write/copy profile selection based on their catalog and instructions.

## Bounds and resources

Normal lexical cleanup reclaims the released suffix of the array arena. Native
tests run 42 one-element `i32` array lifetimes in a loop with a four-byte payload
limit. Nested-loop tests use eight bytes for two concurrent four-byte arrays and
check that inner transfers preserve the outer array. These establish storage reuse
for those fixtures, not process-memory or throughput measurements.

The 16-entry catalog limits declaration sites across the entire compiled program,
including mutually exclusive and already-ended scopes. Repeating one declaration
in a loop reuses its catalog ID with a fresh runtime owner token. Seventeen distinct
sites are rejected even when they would not be live simultaneously. Existing
65,536-byte CLI arena, 128 registers/constants, 256 instructions, and depth budgets
still apply. Cleanup consumes the existing 49 Fuel units per executed `ADROP`.
The CLI fixture `{let i32[1] a=[0;1];} return 42;` passes at 65,657 Fuel and fails
at 65,656, including standard arena preparation.

Array declarations in helper functions or classic `for` headers, array
parameters/results, whole-array reassignment, borrows, slices, and aggregate
wrappers remain unavailable.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice scopes
python -B tools/record-m2-array-write-evidence.py --slice scopes --scalar-regression
```

Per development/release profile, the harness runs 19 native groups and 270 array
CLI cases: 67 reads, 61 writes, 58 copies, 40 lengths, and 44 lexical-scope cases.
Earlier nested-declaration rejection fixtures now reject out-of-scope uses instead.
The new cases cover all scalar element types, normal and early exits, loops,
nearest-loop transfers, initializer transfers, switch yields, scope errors,
catalog limits, exact Fuel, bounds, and quota failures with a tool-free `PATH`.
Negative native IR tests remove cleanup at a return or backedge and require
independent verification to fail. The recorder also runs 1,969 scalar CLI cases
per profile against the same hashed executables.

The full 84-group scalar native suite, separate private-array backend and allocator
instrumentation reruns, Linux, isolation, DLL, and performance checks are skipped.
The receipt checks unchanged backend and primitive inputs against earlier evidence.
The compiler's loop-binding metadata changes in this slice; the VM backend does not.

The development native result and executable were reused after correcting one
legacy mutable-array CLI fixture that still expected a nested declaration to fail.
Native compiler/test inputs were checked against commit `52f7bf8`; all five CLI
matrices were executed again. The receipt includes the recovery command, script,
and reused artifact/report identities. Release native tests and the release build
were executed after that correction.
