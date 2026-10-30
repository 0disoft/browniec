module slice_verifier;
import ir as ir;
import errors as errors;
import register_set as registers;

// Array roots occupy bits 0..15, records 16..31, slice sites 32..47.
pub fn bool borrowed(ref ir::Program p, usize root, usize live) {
    let usize one = 1;
    var usize i = 0;
    while (i < 16) {
        if ((live & (one << (32 + i))) != 0 && p.slice_roots[i] as usize == root + 1) { return true; }
        i += 1;
    }
    return false;
}
fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize f) {
    return r >= p.register_starts[f] && r < p.register_ends[f] && !p.slots[r] &&
        p.array_parameters[r] == 0 && p.record_parameters[r] == 0 &&
        p.types[r] == 12 && registers::contains(defined, r);
}
pub fn Result<usize, errors::Error> step(ref ir::Program p, usize pc, usize f,
    ref mut registers::Set defined, ref mut registers::Set written, usize live) {
    let usize at = pc * 8;
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    let usize id = if (op == 55) { a } else { dst };
    if (id >= 16 || p.slice_roots[id] == 0) { return .err(errors::make(5, pc)); }
    let usize root = (p.slice_roots[id] as usize) - 1;
    if (root >= p.arrays.count || p.array_functions[root] as usize != f) { return .err(errors::make(5, pc)); }
    let usize one = 1;
    let usize mask = one << (32 + id);
    if ((live & (one << root)) == 0) { return .err(errors::make(5, pc)); }
    if (op == 54) {
        if ((live & mask) != 0 || !readable(p, defined, a, f) || !readable(p, defined, b, f)) { return .err(errors::make(5, pc)); }
        return .ok(live | mask);
    }
    if ((live & mask) == 0) { return .err(errors::make(5, pc)); }
    if (op == 56) {
        if (a != 0 || b != 0) { return .err(errors::make(5, pc)); }
        return .ok(live ^ mask);
    }
    if (op != 55 || b != 0 || p.arrays.elements[root] != 10 || dst < p.register_starts[f] ||
        dst >= p.register_ends[f] || p.slots[dst] || p.array_parameters[dst] != 0 ||
        p.record_parameters[dst] != 0 || p.types[dst] != 2 || registers::contains(written, dst)) { return .err(errors::make(5, pc)); }
    registers::insert(defined, dst);
    registers::insert(written, dst);
    return .ok(live);
}
