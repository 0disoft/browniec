module vm_execution;

import ir as ir;
import errors as errors;
import types as types;
import tagged as tagged;
import arithmetic as arithmetic;
import bits as bits;
import shifts as shifts;
import array_vm as array_vm;
import array_range_vm as array_ranges;
import slice_vm as slices;
import struct_vm as struct_vm;
import call_frame_vm as calls;
import slice_call_vm as borrowed;
import array_result_vm as array_results;
import struct_result_vm as record_results;
import std::bytes as bytes;

import slice_frame_vm as slice_dispatch;
import slice_exclusive_vm as exclusive_dispatch;
import slice_lifecycle_vm as lifecycle;

// Internal execution core: caller supplies an immutable independently inspected
// Program and invocation-owned state. Public VM entry points still use verify.
pub fn Result<i64, errors::Error> execute(ref ir::Program p, usize fuel,
    ref mut array_vm::State arrays, ref mut bytes::Buffer payload, ref mut slices::State loans, ref mut borrowed::Frames borrowed_frames) {
    var usize remaining = fuel;
    var struct_vm::State records = struct_vm::empty();
    var i64[4096] registers = [0; 4096];
    var usize[32] return_pcs = [0; 32];
    var usize[32] return_dsts = [0; 32];
    var usize[32] functions = [0;32];
    functions[0] = p.entry;
    var usize frame = 0;
    var usize pc = p.starts[p.entry];
    while (true) {
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op >= 54 && op <= 60) {
            let usize base = frame * 128;
            let usize site=if(op==55 || op==57 || op==58){a}else{dst};
            remaining = if(ir::exclusive(p,site)) {
                exclusive_dispatch::step(p,functions[frame],pc,frame,loans,arrays,payload,
                    ref mut registers[base..base+128],remaining)?
            } else {
                slice_dispatch::step(p, functions[frame], pc, frame, borrowed_frames, loans, arrays, payload,
                    ref mut registers[base..base + 128], remaining)?
            };
            pc += 1; continue;
        }
        if (op == 50) {
            if(frame==0 || return_dsts[frame]<144 || return_dsts[frame]>=160) {
                return .err(errors::make(5,p.offsets[pc]));
            }
            let usize closed=lifecycle::leave(p,functions[frame],frame,borrowed_frames,loans,arrays,payload,p.offsets[pc])?;
            let usize call=(return_pcs[frame]-1)*8;
            remaining=record_results::step(p,p.code[call+2] as usize,a,
                return_dsts[frame]-144,frame,ref mut records,arrays,payload,
                remaining,p.offsets[pc])?;
            pc=return_pcs[frame];frame-=1;continue;
        }
        if (op == 47) {
            remaining = struct_vm::subassign(dst,a,b,p.code[at+4] as usize,p.code[at+5] as usize,frame,
                ref p.records,ref mut records,arrays,payload,remaining,p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 49) {
            let usize base = frame * 128;
            remaining = struct_vm::subreplace(dst,a,b,p.code[at+4] as usize,frame,
                ref p.records,ref mut records,arrays,payload,
                ref registers[base..base+128],remaining,p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 52 || op == 53) {
            let usize base = frame * 128;
            remaining = array_ranges::step(p, pc, frame, arrays, payload,
                ref mut registers[base..base + 128], remaining)?;
            pc += 1; continue;
        }
        if (op >= 41 && op!=51) {
            let usize base = frame * 128;
            remaining = struct_vm::step(op, dst, a, b, frame, ref p.records, ref mut records,
                arrays, payload, ref mut registers[base..base + 128], remaining, p.offsets[pc])?;
            pc += 1; continue;
        }
        if (op == 9) {
            remaining = calls::step(p,pc,frame,borrowed_frames,loans,ref mut records,arrays,
                payload,ref mut registers,ref mut return_pcs,ref mut return_dsts,remaining)?;
            let usize child = frame + 1;
            functions[child] = a;
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
            let usize closed=lifecycle::leave(p,functions[frame],frame,borrowed_frames,loans,arrays,payload,p.offsets[pc])?;
            let usize call=(return_pcs[frame]-1)*8;
            let usize transferred=array_results::leave(p,p.code[call+2] as usize,a,return_dsts[frame]-128,frame,arrays,payload,p.offsets[pc])?;
            pc=return_pcs[frame];frame-=1;continue;
        }
        if (op >= 33) {
            let usize executed = array_vm::execute(op, dst, a, b, frame, ref p.arrays, arrays,
                payload, ref mut registers[base..base + 128], p.offsets[pc])?;
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
            let usize closed=lifecycle::leave(p,functions[frame],frame,borrowed_frames,loans,arrays,payload,p.offsets[pc])?;
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
