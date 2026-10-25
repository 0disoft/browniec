module struct_storage;

import struct_layout as layouts;
import array_storage as arenas;
import scalar_codec as codec;

// Prepared scalar-only record metadata. Revalidated at every storage boundary.
// Offsets are record-relative field offsets, never host pointers or ownership proofs.
pub struct Shape { usize count; u8[16] tags; usize[16] offsets; usize bytes; usize alignment; }
pub enum Error { Layout; Type; Fields; Metadata; Overflow; Quota; Bounds; Alignment; Value; State; }

pub fn Result<Shape, Error> prepare(ref layouts::Catalog catalog, usize record) {
    let layouts::Plan plan = switch (layouts::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Layout); }
    };
    if (record >= plan.count) { return .err(.Bounds); }
    var Shape shape = Shape { .count = catalog.fields[record] as usize,
        .tags = [0; 16], .offsets = [0; 16],
        .bytes = plan.bytes[record], .alignment = plan.alignments[record] };
    var usize field = 0;
    while (field < shape.count) {
        let usize slot = record * 16 + field;
        if (catalog.kinds[slot] != 0) { return .err(.Type); }
        shape.tags[field] = catalog.types[slot];
        shape.offsets[field] = plan.offsets[slot];
        field += 1;
    }
    return .ok(shape);
}

fn Result<usize, Error> validate(ref Shape shape) {
    if (shape.count == 0 || shape.count > 16) { return .err(.Fields); }
    var usize size = 0;
    var usize alignment = 1;
    var usize field = 0;
    while (field < 16) {
        if (field < shape.count) {
            let usize width = codec::width(shape.tags[field]);
            if (width == 0) { return .err(.Type); }
            let usize remainder = size % width;
            if (remainder != 0) { size += width - remainder; }
            if (shape.offsets[field] != size) { return .err(.Metadata); }
            size += width;
            if (alignment < width) { alignment = width; }
        } else if (shape.tags[field] != 0 || shape.offsets[field] != 0) { return .err(.Metadata); }
        field += 1;
    }
    let usize remainder = size % alignment;
    if (remainder != 0) { size += alignment - remainder; }
    // Sixteen fields of width <= 8 prove all arithmetic above <= 128.
    if (shape.bytes != size || shape.alignment != alignment) { return .err(.Metadata); }
    return .ok(size);
}
fn bool valid(ref arenas::Arena arena, usize capacity) {
    return arena.used <= arena.limit && arena.limit <= capacity;
}
fn Error codec_error(codec::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Width: { .Metadata } case .Value: { .Value }
    };
}

struct Reservation { usize base; usize end; }
// The caller has already validated the Shape and Arena.
fn Result<Reservation, Error> reserve(usize bytes, usize alignment, ref arenas::Arena arena) {
    let usize remainder = arena.used % alignment;
    let usize padding = if (remainder == 0) { 0 } else { alignment - remainder };
    if (padding > 18446744073709551615 - arena.used) { return .err(.Overflow); }
    let usize base = arena.used + padding;
    if (bytes > 18446744073709551615 - base) { return .err(.Overflow); }
    let usize end = base + bytes;
    if (end > arena.limit) { return .err(.Quota); }
    return .ok(Reservation { .base = base, .end = end });
}
// Fallible validation/encoding is complete. Only these infallible writes publish
// a new extent; alignment padding is initialized before the cursor advances.
fn usize publish(ref u8[] encoded, ref Reservation plan, ref mut u8[] storage, ref mut arenas::Arena arena) {
    var usize at = arena.used;
    while (at < plan.base) { storage[at] = 0; at += 1; }
    var usize byte = 0;
    while (byte < encoded.len) { storage[plan.base + byte] = encoded[byte]; byte += 1; }
    arena.used = plan.end;
    return plan.base;
}

pub fn Result<usize, Error> initialize(ref Shape shape, ref i64[] fields,
    ref mut u8[] storage, ref mut arenas::Arena arena) {
    let usize bytes = validate(shape)?;
    if (!valid(arena, storage.len)) { return .err(.State); }
    if (fields.len != shape.count) { return .err(.Fields); }
    let Reservation plan = reserve(bytes, shape.alignment, arena)?;
    var u8[128] encoded = [0; 128];
    var usize field = 0;
    while (field < shape.count) {
        let usize offset = shape.offsets[field];
        let usize width = codec::width(shape.tags[field]);
        let usize size = switch (codec::encode(shape.tags[field], fields[field], ref mut encoded[offset..offset + width])) {
            case .ok(value): { value } case .err(e): { return .err(codec_error(e)); }
        };
        field += 1;
    }
    return .ok(publish(ref encoded[..bytes], ref plan, storage, arena));
}

fn Result<usize, Error> address(ref Shape shape, usize base, usize field,
    usize capacity, ref arenas::Arena arena) {
    let usize bytes = validate(shape)?;
    if (!valid(arena, capacity)) { return .err(.State); }
    if (field >= shape.count) { return .err(.Bounds); }
    if (base % shape.alignment != 0) { return .err(.Alignment); }
    if (base > arena.used || bytes > arena.used - base) { return .err(.Bounds); }
    return .ok(base + shape.offsets[field]);
}
pub fn Result<i64, Error> read(ref Shape shape, usize base, usize field,
    ref u8[] storage, ref arenas::Arena arena) {
    let usize at = address(shape, base, field, storage.len, arena)?;
    let usize width = codec::width(shape.tags[field]);
    return switch (codec::decode(shape.tags[field], storage[at..at + width])) {
        case .ok(value): { .ok(value) } case .err(e): { .err(codec_error(e)) }
    };
}
pub fn Result<usize, Error> write(ref Shape shape, usize base, usize field, i64 value,
    ref mut u8[] storage, ref arenas::Arena arena) {
    let usize at = address(shape, base, field, storage.len, arena)?;
    let usize width = codec::width(shape.tags[field]);
    return switch (codec::encode(shape.tags[field], value, storage[at..at + width])) {
        case .ok(size): { .ok(size) } case .err(e): { .err(codec_error(e)) }
    };
}

// Shape and the complete source extent have already been checked. The caller
// owns a zeroed record-sized output view; stage only field bytes so padding stays
// zero. All integer bit patterns are valid;
// bool is the only scalar representation requiring a value check before copying.
fn Result<usize, Error> snapshot(ref Shape shape, usize source, ref u8[] storage,
    ref mut u8[] encoded) {
    var usize field = 0;
    while (field < shape.count) {
        let usize offset = shape.offsets[field];
        let usize width = codec::width(shape.tags[field]);
        if (shape.tags[field] == 2 && storage[source + offset] > 1) { return .err(.Value); }
        var usize byte = 0;
        while (byte < width) {
            encoded[offset + byte] = storage[source + offset + byte];
            byte += 1;
        }
        field += 1;
    }
    return .ok(shape.bytes);
}

pub fn Result<usize, Error> copy(ref Shape shape, usize source,
    ref mut u8[] storage, ref mut arenas::Arena arena) {
    let usize checked = address(shape, source, 0, storage.len, arena)?;
    let Reservation plan = reserve(shape.bytes, shape.alignment, arena)?;
    var u8[128] encoded = [0; 128];
    let usize staged = snapshot(shape, source, storage, ref mut encoded[..shape.bytes])?;
    return .ok(publish(ref encoded[..staged], ref plan, storage, arena));
}

// Existing storage is overwritten only after snapshot validation. This also
// handles self-assignment and partial overlap without an additional arena extent.
pub fn Result<usize, Error> assign(ref Shape shape, usize destination, usize source,
    ref mut u8[] storage, ref arenas::Arena arena) {
    let usize target = address(shape, destination, 0, storage.len, arena)?;
    let usize origin = address(shape, source, 0, storage.len, arena)?;
    var u8[128] encoded = [0; 128];
    let usize staged = snapshot(shape, source, storage, ref mut encoded[..shape.bytes])?;
    var usize byte = 0;
    while (byte < staged) { storage[destination + byte] = encoded[byte]; byte += 1; }
    return .ok(staged);
}
