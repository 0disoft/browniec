module ir;

import errors as errors;
import types as types;
import std::num as num;

// Private eight-byte instructions: op,dst,a,b,0,0,0,0. Scalar tags: 1 i32, 2 bool.
// Opcodes: 1 constant, 2 add, 3 sub, 4 mul, 5 div, 6 rem, 7 neg, 8 return, 9 call.
// 10 not, 11 eq, 12 ne, 13 lt, 14 le, 15 gt, 16 ge.
// 17 load, 18 store, 19 jump, 20 jump-if-false, 21 jump-if-true.
// 22 backedge: a strictly earlier instruction in the same function.
// 23 construct scalar Option/Result: dst has wrapper type, b is the variant.
// 24 guarded case: byte 4 is the forward mismatch PC; dst is defined only on match.
// 25 internal match failure: terminal, no operands.
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
    bool[128] slots;
}

pub fn Program empty() {
    return Program { .code = [0; 2048], .constants = [0; 128],
        .offsets = [0; 256], .count = 0, .registers = 0, .constant_count = 0,
        .starts = [0; 16], .ends = [0; 16], .register_starts = [0; 16],
        .register_ends = [0; 16], .arities = [0; 16], .call_args = [0; 256],
        .call_arities = [0; 32], .function_count = 0, .entry = 0, .call_count = 0,
        .types = [0; 128], .return_types = [0; 16], .slots = [false; 128] };
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
        let u8 tag = if (op >= 10 && op <= 16) { 2 } else if (op == 9) { p.return_types[a] }
            else if (op == 17) { p.types[a] } else { 1 };
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

pub fn Result<usize, errors::Error> construct(ref mut Program p,u8 tag,u8 variant,usize payload,usize offset) {
    let usize result=emit(p,23,payload,variant as usize,offset)?;
    p.types[result]=tag;
    return .ok(result);
}

pub struct Case {usize instruction; usize payload;}
pub fn Result<Case,errors::Error> branch_case(ref mut Program p,usize subject,u8 variant,usize offset) {
    let usize pc=p.count;
    let u8 tag=types::payload(p.types[subject],variant);
    var usize result=0;
    if(tag==0) {let usize branch=raw(p,24,0,subject,variant as usize,offset)?;}
    else {result=emit(p,24,subject,variant as usize,offset)?;p.types[result]=tag;}
    return .ok(Case {.instruction=pc,.payload=result});
}

// Mutable slots share the bounded register cells, but are never value operands.
pub fn Result<usize, errors::Error> slot(ref mut Program p, u8 tag, usize offset) {
    if (p.registers >= 128) { return .err(errors::make(4, offset)); }
    let usize index = p.registers;
    p.types[index] = tag;
    p.slots[index] = true;
    p.registers += 1;
    return .ok(index);
}
pub fn Result<usize, errors::Error> raw(ref mut Program p, u8 op, usize dst, usize a, usize b, usize offset) {
    if (p.count >= 256) { return .err(errors::make(4, offset)); }
    let usize index = p.count;
    let usize at = index * 8;
    p.code[at] = op;
    p.code[at + 1] = byte(dst, offset)?;
    p.code[at + 2] = byte(a, offset)?;
    p.code[at + 3] = byte(b, offset)?;
    p.offsets[index] = offset;
    p.count += 1;
    return .ok(index);
}
pub fn Result<usize, errors::Error> patch(ref mut Program p, usize jump, usize target, usize offset) {
    let u8 op = p.code[jump * 8];
    let usize field = if (op == 24) {4} else if (op == 19 || op == 22) { 2 } else { 3 };
    p.code[jump * 8 + field] = byte(target, offset)?;
    return .ok(target);
}
