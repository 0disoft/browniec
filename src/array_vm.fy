module array_vm;

import array_meta as meta;
import array_layout as layouts;
import array_owners as owners;
import cells as cells;
import errors as errors;
import std::bytes as bytes;

// Static catalog IDs repeat under recursion; tokens belong to an invocation.
// The payload and sixteen live owner descriptors remain shared by all frames.
pub struct State { owners::Table owners; owners::Token[512] tokens; }
pub fn State empty(usize limit) {
    return State { .owners = owners::empty(limit), .tokens = [owners::Token { .slot = 0, .generation = 0 }; 512] };
}
pub fn Result<bytes::Buffer, errors::Error> prepare(usize capacity) {
    if (capacity > 65536) { return .err(errors::make(13, 0)); }
    var bytes::Buffer buffer = switch (bytes::with_capacity(capacity)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(15, 0)); }
    };
    if (bytes::capacity(ref buffer) != capacity || !bytes::resize_zeroed(ref mut buffer, capacity).is_ok) {
        return .err(errors::make(15, 0));
    }
    return .ok(buffer);
}
pub fn Result<usize, errors::Error> cost(ref meta::Catalog catalog, u8 op, usize id, usize offset) {
    if (id >= catalog.count || id >= 16) { return .err(errors::make(5, offset)); }
    let layouts::Array layout = switch (layouts::scalar(catalog.elements[id], catalog.lengths[id])) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(5, offset)); }
    };
    // Descriptor visits are charged at the fixed 16-record ceiling; payload work
    // is charged by byte, including worst-case alignment and codec scratch work.
    if (op == 33) { return .ok(49 + 2 * layout.stride + layout.bytes + 7); }
    if (op == 34) { return .ok(49 + layout.bytes + 7 + if (layout.element == 2) { layout.length } else { 0 }); }
    if (op == 35) { return .ok(33 + layout.stride); }
    if (op == 36) { return .ok(33 + 2 * layout.stride); }
    if (op == 37) { return .ok(49); }
    // Both owner resolutions validate the bounded metadata chain. No reservation
    // or descriptor publication occurs, but bool sources need a full scan.
    if (op == 38) { return .ok(81 + layout.bytes + if (layout.element == 2) { layout.length } else { 0 }); }
    return .err(errors::make(5, offset));
}
fn errors::Error failure(owners::Error error, usize offset) {
    let u8 kind = switch (error) {
        case .Owners: { 13 } case .Quota: { 13 } case .Bounds: { 14 }
        case .Token: { 5 } case .State: { 5 } case .Type: { 5 } case .Length: { 5 }
        case .Metadata: { 5 } case .Overflow: { 5 } case .Alignment: { 5 } case .Value: { 5 }
    };
    return errors::make(kind, offset);
}
pub fn Result<usize, errors::Error> execute(u8 op, usize dst, usize a, usize b, usize frame, ref meta::Catalog catalog,
    ref mut State state, ref mut bytes::Buffer buffer, ref mut i64[] registers, usize offset) {
    if (frame >= 32) { return .err(errors::make(5, offset)); }
    let usize base = frame * 16;
    let ref mut u8[] data = bytes::view_mut(buffer);
    if (op == 33) {
        let layouts::Array layout = switch (layouts::scalar(catalog.elements[dst], catalog.lengths[dst])) {
            case .ok(value): { value } case .err(_): { return .err(errors::make(5, offset)); }
        };
        let owners::Token token = switch (owners::create(ref layout, registers[a], data, ref mut state.owners)) {
            case .ok(value): { value } case .err(e): { return .err(failure(e, offset)); }
        };
        state.tokens[base + dst] = token;
    } else if (op == 34) {
        let owners::Token source = state.tokens[base + a];
        let owners::Token token = switch (owners::copy(source, data, ref mut state.owners)) {
            case .ok(value): { value } case .err(e): { return .err(failure(e, offset)); }
        };
        state.tokens[base + dst] = token;
    } else if (op == 35) {
        let owners::Token token = state.tokens[base + a];
        let usize index = cells::unpack(registers[b], offset)?;
        let i64 value = switch (owners::read(ref state.owners, token, index, data)) {
            case .ok(value): { value } case .err(e): { return .err(failure(e, offset)); }
        };
        registers[dst] = value;
    } else if (op == 36) {
        let owners::Token token = state.tokens[base + dst];
        let usize index = cells::unpack(registers[a], offset)?;
        let usize size = switch (owners::write(ref state.owners, token, index, registers[b], data)) {
            case .ok(value): { value } case .err(e): { return .err(failure(e, offset)); }
        };
    } else if (op == 38) {
        let usize assigned = switch (owners::assign(state.tokens[base + dst], state.tokens[base + a], data, ref state.owners)) {
            case .ok(size): { size } case .err(e): { return .err(failure(e, offset)); }
        };
    } else if (op == 37) {
        let owners::Token token = state.tokens[base + dst];
        let usize reclaimed = switch (owners::release(ref mut state.owners, token, data.len)) {
            case .ok(value): { value } case .err(e): { return .err(failure(e, offset)); }
        };
        state.tokens[base + dst] = owners::Token { .slot = 0, .generation = 0 };
    } else { return .err(errors::make(5, offset)); }
    return .ok(0);
}
