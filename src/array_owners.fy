module array_owners;

import array_layout as layouts;
import array_storage as storage;
import scalar_codec as codec;
import struct_layout as records;
import struct_nested_storage as record_storage;
import struct_range as record_range;

// Instance-local metadata over caller-owned backing bytes. No guest/raw pointer.
pub struct Token { usize slot; usize generation; }
pub struct Owner {
    usize generation; bool occupied; bool live; usize mark; usize base; usize end;
    // element 0 denotes a record: length is bytes, record/alignment identify its layout.
    // Arrays retain their scalar element/length and zero record/alignment fields.
    u8 element; usize length; usize record; usize alignment;
}
pub struct Table { Owner[16] slots; usize[16] order; usize depth; storage::Arena arena; }
// Dense array-argument results, in input order. Scalar arguments are not included.
pub struct Copies { Token[8] tokens; usize count; }
// Dense aggregate arguments in source order. element 0 selects a nominal record
// (length must be zero); arrays use their scalar tag/length and record zero.
pub struct CallArgument { Token source; u8 element; usize length; usize record; }
pub enum Error { Token; Owners; State; Type; Length; Metadata; Overflow; Quota; Bounds; Alignment; Value; }

pub fn Table empty(usize limit) {
    return Table { .slots = [Owner { .generation = 1, .occupied = false, .live = false,
        .mark = 0, .base = 0, .end = 0, .element = 0, .length = 0, .record = 0, .alignment = 0 }; 16],
        .order = [0; 16], .depth = 0, .arena = storage::empty(limit) };
}
fn Error storage_error(storage::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
        case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
        case .Alignment: { .Alignment } case .Value: { .Value } case .State: { .State }
    };
}

// Derive a reservation layout, never an array view of a record token.
fn Result<layouts::Array, Error> allocation_layout(ref Owner owner) {
    if (owner.element != 0) {
        if (owner.record != 0 || owner.alignment != 0) { return .err(.State); }
        return switch (layouts::scalar(owner.element, owner.length)) {
            case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
        };
    }
    if (owner.record >= 32 || owner.length == 0 || owner.length > 128) { return .err(.State); }
    if (owner.alignment != 1 && owner.alignment != 4 && owner.alignment != 8) { return .err(.State); }
    if (owner.length % owner.alignment != 0) { return .err(.State); }
    let u8 tag = if (owner.alignment == 1) { 10 } else if (owner.alignment == 4) { 11 } else { 12 };
    return switch (layouts::scalar(tag, owner.length / owner.alignment)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
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
        let layouts::Array layout = switch (allocation_layout(ref owner)) {
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
fn Result<Owner, Error> resolve_any(ref Table table, Token token, usize capacity) {
    if (token.slot >= 16 || token.generation == 0) { return .err(.Token); }
    let Owner owner = table.slots[token.slot];
    if (!owner.occupied || !owner.live || owner.generation != token.generation) { return .err(.Token); }
    if (!valid(table, capacity)) { return .err(.State); }
    return .ok(owner);
}
// Array entry points must reject record tokens even when their raw size matches.
fn Result<Owner, Error> resolve(ref Table table, Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    if (owner.element == 0) { return .err(.Type); }
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
        .mark = mark, .base = base, .end = end, .element = layout.element, .length = layout.length, .record = 0, .alignment = 0 };
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
// Rehoming a unique owner needs no allocation or payload write. Validate its
// exact shape and all bool bytes before a caller publishes the existing token.
pub fn Result<usize,Error> validate_result(ref Table table,Token token,u8 element,usize length,ref u8[] bytes) {
    let Owner owner=resolve(table,token,bytes.len)?;
    if(owner.element!=element) {return .err(.Type);}
    if(owner.length!=length) {return .err(.Length);}
    if(element==2) {
        var usize at=owner.base;
        while(at<owner.end) {if(bytes[at]>1) {return .err(.Value);}at+=1;}
    }
    return .ok(owner.end-owner.base);
}
// Validate the entire extent and encode once before the first write. Owner and
// arena metadata remain immutable, including when every descriptor is occupied.
pub fn Result<usize,Error> fill(ref Table table,Token token,i64 cell,ref mut u8[] bytes) {
    let Owner owner=resolve(table,token,bytes.len)?;
    let layouts::Array layout=switch(layouts::scalar(owner.element,owner.length)) {
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    var u8[8] encoded=[0;8];
    let usize size=switch(codec::encode(owner.element,cell,ref mut encoded[..layout.stride])) {
        case .ok(n):{n}case .err(e):{return .err(switch(e){case .Type:{.Type}case .Width:{.Metadata}case .Value:{.Value}});}
    };
    var usize at=owner.base;
    while(at<owner.end) {
        var usize byte=0;
        while(byte<size){bytes[at+byte]=encoded[byte];byte+=1;}
        at+=size;
    }
    return .ok(layout.bytes);
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

// Preflight one mixed array/record transaction against the original table.
// Record snapshots normalize padding and validate every nested bool before any
// backing write. Only the complete batch publishes tokens and arena metadata.
pub fn Result<Copies, Error> copy_call_arguments(ref records::Catalog catalog,
    ref CallArgument[] arguments, ref mut u8[] bytes, ref mut Table table) {
    if (arguments.len > 8) { return .err(.Metadata); }
    if (!valid(table, bytes.len)) { return .err(.State); }
    var Table planned = Table { .slots = table.slots, .order = table.order,
        .depth = table.depth, .arena = table.arena };
    var Copies result = Copies { .tokens = [Token { .slot = 0, .generation = 0 }; 8], .count = arguments.len };
    var u8[1024] snapshots = [0; 1024];
    var usize[8] origins = [0; 8]; var usize[8] targets = [0; 8];
    var usize[8] marks = [0; 8]; var usize[8] sizes = [0; 8];
    var usize i = 0;
    while (i < arguments.len) {
        let CallArgument argument = arguments[i];
        let Owner owner = resolve_any(table, argument.source, bytes.len)?;
        if (owner.element != argument.element) { return .err(.Type); }
        if (argument.element == 0) {
            if (argument.length != 0) { return .err(.Metadata); }
            if (owner.record != argument.record) { return .err(.Type); }
            let Owner checked = resolve_record(catalog, table, argument.source, bytes.len)?;
            let usize staged = switch (record_storage::snapshot_into(catalog, owner.record, owner.base,
                bytes, ref table.arena, ref mut snapshots[i * 128..i * 128 + owner.length])) {
                case .ok(n): { n } case .err(e): { return .err(record_error(e)); }
            };
        } else {
            if (argument.record != 0) { return .err(.Metadata); }
            if (owner.length != argument.length) { return .err(.Length); }
            if (owner.element == 2) {
                var usize at = owner.base;
                while (at < owner.end) { if (bytes[at] > 1) { return .err(.Value); } at += 1; }
            }
        }
        let layouts::Array layout = allocation_layout(ref owner)?;
        let usize slot = free_slot(ref planned)?;
        let usize mark = planned.arena.used;
        let layouts::Reservation reservation = switch (layouts::reserve(ref layout, mark, planned.arena.limit)) {
            case .ok(p): { p } case .err(e): { return .err(switch (e) {
                case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
                case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
                case .Alignment: { .Alignment }
            }); }
        };
        origins[i] = owner.base; targets[i] = reservation.offset;
        marks[i] = mark; sizes[i] = layout.bytes;
        planned.arena.used = reservation.end;
        if (argument.element == 0) {
            result.tokens[i] = publish_record(ref mut planned, slot, owner.record,
                owner.length, owner.alignment, mark, reservation.offset);
        } else { result.tokens[i] = publish(ref mut planned, slot, ref layout, mark, reservation.offset); }
        i += 1;
    }
    // Every destination follows the original published prefix. Sources cannot
    // alias a destination, including repeated arguments and provisional slots.
    i = 0;
    while (i < arguments.len) {
        var usize at = marks[i];
        while (at < targets[i]) { bytes[at] = 0; at += 1; }
        var usize byte = 0;
        while (byte < sizes[i]) {
            bytes[targets[i] + byte] = if (arguments[i].element == 0) {
                snapshots[i * 128 + byte]
            } else { bytes[origins[i] + byte] };
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
    table.slots[slot].record = 0; table.slots[slot].alignment = 0;
}
pub fn Result<usize, Error> release(ref mut Table table, Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
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

// Record owners share the same slots, arena, generations and release order as
// arrays. Bind one immutable catalog and backing region to the table lifetime.
fn Error record_error(record_storage::Error error) {
    return switch (error) {
        case .Layout: { .Metadata } case .Bounds: { .Bounds } case .Fields: { .Length }
        case .State: { .State } case .Alignment: { .Alignment } case .Quota: { .Quota }
        case .Overflow: { .Overflow } case .Value: { .Value } case .Type: { .Type }
    };
}
pub fn Result<Token, Error> create_record(ref records::Catalog catalog, usize record,
    ref i64[] fields, ref mut u8[] bytes, ref mut Table table) {
    if (!valid(table, bytes.len)) { return .err(.State); }
    let usize slot = free_slot(table)?;
    let records::Plan plan = switch (records::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Metadata); }
    };
    if (record >= plan.count) { return .err(.Bounds); }
    if (plan.bytes[record] > 128) { return .err(.Quota); }
    let usize mark = table.arena.used;
    let usize base = switch (record_storage::initialize(catalog, record, fields, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(record_error(error)); }
    };
    return .ok(publish_record(table, slot, record, plan.bytes[record], plan.alignments[record], mark, base));
}
// Record initialization/copy have completed every fallible operation.
fn Token publish_record(ref mut Table table, usize slot, usize record, usize bytes,
    usize alignment, usize mark, usize base) {
    let usize generation = table.slots[slot].generation;
    let usize end = table.arena.used;
    let usize depth = table.depth;
    table.slots[slot] = Owner { .generation = generation, .occupied = true, .live = true,
        .mark = mark, .base = base, .end = end, .element = 0,
        .length = bytes, .record = record, .alignment = alignment };
    table.order[depth] = slot;
    table.depth += 1;
    return Token { .slot = slot, .generation = generation };
}

fn Result<Owner, Error> resolve_record(ref records::Catalog catalog, ref Table table,
    Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    if (owner.element != 0) { return .err(.Type); }
    let records::Plan plan = switch (records::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Metadata); }
    };
    if (owner.record >= plan.count) { return .err(.Metadata); }
    if (plan.bytes[owner.record] != owner.length || plan.alignments[owner.record] != owner.alignment) {
        return .err(.Metadata);
    }
    return .ok(owner);
}
pub fn Result<i64, Error> read_record(ref records::Catalog catalog, ref Table table,
    Token token, ref usize[] path, ref u8[] bytes) {
    let Owner owner = resolve_record(catalog, table, token, bytes.len)?;
    return switch (record_storage::read(catalog, owner.record, owner.base, path, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}
pub fn Result<usize, Error> write_record(ref records::Catalog catalog, ref Table table,
    Token token, ref usize[] path, i64 value, ref mut u8[] bytes) {
    let Owner owner = resolve_record(catalog, table, token, bytes.len)?;
    return switch (record_storage::write(catalog, owner.record, owner.base, path, value, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}

// Copy the exact descriptor-bound record into one new shared owner. The old
// owner/bytes remain live and charged until explicitly released.
pub fn Result<Token, Error> copy_record(ref records::Catalog catalog, Token source,
    ref mut u8[] bytes, ref mut Table table) {
    let Owner owner = resolve_record(catalog, table, source, bytes.len)?;
    let usize slot = free_slot(table)?;
    let usize mark = table.arena.used;
    let usize base = switch (record_storage::copy(catalog, owner.record, owner.base, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(record_error(error)); }
    };
    return .ok(publish_record(table, slot, owner.record, owner.length, owner.alignment, mark, base));
}
// Exact record identity is required even when two declared records have the same
// physical layout. Assignment never reserves an owner/extent or changes tokens.
pub fn Result<usize, Error> assign_record(ref records::Catalog catalog, Token destination,
    Token source, ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve_record(catalog, table, destination, bytes.len)?;
    let Owner origin = resolve_record(catalog, table, source, bytes.len)?;
    if (target.record != origin.record) { return .err(.Type); }
    return switch (record_storage::assign(catalog, origin.record, target.base, origin.base, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}

// Both whole owners and exact nominal child ranges are checked before snapshot.
// Exact nominal scalar values replace an existing root without a second owner.
// The table is read-only; callers establish mutability and prepay VM work.
pub fn Result<usize, Error> replace_record(ref records::Catalog catalog, Token destination,
    usize nominal, ref i64[] fields, ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve_record(catalog,table,destination,bytes.len)?;
    if (target.record != nominal) { return .err(.Type); }
    return switch (record_storage::replace_values(catalog,nominal,target.base,fields,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(error): { .err(record_error(error)) }
    };
}

// Storage assignment stages canonical scalar bytes before its first target write.
pub fn Result<usize, Error> assign_subrecord(ref records::Catalog catalog,
    Token destination, Token source, usize nominal, usize target_leaf, usize source_leaf,
    ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve_record(catalog,table,destination,bytes.len)?;
    let Owner origin = resolve_record(catalog,table,source,bytes.len)?;
    let usize target_offset = switch(record_range::offset(catalog,target.record,nominal,target_leaf)) {
        case .ok(n): { n } case .err(_): { return .err(.Type); }
    };
    let usize source_offset = switch(record_range::offset(catalog,origin.record,nominal,source_leaf)) {
        case .ok(n): { n } case .err(_): { return .err(.Type); }
    };
    if (target_offset > target.length || source_offset > origin.length) { return .err(.Bounds); }
    return switch(record_storage::assign(catalog,nominal,target.base+target_offset,
        origin.base+source_offset,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(e): { .err(record_error(e)) }
    };
}

// Resolve authority over the whole root and exact nominal child range before
// encoding all replacement values. Only selected bytes (including padding) publish.
pub fn Result<usize, Error> replace_subrecord(ref records::Catalog catalog,
    Token destination, usize nominal, usize target_leaf, ref i64[] fields,
    ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve_record(catalog,table,destination,bytes.len)?;
    let usize selected = switch(record_range::offset(catalog,target.record,nominal,target_leaf)) {
        case .ok(n): { n } case .err(_): { return .err(.Type); }
    };
    if (selected > target.length) { return .err(.Bounds); }
    return switch(record_storage::replace_values(catalog,nominal,target.base+selected,fields,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(e): { .err(record_error(e)) }
    };
}
