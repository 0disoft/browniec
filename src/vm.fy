module vm;

import ir as ir;
import errors as errors;
import verifier as verifier;
import types as types;
import tagged as tagged;
import arithmetic as arithmetic;
import bits as bits;
import shifts as shifts;
import array_vm as array_vm;
import array_range_vm as array_ranges;
import struct_vm as struct_vm;
import struct_call_vm as calls;
import array_result_vm as array_results;
import struct_result_vm as record_results;
import std::bytes as bytes;

// Guest calls use bounded VM frames, never native recursion. Register reads are
// verified per function, so reclaimed frame slots need no per-call zero-fill.
pub fn Result<i64, errors::Error> run(ref ir::Program p, usize fuel) {
    return run_with_array_limit(p, fuel, 65536);
}
pub fn Result<i64, errors::Error> run_with_array_limit(ref ir::Program p, usize fuel, usize array_limit) {
    let usize verified = verifier::verify(p)?;
    var usize remaining = fuel;
    var bytes::Buffer payload = bytes::empty();
    let bool aggregates = p.arrays.count != 0 || p.records.count != 0;
    var array_vm::State arrays = array_vm::empty(if (aggregates) { array_limit } else { 0 });
    var struct_vm::State records = struct_vm::empty();
    if (aggregates) {
        if (array_limit > 65536) { return .err(errors::make(13, 0)); }
        let usize preparation = 1 + array_limit;
        if (remaining < preparation) { return .err(errors::make(8, 0)); }
        remaining -= preparation;
        payload = array_vm::prepare(array_limit)?;
    }
    var i64[4096] registers = [0; 4096];
    var usize[32] return_pcs = [0; 32];
    var usize[32] return_dsts = [0; 32];
    var usize frame = 0;
    var usize pc = p.starts[p.entry];
    while (true) {
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op == 50) {
            if(frame==0 || return_dsts[frame]<144 || return_dsts[frame]>=160) {
                return .err(errors::make(5,p.offsets[pc]));
            }
            let usize call=(return_pcs[frame]-1)*8;
            remaining=record_results::step(p,p.code[call+2] as usize,a,
                return_dsts[frame]-144,frame,ref mut records,ref arrays,ref payload,
                remaining,p.offsets[pc])?;
            pc=return_pcs[frame];frame-=1;continue;
        }
        if (op == 47) {
            remaining = struct_vm::subassign(dst,a,b,p.code[at+4] as usize,p.code[at+5] as usize,frame,
                ref p.records,ref mut records,ref mut arrays,ref mut payload,remaining,p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 49) {
            let usize base = frame * 128;
            remaining = struct_vm::subreplace(dst,a,b,p.code[at+4] as usize,frame,
                ref p.records,ref mut records,ref mut arrays,ref mut payload,
                ref registers[base..base+128],remaining,p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 52 || op == 53) {
            let usize base = frame * 128;
            remaining = array_ranges::step(p, pc, frame, ref arrays, ref payload,
                ref mut registers[base..base + 128], remaining)?;
            pc += 1; continue;
        }
        if (op >= 41 && op!=51) {
            let usize base = frame * 128;
            remaining = struct_vm::step(op, dst, a, b, frame, ref p.records, ref mut records,
                ref mut arrays, ref mut payload, ref mut registers[base..base + 128], remaining, p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 9) {
            remaining = calls::step(p,a,b,frame,ref mut records,ref mut arrays,
                ref mut payload,remaining,p.offsets[pc])?;
            let usize child = frame + 1;
            let usize child_base = child * 128;
            var usize i = 0;
            while (i < p.arities[a]) {
                let usize formal = p.register_starts[a] + i;
                if (p.array_parameters[formal] == 0 && p.record_parameters[formal] == 0) {
                    let usize source = p.call_args[b * 8 + i] as usize;
                    registers[child_base + formal] = registers[frame * 128 + source];
                }
                i += 1;
            }
            return_pcs[child] = pc + 1;
            return_dsts[child] = dst;
            frame = child;
            pc = p.starts[a];
            continue;
        }
        let usize cost = if(op==39) {array_results::cost(p,a,p.offsets[pc])?}
            else if (op >= 33) { array_vm::cost(ref p.arrays, op, if (op == 35 || op==51) { a } else { dst }, p.offsets[pc])? }
            else { 1 };
        if (remaining < cost) { return .err(errors::make(8, p.offsets[pc])); }
        remaining -= cost;
        let usize base = frame * 128;
        if(op==39) {
            if(frame==0 || return_dsts[frame]<128) {return .err(errors::make(5,p.offsets[pc]));}
            let usize call=(return_pcs[frame]-1)*8;
            let usize transferred=array_results::leave(p,p.code[call+2] as usize,a,return_dsts[frame]-128,frame,ref mut arrays,ref payload,p.offsets[pc])?;
            pc=return_pcs[frame];frame-=1;continue;
        }
        if (op >= 33) {
            let usize executed = array_vm::execute(op, dst, a, b, frame, ref p.arrays, ref mut arrays,
                ref mut payload, ref mut registers[base..base + 128], p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op==25) {return .err(errors::make(5,p.offsets[pc]));}
        if (op==24) {
            let i64 subject=registers[base+a];
            let u8 variant=p.code[at+3];
            if(tagged::variant(subject)!=variant) {pc=p.code[at+4] as usize;}
            else {
                if(types::payload(p.types[a],variant)!=0) {registers[base+dst]=tagged::unpack(subject,variant);}
                pc+=1;
            }
            continue;
        }
        if (op == 19 || op == 20 || op == 21 || op == 22) {
            if (op == 19 || op == 22) { pc = a; }
            else if ((registers[base + a] == 0) == (op == 20)) { pc = b; }
            else { pc += 1; }
            continue;
        }
        if (op == 18) {
            let i64 stored = registers[base + a];
            registers[base + dst] = stored; pc += 1; continue;
        }
        if (op == 8) {
            let i64 value = registers[base + a];
            if (frame == 0) { return .ok(value); }
            let usize parent_base = (frame - 1) * 128;
            let usize parent_dst = return_dsts[frame];
            registers[parent_base + parent_dst] = value;
            pc = return_pcs[frame];
            frame -= 1;
            continue;
        }
        var i64 value = 0;
        if (op == 1) { value = p.constants[a]; }
        else if (op == 23) {
            let i64 payload=if(types::payload(p.types[dst],p.code[at + 3])==0) {0} else {registers[base+a]};
            value=tagged::pack(payload,p.code[at + 3]);
        }
        else if (op == 17 || op == 26) { value = registers[base + a]; }
        else {
            let i64 left = registers[base + a];
            // Unary negation has no right register; b=0 may belong to another function.
            let i64 right = if (op == 7 || op == 10 || op == 27) { 0 } else { registers[base + b] };
            if (op >= 2 && op <= 7) {
                value=if(types::unsigned(p.types[dst])) {arithmetic::unsigned(op,left,right,p.types[dst],p.offsets[pc])?}
                    else {arithmetic::signed(op,left,right,p.types[dst],p.offsets[pc])?};
            }
            else if (op >= 31) {value=shifts::apply(op,left,right,p.types[dst],p.offsets[pc])?;}
            else if (op >= 27) {value=bits::apply(op,left,right,p.types[dst],p.offsets[pc])?;}
            else if (op == 10) { value = if (left == 0) { 1 } else { 0 }; }
            else if (op == 11) { value = if (left == right) { 1 } else { 0 }; }
            else if (op == 12) { value = if (left != right) { 1 } else { 0 }; }
            else if (types::unsigned(p.types[a])) {value=arithmetic::ordering(op,left,right,p.offsets[pc])?;}
            else if (op == 13) { value = if (left < right) { 1 } else { 0 }; }
            else if (op == 14) { value = if (left <= right) { 1 } else { 0 }; }
            else if (op == 15) { value = if (left > right) { 1 } else { 0 }; }
            else if (op == 16) { value = if (left >= right) { 1 } else { 0 }; }
        }
        registers[base + dst] = value;
        pc += 1;
    }
    return .err(errors::make(5, pc));
}
