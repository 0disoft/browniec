# M2 Array Function Frames

- Status: implemented and focused-harness verified in development and release
- Evidence: [Windows frame receipt](../evidence/m2-array-frames-windows-20261025.json)
- Scope: private array ownership and lifetime across bounded guest frames
- Integration target: [`ir.fy`](../../src/ir.fy), [`array_verifier.fy`](../../src/array_verifier.fy), [`array_vm.fy`](../../src/array_vm.fy), and [`vm.fy`](../../src/vm.fy)

The foundation gives private array IR and VM execution a function owner
and a frame-local token slot for each catalog array. It preserves the existing public
source boundary: array declarations remain limited to `main`, and this work adds
no source grammar or public opcode. The [whole-array assignment contract](m2-array-assignment.md)
continues to apply within a function.

## Private IR ownership

`Program` carries a bounded `array_functions: u8[16]` map. The map records which
guest function owns each entry in the single 16-entry array catalog. The private
helper `ir::array_in(function, ...)` declares an array for a selected function;
the existing `ir::array(...)` helper remains the shorthand for declaring an entry
function array.

The verifier resolves the catalog ID used by every array instruction and requires
that ID to belong to the instruction's current function. This applies to array
initialization, copy, element read, element write, drop, and whole-array
assignment. Invalid catalog IDs, function owners, or cross-function accesses fail
verification before execution.

An IR builder can create local arrays for helper functions and use
helper recursion without changing the ownership of suspended parent arrays. The
16 catalog entries remain a program-wide limit; different functions may own
different entries, while each instruction can access only its own function's set.

## VM frames and lifetime

The VM retains 32 bounded guest frames. Each frame has 16 private token slots, so
the token map is indexed by `frame * 16 + array_id`. Token bindings for an active
parent stay in the parent's slots while a child executes. A recursive activation
uses another frame's slots instead of overwriting the suspended parent's tokens.
This uses 512 fixed `Token` records, each containing two `usize` fields, instead
of the previous 16 records. The map is part of bounded run state; no per-call
allocation or linear token search is introduced. Its O(F * C) metadata cost for
F frame slots and C catalog entries is separate from the payload quota.

All frames share one owner table with 16 live-owner slots and one payload arena
with a ceiling of 65,536 bytes. Thus the frame token map does not multiply owner
or payload capacity: at most 16 array owners can be live across the run. Helper
calls use the shared arena and owner table through the existing metered array
operations.

A successful `RETURN` requires the returning function's local live-array set to
be empty. Parent arrays remain live but are excluded from the callee's verifier
state and are available when the parent resumes. Any array or owner error ends the
whole run; execution does not continue in the caller. The run-owned payload buffer
is reclaimed during error exit.

`CALL` performs no array allocation, copy, or token transfer. Scalar argument
movement and the existing `1 + arity` call charge remain unchanged.

The existing metered array work stays in force. For element width `w`, payload
bytes `n`, literal length `L`, and selected arena ceiling `B`:

| Operation | Existing Fuel charge |
| --- | --- |
| Arena preparation | `1 + B` |
| `AINIT` | `49 + 2w + n + 7` |
| `ACOPY` | `49 + n + 7 + (bool ? L : 0)` |
| `AREAD` | `33 + w` |
| `AWRITE` | `33 + 2w` |
| `ADROP` | `49` |
| `AASSIGN` | `81 + n + (bool ? L : 0)` |

These charges are unchanged by function ownership or frame-local token slots.

The recursive i32 fixture retains four one-element arrays in a 16-byte arena:
686 Fuel succeeds and 685 fails. A separate fixture allocates only after its
recursive call returns, reaches frame 31 with catalog ID 15, and reuses a
four-byte arena on unwind. One further frame fails with `frame_limit`.

## Source boundary

The source grammar still permits arrays only in `main`. Array declarations in
helper source functions, array parameters, array results, and borrows remain
unimplemented. In an array program, a `CALL` to the entry function remains
rejected; private helper calls and recursion are the intended nested-frame path.

## Verification

```powershell
pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice frames
python -B tools/record-m2-array-write-evidence.py --slice frames --scalar-regression
```

The focused harness passed 24 native groups per development/release profile:
five array IR, six array VM, two assignment storage, three assignment source,
three function ownership, and five recursive-frame groups. The same binaries
passed 329 array CLI cases per profile: 67 reads, 61 writes, 58 copies, 40 lengths,
44 lexical scopes, and 59 whole-array assignments. CLI subprocesses use a
tool-free `PATH`; this does not establish OS isolation.
The recorder also passed 1,969 scalar CLI cases per profile on those same binaries.

The native frame tests cover all six scalar element types, 24 sequential calls
while a caller array stays live, recursive parent preservation, exact Fuel,
shared owner and payload exhaustion, the highest frame/catalog token index,
frame exhaustion, return cleanup rejection, and explicit fresh executions after
failures. The malformed ownership tests reject invalid function IDs, nonzero
unused metadata, and foreign-function array instructions.

The changed IR, independent verifiers, array dispatch, VM, and array IR fixture
receive fresh checks. The prior assignment receipt is historical for these
inputs. The complete 84-group scalar native suite, M0 native rerun, allocator
instrumentation, Linux execution, isolation, DLL, and performance measurements
are skipped.

## Staged next work

The stages below are proposals and are not implemented or verified.

1. **Helper source declarations.** Lower the existing local array declaration,
   read, write, copy, length, assignment, and lexical cleanup behavior for helper
   functions. Declarations use function-specific catalog ownership and the same
   frame-local live-set and drop rules. Array parameters and results remain out of
   scope for this stage. Scalar and wrapper return paths, including `?` failure
   edges, need local cleanup before admitting helper source arrays on those paths.
2. **Exact-shape by-value parameters.** Add exact element-type and length matches
   as immutable callee parameters. Each parameter receives an independent copy.
   The caller evaluates and captures each argument exactly once, left to right,
   before later argument effects can change the captured value. Copy accounting
   must include the old and new payload extents when checking the arena peak, and
   a failed copy must roll back every partial copy and owner mutation before the
   call transaction is rejected. Verifier call-shape checks must tie each argument
   to its parameter and to frame-specific ownership. Array returns and borrows
   remain separate future work.

No implementation or test result for either stage is claimed here.
