module array_storage;

import array_layout as layouts;
import scalar_codec as codec;

// Caller-owned backing bytes; no heap allocation, ownership token, or VM opcode.
// This private cursor publishes only fully initialized scalar arrays.
pub struct Arena { usize used; usize limit; }
pub enum Error { Type; Length; Metadata; Overflow; Quota; Bounds; Alignment; Value; State; }

pub fn Arena empty(usize limit) { return Arena { .used = 0, .limit = limit }; }

fn Error layout_error(layouts::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
        case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
        case .Alignment: { .Alignment }
    };
}
fn Error codec_error(codec::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Width: { .Metadata } case .Value: { .Value }
    };
}
fn bool valid(ref Arena arena, usize storage_bytes) {
    return arena.used <= arena.limit && arena.limit <= storage_bytes;
}

pub fn Result<usize, Error> initialize(ref layouts::Array layout, i64 fill,
    ref mut u8[] storage, ref mut Arena arena) {
    if (!valid(arena, storage.len)) { return .err(.State); }
    let layouts::Reservation plan = switch (layouts::reserve(layout, arena.used, arena.limit)) {
        case .ok(value): { value } case .err(e): { return .err(layout_error(e)); }
    };
    var u8[8] encoded = [0; 8];
    let usize size = switch (codec::encode(layout.element, fill, ref mut encoded[..layout.stride])) {
        case .ok(value): { value } case .err(e): { return .err(codec_error(e)); }
    };
    // All failure points precede mutation; padding and payload become initialized
    // before the cursor is advanced. The maximum payload loop is 32768 bytes.
    var usize at = arena.used;
    while (at < plan.offset) { storage[at] = 0; at += 1; }
    while (at < plan.end) {
        var usize byte = 0;
        while (byte < size) { storage[at + byte] = encoded[byte]; byte += 1; }
        at += size;
    }
    arena.used = plan.end;
    return .ok(plan.offset);
}

// Scratch belongs to the caller and must not overlap values or storage. Its
// contents are discardable on failure; storage and the arena remain unchanged.
// Exact payload-sized staging supports all 4096 elements without heap work.
pub fn Result<usize,Error> initialize_values(ref layouts::Array layout,ref i64[] values,
    ref mut u8[] scratch,ref mut u8[] storage,ref mut Arena arena){
    if(!valid(arena,storage.len)){return .err(.State);}
    let layouts::Reservation plan=switch(layouts::reserve(layout,arena.used,arena.limit)){
        case .ok(value):{value}case .err(error):{return .err(layout_error(error));}
    };
    if(values.len!=layout.length || scratch.len!=layout.bytes){return .err(.Length);}
    var usize i=0;
    while(i<values.len){let usize at=i*layout.stride;
        let usize encoded=switch(codec::encode(layout.element,values[i],scratch[at..at+layout.stride])){
            case .ok(value):{value}case .err(error):{return .err(codec_error(error));}
        };i+=1;
    }
    // All fallible validation/encoding precedes padding, payload and publication.
    i=arena.used;while(i<plan.offset){storage[i]=0;i+=1;}
    i=0;while(i<scratch.len){storage[plan.offset+i]=scratch[i];i+=1;}
    arena.used=plan.end;return .ok(plan.offset);
}

fn Result<usize, Error> address(ref layouts::Array layout, usize base, usize index,
    usize storage_bytes, ref Arena arena) {
    if (!valid(arena, storage_bytes)) { return .err(.State); }
    return switch (layouts::offset(layout, base, index, arena.used)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(layout_error(e)) }
    };
}

pub fn Result<i64, Error> read(ref layouts::Array layout, usize base, usize index,
    ref u8[] storage, ref Arena arena) {
    let usize at = address(layout, base, index, storage.len, arena)?;
    return switch (codec::decode(layout.element, storage[at..at + layout.stride])) {
        case .ok(value): { .ok(value) } case .err(e): { .err(codec_error(e)) }
    };
}

pub fn Result<usize, Error> write(ref layouts::Array layout, usize base, usize index,
    i64 cell, ref mut u8[] storage, ref Arena arena) {
    let usize at = address(layout, base, index, storage.len, arena)?;
    return switch (codec::encode(layout.element, cell, storage[at..at + layout.stride])) {
        case .ok(size): { .ok(size) } case .err(e): { .err(codec_error(e)) }
    };
}
