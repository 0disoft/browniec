module ir;

import errors as errors;
import types as types;
import array_meta as arrays;
import struct_meta as records;
import std::num as num;

// Private eight-byte instructions: op,dst,a,b,0,0,0,0. Scalar tags are in types.fy.
// Opcodes: 1 constant, 2 add, 3 sub, 4 mul, 5 div, 6 rem, 7 neg, 8 return, 9 call.
// 10 not, 11 eq, 12 ne, 13 lt, 14 le, 15 gt, 16 ge.
// 17 load, 18 store, 19 jump, 20 jump-if-false, 21 jump-if-true.
// 22 backedge: a strictly earlier instruction in the same function.
// 23 construct scalar Option/Result: dst has wrapper type, b is the variant.
// 24 guarded case: byte 4 is the forward mismatch PC; dst is defined only on match.
// 25 internal match failure: terminal, no operands.
// 26 widen: dst's type is a strict value-preserving widening of a; b is zero.
// 27 complement (b=0), 28 bitwise and, 29 bitwise xor, 30 bitwise or.
// 31 checked left shift, 32 arithmetic signed / logical unsigned right shift.
// 33 array init, 34 independent copy, 35 element read, 36 write, 37 drop.
// 38 overwrite an existing mutable array from an exact-shape live source.
// 39 return the sole remaining callee array owner: dst=0,a=catalog ID,b=0.
// 47 atomic subrecord assignment: dst=target,a=source,b=nominal record,
// byte 4=target scalar-leaf start, byte 5=source scalar-leaf start; bytes 6..7=0.
// 48 atomic root replacement: dst=live target,a=first scalar,b=nominal record.
// 49 atomic subtree replacement: same operands; byte 4=target leaf, 5..7=0.
// 50 return the sole remaining callee record owner: dst=0,a=site,b=0.
// 51 read-only UTF-8 predicate: bool dst, a=live u8 array catalog ID, b=0.
// 52 selected UTF-8 range: same operands; bytes 4..5=start, 6..7=end (little endian).
// 54 slice open: dst=slice ID,a=start usize register,b=end usize register.
// 55 slice UTF-8: bool dst,a=slice ID,b=0. 56 slice close: dst=slice ID,a=b=0.
// 57 slice length: fresh usize dst,a=live slice ID,b=0.
// 58 slice read: fresh element dst,a=live slice ID,b=usize index register.
// 59 subslice: dst=new slice ID,a=live parent ID,b=start usize,byte4=end usize.
// 53 register UTF-8 range: bool dst,a=array,b=start usize register,byte4=end register;5..7=0.
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
    records::Catalog records;
    arrays::Catalog arrays;
    u8[16] array_functions;
    // Static record sites belong to functions; runtime frames remain a separate concern.
    u8[16] record_functions;
    // Parameter register positions: zero scalar, otherwise array catalog ID + 1.
    // Array positions reserve a register index but never contain scalar values.
    u8[128] array_parameters;
    // Zero scalar/array, otherwise immutable record site ID + 1. Type tag is zero.
    u8[128] record_parameters;
    // Zero scalar, otherwise a callee-owned result shape anchor (catalog ID + 1).
    u8[16] array_results;
    // Zero scalar/array, otherwise a callee-owned nominal record anchor (site + 1).
    u8[16] record_results;
    // Zero unused; otherwise slice origin array catalog ID + 1.
    u8[16] slice_roots;
    // Reserved borrowed-parameter metadata. Nonzero entries are not executable yet.
    // Parameter register -> slice site + 1; these positions hold no scalar cell.
    u8[128] slice_parameters;
    // Rootless borrowed site -> formal anchor site + 1 (formal anchors name self).
    u8[16] slice_origins;
    // Rootless borrowed site -> owning function + 1; owned array sites keep zero.
    u8[16] slice_functions;
}

pub fn Program empty() {
    return Program { .code = [0; 2048], .constants = [0; 128],
        .offsets = [0; 256], .count = 0, .registers = 0, .constant_count = 0,
        .starts = [0; 16], .ends = [0; 16], .register_starts = [0; 16],
        .register_ends = [0; 16], .arities = [0; 16], .call_args = [0; 256],
        .call_arities = [0; 32], .function_count = 0, .entry = 0, .call_count = 0,
        .types = [0; 128], .return_types = [0; 16], .slots = [false; 128], .arrays = arrays::empty(), .records = records::empty(),
        .array_functions = [0; 16], .record_functions = [0; 16], .array_parameters = [0; 128], .record_parameters = [0; 128], .array_results = [0; 16], .record_results = [0; 16], .slice_roots = [0; 16],
        .slice_parameters = [0; 128], .slice_origins = [0; 16], .slice_functions = [0; 16] };
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
        let u8 tag = if (op==57) { 12 } else if ((op >= 10 && op <= 16) || op==51 || op==52 || op==53 || op==55) { 2 } else if (op == 9) { p.return_types[a] }
            else if (op == 17 || op>=27 || (op >= 2 && op <= 7)) { p.types[a] } else { 1 };
        p.types[dst] = tag;
        p.registers += 1;
    }
    return .ok(dst);
}

pub fn Result<usize, errors::Error> literal(ref mut Program p, i64 value, usize offset) {
    return integer(p,value,1,offset);
}
pub fn Result<usize, errors::Error> integer(ref mut Program p, i64 value, u8 tag, usize offset) {
    if (!types::fits(tag,value)) { return .err(errors::make(3, offset)); }
    if (p.constant_count >= 128) { return .err(errors::make(4, offset)); }
    let usize index = p.constant_count;
    p.constants[index] = value;
    p.constant_count += 1;
    let usize result=emit(p, 1, index, 0, offset)?;
    p.types[result]=tag;
    return .ok(result);
}

pub fn Result<usize,errors::Error> widen(ref mut Program p,usize source,u8 target,usize offset) {
    if(!types::widening(p.types[source],target)) {return .err(errors::make(3,offset));}
    let usize result=emit(p,26,source,0,offset)?;
    p.types[result]=target;
    return .ok(result);
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

pub fn Result<usize, errors::Error> array(ref mut Program p, u8 element, usize length, bool mutable, usize offset) {
    let usize function = p.entry;
    return array_in(p, function, element, length, mutable, offset);
}
// Function ownership belongs to verified Program metadata, never a runtime token.
pub fn Result<usize, errors::Error> array_in(ref mut Program p, usize function, u8 element, usize length, bool mutable, usize offset) {
    if (function >= 16 || (p.function_count != 0 && function >= p.function_count)) {
        return .err(errors::make(3, offset));
    }
    let usize id = arrays::declare(ref mut p.arrays, element, length, mutable, offset)?;
    p.array_functions[id] = byte(function, offset)?;
    return .ok(id);
}
pub fn Result<usize, errors::Error> array_init(ref mut Program p, usize id, usize fill, usize offset) {
    return raw(p, 33, id, fill, 0, offset);
}
pub fn Result<usize, errors::Error> array_parameter(ref mut Program p, usize function, u8 element, usize length, usize offset) {
    if (p.registers >= 128) { return .err(errors::make(4, offset)); }
    let usize id = array_in(p, function, element, length, false, offset)?;
    let usize register = p.registers;
    p.types[register] = element;
    p.array_parameters[register] = byte(id + 1, offset)?;
    p.registers += 1;
    return .ok(id);
}
pub fn Result<usize, errors::Error> array_copy(ref mut Program p, usize dst, usize source, usize offset) {
    return raw(p, 34, dst, source, 0, offset);
}
pub fn Result<usize, errors::Error> array_assign(ref mut Program p, usize dst, usize source, usize offset) {
    return raw(p, 38, dst, source, 0, offset);
}
pub fn Result<usize,errors::Error> array_fill(ref mut Program p,usize dst,usize value,usize offset) {
    return raw(p,40,dst,value,0,offset);
}
pub fn Result<usize, errors::Error> array_read(ref mut Program p, usize id, usize index, usize offset) {
    if (id >= 16 || id >= p.arrays.count) { return .err(errors::make(3, offset)); }
    let u8 element = p.arrays.elements[id];
    let usize result = emit(p, 35, id, index, offset)?;
    p.types[result] = element;
    return .ok(result);
}
pub fn Result<usize, errors::Error> array_write(ref mut Program p, usize id, usize index, usize value, usize offset) {
    return raw(p, 36, id, index, value, offset);
}
pub fn Result<usize, errors::Error> array_drop(ref mut Program p, usize id, usize offset) {
    return raw(p, 37, id, 0, 0, offset);
}
pub fn Result<usize,errors::Error> array_utf8(ref mut Program p,usize id,usize offset){
    if(id>=16 || id>=p.arrays.count || p.arrays.elements[id]!=10){return .err(errors::make(3,offset));}
    return emit(p,51,id,0,offset);
}
pub fn Result<usize, errors::Error> array_range_utf8(ref mut Program p, usize id, usize start, usize end, usize offset) {
    if (id >= 16 || id >= p.arrays.count || p.arrays.elements[id] != 10 ||
        start > end || end > p.arrays.lengths[id] || end > 4096) { return .err(errors::make(3, offset)); }
    let usize pc = p.count;
    let usize result = emit(p, 52, id, 0, offset)?;
    p.code[pc * 8 + 4] = byte(start % 256, offset)?;
    p.code[pc * 8 + 5] = byte(start / 256, offset)?;
    p.code[pc * 8 + 6] = byte(end % 256, offset)?;
    p.code[pc * 8 + 7] = byte(end / 256, offset)?;
    return .ok(result);
}
pub fn Result<usize, errors::Error> array_dynamic_utf8(ref mut Program p, usize id, usize start, usize end, usize offset) {
    if (id >= 16 || id >= p.arrays.count || p.arrays.elements[id] != 10 ||
        start >= p.registers || start >= 128 || end >= p.registers || end >= 128 ||
        p.types[start] != 12 || p.types[end] != 12 || p.slots[start] || p.slots[end] ||
        p.array_parameters[start] != 0 || p.record_parameters[start] != 0 ||
        p.array_parameters[end] != 0 || p.record_parameters[end] != 0) { return .err(errors::make(3, offset)); }
    let usize pc = p.count;
    let usize result = emit(p, 53, id, start, offset)?;
    p.code[pc * 8 + 4] = byte(end, offset)?;
    return .ok(result);
}
pub fn Result<usize,errors::Error> array_call(ref mut Program p,usize target,usize destination,ref usize[] arguments,usize offset) {
    if(p.call_count>=32 || arguments.len>8 || destination>=16) {return .err(errors::make(4,offset));}
    let usize site=p.call_count;
    var usize i=0;
    while(i<arguments.len) {p.call_args[site*8+i]=byte(arguments[i],offset)?;i+=1;}
    p.call_arities[site]=byte(arguments.len,offset)?;p.call_count+=1;
    return raw(p,9,128+destination,target,site,offset);
}
pub fn Result<usize,errors::Error> array_return(ref mut Program p,usize source,usize offset) {
    return raw(p,39,0,source,0,offset);
}

// Private struct opcodes 41..46. Initializers consume consecutive scalar values.
pub fn Result<usize, errors::Error> record(ref mut Program p, usize record, bool mutable, usize offset) {
    let usize function = p.entry;
    return record_in(p,function,record,mutable,offset);
}
pub fn Result<usize, errors::Error> record_in(ref mut Program p, usize function,
    usize record, bool mutable, usize offset) {
    if (function >= 16 || (p.function_count != 0 && function >= p.function_count)) {
        return .err(errors::make(3,offset));
    }
    if (p.records.count >= 16) { return .err(errors::make(4, offset)); }
    if (record >= p.records.layouts.count || record >= 32) { return .err(errors::make(3, offset)); }
    let usize id = p.records.count;
    p.record_functions[id] = byte(function,offset)?;
    p.records.records[id] = byte(record, offset)?; p.records.mutable[id] = mutable;
    p.records.count += 1; return .ok(id);
}
pub fn Result<usize, errors::Error> record_init(ref mut Program p, usize id, usize first, usize offset) {
    return raw(p, 41, id, first, 0, offset);
}
pub fn Result<usize, errors::Error> record_parameter(ref mut Program p, usize function, usize record, usize offset) {
    if (p.registers >= 128) { return .err(errors::make(4, offset)); }
    let usize id = record_in(p, function, record, false, offset)?;
    let usize register = p.registers;
    p.types[register] = 0;
    p.record_parameters[register] = byte(id + 1, offset)?;
    p.registers += 1;
    return .ok(id);
}
pub fn Result<usize, errors::Error> record_copy(ref mut Program p, usize dst, usize source, usize offset) {
    return raw(p, 42, dst, source, 0, offset);
}
pub fn Result<usize, errors::Error> record_read(ref mut Program p, usize id, usize leaf, usize offset) {
    let records::Prepared shapes = records::prepare(ref p.records)?;
    if (id >= p.records.count || leaf >= shapes.leaves[id]) { return .err(errors::make(3, offset)); }
    let usize result = emit(p, 43, id, leaf, offset)?;
    p.types[result] = shapes.tags[id * 128 + leaf]; return .ok(result);
}
pub fn Result<usize, errors::Error> record_write(ref mut Program p, usize id, usize leaf, usize value, usize offset) {
    return raw(p, 44, id, leaf, value, offset);
}
pub fn Result<usize, errors::Error> record_drop(ref mut Program p, usize id, usize offset) {
    return raw(p, 45, id, 0, 0, offset);
}
pub fn Result<usize, errors::Error> record_assign(ref mut Program p, usize dst, usize source, usize offset) {
    return raw(p, 46, dst, source, 0, offset);
}
pub fn Result<usize, errors::Error> record_subassign(ref mut Program p, usize dst,
    usize source, usize nominal, usize target_leaf, usize source_leaf, usize offset) {
    let u8 target = byte(target_leaf,offset)?; let u8 origin = byte(source_leaf,offset)?;
    let usize pc = raw(p,47,dst,source,nominal,offset)?;
    p.code[pc*8+4] = target; p.code[pc*8+5] = origin; return .ok(pc);
}
pub fn Result<usize, errors::Error> record_replace(ref mut Program p, usize dst,
    usize first, usize nominal, usize offset) {
    return raw(p,48,dst,first,nominal,offset);
}

pub fn Result<usize, errors::Error> record_subreplace(ref mut Program p, usize dst,
    usize first, usize nominal, usize target_leaf, usize offset) {
    let u8 target = byte(target_leaf,offset)?;
    let usize pc = raw(p,49,dst,first,nominal,offset)?;
    p.code[pc*8+4] = target; return .ok(pc);
}

// Record results use CALL's existing argument table and a non-scalar destination.
pub fn Result<usize,errors::Error> record_call(ref mut Program p,usize target,usize destination,ref usize[] arguments,usize offset) {
    if(p.count>=256 || p.call_count>=32 || arguments.len>8 || target>=16 || destination>=16) {return .err(errors::make(4,offset));}
    var usize i=0;
    while(i<arguments.len){if(arguments[i]>255){return .err(errors::make(4,offset));}i+=1;}
    let usize site=p.call_count;i=0;
    while(i<arguments.len){p.call_args[site*8+i]=byte(arguments[i],offset)?;i+=1;}
    p.call_arities[site]=byte(arguments.len,offset)?;p.call_count+=1;
    return raw(p,9,144+destination,target,site,offset);
}
pub fn Result<usize,errors::Error> record_return(ref mut Program p,usize source,usize offset) {
    return raw(p,50,0,source,0,offset);
}

// Find a free site across both owned and prospective borrowed declarations.
// The caller publishes metadata only after all remaining checks succeed.
pub fn Result<usize, errors::Error> slice_site(ref Program p, usize offset) {
    var usize id = 0;
    while (id < 16) {
        if (p.slice_roots[id] == 0 && p.slice_origins[id] == 0 && p.slice_functions[id] == 0) { return .ok(id); }
        id += 1;
    }
    return .err(errors::make(4, offset));
}
// Declare a static slice site; the root determines function and scalar shape.
pub fn Result<usize, errors::Error> slice(ref mut Program p, usize root, usize offset) {
    if (root >= 16 || root >= p.arrays.count) { return .err(errors::make(3, offset)); }
    let usize id = slice_site(p, offset)?;
    p.slice_roots[id] = byte(root + 1, offset)?;
    return .ok(id);
}
pub fn Result<usize, errors::Error> slice_open(ref mut Program p, usize id, usize start, usize end, usize offset) {
    if (id >= 16 || p.slice_roots[id] == 0 || p.slice_roots[id] > 16 || p.slice_roots[id] as usize > p.arrays.count ||
        start >= p.registers || end >= p.registers || start >= 128 || end >= 128 ||
        p.types[start] != 12 || p.types[end] != 12 || p.slots[start] || p.slots[end] ||
        p.array_parameters[start] != 0 || p.record_parameters[start] != 0 ||
        p.array_parameters[end] != 0 || p.record_parameters[end] != 0) { return .err(errors::make(3, offset)); }
    return raw(p, 54, id, start, end, offset);
}
pub fn Result<usize, errors::Error> slice_utf8(ref mut Program p, usize id, usize offset) {
    if (id >= 16 || p.slice_roots[id] == 0 || p.slice_roots[id] > 16 || p.slice_roots[id] as usize > p.arrays.count ||
        p.arrays.elements[(p.slice_roots[id] as usize) - 1] != 10) { return .err(errors::make(3, offset)); }
    return emit(p, 55, id, 0, offset);
}
pub fn Result<usize, errors::Error> slice_close(ref mut Program p, usize id, usize offset) {
    if (id >= 16 || p.slice_roots[id] == 0) { return .err(errors::make(3, offset)); }
    return raw(p, 56, id, 0, 0, offset);
}

pub fn Result<usize, errors::Error> slice_length(ref mut Program p, usize id, usize offset) {
    if (id >= 16 || p.slice_roots[id] == 0 || p.slice_roots[id] > 16 ||
        p.slice_roots[id] as usize > p.arrays.count) { return .err(errors::make(3, offset)); }
    return emit(p, 57, id, 0, offset);
}

pub fn Result<usize, errors::Error> slice_read(ref mut Program p, usize id, usize index, usize offset) {
    if (id >= 16 || p.slice_roots[id] == 0 || p.slice_roots[id] > 16 ||
        p.slice_roots[id] as usize > p.arrays.count || index >= 128 || index >= p.registers ||
        p.types[index] != 12 || p.slots[index] || p.array_parameters[index] != 0 ||
        p.record_parameters[index] != 0) { return .err(errors::make(3, offset)); }
    let u8 element = p.arrays.elements[(p.slice_roots[id] as usize) - 1];
    let usize dst = emit(p, 58, id, index, offset)?;
    p.types[dst] = element;
    return .ok(dst);
}

pub fn Result<usize, errors::Error> slice_sub(ref mut Program p, usize id, usize parent, usize start, usize end, usize offset) {
    if (id >= 16 || parent >= 16 || id == parent || p.slice_roots[id] == 0 ||
        p.slice_roots[id] > 16 || p.slice_roots[id] as usize > p.arrays.count ||
        p.slice_roots[id] != p.slice_roots[parent] || start >= 128 || end >= 128 ||
        start >= p.registers || end >= p.registers || p.types[start] != 12 || p.types[end] != 12 ||
        p.slots[start] || p.slots[end] || p.array_parameters[start] != 0 || p.array_parameters[end] != 0 ||
        p.record_parameters[start] != 0 || p.record_parameters[end] != 0) { return .err(errors::make(3, offset)); }
    let usize pc = raw(p, 59, id, parent, start, offset)?;
    p.code[pc * 8 + 4] = byte(end, offset)?;
    return .ok(pc);
}
