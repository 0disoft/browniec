# M2 Private Scalar Struct Storage

- Status: verified private storage receipt; development and release passed.
- Scope: scalar-only record preparation, initialization, and indexed field access.
- Implementation: [src/struct_storage.fy](../../src/struct_storage.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--storage`.
- Evidence: [Windows receipt](../evidence/m2-struct-storage-windows-20261026.json).

This increment adds no source `.brc` struct syntax, whole-record copy, ownership
token, IR, VM, Fuel schedule, or allocator call. It stores only records whose
fields use the six existing scalar tags. The [layout planner](m2-struct-layout.md)
still accepts nested records and validates the whole catalog; storing a selected
nested record returns `Type`. M2 remains incomplete.

`prepare(Catalog, record)` calls the planner once with the maximum `usize` byte
limit. Every catalog record must pass validation, including disconnected and
nested records. The selected record must have 1..16 fields and every field kind
zero; a missing record returns `Bounds`, a rejected catalog returns `Layout`, and
a nested selected record returns `Type`. The result holds the field count, up to
sixteen tags, record-relative field offsets, record bytes, and alignment.

Every storage operation recomputes the canonical shape from the field count, tags,
and widths. It rejects an empty or oversized count, nonzero inactive tags or offsets,
unknown tags, stale offsets, and a stale byte size or alignment before using
stored metadata for arithmetic. Sixteen fields of at most eight bytes bound the
record to 128 bytes and the alignment to 1, 4, or 8.

`initialize(shape, fields, storage, arena)` requires exactly one value per field.
All six tags use the shared codec, including i64 MIN and the packed `-1` cell for
guest `usize` MAX. Bool accepts only 0 or 1. The shared `array_storage::Arena`
tracks `used` and `limit`; the caller supplies initialized backing bytes where
`used <= limit <= storage.len` holds.

The initializer validates shape and state, checks the exact field count, computes
arena-alignment padding and the record end with overflow guards, and checks the
whole record against the published limit. It then encodes every field into a
zeroed 128-byte scratch. A missing field, extra field, or bad last bool therefore
leaves all backing bytes and the cursor unchanged. Only after complete encoding
does it zero the arena padding, copy the record, and advance `used` last.
Destination writes are at most 135 bytes, 128 record bytes plus seven padding bytes.

`read` and `write` require a record-aligned base and the entire record extent
inside the published `used` prefix, not merely the selected field. A field write
uses the existing atomic eight-byte codec scratch and allocates no extent.
Noncanonical bool bytes fail a read with `Value`; a rejected write preserves every
byte and the cursor.

## Boundary and work

A base offset proves neither object identity nor ownership, lifetime, or borrow
authority, and these helpers never read the owner ledger. No heap or payload
allocator is invoked. The record staging buffer is 128 bytes, and the shared codec
uses eight scratch bytes. These do not measure total native stack use.
Initialization is O(F+B), with F at most 16 and B at most 128
bytes. Indexed reads and writes are O(F+W), with W at most eight bytes, because
every operation revalidates the shape. `prepare` pays the planner's existing
O(R²F) work once; field access never replans the catalog.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --storage` runs 20 native groups per
profile: eight new storage groups, eight unchanged struct-layout groups, and four
unchanged scalar-codec groups. Development and release passed. The default
14-group layout selection remains and was not rerun. The other 37 source files and
the CLI are unchanged, so CLI, full native suites, M0, Linux, isolation, DLL,
clean-machine packaging, performance, and allocation instrumentation were not run.

Next: nested record storage, by-value copies, and owner, IR, and source
integration. No source example is added for unimplemented grammar.
