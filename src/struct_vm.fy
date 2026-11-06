module struct_vm;

import struct_meta as meta;
import struct_range as ranges;
import struct_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import errors as errors;
import fuel as meter;
import std::bytes as bytes;

// Static record sites repeat under recursion; each invocation has its own tokens.
// All frames share the array state's sixteen owner slots and payload arena.
pub struct State { owners::Token[512] tokens; }
struct Selection { usize leaves; usize length; usize[16] path; }
pub fn State empty() {
    return State { .tokens = [owners::Token { .slot = 0, .generation = 0 }; 512] };
}
pub fn Result<usize, errors::Error> cost(u8 op, usize offset) {
    return switch(meter::record_instruction(op)){
        case .some(price):{.ok(price)}case .none:{.err(errors::make(5,offset))}
    };
}

// Ordinal 128 counts the whole root; ordinary ordinals select a scalar path.
// Metadata is immutable and independently verified before dispatch. Defensive
// limits also bound direct helper calls with malformed depth/cycles/leaf counts.
fn Result<Selection, errors::Error> select(ref layouts::Catalog catalog, usize root, usize ordinal, usize offset) {
    if (catalog.count > 32 || root >= catalog.count || ordinal > 128) { return .err(errors::make(5, offset)); }
    var usize[16] records = [0; 16]; var usize[16] fields = [0; 16];
    var usize leaves = 0; var usize[16] path = [0; 16];
    records[0] = root; var usize depth = 1; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(5, offset)); }
        visits += 1;
        let usize level = depth - 1; let usize record = records[level];
        if (record >= catalog.count || catalog.fields[record] == 0 || catalog.fields[record] > 16) { return .err(errors::make(5, offset)); }
        let usize field = fields[level];
        if (field >= catalog.fields[record] as usize) { depth -= 1; }
        else {
            fields[level] += 1; path[level] = field;
            let usize slot = record * 16 + field;
            if (catalog.kinds[slot] == 0) {
                if (leaves >= 128) { return .err(errors::make(5, offset)); }
                if (leaves == ordinal) { return .ok(Selection { .leaves = leaves, .length = depth, .path = path }); }
                leaves += 1;
            } else {
                if (catalog.kinds[slot] != 1 || depth >= 16) { return .err(errors::make(5, offset)); }
                records[depth] = catalog.types[slot] as usize; fields[depth] = 0; depth += 1;
            }
        }
    }
    if (ordinal != 128) { return .err(errors::make(5, offset)); }
    return .ok(Selection { .leaves = leaves, .length = 0, .path = path });
}
fn bool bound(ref meta::Catalog catalog, usize id, usize frame, ref State state, ref owners::Table table) {
    if (frame >= 32 || id >= catalog.count || id >= 16) { return false; }
    let owners::Token token = state.tokens[frame * 16 + id];
    if (token.slot >= 16 || token.generation == 0) { return false; }
    let owners::Owner owner = table.slots[token.slot];
    return owner.occupied && owner.live && owner.generation == token.generation &&
        owner.element == 0 && owner.record == catalog.records[id] as usize;
}
pub fn Result<usize, errors::Error> execute_data(u8 op, usize dst, usize a, usize b, usize frame,
    ref meta::Catalog catalog, ref mut State state, ref mut arrays::State shared,
    ref mut u8[] data, ref mut i64[] registers, usize offset) {
    let usize id = if (op == 43) { a } else { dst };
    if (frame >= 32 || catalog.count > 16 || id >= catalog.count) { return .err(errors::make(5, offset)); }
    let usize base = frame * 16;
    let usize record = catalog.records[id] as usize;
    if (op == 41 || op == 42) {
        if (b != 0 || state.tokens[base + id].generation != 0) { return .err(errors::make(5, offset)); }
        var owners::Token token = owners::Token { .slot = 0, .generation = 0 };
        if (op == 41) {
            let Selection shape = select(ref catalog.layouts, record, 128, offset)?;
            if (a > registers.len || shape.leaves > registers.len - a) { return .err(errors::make(5, offset)); }
            token = switch (owners::create_record(ref catalog.layouts, record, registers[a..a + shape.leaves], data, ref mut shared.owners)) {
                case .ok(value): { value } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        } else {
            if (!bound(catalog, a, frame, state, ref shared.owners) || catalog.records[a] != catalog.records[id]) { return .err(errors::make(5, offset)); }
            token = switch (owners::copy_record(ref catalog.layouts, state.tokens[base + a], data, ref mut shared.owners)) {
                case .ok(value): { value } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        }
        state.tokens[base + id] = token;
    } else {
        if (!bound(catalog, id, frame, state, ref shared.owners)) { return .err(errors::make(5, offset)); }
        if (op == 48) {
            if (!catalog.mutable[id] || b != record) { return .err(errors::make(5,offset)); }
            let Selection shape = select(ref catalog.layouts,record,128,offset)?;
            if (a > registers.len || shape.leaves > registers.len-a) { return .err(errors::make(5,offset)); }
            let usize replaced = switch (owners::replace_record(ref catalog.layouts,state.tokens[base + id],b,
                registers[a..a+shape.leaves],data,ref shared.owners)) {
                case .ok(n): { n } case .err(e): { return .err(arrays::failure(e,offset)); }
            };
        } else if (op == 45) {
            if (a != 0 || b != 0) { return .err(errors::make(5, offset)); }
            let usize reclaimed = switch (owners::release(ref mut shared.owners, state.tokens[base + id], data.len)) {
                case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
            state.tokens[base + id] = owners::Token { .slot = 0, .generation = 0 };
        } else if (op == 46) {
            if (b != 0 || !catalog.mutable[id] || !bound(catalog, a, frame, state, ref shared.owners) || catalog.records[a] != catalog.records[id]) { return .err(errors::make(5, offset)); }
            let usize assigned = switch (owners::assign_record(ref catalog.layouts, state.tokens[base + id], state.tokens[base + a], data, ref shared.owners)) {
                case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
            };
        } else {
            if ((op == 43 && dst >= registers.len) || (op == 44 && (b >= registers.len || !catalog.mutable[id]))) { return .err(errors::make(5, offset)); }
            let usize ordinal = if (op == 43) { b } else { a };
            if (ordinal >= 128) { return .err(errors::make(5, offset)); }
            let Selection leaf = select(ref catalog.layouts, record, ordinal, offset)?;
            if (op == 43) {
                let i64 value = switch (owners::read_record(ref catalog.layouts, ref shared.owners, state.tokens[base + id], ref leaf.path[..leaf.length], data)) {
                    case .ok(n): { n } case .err(e): { return .err(arrays::failure(e, offset)); }
                };
                registers[dst] = value;
            } else if (op == 44) {
                let usize written = switch (owners::write_record(ref catalog.layouts, ref shared.owners, state.tokens[base + id], ref leaf.path[..leaf.length], registers[b], data)) {
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
    return step_data(op,dst,a,b,frame,catalog,state,shared,bytes::view_mut(buffer),registers,fuel,offset);
}
pub fn Result<usize, errors::Error> step_data(u8 op, usize dst, usize a, usize b, usize frame,
    ref meta::Catalog catalog, ref mut State state, ref mut arrays::State shared,
    ref mut u8[] data, ref mut i64[] registers, usize fuel, usize offset) {
    let usize work = cost(op, offset)?;
    if (fuel < work) { return .err(errors::make(8, offset)); }
    let usize remaining = fuel - work;
    let usize executed = execute_data(op, dst, a, b, frame, catalog, state, shared, data, registers, offset)?;
    return .ok(remaining);
}

// Prepay the entire operation. All owner/range/value checks and canonical byte
// staging finish before storage assignment publishes any destination byte.
pub fn Result<usize, errors::Error> subassign(usize dst, usize source, usize nominal,
    usize target_leaf, usize source_leaf, usize frame, ref meta::Catalog catalog,
    ref mut State state, ref mut arrays::State shared, ref mut bytes::Buffer buffer,
    usize fuel, usize offset) {
    return subassign_data(dst,source,nominal,target_leaf,source_leaf,frame,catalog,state,shared,bytes::view_mut(buffer),fuel,offset);
}
pub fn Result<usize, errors::Error> subassign_data(usize dst, usize source, usize nominal,
    usize target_leaf, usize source_leaf, usize frame, ref meta::Catalog catalog,
    ref mut State state, ref mut arrays::State shared, ref mut u8[] data,
    usize fuel, usize offset) {
    let usize work = cost(47,offset)?;
    if (fuel < work) { return .err(errors::make(8,offset)); }
    if (frame >= 32 || catalog.count > 16 || dst >= catalog.count || !catalog.mutable[dst] ||
        !bound(catalog,dst,frame,state,ref shared.owners) || !bound(catalog,source,frame,state,ref shared.owners)) {
        return .err(errors::make(5,offset));
    }
    let usize base = frame * 16;
    let usize assigned = switch(owners::assign_subrecord(ref catalog.layouts,state.tokens[base + dst],state.tokens[base + source],
        nominal,target_leaf,source_leaf,data,ref shared.owners)) {
        case .ok(n): { n } case .err(e): { return .err(arrays::failure(e,offset)); }
    };
    return .ok(fuel-work);
}

// All input checks and byte staging precede the single child-range commit.
pub fn Result<usize, errors::Error> subreplace(usize dst, usize first, usize nominal,
    usize target_leaf, usize frame, ref meta::Catalog catalog, ref mut State state,
    ref mut arrays::State shared, ref mut bytes::Buffer buffer, ref i64[] registers,
    usize fuel, usize offset) {
    return subreplace_data(dst,first,nominal,target_leaf,frame,catalog,state,shared,bytes::view_mut(buffer),registers,fuel,offset);
}
pub fn Result<usize, errors::Error> subreplace_data(usize dst, usize first, usize nominal,
    usize target_leaf, usize frame, ref meta::Catalog catalog, ref mut State state,
    ref mut arrays::State shared, ref mut u8[] data, ref i64[] registers,
    usize fuel, usize offset) {
    let usize work = cost(49,offset)?;
    if (fuel < work) { return .err(errors::make(8,offset)); }
    if (frame >= 32 || catalog.count > 16 || dst >= catalog.count || !catalog.mutable[dst] ||
        !bound(catalog,dst,frame,state,ref shared.owners)) { return .err(errors::make(5,offset)); }
    let usize base = frame * 16;
    let usize count = switch(ranges::leaves(ref catalog.layouts,nominal)) {
        case .ok(n): { n } case .err(_): { return .err(errors::make(5,offset)); }
    };
    if (first > registers.len || count > registers.len-first) { return .err(errors::make(5,offset)); }
    let usize replaced = switch(owners::replace_subrecord(ref catalog.layouts,state.tokens[base + dst],nominal,
        target_leaf,registers[first..first+count],data,ref shared.owners)) {
        case .ok(n): { n } case .err(e): { return .err(arrays::failure(e,offset)); }
    };
    return .ok(fuel-work);
}
