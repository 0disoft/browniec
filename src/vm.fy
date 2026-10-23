module vm;

import ir as ir;
import errors as errors;
import verifier as verifier;

// A fresh register array is the one-shot Instance for this straight-line subset.
pub fn Result<i64, errors::Error> run(ref ir::Program p, usize fuel) {
    let usize verified = verifier::verify(p)?;
    var i64[128] registers = [0; 128];
    var usize remaining = fuel;
    var usize pc = 0;
    while (pc < p.count) {
        if (remaining == 0) { return .err(errors::make(8, p.offsets[pc])); }
        remaining -= 1;
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op == 8) { return .ok(registers[a]); }
        var i64 value = 0;
        if (op == 1) { value = p.constants[a]; }
        else {
            let i64 left = registers[a];
            let i64 right = registers[b];
            // i32 operands widen to i64; every intermediate below fits i64.
            if (op == 2) { value = left + right; }
            else if (op == 3) { value = left - right; }
            else if (op == 4) { value = left * right; }
            else if (op == 7) { value = -left; }
            else {
                if (right == 0) { return .err(errors::make(7, p.offsets[pc])); }
                if (left == -2147483648 && right == -1) { return .err(errors::make(6, p.offsets[pc])); }
                value = if (op == 5) { left / right } else { left % right };
            }
        }
        if (value < -2147483648 || value > 2147483647) { return .err(errors::make(6, p.offsets[pc])); }
        registers[dst] = value;
        pc += 1;
    }
    return .err(errors::make(5, pc));
}
