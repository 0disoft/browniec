# M2 Private Nested Struct Storage

- Status: verified private storage receipt; historical for later nested-copy inputs.
- Scope: nested acyclic record initialization and scalar field-path access.
- Implementation: [src/struct_nested_storage.fy](../../src/struct_nested_storage.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--nested`.
- Evidence: [Windows receipt](../evidence/m2-struct-nested-storage-windows-20261026.json).
- Scalar-value replacement: [private successor](m2-struct-replace-values.md).

This private module materializes a selected acyclic record from depth-first
scalar leaf inputs and reads or writes a scalar field selected by an index path.
It uses the existing [layout planner](m2-struct-layout.md) and the shared
`array_storage::Arena`. The backing storage bytes and arena are caller-provided;
initialization owns the zeroed 128-byte scratch. The scalar [storage](m2-struct-storage.md) and
[copy](m2-struct-copy.md) APIs are unchanged and remain scalar-only. Nested
copy/assignment now has a [private successor](m2-struct-nested-copy.md); ownership,
IR, VM, Fuel, and source `.brc` struct grammar remain future work.

## Initialization

`initialize(catalog, record, fields, storage, arena)` replans the complete
catalog at the public boundary. The selected record must be at most 128 bytes and
receive 1..128 scalar inputs; the planner supplies acyclic depth at most 16. A
missing record returns `Bounds`, a rejected catalog returns `Layout`, and a
selected root over 128 bytes returns `Quota`. Validation also requires
`used <= limit <= storage.len`, an exact leaf count, and the complete aligned
root extent inside the limit. Every fallible check precedes backing and cursor
mutation.

The traversal is iterative, with a 16-frame cursor. It visits scalar leaves in
declaration order, descending through nested records without native recursion.
Each leaf is encoded into that initialization-owned scratch. After
all leaves encode successfully, initialization zeroes arena alignment padding,
copies the complete root including nested and tail padding, and advances
`arena.used` last. It returns the appended base.

## Field paths and bounds

`read(catalog, record, base, path, storage, arena)` and `write(...)` replan the
full catalog, then require a selected root of at most 128 bytes. They recheck
arena state, root alignment, and the complete published root extent, not only
the addressed leaf. A path contains 1..16 field indexes, one per nesting level,
and must end at a scalar; an empty or overlong path, a missing field, or a path
ending at a nested record is rejected. `write` encodes into existing storage and
reserves no extent.

The full catalog is validated even when the selected root is small. Valid
unselected records may exceed 128 bytes; the cap applies to the selected root.
Path resolution is bounded by 16 steps, while every public boundary also pays
the planner's existing catalog cost. Initialization is bounded by 128 scalar
leaves and 128 root bytes. The scratch capacity, depth, path, and leaf limits
are algorithmic bounds, not native stack, allocator, or throughput measurements.
Base offsets and field paths prove no ownership, lifetime, or write authority.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --nested` selects 18
native groups per profile: six nested-storage, eight struct-layout, and four
scalar-codec groups. Development and release each passed all 18 groups. The
[tests/m2/struct_nested_storage.fy](../../tests/m2/struct_nested_storage.fy)
cases cover repeated nesting, all scalar bits and padding, exact leaf/input
counts, old-plus-new quota, 128 leaves, depth 16 and 17, scalar-only paths,
forged catalog metadata, arena state, alignment, and full-root bounds. Other CLI
and native suites, M0, Linux, isolation, DLL, clean-machine packaging, allocation
instrumentation, and performance checks were not run. The existing 38 source
files are unchanged; the scalar-storage and scalar-copy native suites were not
rerun. This receipt is historical for the changed shared module and harness inputs.
The [nested-copy receipt](../evidence/m2-struct-nested-copy-windows-20261026.json)
freshly reruns all six nested-storage groups in both native profiles.

Next: private struct ownership and lifetime, then IR, VM, Fuel, and source
integration. No source example is added for unimplemented grammar.
