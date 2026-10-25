# M2 Private Nested Struct Copy and Assignment

- Status: verified private copy/assignment receipt; development and release passed.
- Scope: by-value copy and assignment of nested acyclic records.
- Implementation: [src/struct_nested_storage.fy](../../src/struct_nested_storage.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--nested-copy`.
- Evidence: [Windows receipt](../evidence/m2-struct-nested-copy-windows-20261026.json).

`copy(catalog, record, source, storage, arena)` appends an independent byte copy
of the selected nested record and returns its base. `assign(catalog, record,
destination, source, storage, arena)` overwrites an existing record and returns
its byte size. Both replan the complete catalog once per public operation, then
validate arena state, selected-root alignment, and complete source or destination
extents inside the published `used` prefix. Selected roots are limited to 128
bytes, 128 scalar leaves, and depth 16. Valid unselected records may be larger.

## Copy

Copy validates the full source extent, reserves the old-plus-new peak including
destination alignment padding, and checks it against the caller limit. A private
iterative snapshot reuses the existing 16-frame cursor, reads only scalar leaf
bytes from the source, and checks every bool before any backing write. Integers
keep their raw bits. The caller-local zeroed 128-byte scratch normalizes nested,
interfield, and tail padding. Publication zeroes arena alignment padding, writes
the staged root, and advances `arena.used` last. A late invalid bool leaves every
byte and the cursor unchanged.

## Assignment

Assignment validates both complete extents and metadata before snapshotting. It
then writes the staged bytes into existing storage. Self-assignment and partial
overlap in either direction use prewrite values. No additional extent is
reserved and `arena.used` does not change; destination padding is normalized to
zero.

## Boundary and work

Reservation, publication, and extent checks are shared with initialization and
field access. Copy writes at most 128 record bytes plus at most seven alignment
padding bytes. Assignment writes at most 128 bytes. The 128-byte scratch,
selected-root byte, leaf, and depth limits are algorithmic bounds, not
measurements of native stack, allocation, or throughput. A matching record
descriptor and offset do not establish nominal type, ownership, lifetime, borrow,
or write authority. Overlap safety is primitive behavior, not guest aliasing
authorization.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --nested-copy` selects
24 native groups per profile: six new nested-copy, six nested-storage, eight
struct-layout, and four scalar-codec groups. Development and release each passed
all 24 groups on a fresh full selection. The [tests/m2/struct_nested_copy.fy](../../tests/m2/struct_nested_copy.fy)
cases cover all scalar bits and nested padding, source independence, old-plus-new
quota with alignment, corrupt late bools, 128 leaves, depth 16, full-capacity
copy and assignment, self and both partial overlap directions, forged metadata,
state, alignment, and complete source/destination bounds. Full CLI, scalar
storage/copy native suites, M0, Linux, isolation, DLL, packaging, performance, and
allocator instrumentation were not rerun. The earlier 18-group nested-storage
receipt is historical for changed inputs.

Next: private struct ownership and lifetime, then IR, VM, Fuel, and source
structs. Existing source syntax is unaffected, and no source example is added for
unimplemented grammar.
