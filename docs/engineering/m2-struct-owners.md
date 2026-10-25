# M2 Shared Struct Owner Foundation

- Status: verified private shared-owner foundation; historical for later owner-copy inputs.
- Scope: private shared owner descriptors for nested records and existing arrays.
- Implementation: [src/array_owners.fy](../../src/array_owners.fy).
- Harness: [tools/verify-m2-struct-layout.py](../../tools/verify-m2-struct-layout.py) with `--owners`.
- Evidence: [Windows receipt](../evidence/m2-struct-owners-windows-20261026.json).

The existing 16-slot owner table now also tracks nested record owners. Record
owners use element 0 as the discriminator and store record bytes in `length`, with
the selected record id and alignment in `record` and `alignment`. Array owners
keep their scalar element and length with zero record/alignment fields. Arrays and
records share the same slots, allocation-order chain, generation lifecycle, and
caller-owned arena; record creation uses one existing slot and the shared arena,
with no new descriptor pool or separate arena. The [owner copy/assignment
successor](m2-struct-owner-copy.md) now adds independent record copies and exact-id
assignment.

## Descriptor and access checks

`create_record(catalog, record, fields, bytes, table)` validates table state,
preflights a free slot, replans the full catalog, rejects a missing or oversized
root, and stages initialization before publishing the descriptor last. The
descriptor caches the generation, mark, base/end, element 0, record bytes, record
id, and alignment. A failure before descriptor publication publishes no token.

`read_record` and `write_record` resolve an occupied, live token with matching
generation, require element 0, replan the current catalog, and require the cached
record id to resolve within that plan and its byte size and alignment to match.
The field path is then
resolved through the existing nested storage helpers against the complete
published root. Array-only read/write/fill/copy/assignment/argument/result
helpers reject record tokens with `Type`.

The trusted caller must bind one immutable record catalog and stable backing
region to the table lifetime. There is no catalog-identity hash or cross-table/
Instance capability check; a different catalog with the same record id, size, and
alignment is outside this private contract. Generation checks establish liveness
only within that table lifetime; public cross-Instance capabilities, nominal
source typing, borrow checking, and source write authority remain unimplemented.

## Lifecycle and boundaries

Release and clear are shared by both owner kinds. Releasing retires the token and
advances its generation; generation `usize::MAX` permanently retires the slot
at zero rather than reusing it. A
dead middle extent retains its bytes and descriptor until every later extent in
the allocation-order suffix is released. Clear invalidates all live tokens,
preserves retired slots, and empties the order table and arena.

This foundation itself does not add struct-owner copies or assignment; the
successor does. It adds no source structs, borrows, struct IR or VM execution, or
Fuel accounting. A selected record remains
bounded to 128 bytes, 128 scalar leaves, and depth 16 by the nested-storage profile.
The receipt's 128-byte scratch and 135-write initialization limits describe records;
arrays retain their separate 32,768-byte per-payload bound. These are algorithmic
bounds, not stack, allocator, or throughput measurements.

## Verification and next work

`python -B tools/verify-m2-struct-layout.py --owners` selects 34 native groups
per profile: six struct owners, five array owners, four array copy, two assignment
storage, seven argument copies, four fill, and six array VM groups. Development
and release each passed all 34 groups on a full selection. The
[tests/m2/struct_owners.fy](../../tests/m2/struct_owners.fy) cases cover mixed
array/record slots and arena, record creation/access, forged extents and catalog
mismatch, typed API rejection, middle-hole reclamation, stale tokens,
generation-zero retirement, clear, full 16-owner pressure, 128 leaves, and depth
16. The [receipt](../evidence/m2-struct-owners-windows-20261026.json) records both profiles.
This receipt and earlier ones are historical for changed `array_owners`, harness,
and root-lock inputs. The [owner-copy receipt](../evidence/m2-struct-owner-copy-windows-20261026.json)
freshly reruns six struct-owner and five array-owner groups per profile. Existing
nested-storage and source CLI files are unchanged.

Full CLI, other native suites including call/result VM, M0, Linux, isolation,
DLL, packaging, performance, and allocation instrumentation were not rerun.

Next: private struct IR and verifier.
