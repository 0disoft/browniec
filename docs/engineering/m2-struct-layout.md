# M2 Private Struct Layout Planner

- Status: verified private planner receipt; development and release passed.
- Scope: private Fairy C planning for plain acyclic records.
- Implementation: [src/struct_layout.fy](../../src/struct_layout.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py).
- Evidence: [Windows receipt](../evidence/m2-struct-layout-windows-20261026.json).

This increment adds no source struct syntax, storage, codec, ownership, IR, VM,
Fuel, CLI artifact, or allocator call. It plans record metadata for a future
storage slice. M2 remains incomplete.

## Catalog contract

A catalog holds 0..32 records and 16 field slots per record. Each active record
must declare 1..16 fields. Slots at or beyond that count, and every slot of an
inactive record, must keep zero kind and type bytes. The full catalog is
validated, including disconnected records.

A field has one of two kinds:

- kind 0 (scalar): a tag accepted by the shared scalar-array layout: bool, u8,
  i32, u32, i64, or usize.
- kind 1 (record): an in-catalog record ID, including a forward reference.

Self, mutual, and disconnected cycles are rejected. Field kinds, counts, and types
are checked before layout arithmetic. Wrapper fields are unsupported.

## Layout

Scalar widths are 1 byte for bool and u8, 4 for i32 and u32, and 8 for i64 and
usize. Scalar alignment equals its width. Fields are placed in declaration order:
each offset is rounded up to its width or child alignment, and the record size is
rounded up to the largest field alignment. Shared children are laid out by value,
so repeated children consume repeated bytes.
The resulting offsets and sizes describe a private arena layout, not host
pointers or a C ABI.

For `u8`, `i64`, `bool`, `u32`, the offsets are 0, 8, 16, and 20. The size and
alignment are 24 and 8.

Depth is 1 for a scalar-only record and `1 + max(child depth)` otherwise. The
16-level structural limit is separate from the 32-record catalog capacity.

The caller supplies a per-record byte ceiling that applies to every record. It
includes alignment padding. Additions are guarded by subtraction from the maximum
usize, so overflow returns `Overflow` before a native trap. Validation precedes
all arithmetic.

## Failure and work bounds

Planning returns `Limit`, `Fields`, `Type`, `Metadata`, `Cycle`, `Depth`,
`Overflow`, or `Quota`. Any error publishes no partial plan and leaves the caller's
catalog unchanged. The planner allocates no heap or payload and makes no measured
allocation, stack, or performance guarantee.

Dependencies are resolved by bounded iterative passes. No native recursion is
used, and shared subgraphs are not expanded exponentially. Dependency checks
examine at most R²F field references in total (16,384 at the limits); a single
ready check examines at most F. Validation scans all 512 catalog slots, while
placement visits at most 512 active fields. Metadata is O(RF) and planning work
is O(R²F).

## Verification and next work

`python -B tools/verify-m2-struct-layout.py` runs the native harness with the
OS-specific default compiler name, the Python standard library, shell execution
disabled, and the repository as its working directory. No new PowerShell wrapper
is added. The recorded Windows run passed 14 native groups per profile: 8 new
struct groups and 6 unchanged array-layout regression groups, in both development
and release. Linux was not run. The receipt records the baseline commit, compiler
identity, and input hashes.

The M1 compiler, VM, and verifier files are unchanged, so full scalar/array CLI
suites, native M1 suites, and M0 were not rerun. No new CLI artifact or source
`.brc` example is added for unimplemented grammar. Isolation, DLL, clean-machine,
performance, and allocation instrumentation remain skipped.

Next: struct storage with complete initialization, copies, and field access; then
IR, VM, and source integration. This planner does not establish wrapper budget
coupling or complete M2 structs.
