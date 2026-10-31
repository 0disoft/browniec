module slice_frame_vm;
import ir as ir;
import errors as errors;
import cells as cells;
import slice_call_vm as calls;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

// Private instruction adapter for immutable independently inspected Programs.
// Owned roots keep their dispatch. Rootless reads use the same element-width
// price; non-u8 public admission stays gated until source/CLI promotion.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize function,usize pc,usize frame,
    ref calls::Frames frames,ref mut loans::State loan,ref mut arrays::State state,
    ref bytes::Buffer buffer,ref mut i64[] registers,usize fuel) {
    if(pc>=p.count || pc>=256) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc]; let usize at=pc*8; let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize; let usize a=p.code[at+2] as usize;
    let usize b=p.code[at+3] as usize; let usize id=if(op==55 || op==57 || op==58){a}else{dst};
    if(p.function_count>16 || function>=p.function_count || pc<p.starts[function] || pc>=p.ends[function] ||
        frame>=32 || registers.len>128 || id>=16 || op<54 || op>59) { return .err(errors::make(5,offset)); }
    if(p.slice_roots[id]!=0) {
        let owners::Token root=calls::root(p,function,frame,id,frames,state,offset)?;
        return loans::step(p,pc,frame,loan,state,buffer,registers,fuel);
    }
    if(op==54 || (op!=59 && p.code[at+4]!=0) || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        ((op==55 || op==57) && (dst>=registers.len || b!=0)) ||
        (op==58 && (dst>=registers.len || b>=registers.len)) ||
        (op==56 && (a!=0 || b!=0)) ||
        (op==59 && (a>=16 || b>=registers.len || p.code[at+4] as usize>=registers.len ||
            p.slice_roots[a]!=0 || p.slice_origins[a]!=p.slice_origins[id] ||
            p.slice_functions[a]!=p.slice_functions[id] || p.slice_elements[a]!=p.slice_elements[id] ||
            p.slice_origins[id] as usize==id+1))) {
        return .err(errors::make(5,offset));
    }
    let u8 element=p.slice_elements[id];
    let layouts::Array shape=switch(layouts::scalar(element,1)) {
        case .ok(v):{v} case .err(_):{return .err(errors::make(5,offset));}
    };
    if(op==55 && element!=10) { return .err(errors::make(5,offset)); }
    let usize base=if(op==59){65537}else if(op==58){4130+shape.stride}else{4097};
    if(fuel<base) { return .err(errors::make(8,offset)); }
    let owners::Token root=calls::root(p,function,frame,id,frames,state,offset)?;
    // Metadata-only resolution is covered by base. No payload is read here.
    let owners::View view=switch(owners::view(ref state.owners,root,0,0,bytes::len(buffer))) {
        case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
    };
    if(view.element!=element || view.length==0 || view.length>4096) { return .err(errors::make(5,offset)); }
    let usize work=base+if(op==55){4*view.length}else{0};
    if(fuel<work) { return .err(errors::make(8,offset)); }
    let usize slot=frame*16+id;
    if(op==59 && (loan.tickets[slot].slot!=16 || loan.tickets[slot].generation!=0)) { return .err(errors::make(5,offset)); }
    let slices::Ticket source=loan.tickets[if(op==59){frame*16+a}else{slot}];
    if(source.slot>=16 || source.generation==0) { return .err(errors::make(5,offset)); }
    let slices::Slot entry=loan.pool.slots[source.slot];
    if(entry.view.root.slot!=root.slot || entry.view.root.generation!=root.generation ||
        entry.view.element!=element || entry.view.length!=view.length) { return .err(errors::make(5,offset)); }
    let ref u8[] data=bytes::view(buffer);
    if(op==59) {
        let usize start=cells::unpack(registers[b],offset)?;
        let usize end=cells::unpack(registers[p.code[at+4] as usize],offset)?;
        let slices::Ticket child=switch(slices::subslice(ref mut loan.pool,source,ref state.owners,start,end,data.len)) {
            case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
        };
        loan.tickets[slot]=child;
    } else if(op==55) {
        let bool valid=switch(slices::utf8(ref loan.pool,source,ref state.owners,data)) {
            case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
        }; registers[dst]=if(valid){1}else{0};
    } else if(op==57) {
        let usize length=switch(slices::length(ref loan.pool,source,ref state.owners,data.len)) {
            case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
        }; let i64 value=cells::pack(length,offset)?; registers[dst]=value;
    } else if(op==58) {
        let usize index=cells::unpack(registers[b],offset)?;
        let i64 value=switch(slices::read(ref loan.pool,source,ref state.owners,index,data)) {
            case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
        }; registers[dst]=value;
    } else {
        let usize closed=switch(slices::close(ref mut loan.pool,source,ref mut state.owners,data.len)) {
            case .ok(v):{v} case .err(e):{return .err(arrays::failure(e,offset));}
        }; loan.tickets[slot]=slices::Ticket{.slot=16,.generation=0};
    }
    return .ok(fuel-work);
}
