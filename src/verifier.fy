module verifier;

import errors as errors;
import ir as ir;

// Reconstruct definitions independently; compiler register counts are not proof.
pub fn Result<usize, errors::Error> verify(ref ir::Program p) {
    if (p.count == 0 || p.count > 256 || p.registers == 0 || p.registers > 128 || p.constant_count > 128) {
        return .err(errors::make(5, 0));
    }
    var bool[128] defined = [false; 128];
    var usize definitions = 0;
    var usize pc = 0;
    while (pc < p.count) {
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op < 1 || op > 8 || p.code[at + 4] != 0 || p.code[at + 5] != 0 ||
            p.code[at + 6] != 0 || p.code[at + 7] != 0) { return .err(errors::make(5, pc)); }
        if (op == 8) {
            if (dst != 0 || b != 0 || a >= p.registers || !defined[a] || pc + 1 != p.count) {
                return .err(errors::make(5, pc));
            }
        } else {
            if (dst >= p.registers || defined[dst]) { return .err(errors::make(5, pc)); }
            if (op == 1) {
                if (a >= p.constant_count || b != 0) { return .err(errors::make(5, pc)); }
                if (p.constants[a] < -2147483648 || p.constants[a] > 2147483647) {
                    return .err(errors::make(5, pc));
                }
            } else {
                if (a >= p.registers || !defined[a]) { return .err(errors::make(5, pc)); }
                if (op == 7) {
                    if (b != 0) { return .err(errors::make(5, pc)); }
                } else if (b >= p.registers || !defined[b]) { return .err(errors::make(5, pc)); }
            }
            defined[dst] = true;
            definitions += 1;
        }
        pc += 1;
    }
    if (p.code[(p.count - 1) * 8] != 8 || definitions != p.registers) {
        return .err(errors::make(5, p.count));
    }
    return .ok(p.count);
}
