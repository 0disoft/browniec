# M2 Scalar Array Layout Foundation

- Scope: private Fairy C layout and arena-preflight primitives.
- Implementation: [`src/array_layout.fy`](../../src/array_layout.fy).
- Harness: [`tools/verify-m2-layout.ps1`](../../tools/verify-m2-layout.ps1).
- Evidence: [Windows receipt](../evidence/m2-array-layout-windows-20261023.json).

The successor [storage slice](m2-array-storage.md) connects this unchanged layout
to scalar codecs and caller-owned backing bytes. This document retains the
original layout-only scope and receipt.

This first M2 slice prepares compact array storage independently of the scalar
VM's 128 value registers. It does not admit array source syntax or execute array
instructions. The M1 CLI grammar, profile name, opcodes, frames, and Fuel schedule
remain unchanged.

## Layout

An array has one admitted scalar element type and a literal length 1..4096.
Wrapper and unknown tags are rejected. This private layout uses these widths:

| Element | Existing scalar tag | Stride and alignment in bytes | Maximum payload bytes |
| --- | --- | --- | --- |
| bool | 2 | 1 | 4096 |
| u8 | 10 | 1 | 4096 |
| i32 | 1 | 4 | 16384 |
| u32 | 11 | 4 | 16384 |
| i64 | 9 | 8 | 32768 |
| 64-bit usize | 12 | 8 | 32768 |

Alignment is an offset constraint in the planned arena, not permission to form a
native pointer or expose C layout. A layout records element tag, length, stride,
alignment, and payload bytes. `validate` recomputes the canonical layout and
rejects changed metadata before division, multiplication, or indexing. The bounds
on length and stride prove the size multiplication is at most 32768.

This increment defines no byte codec or bool load/store operation. Canonical bool
bytes and initialized payload publication remain obligations for storage execution.

## Preflight and indexing

`reserve(layout, used, limit)` returns an aligned offset, exclusive end, and charge.
Charge includes all alignment padding after `used`. It checks metadata, an
already-over-limit arena, alignment addition, payload addition, and the final
ceiling before returning a plan. For example, after three u8 bytes, two i64 values
start at byte 8, end at byte 24, and charge 21 bytes. A ceiling of 23 rejects the
plan. Arithmetic beyond 64-bit usize returns Overflow before the native operation.

Planning is pure: failure and success change no ledger and allocate nothing. A
caller must reserve the actual instance/engine and owner costs, allocate fallibly,
initialize, and commit separately in a future storage slice. The supplied arena
ceiling is not a complete runtime memory-accounting policy. Old-plus-new copy peaks
and frame reclamation remain unimplemented.

`offset(layout, base, index, storage_bytes)` checks metadata, index bounds, base
alignment, and the entire array extent before returning an element offset. The
containment test subtracts only after checking `base <= storage_bytes`. Even a
valid first element is rejected if the rest of its array would be out of bounds.
The successful containment proof bounds the final multiplication and addition.
No pointer or payload access occurs in this helper.

Type, Length, Metadata, Overflow, Quota, Bounds, and Alignment are private planner
errors. They are not new CLI diagnostics or public ABI values.

## Verification and next work

The focused harness executes six native groups in development and release using
the retained Fairy C `4ce12642` compiler. Tests cover all six scalar types at length
1 and 4096, every rejected u8 type tag, invalid lengths, corrupt metadata including
zero alignment and maximum stride, alignment padding, exact and insufficient
ceilings, repeat planning after rejection, usize arithmetic edges, and whole-array
index containment.

M2 tests live under `tests/m2/`; the M1 harness explicitly selects root-level test
files so its 81 scalar groups remain independently countable. Its selector is
checked without claiming a new M1 runtime run. The earlier M1 1,969 CLI cases per
profile remain recorded evidence for unchanged scalar execution code. M0 inputs
and the compiler binary are unchanged and are not rerun here.

Next: connect a bounded payload arena and checked scalar codecs, then source
initializers, by-value copies, index reads/writes, independent IR verification,
frame cleanup, and metering. Structs, borrows, Buffer and input/output remain later
M2 slices. No array end-to-end, allocation-failure, isolation, DLL, clean-machine,
or performance result follows from these planner tests.
