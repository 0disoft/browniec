module array_verifier;

import ir as ir;
import errors as errors;
import register_set as registers;
import array_parameters as parameters;

fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize f, u8 tag) {
    return r >= p.register_starts[f] && r < p.register_ends[f] && !p.slots[r] && p.array_parameters[r] == 0 && registers::contains(defined, r) && p.types[r] == tag;
}
pub fn Result<usize, errors::Error> step(ref ir::Program p, usize pc, usize f,
    ref mut registers::Set defined, ref mut registers::Set written, usize live) {
    let usize at = pc * 8;
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    let usize id = if (op == 35) { a } else { dst };
    if (id >= p.arrays.count || p.array_functions[id] as usize != f) { return .err(errors::make(5, pc)); }
    let usize one = 1;
    let usize mask = one << id;
    let u8 element = p.arrays.elements[id];
    if (op == 33 || op == 34) {
        if (b != 0 || (live & mask) != 0 || (parameters::initial(p, f) & mask) != 0) { return .err(errors::make(5, pc)); }
        if (op == 33) {
            if (!readable(p, defined, a, f, element)) { return .err(errors::make(5, pc)); }
        } else {
            if (a >= p.arrays.count || (live & (one << a)) == 0 ||
                p.arrays.elements[a] != element || p.arrays.lengths[a] != p.arrays.lengths[id]) { return .err(errors::make(5, pc)); }
        }
        return .ok(live | mask);
    }
    if ((live & mask) == 0) { return .err(errors::make(5, pc)); }
    if (op == 38) {
        if (b != 0 || !p.arrays.mutable[id] || a >= p.arrays.count || (live & (one << a)) == 0 ||
            p.arrays.elements[a] != element || p.arrays.lengths[a] != p.arrays.lengths[id]) { return .err(errors::make(5, pc)); }
        return .ok(live);
    }
    if (op == 37) {
        if (a != 0 || b != 0) { return .err(errors::make(5, pc)); }
        return .ok(live ^ mask);
    }
    if (op == 36) {
        if (!p.arrays.mutable[id] || !readable(p, defined, a, f, 12) || !readable(p, defined, b, f, element)) { return .err(errors::make(5, pc)); }
    } else if (op == 35) {
        if (!readable(p, defined, b, f, 12) || dst < p.register_starts[f] || dst >= p.register_ends[f] ||
            p.slots[dst] || registers::contains(written, dst) || p.types[dst] != element) { return .err(errors::make(5, pc)); }
        registers::insert(defined, dst); registers::insert(written, dst);
    } else { return .err(errors::make(5, pc)); }
    return .ok(live);
}
