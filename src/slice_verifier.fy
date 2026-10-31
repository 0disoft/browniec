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
        p.array_parameters[r] == 0 && p.record_parameters[r] == 0 && p.slice_parameters[r] == 0 &&
        p.types[r] == 12 && registers::contains(defined, r);
}
pub fn Result<usize, errors::Error> step(ref ir::Program p, usize pc, usize f,
    ref mut registers::Set defined, ref mut registers::Set written, usize live) {
    let usize at = pc * 8;
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    let usize id = if (op == 55 || op == 57 || op == 58) { a } else { dst };
    if (id >= 16) { return .err(errors::make(5, pc)); }
    let usize root = p.slice_roots[id] as usize;
    let usize origin = p.slice_origins[id] as usize;
    var u8 element = p.slice_elements[id];
    let usize one = 1;
    let usize mask = one << (32 + id);
    // Whole-Program metadata was checked before any per-PC table access.
    if (root != 0) {
        if (root > 16 || root > p.arrays.count || p.array_functions[root - 1] as usize != f ||
            origin != 0 || p.slice_functions[id] != 0 || (live & (one << (root - 1))) == 0) { return .err(errors::make(5, pc)); }
        element = p.arrays.elements[root - 1];
    } else if (origin == 0 || origin > 16 || p.slice_functions[id] as usize != f + 1) { return .err(errors::make(5, pc)); }
    if (op == 59) {
        let usize end = p.code[at + 4] as usize;
        if ((live & mask) != 0 || a >= 16 || a == id || p.slice_roots[a] != p.slice_roots[id] ||
            p.slice_origins[a] != p.slice_origins[id] || p.slice_functions[a] != p.slice_functions[id] ||
            (root == 0 && origin == id + 1) ||
            (live & (one << (32 + a))) == 0 || !readable(p, defined, b, f) ||
            !readable(p, defined, end, f)) { return .err(errors::make(5, pc)); }
        return .ok(live | mask);
    }
    if (op == 54) {
        if (root == 0 || (live & mask) != 0 || !readable(p, defined, a, f) || !readable(p, defined, b, f)) { return .err(errors::make(5, pc)); }
        return .ok(live | mask);
    }
    if ((live & mask) == 0) { return .err(errors::make(5, pc)); }
    if (op == 56) {
        if (a != 0 || b != 0) { return .err(errors::make(5, pc)); }
        return .ok(live ^ mask);
    }
    if ((op != 55 && op != 57 && op != 58) ||
        (op == 58 && !readable(p, defined, b, f)) || (op != 58 && b != 0) ||
        (op == 55 && element != 10) || dst < p.register_starts[f] ||
        dst >= p.register_ends[f] || p.slots[dst] || p.array_parameters[dst] != 0 ||
        p.record_parameters[dst] != 0 || p.slice_parameters[dst] != 0 ||
        p.types[dst] != if (op == 58) { element } else if (op == 57) { 12 } else { 2 } || registers::contains(written, dst)) { return .err(errors::make(5, pc)); }
    registers::insert(defined, dst);
    registers::insert(written, dst);
    return .ok(live);
}
