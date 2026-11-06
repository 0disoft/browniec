module struct_nested_storage;

import struct_layout as layouts;
import array_storage as arenas;
import scalar_codec as codec;
import aggregate_copy as copying;

// Private nested storage. Replan caller metadata at every public boundary.
pub enum Error { Layout; Bounds; Fields; State; Alignment; Quota; Overflow; Value; Type; }
struct Cursor { usize depth; usize[16] records; usize[16] fields; usize[16] bases; }
// A checked scalar location is metadata, never a pointer or ownership proof.
pub struct Leaf { u8 tag; usize offset; }

fn bool valid(ref arenas::Arena arena, usize capacity) {
    return arena.used <= arena.limit && arena.limit <= capacity;
}
fn Error codec_error(codec::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Width: { .Bounds } case .Value: { .Value }
    };
}
fn Result<usize, Error> selected(ref layouts::Plan plan, usize record) {
    if (record >= plan.count) { return .err(.Bounds); }
    if (plan.bytes[record] > 128) { return .err(.Quota); }
    return .ok(plan.bytes[record]);
}
// Only validated acyclic catalogs enter this iterator. The plan proves depth
// <= 16, every offset inside the selected record, and <= 128 scalar leaves.
// A zero tag marks exhaustion; valid scalar tags are always nonzero.
fn Leaf next(ref layouts::Catalog catalog, ref layouts::Plan plan, ref mut Cursor cursor) {
    while (cursor.depth > 0) {
        let usize level = cursor.depth - 1;
        let usize record = cursor.records[level];
        let usize field = cursor.fields[level];
        if (field >= catalog.fields[record] as usize) { cursor.depth -= 1; }
        else {
            cursor.fields[level] += 1;
            let usize slot = record * 16 + field;
            let usize offset = cursor.bases[level] + plan.offsets[slot];
            if (catalog.kinds[slot] == 0) {
                return Leaf { .tag = catalog.types[slot], .offset = offset };
            }
            let usize child = cursor.depth;
            cursor.records[child] = catalog.types[slot] as usize;
            cursor.fields[child] = 0;
            cursor.bases[child] = offset;
            cursor.depth += 1;
        }
    }
    return Leaf { .tag = 0, .offset = 0 };
}

struct Reservation { usize base; usize end; }
// The selected size, alignment and arena state are validated by the caller.
fn Result<Reservation, Error> reserve(usize size, usize alignment, ref arenas::Arena arena) {
    let usize remainder = arena.used % alignment;
    let usize padding = if (remainder == 0) { 0 } else { alignment - remainder };
    if (padding > 18446744073709551615 - arena.used) { return .err(.Overflow); }
    let usize base = arena.used + padding;
    if (size > 18446744073709551615 - base) { return .err(.Overflow); }
    let usize end = base + size;
    if (end > arena.limit) { return .err(.Quota); }
    return .ok(Reservation { .base = base, .end = end });
}
fn usize publish(ref u8[] encoded, ref Reservation reservation,
    ref mut u8[] storage, ref mut arenas::Arena arena) {
    var usize at = arena.used;
    while (at < reservation.base) { storage[at] = 0; at += 1; }
    at = 0;
    while (at < encoded.len) { storage[reservation.base + at] = encoded[at]; at += 1; }
    arena.used = reservation.end;
    return reservation.base;
}
fn Result<usize, Error> extent(ref layouts::Plan plan, usize record, usize base,
    usize capacity, ref arenas::Arena arena) {
    let usize size = selected(plan, record)?;
    if (!valid(arena, capacity)) { return .err(.State); }
    if (base % plan.alignments[record] != 0) { return .err(.Alignment); }
    if (base > arena.used || size > arena.used - base) { return .err(.Bounds); }
    return .ok(size);
}

// Callers supply zeroed, selected-size scratch after validating the full plan.
// Fields are depth-first scalar leaves; every value is encoded before publishing.
fn Result<usize, Error> encode_fields(ref layouts::Catalog catalog, ref layouts::Plan plan,
    usize record, ref i64[] fields, ref mut u8[] encoded) {
    if (fields.len == 0 || fields.len > 128) { return .err(.Fields); }
    var Cursor cursor = Cursor { .depth = 1, .records = [0; 16], .fields = [0; 16], .bases = [0; 16] };
    cursor.records[0] = record;
    var usize count = 0;
    var bool done = false;
    while (!done) {
        let Leaf leaf = next(catalog, plan, ref mut cursor);
        if (leaf.tag == 0) { done = true; }
        else {
            if (count >= fields.len) { return .err(.Fields); }
            let usize width = codec::width(leaf.tag);
            let usize written = switch (codec::encode(leaf.tag, fields[count], encoded[leaf.offset..leaf.offset + width])) {
                case .ok(value): { value } case .err(error): { return .err(codec_error(error)); }
            };
            count += 1;
        }
    }
    if (count != fields.len) { return .err(.Fields); }
    return .ok(plan.bytes[record]);
}

// The complete record, including padding, is staged before backing mutation.
pub fn Result<usize, Error> initialize(ref layouts::Catalog catalog, usize record,
    ref i64[] fields, ref mut u8[] storage, ref mut arenas::Arena arena) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = selected(ref plan, record)?;
    if (!valid(arena, storage.len)) { return .err(.State); }
    if (fields.len == 0 || fields.len > 128) { return .err(.Fields); }
    let Reservation reservation = reserve(size, plan.alignments[record], arena)?;
    var u8[128] encoded = [0; 128];
    let usize staged = encode_fields(catalog,ref plan,record,fields,ref mut encoded[..size])?;
    return .ok(publish(ref encoded[..size], ref reservation, storage, arena));
}

// Replace an existing extent from scalar values. No reservation, allocation,
// cursor change or target write occurs until all fields encode successfully.
pub fn Result<usize, Error> replace_values(ref layouts::Catalog catalog, usize record,
    usize destination, ref i64[] fields, ref mut u8[] storage, ref arenas::Arena arena) {
    let layouts::Plan plan = switch (layouts::plan(catalog,18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan,record,destination,storage.len,arena)?;
    var u8[128] encoded = [0; 128];
    let usize staged = encode_fields(catalog,ref plan,record,fields,ref mut encoded[..size])?;
    var usize byte = 0;
    while (byte < staged) { storage[destination+byte] = encoded[byte]; byte += 1; }
    return .ok(staged);
}

// Check the whole published root, then resolve a scalar-only field path.
// Neither a base nor a path establishes ownership, lifetime or write authority.
fn Result<Leaf, Error> address(ref layouts::Catalog catalog, usize record, usize base,
    ref usize[] path, usize capacity, ref arenas::Arena arena) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan, record, base, capacity, arena)?;
    if (path.len == 0 || path.len > 16) { return .err(.Bounds); }
    var usize current = record;
    var usize offset = base;
    var usize depth = 0;
    while (depth < path.len) {
        let usize field = path[depth];
        if (field >= catalog.fields[current] as usize) { return .err(.Bounds); }
        let usize slot = current * 16 + field;
        offset += plan.offsets[slot];
        if (catalog.kinds[slot] == 0) {
            if (depth + 1 != path.len) { return .err(.Type); }
            return .ok(Leaf { .tag = catalog.types[slot], .offset = offset });
        }
        current = catalog.types[slot] as usize;
        depth += 1;
    }
    return .err(.Type);
}
pub fn Result<i64, Error> read(ref layouts::Catalog catalog, usize record, usize base,
    ref usize[] path, ref u8[] storage, ref arenas::Arena arena) {
    let Leaf leaf = address(catalog, record, base, path, storage.len, arena)?;
    let usize width = codec::width(leaf.tag);
    return switch (codec::decode(leaf.tag, storage[leaf.offset..leaf.offset + width])) {
        case .ok(value): { .ok(value) } case .err(error): { .err(codec_error(error)) }
    };
}
pub fn Result<usize, Error> write(ref layouts::Catalog catalog, usize record, usize base,
    ref usize[] path, i64 value, ref mut u8[] storage, ref arenas::Arena arena) {
    let Leaf leaf = address(catalog, record, base, path, storage.len, arena)?;
    let usize width = codec::width(leaf.tag);
    return switch (codec::encode(leaf.tag, value, storage[leaf.offset..leaf.offset + width])) {
        case .ok(written): { .ok(written) } case .err(error): { .err(codec_error(error)) }
    };
}

// Depth-first scalar ordinals match record IR. Resolve without reading payload
// or retaining a mutable caller path. The canonical <=128-byte root and <=16
// levels bound the iterator; ordinals outside 0..127 fail before walking.
pub fn Result<Leaf, Error> scalar_location(ref layouts::Catalog catalog, usize record,
    usize base, usize ordinal, usize capacity, ref arenas::Arena arena) {
    if (ordinal >= 128) { return .err(.Bounds); }
    let layouts::Plan plan = switch (layouts::plan(catalog,18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan,record,base,capacity,arena)?;
    var Cursor cursor = Cursor { .depth = 1, .records = [0;16], .fields = [0;16], .bases = [0;16] };
    cursor.records[0] = record; var usize index = 0;
    while (index <= ordinal) {
        let Leaf leaf = next(catalog,ref plan,ref mut cursor);
        if (leaf.tag == 0) { return .err(.Bounds); }
        if (index == ordinal) { return .ok(Leaf { .tag = leaf.tag, .offset = base+leaf.offset }); }
        index += 1;
    }
    return .err(.Bounds);
}

// The validated root extent and plan bound all iterator offsets. The caller
// owns zeroed scratch: only scalar bytes are read, never source padding.
fn Result<usize, Error> snapshot(ref layouts::Catalog catalog, ref layouts::Plan plan,
    usize record, usize source, ref u8[] storage, ref mut u8[] encoded) {
    var Cursor cursor = Cursor { .depth = 1, .records = [0; 16], .fields = [0; 16], .bases = [0; 16] };
    cursor.records[0] = record;
    var bool done = false;
    while (!done) {
        let Leaf leaf = next(catalog, plan, ref mut cursor);
        if (leaf.tag == 0) { done = true; }
        else {
            if (leaf.tag == 2 && storage[source + leaf.offset] > 1) { return .err(.Value); }
            let usize width = codec::width(leaf.tag);
            var usize byte = 0;
            while (byte < width) {
                encoded[leaf.offset + byte] = storage[source + leaf.offset + byte];
                byte += 1;
            }
        }
    }
    return .ok(plan.bytes[record]);
}
// Copy canonical bytes into caller-owned scratch without changing backing or
// arena state. Scratch may be partially changed on error; it is never published.
// The caller must supply a disjoint, exact-size scratch region.
pub fn Result<usize, Error> snapshot_into(ref layouts::Catalog catalog, usize record, usize source,
    ref u8[] storage, ref arenas::Arena arena, ref mut u8[] encoded) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(p): { p } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan, record, source, storage.len, arena)?;
    if (encoded.len != size) { return .err(.Bounds); }
    var usize i = 0;
    while (i < size) { encoded[i] = 0; i += 1; }
    return snapshot(catalog, ref plan, record, source, storage, encoded);
}
pub fn Result<usize, Error> copy(ref layouts::Catalog catalog, usize record, usize source,
    ref mut u8[] storage, ref mut arenas::Arena arena) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan, record, source, storage.len, arena)?;
    let Reservation reservation = reserve(size, plan.alignments[record], arena)?;
    let copying::Mode transfer=switch(copying::prove(reservation.base,source,size,reservation.end,true,128,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    var u8[128] encoded = [0; 128];
    let usize staged = snapshot(catalog, ref plan, record, source, storage, ref mut encoded[..size])?;
    return .ok(publish(ref encoded[..staged], ref reservation, storage, arena));
}
pub fn Result<usize, Error> assign(ref layouts::Catalog catalog, usize record,
    usize destination, usize source, ref mut u8[] storage, ref arenas::Arena arena) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    let usize size = extent(ref plan, record, destination, storage.len, arena)?;
    let usize origin = extent(ref plan, record, source, storage.len, arena)?;
    let copying::Mode transfer=switch(copying::prove(destination,source,size,arena.used,true,128,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    var u8[128] encoded = [0; 128];
    let usize staged = snapshot(catalog, ref plan, record, source, storage, ref mut encoded[..size])?;
    var usize byte = 0;
    while (byte < staged) { storage[destination + byte] = encoded[byte]; byte += 1; }
    return .ok(staged);
}
