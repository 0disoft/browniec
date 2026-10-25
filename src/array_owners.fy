module array_owners;

import array_layout as layouts;
import array_storage as storage;

// Instance-local metadata over caller-owned backing bytes. No guest/raw pointer.
pub struct Token { usize slot; usize generation; }
pub struct Owner {
    usize generation; bool occupied; bool live; usize mark; usize base; usize end;
    u8 element; usize length;
}
pub struct Table { Owner[16] slots; usize[16] order; usize depth; storage::Arena arena; }
// Dense array-argument results, in input order. Scalar arguments are not included.
pub struct Copies { Token[8] tokens; usize count; }
pub enum Error { Token; Owners; State; Type; Length; Metadata; Overflow; Quota; Bounds; Alignment; Value; }

pub fn Table empty(usize limit) {
    return Table { .slots = [Owner { .generation = 1, .occupied = false, .live = false,
        .mark = 0, .base = 0, .end = 0, .element = 0, .length = 0 }; 16],
        .order = [0; 16], .depth = 0, .arena = storage::empty(limit) };
}
fn Error storage_error(storage::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
        case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
        case .Alignment: { .Alignment } case .Value: { .Value } case .State: { .State }
    };
}

// Validate only metadata, never payload. The allocation-order chain proves that
// retained extents cover exactly the published prefix without gaps or overlap.
fn bool valid(ref Table table, usize capacity) {
    if (table.depth > 16 || table.arena.used > table.arena.limit || table.arena.limit > capacity) { return false; }
    var bool[16] seen = [false; 16];
    var usize cursor = 0;
    var usize i = 0;
    while (i < table.depth) {
        let usize slot = table.order[i];
        if (slot >= 16 || seen[slot]) { return false; }
        seen[slot] = true;
        let Owner owner = table.slots[slot];
        if (!owner.occupied || owner.mark != cursor || (owner.live && owner.generation == 0)) { return false; }
        let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        let layouts::Reservation plan = switch (layouts::reserve(ref layout, cursor, table.arena.limit)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        if (owner.base != plan.offset || owner.end != plan.end) { return false; }
        cursor = owner.end;
        i += 1;
    }
    if (cursor != table.arena.used) { return false; }
    i = 0;
    while (i < 16) {
        if (table.slots[i].occupied != seen[i] || (table.slots[i].live && !seen[i])) { return false; }
        i += 1;
    }
    return true;
}
fn Result<Owner, Error> resolve(ref Table table, Token token, usize capacity) {
    if (token.slot >= 16 || token.generation == 0) { return .err(.Token); }
    let Owner owner = table.slots[token.slot];
    if (!owner.occupied || !owner.live || owner.generation != token.generation) { return .err(.Token); }
    if (!valid(table, capacity)) { return .err(.State); }
    return .ok(owner);
}
fn Result<usize, Error> free_slot(ref Table table) {
    var usize i = 0;
    while (i < 16) {
        if (!table.slots[i].occupied && table.slots[i].generation != 0) { return .ok(i); }
        i += 1;
    }
    return .err(.Owners);
}
fn Token publish(ref mut Table table, usize slot, ref layouts::Array layout, usize mark, usize base) {
    let usize generation = table.slots[slot].generation;
    let usize end = table.arena.used;
    let usize depth = table.depth;
    table.slots[slot] = Owner { .generation = generation, .occupied = true, .live = true,
        .mark = mark, .base = base, .end = end, .element = layout.element, .length = layout.length };
    table.order[depth] = slot;
    table.depth += 1;
    return Token { .slot = slot, .generation = generation };
}

pub fn Result<Token, Error> create(ref layouts::Array layout, i64 fill, ref mut u8[] bytes, ref mut Table table) {
    if (!valid(table, bytes.len)) { return .err(.State); }
    let usize slot = free_slot(table)?;
    let usize mark = table.arena.used;
    let usize base = switch (storage::initialize(layout, fill, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(e): { return .err(storage_error(e)); }
    };
    return .ok(publish(table, slot, layout, mark, base));
}
pub fn Result<i64, Error> read(ref Table table, Token token, usize index, ref u8[] bytes) {
    let Owner owner = resolve(table, token, bytes.len)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::read(ref layout, owner.base, index, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}
pub fn Result<usize, Error> write(ref Table table, Token token, usize index, i64 cell, ref mut u8[] bytes) {
    let Owner owner = resolve(table, token, bytes.len)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::write(ref layout, owner.base, index, cell, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}

// Copy into a fresh, nonoverlapping extent. Validate the entire bool source and
// all destination limits before changing either payload bytes or owner state.
pub fn Result<Token, Error> copy(Token source, ref mut u8[] bytes, ref mut Table table) {
    let Owner owner = resolve(table, source, bytes.len)?;
    let usize slot = free_slot(table)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    let usize mark = table.arena.used;
    let layouts::Reservation plan = switch (layouts::reserve(ref layout, mark, table.arena.limit)) {
        case .ok(value): { value }
        case .err(e): { return .err(switch (e) {
            case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
            case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
            case .Alignment: { .Alignment }
        }); }
    };
    if (owner.element == 2) {
        var usize at = owner.base;
        while (at < owner.end) {
            if (bytes[at] > 1) { return .err(.Value); }
            at += 1;
        }
    }
    var usize at = mark;
    while (at < plan.offset) { bytes[at] = 0; at += 1; }
    var usize i = 0;
    while (i < layout.bytes) {
        let u8 byte = bytes[owner.base + i];
        bytes[plan.offset + i] = byte;
        i += 1;
    }
    table.arena.used = plan.end;
    return .ok(publish(table, slot, ref layout, mark, plan.offset));
}
fn usize next_generation(usize generation) {
    return if (generation == 18446744073709551615) { 0 } else { generation + 1 };
}

// Private call-storage foundation. All fallible work precedes payload mutation;
// only a complete batch publishes owners. Resolve sources against the original
// table, so no argument can refer to another argument's provisional destination.
pub fn Result<Copies, Error> copy_arguments(ref Token[] sources, ref layouts::Array[] shapes,
    ref mut u8[] bytes, ref mut Table table) {
    if (sources.len > 8 || sources.len != shapes.len) { return .err(.Metadata); }
    if (!valid(table, bytes.len)) { return .err(.State); }
    var Table planned = Table { .slots = table.slots, .order = table.order,
        .depth = table.depth, .arena = table.arena };
    var Copies result = Copies { .tokens = [Token { .slot = 0, .generation = 0 }; 8], .count = sources.len };
    var usize[8] origins = [0; 8];
    var usize[8] targets = [0; 8];
    var usize[8] marks = [0; 8];
    var usize[8] sizes = [0; 8];
    var usize i = 0;
    while (i < sources.len) {
        let Owner owner = resolve(table, sources[i], bytes.len)?;
        let layouts::Array shape = shapes[i];
        if (owner.element != shape.element) { return .err(.Type); }
        if (owner.length != shape.length) { return .err(.Length); }
        let usize slot = free_slot(ref planned)?;
        let usize mark = planned.arena.used;
        let layouts::Reservation plan = switch (layouts::reserve(ref shape, mark, planned.arena.limit)) {
            case .ok(value): { value }
            case .err(e): { return .err(switch (e) {
                case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
                case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
                case .Alignment: { .Alignment }
            }); }
        };
        if (owner.element == 2) {
            var usize at = owner.base;
            while (at < owner.end) {
                if (bytes[at] > 1) { return .err(.Value); }
                at += 1;
            }
        }
        origins[i] = owner.base; targets[i] = plan.offset;
        marks[i] = mark; sizes[i] = shape.bytes;
        planned.arena.used = plan.end;
        result.tokens[i] = publish(ref mut planned, slot, ref shape, mark, plan.offset);
        i += 1;
    }
    // Reservations are disjoint and lie beyond every original source extent.
    // No validation, allocation, callback, or recoverable failure follows here.
    i = 0;
    while (i < sources.len) {
        var usize at = marks[i];
        while (at < targets[i]) { bytes[at] = 0; at += 1; }
        var usize byte = 0;
        while (byte < sizes[i]) {
            bytes[targets[i] + byte] = bytes[origins[i] + byte];
            byte += 1;
        }
        i += 1;
    }
    table.slots = planned.slots; table.order = planned.order;
    table.depth = planned.depth; table.arena = planned.arena;
    return .ok(result);
}

// Replace an existing extent. Resolve both tokens and validate the full bool
// source before the first write; valid owners are disjoint unless identical.
pub fn Result<usize, Error> assign(Token destination, Token source, ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve(table, destination, bytes.len)?;
    let Owner origin = resolve(table, source, bytes.len)?;
    if (target.element != origin.element) { return .err(.Type); }
    if (target.length != origin.length) { return .err(.Length); }
    if (origin.element == 2) {
        var usize at = origin.base;
        while (at < origin.end) {
            if (bytes[at] > 1) { return .err(.Value); }
            at += 1;
        }
    }
    let usize size = origin.end - origin.base;
    var usize i = 0;
    while (i < size) { bytes[target.base + i] = bytes[origin.base + i]; i += 1; }
    return .ok(size);
}
fn void forget(ref mut Table table, usize slot) {
    table.slots[slot].occupied = false;
    table.slots[slot].live = false;
    table.slots[slot].mark = 0; table.slots[slot].base = 0; table.slots[slot].end = 0;
    table.slots[slot].element = 0; table.slots[slot].length = 0;
}
pub fn Result<usize, Error> release(ref mut Table table, Token token, usize capacity) {
    let Owner owner = resolve(table, token, capacity)?;
    let usize before = table.arena.used;
    table.slots[token.slot].live = false;
    table.slots[token.slot].generation = next_generation(owner.generation);
    while (table.depth > 0) {
        let usize top = table.order[table.depth - 1];
        if (table.slots[top].live) { break; }
        table.arena.used = table.slots[top].mark;
        forget(table, top);
        let usize last = table.depth - 1;
        table.order[last] = 0;
        table.depth -= 1;
    }
    return .ok(before - table.arena.used);
}
pub fn Result<usize, Error> clear(ref mut Table table, usize capacity) {
    if (!valid(table, capacity)) { return .err(.State); }
    let usize before = table.arena.used;
    var usize i = 0;
    while (i < 16) {
        if (table.slots[i].live) {
            let usize next = next_generation(table.slots[i].generation);
            table.slots[i].generation = next;
        }
        forget(table, i);
        table.order[i] = 0;
        i += 1;
    }
    table.depth = 0; table.arena.used = 0;
    return .ok(before);
}
