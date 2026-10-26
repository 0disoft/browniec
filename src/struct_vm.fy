module struct_vm;

import struct_meta as meta;
import struct_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import errors as errors;
import std::bytes as bytes;

// Entry invocation only. These bindings share the array state's owner table.
pub struct State { owners::Token[16] tokens; }
struct Selection { usize leaves; usize length; usize[16] path; }
pub fn State empty() {
    return State { .tokens = [owners::Token { .slot = 0, .generation = 0 }; 16] };
}
pub fn Result<usize, errors::Error> cost(u8 op, usize offset) {
    // Fixed ceilings, not machine-instruction counts. One canonical plan visits
    // <= 17408 fields; one selected-root traversal uses <= 4096 iterations.
    // Include complete record staging, codec work, padding and owner scans.
    if (op == 41) { return .ok(2 * 18432 + 2 * 4096 + 1024 + 65); }
    if (op == 42) { return .ok(2 * 18432 + 4096 + 1024 + 65); }
    if (op == 43 || op == 44) { return .ok(2 * 18432 + 4096 + 256 + 65); }
    if (op == 45) { return .ok(65); }
    if (op == 46) { return .ok(3 * 18432 + 4096 + 1024 + 129); }
    // Five complete plans, <= four 4096-visit traversals, staging and owner scans.
    if (op == 47) { return .ok(131072); }
    return .err(errors::make(5, offset));
}

// Ordinal 128 counts the whole root; ordinary ordinals select a scalar path.
// Metadata is immutable and independently verified before dispatch. Defensive
// limits also bound direct helper calls with malformed depth/cycles/leaf counts.
fn Result<Selection, errors::Error> select(ref layouts::Catalog catalog, usize root, usize ordinal, usize offset) {
    if (catalog.count > 32 || root >= catalog.count || ordinal > 128) { return .err(errors::make(5, offset)); }
    var usize[16] records = [0; 16]; var usize[16] fields = [0; 16];
    var Selection result = Selection { .leaves = 0, .length = 0, .path = [0; 16] };
    records[0] = root; var usize depth = 1; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(5, offset)); }
        visits += 1;
        let usize level = depth - 1; let usize record = records[level];
        if (record >= catalog.count || catalog.fields[record] == 0 || catalog.fields[record] > 16) { return .err(errors::make(5, offset)); }
        let usize field = fields[level];
        if (field >= catalog.fields[record] as usize) { depth -= 1; }
        else {
            fields[level] += 1; result.path[level] = field;
            let usize slot = record * 16 + field;
            if (catalog.kinds[slot] == 0) {
                if (result.leaves >= 128) { return .err(errors::make(5, offset)); }
                if (result.leaves == ordinal) { result.length = depth; return .ok(result); }
                result.leaves += 1;
            } else {
                if (catalog.kinds[slot] != 1 || depth >= 16) { return .err(errors::make(5, offset)); }
                records[depth] = catalog.types[slot] as usize; fields[depth] = 0; depth += 1;
            }
        }
    }
    if (ordinal != 128) { return .err(errors::make(5, offset)); }
    return .ok(result);
}
fn bool bound(ref meta::Catalog catalog, usize id, ref State state, ref owners::Table table) {
    if (id >= catalog.count || id >= 16) { return false; }
    let owners::Token token = state.tokens[id];
    if (token.slot >= 16 || token.generation == 0) { return false; }
    let owners::Owner owner = table.slots[token.slot];
    return owner.occupied && owner.live && owner.generation == token.generation &&
        owner.element == 0 && owner.record == catalog.records[id] as usize;
}
fn Result<usize, errors::Error> execute(u8 op, usize dst, usize a, usize b, usize frame,
    ref meta::Catalog catalog, ref mut State state, ref mut arrays::State shared,
    ref mut bytes::Buffer buffer, ref mut i64[] registers, usize offset) {
    let usize id = if (op == 43) { a } else { dst };
    if (frame != 0 || catalog.count > 16 || id >= catalog.count) { return .err(errors::make(5, offset)); }
    let usize record = catalog.records[id] as usize;
    let ref mut u8[] data = bytes::view_mut(buffer);
    if (op == 41 || op == 42) {
        if (b != 0 || state.tokens[id].generation != 0) { return .err(errors::make(5, offset)); }
        var owners::Token token = owners::Token { .slot = 0, .generation = 0 };
        if (op == 41) {
            let Selection shape = select(ref catalog.layouts, record, 128, offset)?;
            if (a > registers.len || shape.leaves > registers.len - a) { return .err(errors::make(5, offset)); }
            token = switch (owners::create_record(ref catalog.layouts, record, registers[a..a + shape.leaves], data, ref mut shared.owners)) {
                case .ok(value): { value } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        } else {
            if (!bound(catalog, a, state, ref shared.owners) || catalog.records[a] != catalog.records[id]) { return .err(errors::make(5, offset)); }
            token = switch (owners::copy_record(ref catalog.layouts, state.tokens[a], data, ref mut shared.owners)) {
                case .ok(value): { value } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        }
        state.tokens[id] = token;
    } else {
        if (!bound(catalog, id, state, ref shared.owners)) { return .err(errors::make(5, offset)); }
        if (op == 45) {
            if (a != 0 || b != 0) { return .err(errors::make(5, offset)); }
            let usize reclaimed = switch (owners::release(ref mut shared.owners, state.tokens[id], data.len)) {
                case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            state.tokens[id] = owners::Token { .slot = 0, .generation = 0 };
        } else if (op == 46) {
            if (b != 0 || !catalog.mutable[id] || !bound(catalog, a, state, ref shared.owners) || catalog.records[a] != catalog.records[id]) { return .err(errors::make(5, offset)); }
            let usize assigned = switch (owners::assign_record(ref catalog.layouts, state.tokens[id], state.tokens[a], data, ref shared.owners)) {
                case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        } else {
            if ((op == 43 && dst >= registers.len) || (op == 44 && (b >= registers.len || !catalog.mutable[id]))) { return .err(errors::make(5, offset)); }
            let usize ordinal = if (op == 43) { b } else { a };
            if (ordinal >= 128) { return .err(errors::make(5, offset)); }
            let Selection leaf = select(ref catalog.layouts, record, ordinal, offset)?;
            if (op == 43) {
                let i64 value = switch (owners::read_record(ref catalog.layouts, ref shared.owners, state.tokens[id], ref leaf.path[..leaf.length], data)) {
                    case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
                };
                registers[dst] = value;
            } else if (op == 44) {
                let usize written = switch (owners::write_record(ref catalog.layouts, ref shared.owners, state.tokens[id], ref leaf.path[..leaf.length], registers[b], data)) {
                    case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
                };
            } else { return .err(errors::make(5, offset)); }
        }
    }
    return .ok(0);
}
// Charge before path traversal, validation, staging or any token/register write.
// Caller binds a verified immutable catalog and unchanged backing region.
pub fn Result<usize, errors::Error> step(u8 op, usize dst, usize a, usize b, usize frame,
    ref meta::Catalog catalog, ref mut State state, ref mut arrays::State shared,
    ref mut bytes::Buffer buffer, ref mut i64[] registers, usize fuel, usize offset) {
    let usize work = cost(op, offset)?;
    if (fuel < work) { return .err(errors::make(8, offset)); }
    let usize remaining = fuel - work;
    let usize executed = execute(op, dst, a, b, frame, catalog, state, shared, buffer, registers, offset)?;
    return .ok(remaining);
}

// Prepay the entire operation. All owner/range/value checks and canonical byte
// staging finish before storage assignment publishes any destination byte.
pub fn Result<usize, errors::Error> subassign(usize dst, usize source, usize nominal,
    usize target_leaf, usize source_leaf, usize frame, ref meta::Catalog catalog,
    ref mut State state, ref mut arrays::State shared, ref mut bytes::Buffer buffer,
    usize fuel, usize offset) {
    let usize work = cost(47,offset)?;
    if (fuel < work) { return .err(errors::make(8,offset)); }
    if (frame != 0 || catalog.count > 16 || dst >= catalog.count || !catalog.mutable[dst] ||
        !bound(catalog,dst,state,ref shared.owners) || !bound(catalog,source,state,ref shared.owners)) {
        return .err(errors::make(5,offset));
    }
    let ref mut u8[] data = bytes::view_mut(buffer);
    let usize assigned = switch(owners::assign_subrecord(ref catalog.layouts,state.tokens[dst],state.tokens[source],
        nominal,target_leaf,source_leaf,data,ref shared.owners)) {
        case .ok(n): { n } case .err(e): { return .err(arrays::failure(e,offset)); }
    };
    return .ok(fuel-work);
}
