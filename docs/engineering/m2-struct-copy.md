# M2 Private Scalar Record Copy and Assignment

- Status: verified private copy/assignment receipt; development and release passed.
- Scope: by-value scalar-record copy and assignment into existing storage.
- Implementation: [src/struct_storage.fy](../../src/struct_storage.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--copy`.
- Evidence: [Windows receipt](../evidence/m2-struct-copy-windows-20261026.json).

This increment adds private record copies, not nested record storage or source
`.brc` struct grammar. `copy` appends an independent record and returns its base;
`assign` overwrites an existing record. Both accept the same validated Shape as
[scalar struct storage](m2-struct-storage.md): 1..16 fields using the six scalar
tags, at most 128 record bytes, and alignment 1, 4, or 8. `Shape.offsets` are
record-relative field offsets; source, destination, and returned bases are arena
byte offsets. These positions prove no owner or type identity, lifetime, borrow,
or mutability authority. No heap allocator API, owner token, IR, VM, Fuel, or DLL
integration is added. The `--storage` and `--copy` selections are mutually
exclusive; the existing default 14-group layout and 20-group storage selections
remain available but were not invoked separately.

## Copy initialization

`copy(shape, source, storage, arena)` validates the Shape, arena state, source
alignment, and the complete source record extent inside the published `used`
prefix. It then reserves the old-plus-new arena peak, including destination
alignment padding, and checks it against the caller limit. A snapshot copies only
field bytes into a caller-owned, zeroed 128-byte scratch buffer. Every bool field
is checked before any backing write; integers accept all bit patterns and retain
their raw bits.

Publication zeroes destination alignment padding, writes at most 128 record
bytes plus at most seven padding bytes, and advances `arena.used` last. A late
invalid bool therefore leaves every backing byte and the cursor unchanged. The
returned base is the appended record. Neither operation copies source padding.

## Assignment

`assign(shape, destination, source, storage, arena)` validates metadata, arena
state, and complete source and destination extents before snapshotting every
field. It then writes the snapshot into existing storage. Self-assignment and
partial overlap in either direction use prewrite values. No additional arena
extent is reserved and `arena.used` does not change. Destination padding is
normalized to zero, and the returned value is the record byte size.

## Boundary and work

Copy writes at most 135 backing bytes; assignment writes at most 128. The
128-byte scratch capacity and record ceiling are algorithmic bounds, not
measurements of native stack use, allocation, or throughput. Both operations are
O(F+B), with F at most 16 and B at most 128. Assignment performs the metadata
and address checks twice and the bool scan once, which remains O(F+B). Existing
initializer reserve and publish logic now lives in shared private helpers.

Scratch lifetime stays local to `copy` or `assign`; the snapshot helper fills a
borrowed output view instead of returning an array-bearing tagged payload. The
earlier return-based staging passed development but failed release assertions,
so both native profiles remain part of the regression selection.

Copies do not copy source padding or establish guest aliasing authority. The
overlap behavior is a primitive property of the snapshot; source-language
aliasing, borrows, and mutability rules remain unimplemented.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --copy` selects 28 native groups per
profile: eight copy, eight fresh storage, eight struct-layout, and four
scalar-codec groups. Development and release each passed 28/28 on a fresh full
selection after the staging fix. The original 23/28 release result is superseded
by this final receipt; no earlier native results were reused.
The new [tests/m2/struct_copy.fy](../../tests/m2/struct_copy.fy) cases cover all six
scalar bit patterns, padding normalization, source independence, old-plus-new
quota with alignment, late-bool atomicity, a full 256-byte arena with 128-byte
assignment, self-assignment at capacity, both partial overlap directions, forged
metadata, state rejection, and alignment/full-extent bounds. The other 37 source
files and the CLI are unchanged. Full CLI and native suites, M0, Linux, isolation,
DLL, clean-machine packaging, performance, and allocation instrumentation were
not run. Earlier receipts are historical for changed struct-storage and harness
inputs; the 28-group selection includes eight fresh storage groups.

Next: nested record storage, then ownership, IR, VM, and source integration. No
source example is added for unimplemented grammar.
