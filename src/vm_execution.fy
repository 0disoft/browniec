module vm_execution;

import ir as ir;
import errors as errors;
import types as types;
import tagged as tagged;
import arithmetic as arithmetic;
import bits as bits;
import shifts as shifts;
import array_vm as array_vm;
import array_list_vm as lists;
import slice_place_vm as places;
import record_place_vm as record_places;
import array_owners as owners;
import place_vm as place_frames;
import array_range_vm as array_ranges;
import slice_vm as slices;
import struct_vm as struct_vm;
import call_frame_vm as calls;
import slice_call_vm as borrowed;
import array_result_vm as array_results;
import struct_result_vm as record_results;
import std::bytes as bytes;
import std::vec as vec;

import slice_frame_vm as slice_dispatch;
import slice_exclusive_vm as exclusive_dispatch;
import slice_lifecycle_vm as lifecycle;
import slice_mutable_call_vm as mutable;
import slice_mutable_frame_vm as mutable_dispatch;
import slice_reborrow_ir as reborrows;
import slice_authority as canonical;
import slice_reborrow_vm as child_sites;
import slice_authority_call_vm as canonical_calls;
import slice_formal_reborrow_vm as canonical_dispatch;

// Existing public/readonly execution passes an empty view, avoiding the full
// 32-frame receipt array. One inert native receipt supplies that empty view.
pub fn Result<i64, errors::Error> execute(ref ir::Program p,usize fuel,
    ref mut array_vm::State arrays,ref mut bytes::Buffer payload,ref mut slices::State loans,ref mut borrowed::Frames borrowed_frames){
    var mutable::Frame[1] receipts=[mutable::empty();1];
    var canonical::State[1] authority=[canonical::empty();1];
    var canonical_calls::Bindings[1] call_sites=[canonical_calls::empty();1];
    var child_sites::Bindings[1] child_bindings=[child_sites::empty();1];
    let reborrows::Sites sites=reborrows::Sites{.parents=[16;16],.newer=[0;16],.count=0};
    return core(p,fuel,arrays,payload,loans,borrowed_frames,ref mut receipts[..0],ref mut authority[..0],ref mut call_sites[..0],ref mut child_bindings[..0],ref sites);
}
// Private integration entry: caller owns 32 initialized, unique frame receipts,
// has independently inspected the immutable Program, and calls mutable::finish
// on every outcome before disposing the invocation state.
pub fn Result<i64, errors::Error> execute_mutable(ref ir::Program p,usize fuel,
    ref mut array_vm::State arrays,ref mut bytes::Buffer payload,ref mut slices::State loans,ref mut borrowed::Frames borrowed_frames,
    ref mut mutable::Frame[] receipts){
    if(receipts.len!=32){return .err(errors::make(5,0));}
    var usize i=0;while(i<32){if(receipts[i].active){return .err(errors::make(5,0));}i+=1;}
    var canonical::State[1] authority=[canonical::empty();1];
    var canonical_calls::Bindings[1] call_sites=[canonical_calls::empty();1];
    var child_sites::Bindings[1] child_bindings=[child_sites::empty();1];
    let reborrows::Sites sites=reborrows::Sites{.parents=[16;16],.newer=[0;16],.count=0};
    return core(p,fuel,arrays,payload,loans,borrowed_frames,receipts,ref mut authority[..0],ref mut call_sites[..0],ref mut child_bindings[..0],ref sites);
}
// Native-only raw entry. Caller independently inspects immutable IR/Sites,
// admits the canonical CALL subset and fresh unique context, then finishes every
// outcome. vm_reborrow_execution supplies that admission and mandatory finish.
pub fn Result<i64,errors::Error> execute_canonical(ref ir::Program p,ref reborrows::Sites sites,usize fuel,
    ref mut array_vm::State arrays,ref mut bytes::Buffer payload,ref mut slices::State loans,ref mut borrowed::Frames frames,
    ref mut canonical::State[] authority,ref mut canonical_calls::Bindings[] call_sites,ref mut child_sites::Bindings[] child_bindings){
    if(authority.len!=1 || call_sites.len!=1 || child_bindings.len!=1){return .err(errors::make(5,0));}
    var mutable::Frame[1] unused=[mutable::empty();1];
    return core(p,fuel,arrays,payload,loans,frames,ref mut unused[..0],authority,call_sites,child_bindings,sites);
}
fn bool mutable_function(ref ir::Program p,usize function){
    var usize i=0;while(i<p.arities[function]){let usize site=p.slice_parameters[p.register_starts[function]+i] as usize;
        if(site!=0 && ir::exclusive(p,site-1)){return true;}i+=1;}return false;
}
fn Result<usize,errors::Error> leave(ref ir::Program p,usize function,usize frame,
    ref mut array_vm::State arrays,ref bytes::Buffer payload,ref mut slices::State loans,ref mut borrowed::Frames frames,
    ref mut mutable::Frame[] receipts,ref mut canonical::State[] authority,ref mut canonical_calls::Bindings[] call_sites,ref mut child_sites::Bindings[] child_bindings,ref struct_vm::State records,usize offset){
    if(authority.len==1 && frame>0){return canonical_calls::leave(p,function,frame,ref mut call_sites[0],ref mut authority[0],frames,loans,arrays,records,payload,offset);}
    if(frame>0 && receipts.len==32 && receipts[frame].active){return mutable::leave(p,function,frame,ref mut receipts[frame],frames,loans,arrays,payload,offset);}
    return lifecycle::leave(p,function,frame,frames,loans,arrays,payload,offset);
}

// Internal execution core: caller supplies an immutable independently inspected
// Program and invocation-owned state. Public VM entry points still use verify.
fn Result<i64, errors::Error> core(ref ir::Program p, usize fuel,
    ref mut array_vm::State arrays, ref mut bytes::Buffer payload, ref mut slices::State loans, ref mut borrowed::Frames borrowed_frames, ref mut mutable::Frame[] receipts, ref mut canonical::State[] authority,ref mut canonical_calls::Bindings[] call_sites,ref mut child_sites::Bindings[] child_bindings, ref reborrows::Sites sites) {
    if(authority.len>1 || call_sites.len!=authority.len || child_bindings.len!=authority.len){return .err(errors::make(5,0));}
    if(authority.len==0 && reborrows::present(p)) { return .err(errors::make(5,0)); }
    let lists::Requirement list_plan=lists::requirement(p)?;
    let record_places::Requirement place_plan=record_places::requirement(p)?;
    if(fuel<list_plan.cost+place_plan.cost){return .err(errors::make(8,0));}
    var vec::Vec<i64> list_cells=lists::prepare_values(ref list_plan)?;
    var bytes::Buffer list_scratch=lists::prepare_encoded(ref list_plan)?;
    var vec::Vec<usize> place_state=record_places::prepare(ref place_plan)?;
    var usize remaining = fuel-list_plan.cost-place_plan.cost;
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
        if(op>=83 && op<=86){let usize base=frame*128;
            if(place_plan.records && (p.code[at+4]==2 || op==86)){
                let usize price=record_places::price(p,pc,functions[frame],ref place_state)?;
                if(remaining<price){return .err(errors::make(8,p.offsets[pc]));}
                let owners::Token current=if(op==83){records.tokens[frame*16+a]}else{owners::Token{.slot=0,.generation=0}};
                remaining=record_places::bound(p,pc,functions[frame],frame,ref mut place_state,ref arrays.owners,current,
                    bytes::view_mut(payload),ref mut registers[base..base+128],remaining)?;
            }else{remaining=places::bound(p,pc,functions[frame],frame,ref mut place_state,ref arrays.owners,ref arrays.tokens,
                ref loans.pool,ref loans.tickets,bytes::view_mut(payload),ref mut registers[base..base+128],remaining)?;
            }
            pc+=1;continue;
        }
        if(op==8 || op==39 || op==50 || op==82){let usize ended=place_frames::empty_frame(ref place_state,frame,p.offsets[pc])?;}
        if(op==82){
            if(remaining==0){return .err(errors::make(8,p.offsets[pc]));}remaining-=1;
            if(frame==0 || p.return_types[functions[frame]]!=13){return .err(errors::make(5,p.offsets[pc]));}
            let usize closed=leave(p,functions[frame],frame,arrays,payload,loans,borrowed_frames,receipts,authority,call_sites,child_bindings,ref records,p.offsets[pc])?;
            pc=return_pcs[frame];frame-=1;continue;
        }
        if(op==80 || op==81){let usize base=frame*128;
            remaining=lists::step(p,pc,frame,arrays,bytes::view_mut(payload),ref registers[base..base+128],ref mut list_cells,ref mut list_scratch,remaining)?;
            pc+=1;continue;
        }
        if(op==61 || op==62){
            if(authority.len!=1 || call_sites.len!=1 || child_bindings.len!=1){return .err(errors::make(5,p.offsets[pc]));}
            let usize base=frame*128;
            remaining=canonical_dispatch::step(p,sites,functions[frame],pc,frame,ref mut child_bindings[0],ref call_sites[0],
                ref mut authority[0],borrowed_frames,loans,arrays,payload,ref registers[base..base+128],remaining)?;
            pc+=1;continue;
        }
        if (op >= 54 && op <= 60) {
            let usize base = frame * 128;
            let usize site=if(op==55 || op==57 || op==58){a}else{dst};
            remaining = if(authority.len==1 && ir::exclusive(p,site) && (op==55 || op==57 || op==58 || op==60)){
                canonical_dispatch::access(p,sites,functions[frame],pc,frame,ref child_bindings[0],ref call_sites[0],
                    ref authority[0],borrowed_frames,loans,arrays,payload,ref mut registers[base..base+128],remaining)?
            }else if(authority.len==1 && ir::exclusive(p,site) && p.slice_roots[site]==0 && op==56){
                canonical_calls::release(p,functions[frame],frame,site,ref mut call_sites[0],ref authority[0],
                    borrowed_frames,loans,arrays,payload,remaining,p.offsets[pc])?
            }else if(ir::exclusive(p,site) && p.slice_roots[site]==0) {
                if(receipts.len!=32 || frame==0){return .err(errors::make(5,p.offsets[pc]));}
                mutable_dispatch::step(p,functions[frame],pc,frame,ref mut receipts[frame],borrowed_frames,loans,arrays,payload,
                    ref mut registers[base..base+128],remaining)?
            } else if(ir::exclusive(p,site)) {
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
            if(authority.len==1){
                remaining=canonical_calls::return_record(p,functions[frame],frame,a,return_dsts[frame]-144,
                    ref mut call_sites[0],ref mut authority[0],borrowed_frames,loans,arrays,ref mut records,payload,remaining,p.offsets[pc])?;
            }else{
            let usize closed=leave(p,functions[frame],frame,arrays,payload,loans,borrowed_frames,receipts,authority,call_sites,child_bindings,ref records,p.offsets[pc])?;
            let usize call=(return_pcs[frame]-1)*8;
            remaining=record_results::step(p,p.code[call+2] as usize,a,
                return_dsts[frame]-144,frame,ref mut records,arrays,payload,
                remaining,p.offsets[pc])?;
            }
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
            if(frame<31){let usize fresh=place_frames::empty_frame(ref place_state,frame+1,p.offsets[pc])?;}
            if(authority.len==1){
                remaining=calls::step_canonical_derived(p,sites,pc,frame,ref child_bindings[0],ref mut call_sites[0],ref mut authority[0],borrowed_frames,loans,ref mut records,arrays,payload,
                    ref mut registers,ref mut return_pcs,ref mut return_dsts,remaining)?;
            }else if(mutable_function(p,a)){
                if(receipts.len!=32){return .err(errors::make(5,p.offsets[pc]));}
                remaining=calls::step_mutable(p,pc,frame,ref mut receipts[if(frame<31){frame+1}else{31}],borrowed_frames,loans,ref mut records,arrays,
                    payload,ref mut registers,ref mut return_pcs,ref mut return_dsts,remaining)?;
            }else{
                remaining = calls::step(p,pc,frame,borrowed_frames,loans,ref mut records,arrays,
                    payload,ref mut registers,ref mut return_pcs,ref mut return_dsts,remaining)?;
            }
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
            if(authority.len==1){
                let usize transferred=canonical_calls::return_array(p,functions[frame],frame,a,return_dsts[frame]-128,
                    ref mut call_sites[0],ref mut authority[0],borrowed_frames,loans,arrays,ref records,payload,p.offsets[pc])?;
            }else{
            let usize closed=leave(p,functions[frame],frame,arrays,payload,loans,borrowed_frames,receipts,authority,call_sites,child_bindings,ref records,p.offsets[pc])?;
            let usize call=(return_pcs[frame]-1)*8;
            let usize transferred=array_results::leave(p,p.code[call+2] as usize,a,return_dsts[frame]-128,frame,arrays,payload,p.offsets[pc])?;
            }
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
            let usize closed=leave(p,functions[frame],frame,arrays,payload,loans,borrowed_frames,receipts,authority,call_sites,child_bindings,ref records,p.offsets[pc])?;
            if (frame == 0) { return .ok(value); }
            let usize parent_base = (frame - 1) * 128;
            let usize parent_dst = return_dsts[frame];
            registers[parent_base + parent_dst] = value;
            pc = return_pcs[frame];
            frame -= 1;
            continue;
        }
        let i64 value=scalar(p,pc,ref registers[base..base+128])?;
        registers[base + dst] = value;
        pc += 1;
    }
    return .err(errors::make(5, pc));
}

// Shared scalar value semantics for independently inspected immutable IR. The
// caller handles branches, STORE, CALL and RETURN, and charges instruction Fuel.
pub fn Result<i64,errors::Error> scalar(ref ir::Program p,usize pc,ref i64[] registers){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    var i64 value = 0;
    if (op == 1) { value = p.constants[a]; }
    else if (op == 23) {
        let i64 payload=if(types::payload(p.types[dst],p.code[at + 3])==0) {0} else {registers[a]};
        value=tagged::pack(payload,p.code[at + 3]);
    }
    else if (op == 17 || op == 26) { value = registers[a]; }
    else {
        let i64 left = registers[a];
        // Unary negation has no right register; b=0 may belong to another function.
        let i64 right = if (op == 7 || op == 10 || op == 27) { 0 } else { registers[b] };
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
    return .ok(value);
}
