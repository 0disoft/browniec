module slice_vm;
import ir as ir;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import cells as cells;
import errors as errors;
import std::bytes as bytes;

pub struct State { slices::Pool pool; slices::Ticket[512] tickets; }
pub fn State empty() {
    return State { .pool = slices::empty(), .tickets = [slices::Ticket { .slot = 16, .generation = 0 }; 512] };
}
// Open prepays conservative fixed metadata work including eventual abort cleanup.
// UTF-8 prepays the entire origin length, before any payload read.
pub fn Result<usize, errors::Error> step(ref ir::Program p, usize pc, usize frame,
    ref mut State state, ref mut arrays::State arrays, ref bytes::Buffer buffer,
    ref mut i64[] registers, usize fuel) {
    if (pc >= p.count || pc >= 256) { return .err(errors::make(5, 0)); }
    let usize at = pc * 8;
    let usize offset = p.offsets[pc];
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    let usize id = if (op == 55 || op == 57 || op == 58) { a } else { dst };
    if (op < 54 || op > 59 || frame >= 32 || id >= 16 || ir::exclusive(p, id) || p.slice_roots[id] == 0 ||
        (op != 59 && p.code[at+4] != 0) || p.code[at+5] != 0 || p.code[at+6] != 0 || p.code[at+7] != 0) { return .err(errors::make(5, offset)); }
    let usize root = (p.slice_roots[id] as usize) - 1;
    if (root >= 16 || root >= p.arrays.count || p.arrays.lengths[root] == 0 || p.arrays.lengths[root] > 4096 ||
        (op == 54 && (a >= registers.len || b >= registers.len)) ||
        ((op == 55 || op == 57) && (dst >= registers.len || b != 0 || (op == 55 && p.arrays.elements[root] != 10))) ||
        (op == 58 && (dst >= registers.len || b >= registers.len)) ||
        (op == 59 && (a >= 16 || p.slice_roots[a] != p.slice_roots[id] || b >= registers.len ||
            p.code[at+4] as usize >= registers.len)) ||
        (op == 56 && (a != 0 || b != 0))) { return .err(errors::make(5, offset)); }
    let usize cost = if (op == 54 || op == 59) { 65537 } else if (op == 55) { 4097 + 4 * p.arrays.lengths[root] }
        else if (op == 58) { 4097 + arrays::cost(ref p.arrays, 35, root, offset)? } else { 4097 };
    if (fuel < cost) { return .err(errors::make(8, offset)); }
    let usize slot = frame * 16 + id;
    let ref u8[] data = bytes::view(buffer);
    if (op == 54) {
        if (state.tickets[slot].generation != 0) { return .err(errors::make(5, offset)); }
        let usize start = cells::unpack(registers[a], offset)?;
        let usize end = cells::unpack(registers[b], offset)?;
        let owners::Token token = arrays.tokens[frame * 16 + root];
        // Match runtime shape to the independent Program origin before publication.
        let owners::View view = switch (owners::view(ref arrays.owners, token, start, end, data.len)) {
            case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
        };
        if (view.element != p.arrays.elements[root] || view.length != p.arrays.lengths[root]) { return .err(errors::make(5, offset)); }
        let slices::Ticket opened = switch (slices::open(ref mut state.pool, ref mut arrays.owners, token, start, end, data.len)) {
            case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
        };
        state.tickets[slot] = opened;
    } else {
        if (op == 59 && state.tickets[slot].generation != 0) { return .err(errors::make(5, offset)); }
        let slices::Ticket ticket = state.tickets[if (op == 59) { frame * 16 + a } else { slot }];
        if (ticket.slot >= 16 || ticket.generation == 0) { return .err(errors::make(5, offset)); }
        let slices::Slot entry = state.pool.slots[ticket.slot];
        if (entry.exclusive) { return .err(errors::make(5, offset)); }
        let owners::Token token = arrays.tokens[frame * 16 + root];
        if (entry.view.root.slot != token.slot || entry.view.root.generation != token.generation ||
            entry.view.element != p.arrays.elements[root] || entry.view.length != p.arrays.lengths[root]) { return .err(errors::make(5, offset)); }
        if (op == 59) {
            let usize start = cells::unpack(registers[b], offset)?;
            let usize end = cells::unpack(registers[p.code[at+4] as usize], offset)?;
            let slices::Ticket child = switch (slices::subslice(ref mut state.pool, ticket, ref arrays.owners, start, end, data.len)) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            state.tickets[slot] = child;
        } else if (op == 55) {
            let bool valid = switch (slices::utf8(ref state.pool, ticket, ref arrays.owners, data)) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            registers[dst] = if (valid) { 1 } else { 0 };
        } else if (op == 58) {
            let usize index = cells::unpack(registers[b], offset)?;
            let i64 value = switch (slices::read(ref state.pool, ticket, ref arrays.owners, index, data)) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            registers[dst] = value;
        } else if (op == 57) {
            let usize length = switch (slices::length(ref state.pool, ticket, ref arrays.owners, data.len)) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            registers[dst] = cells::pack(length, offset)?;
        } else {
            let usize closed = switch (slices::close(ref mut state.pool, ticket, ref mut arrays.owners, data.len)) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            state.tickets[slot] = slices::Ticket { .slot = 16, .generation = 0 };
        }
    }
    return .ok(fuel - cost);
}
// Fixed bounded resource cleanup is already prepaid by successful open operations.
// On a native invariant failure retain metadata for diagnosis; never hide it.
pub fn Result<i64, errors::Error> finish(ref mut State state, ref mut arrays::State arrays,
    ref bytes::Buffer buffer, Result<i64, errors::Error> outcome) {
    var errors::Error failure = errors::make(0, 0);
    let i64 value = switch (outcome) { case .ok(v): { v } case .err(e): { failure = e; 0 } };
    let usize closed = drain(state, arrays, buffer)?;
    if (failure.kind != 0) { return .err(failure); }
    return .ok(value);
}

// Shared invocation cleanup; table publication precedes clearing ticket entries.
pub fn Result<usize, errors::Error> drain(ref mut State state, ref mut arrays::State arrays,
    ref bytes::Buffer buffer) {
    let usize closed = switch (slices::clear(ref mut state.pool, ref mut arrays.owners, bytes::len(buffer))) {
        case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, 0)); }
    };
    var usize i = 0;
    while (i < 512) { state.tickets[i] = slices::Ticket { .slot = 16, .generation = 0 }; i += 1; }
    return .ok(closed);
}
