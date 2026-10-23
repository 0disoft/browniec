module ir;

import errors as errors;
import std::num as num;

// Private eight-byte instructions: op,dst,a,b,0,0,0,0. Scalar tags: 1 i32, 2 bool.
// Opcodes: 1 constant, 2 add, 3 sub, 4 mul, 5 div, 6 rem, 7 neg, 8 return, 9 call.
// 10 not, 11 eq, 12 ne, 13 lt, 14 le, 15 gt, 16 ge.
pub struct Program {
    u8[2048] code;
    i64[128] constants;
    usize[256] offsets;
    usize count;
    usize registers;
    usize constant_count;
    usize[16] starts;
    usize[16] ends;
    usize[16] register_starts;
    usize[16] register_ends;
    usize[16] arities;
    u8[256] call_args;
    u8[32] call_arities;
    usize function_count;
    usize entry;
    usize call_count;
    u8[128] types;
    u8[16] return_types;
}

pub fn Program empty() {
    return Program { .code = [0; 2048], .constants = [0; 128],
        .offsets = [0; 256], .count = 0, .registers = 0, .constant_count = 0,
        .starts = [0; 16], .ends = [0; 16], .register_starts = [0; 16],
        .register_ends = [0; 16], .arities = [0; 16], .call_args = [0; 256],
        .call_arities = [0; 32], .function_count = 0, .entry = 0, .call_count = 0,
        .types = [0; 128], .return_types = [0; 16] };
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
    if (op != 8) {
        let u8 tag = if (op >= 10 && op <= 16) { 2 } else if (op == 9) { p.return_types[a] } else { 1 };
        p.types[dst] = tag;
        p.registers += 1;
    }
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

pub fn Result<usize, errors::Error> call(ref mut Program p, usize target, ref usize[] arguments, usize offset) {
    if (p.call_count >= 32 || arguments.len > 8) { return .err(errors::make(4, offset)); }
    let usize site = p.call_count;
    var usize i = 0;
    while (i < arguments.len) {
        p.call_args[site * 8 + i] = byte(arguments[i], offset)?;
        i += 1;
    }
    p.call_arities[site] = byte(arguments.len, offset)?;
    p.call_count += 1;
    return emit(p, 9, target, site, offset);
}

pub fn Result<usize, errors::Error> boolean(ref mut Program p, bool value, usize offset) {
    let usize result = literal(p, if (value) { 1 } else { 0 }, offset)?;
    p.types[result] = 2;
    return .ok(result);
}
