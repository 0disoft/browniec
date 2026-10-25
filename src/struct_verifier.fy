module struct_verifier;

import ir as ir;
import errors as errors;
import struct_meta as meta;
import register_set as registers;

fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize f, u8 tag) {
    return r >= p.register_starts[f] && r < p.register_ends[f] && !p.slots[r] &&
        p.array_parameters[r] == 0 && registers::contains(defined, r) && p.types[r] == tag;
}
pub fn Result<usize, errors::Error> step(ref ir::Program p, ref meta::Prepared shapes,
    usize pc, usize f, ref mut registers::Set defined, ref mut registers::Set written, usize live) {
    let usize at = pc * 8;
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    let usize id = if (op == 43) { a } else { dst };
    if (f != p.entry || id >= p.records.count) { return .err(errors::make(5, pc)); }
    let usize one = 1;
    let usize mask = one << (16 + id);
    if (op == 41 || op == 42) {
        if (b != 0 || (live & mask) != 0) { return .err(errors::make(5, pc)); }
        if (op == 41) {
            let usize count = shapes.leaves[id];
            if (a > p.register_ends[f] || count > p.register_ends[f] - a) { return .err(errors::make(5, pc)); }
            var usize leaf = 0;
            while (leaf < count) {
                if (!readable(p, defined, a + leaf, f, shapes.tags[id * 128 + leaf])) { return .err(errors::make(5, pc)); }
                leaf += 1;
            }
        } else if (a >= p.records.count || (live & (one << (16 + a))) == 0 ||
            p.records.records[a] != p.records.records[id]) { return .err(errors::make(5, pc)); }
        return .ok(live | mask);
    }
    if ((live & mask) == 0) { return .err(errors::make(5, pc)); }
    if (op == 45) {
        if (a != 0 || b != 0) { return .err(errors::make(5, pc)); }
        return .ok(live ^ mask);
    }
    if (op == 46) {
        if (b != 0 || !p.records.mutable[id] || a >= p.records.count ||
            (live & (one << (16 + a))) == 0 || p.records.records[a] != p.records.records[id]) { return .err(errors::make(5, pc)); }
        return .ok(live);
    }
    let usize leaf = if (op == 43) { b } else { a };
    if (leaf >= shapes.leaves[id]) { return .err(errors::make(5, pc)); }
    let u8 tag = shapes.tags[id * 128 + leaf];
    if (op == 43) {
        if (dst < p.register_starts[f] || dst >= p.register_ends[f] || p.slots[dst] ||
            p.array_parameters[dst] != 0 || registers::contains(written, dst) || p.types[dst] != tag) { return .err(errors::make(5, pc)); }
        registers::insert(defined, dst); registers::insert(written, dst);
    } else if (op == 44) {
        if (!p.records.mutable[id] || !readable(p, defined, b, f, tag)) { return .err(errors::make(5, pc)); }
    } else { return .err(errors::make(5, pc)); }
    return .ok(live);
}
