module array_range_vm;

import ir as ir;
import array_vm as arrays;
import array_owners as owners;
import errors as errors;
import std::bytes as bytes;

// Synchronous range scan: no retained handle, lease, payload copy or owner slot.
// Call only with the VM-owned table and its associated backing buffer.
pub fn Result<usize, errors::Error> step(ref ir::Program p, usize pc, usize frame,
    ref arrays::State state, ref bytes::Buffer buffer, ref mut i64[] registers, usize fuel) {
    if (pc >= p.count || pc >= 256) { return .err(errors::make(5, 0)); }
    let usize at = pc * 8;
    let usize offset = p.offsets[pc];
    let usize dst = p.code[at + 1] as usize;
    let usize id = p.code[at + 2] as usize;
    let usize start = p.code[at + 4] as usize + 256 * (p.code[at + 5] as usize);
    let usize end = p.code[at + 6] as usize + 256 * (p.code[at + 7] as usize);
    if (p.code[at] != 52 || p.code[at + 3] != 0 || frame >= 32 || dst >= registers.len ||
        id >= 16 || id >= p.arrays.count || p.arrays.elements[id] != 10 ||
        p.arrays.lengths[id] == 0 || p.arrays.lengths[id] > 4096 ||
        start > end || end > p.arrays.lengths[id]) { return .err(errors::make(5, offset)); }
    // Two bounded owner-chain checks plus up to four units per selected byte.
    let usize cost = 65 + 4 * (end - start);
    if (fuel < cost) { return .err(errors::make(8, offset)); }
    let ref u8[] data = bytes::view(buffer);
    let owners::View view = switch (owners::view(ref state.owners, state.tokens[frame * 16 + id], start, end, data.len)) {
        case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
    };
    if (view.element != 10 || view.length != p.arrays.lengths[id]) { return .err(errors::make(5, offset)); }
    let bool valid = switch (owners::view_utf8(ref state.owners, ref view, data)) {
        case .ok(v): { v } case .err(e): { return .err(arrays::failure(e, offset)); }
    };
    registers[dst] = if (valid) { 1 } else { 0 };
    return .ok(fuel - cost);
}
