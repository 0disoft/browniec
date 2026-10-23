module ir;

import errors as errors;
import std::num as num;

// Private eight-byte instructions: op,dst,a,b,0,0,0,0. All values are i32.
// Opcodes: 1 constant, 2 add, 3 sub, 4 mul, 5 div, 6 rem, 7 neg, 8 return.
pub struct Program {
    u8[2048] code;
    i64[128] constants;
    usize[256] offsets;
    usize count;
    usize registers;
    usize constant_count;
}

pub fn Program empty() {
    return Program { .code = [0; 2048], .constants = [0; 128],
        .offsets = [0; 256], .count = 0, .registers = 0, .constant_count = 0 };
}

fn Result<u8, errors::Error> byte(usize value, usize offset) {
    let i64 wide = switch (num::i64_from_usize(value)) {
        case .ok(n): { n } case .err(_): { return .err(errors::make(4, offset)); }
    };
    return switch (num::u8_from_i64(wide)) {
        case .ok(n): { .ok(n) } case .err(_): { .err(errors::make(4, offset)) }
    };
}

pub fn Result<usize, errors::Error> emit(ref mut Program p, u8 op, usize a, usize b, usize offset) {
    if (p.count >= 256 || (op != 8 && p.registers >= 128)) { return .err(errors::make(4, offset)); }
    let usize dst = if (op == 8) { 0 } else { p.registers };
    let usize at = p.count * 8;
    p.code[at] = op;
    p.code[at + 1] = byte(dst, offset)?;
    p.code[at + 2] = byte(a, offset)?;
    p.code[at + 3] = byte(b, offset)?;
    let usize index = p.count;
    p.offsets[index] = offset;
    p.count += 1;
    if (op != 8) { p.registers += 1; }
    return .ok(dst);
}

pub fn Result<usize, errors::Error> literal(ref mut Program p, i64 value, usize offset) {
    if (value < -2147483648 || value > 2147483647) { return .err(errors::make(3, offset)); }
    if (p.constant_count >= 128) { return .err(errors::make(4, offset)); }
    let usize index = p.constant_count;
    p.constants[index] = value;
    p.constant_count += 1;
    return emit(p, 1, index, 0, offset);
}
