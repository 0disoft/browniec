module array_places;

import array_owners as owners;
import array_layout as layouts;
import array_storage as storage;

// Native metadata only, bound to one owner table and its backing lifetime.
// This is neither a guest value nor an affine IR place/loan obligation yet.
pub struct Place {
    owners::Token root; u8 element; usize length;
    usize mark; usize base; usize end; usize index; usize offset;
}

// Authenticate the owner and bounds without reading the old scalar. In
// particular, ordinary assignment may replace a noncanonical bool payload.
pub fn Result<Place, owners::Error> select(ref owners::Table table,
    owners::Token root, usize index, usize capacity) {
    let owners::View view = owners::view(table, root, index, index, capacity)?;
    let owners::Owner owner = table.slots[root.slot];
    if (owner.reading) { return .err(.State); }
    if (index >= view.length) { return .err(.Bounds); }
    let layouts::Array layout = switch (layouts::scalar(view.element, view.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    let usize offset = switch (layouts::offset(ref layout, owner.base, index, table.arena.used)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return .ok(Place { .root = root, .element = view.element, .length = view.length,
        .mark = owner.mark, .base = owner.base, .end = owner.end, .index = index, .offset = offset });
}

// Re-resolve the captured token, never the caller's current descriptor. RHS
// allocation and completed loans may change other metadata; the target's exact
// reservation and shape must remain unchanged and writable at the final store.
fn Result<layouts::Array, owners::Error> validate(ref owners::Table table,
    ref Place place, usize capacity) {
    let Place current = select(table, place.root, place.index, capacity)?;
    if (current.element != place.element) { return .err(.Type); }
    if (current.length != place.length) { return .err(.Length); }
    if (current.mark != place.mark || current.base != place.base ||
        current.end != place.end || current.offset != place.offset) { return .err(.State); }
    return switch (layouts::scalar(place.element, place.length)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
    };
}
fn owners::Error storage_error(storage::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
        case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
        case .Alignment: { .Alignment } case .Value: { .Value } case .State: { .State }
    };
}

// Compound lowering must call read before evaluating the RHS and retain that
// scalar separately; a later read deliberately observes the current payload.
pub fn Result<i64, owners::Error> read(ref owners::Table table,
    ref Place place, ref u8[] bytes) {
    let layouts::Array layout = validate(table, place, bytes.len)?;
    return switch (storage::read(ref layout, place.base, place.index, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(storage_error(error)) }
    };
}
// The codec validates and stages at most eight bytes before publishing. Failed
// revalidation/encoding changes neither backing bytes nor any owner metadata.
pub fn Result<usize, owners::Error> store(ref owners::Table table,
    ref Place place, i64 cell, ref mut u8[] bytes) {
    let layouts::Array layout = validate(table, place, bytes.len)?;
    return switch (storage::write(ref layout, place.base, place.index, cell, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(storage_error(error)) }
    };
}
