module verifier;

import errors as errors;
import ir as ir;

fn bool readable(ref bool[] defined, usize r, usize start, usize end) {
    return r >= start && r < end && defined[r];
}
fn Result<usize, errors::Error> function(ref ir::Program p, usize f, ref mut bool[] used_calls) {
    let usize start = p.register_starts[f];
    let usize end = p.register_ends[f];
    let usize arity = p.arities[f];
    if (start > end || end > p.registers || arity > 8 || start + arity > end) { return .err(errors::make(5, p.starts[f])); }
    var bool[128] defined = [false; 128];
    var usize i = 0;
    while (i < arity) { defined[start + i] = true; i += 1; }
    var usize definitions = arity;
    var usize pc = p.starts[f];
    while (pc < p.ends[f]) {
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op < 1 || op > 9 || p.code[at + 4] != 0 || p.code[at + 5] != 0 || p.code[at + 6] != 0 || p.code[at + 7] != 0) { return .err(errors::make(5, pc)); }
        if (op == 8) {
            if (dst != 0 || b != 0 || !readable(ref defined, a, start, end) || pc + 1 != p.ends[f]) { return .err(errors::make(5, pc)); }
        } else {
            if (dst < start || dst >= end || defined[dst]) { return .err(errors::make(5, pc)); }
            if (op == 1) {
                if (a >= p.constant_count || b != 0 || p.constants[a] < -2147483648 || p.constants[a] > 2147483647) { return .err(errors::make(5, pc)); }
            } else if (op == 9) {
                if (a >= p.function_count || b >= p.call_count || used_calls[b]) { return .err(errors::make(5, pc)); }
                let usize count = p.call_arities[b] as usize;
                if (count != p.arities[a] || count > 8) { return .err(errors::make(5, pc)); }
                var usize arg = 0;
                while (arg < 8) {
                    let usize r = p.call_args[b * 8 + arg] as usize;
                    if (arg < count) {
                        if (!readable(ref defined, r, start, end)) { return .err(errors::make(5, pc)); }
                    } else if (r != 0) { return .err(errors::make(5, pc)); }
                    arg += 1;
                }
                used_calls[b] = true;
            } else {
                if (!readable(ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
                if (op == 7) {
                    if (b != 0) { return .err(errors::make(5, pc)); }
                } else if (!readable(ref defined, b, start, end)) { return .err(errors::make(5, pc)); }
            }
            defined[dst] = true;
            definitions += 1;
        }
        pc += 1;
    }
    if (p.code[(p.ends[f] - 1) * 8] != 8 || definitions != end - start) { return .err(errors::make(5, pc)); }
    return .ok(definitions);
}

pub fn Result<usize, errors::Error> verify(ref ir::Program p) {
    if (p.count == 0 || p.count > 256 || p.registers == 0 || p.registers > 128 || p.constant_count > 128 ||
        p.function_count == 0 || p.function_count > 16 || p.entry >= p.function_count || p.call_count > 32) { return .err(errors::make(5, 0)); }
    if (p.arities[p.entry] != 0) { return .err(errors::make(5, 0)); }
    // Validate the entire directory before decoding any function or call target.
    var usize f = 0;
    var usize code_end = 0;
    var usize register_end = 0;
    while (f < p.function_count) {
        if (p.starts[f] != code_end || p.ends[f] <= code_end || p.ends[f] > p.count ||
            p.register_starts[f] != register_end || p.register_ends[f] < register_end ||
            p.register_ends[f] > p.registers || p.arities[f] > 8 ||
            p.arities[f] > p.register_ends[f] - register_end) { return .err(errors::make(5, code_end)); }
        code_end = p.ends[f]; register_end = p.register_ends[f]; f += 1;
    }
    if (code_end != p.count || register_end != p.registers) { return .err(errors::make(5, 0)); }
    var bool[32] used_calls = [false; 32];
    f = 0;
    while (f < p.function_count) { let usize checked = function(p, f, ref mut used_calls)?; f += 1; }
    var usize call = 0;
    while (call < p.call_count) { if (!used_calls[call]) { return .err(errors::make(5, 0)); } call += 1; }
    return .ok(p.count);
}
