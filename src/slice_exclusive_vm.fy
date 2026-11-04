module slice_exclusive_vm;
import ir as ir;
import errors as errors;
import fuel as meter;
import cells as cells;
import array_layout as layouts;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import slice_vm as loans;
import std::bytes as bytes;

// Private adapter: an immutable independently inspected Program is required.
// Public VM admission runs the same complete proof before allocation/execution.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize function,usize pc,usize frame,
    ref mut loans::State loan,ref mut arrays::State state,ref mut bytes::Buffer buffer,
    ref mut i64[] registers,usize fuel) {
    if(pc>=p.count || pc>=256) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc];let usize at=pc*8;let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize id=if(op==55 || op==57 || op==58){a}else{dst};
    if(p.function_count>16 || function>=p.function_count || pc<p.starts[function] || pc>=p.ends[function] ||
        frame>=32 || registers.len>128 || id>=16 || !ir::exclusive(p,id) || op<54 || op>60 || op==59 ||
        p.slice_origins[id]!=0 || p.slice_functions[id]!=0 || p.slice_roots[id]==0 ||
        p.code[at+4]!=0 || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0) {
        return .err(errors::make(5,offset));
    }
    let usize root=(p.slice_roots[id] as usize)-1;
    if(root>=16 || root>=p.arrays.count || p.array_functions[root] as usize!=function || !p.arrays.mutable[root] ||
        ((op==54 || op==60) && (a>=registers.len || b>=registers.len)) ||
        ((op==55 || op==57) && (dst>=registers.len || b!=0)) ||
        (op==58 && (dst>=registers.len || b>=registers.len)) ||
        (op==56 && (a!=0 || b!=0))) { return .err(errors::make(5,offset)); }
    let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[root],p.arrays.lengths[root])) {
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
    };
    if(op==55 && shape.element!=10) { return .err(errors::make(5,offset)); }
    // Bounded metadata and abort cleanup use the existing slice reserves.
    // Stores additionally cover scalar validation/encoding, as ordinary stores do.
    let usize cost=meter::slice_base(op,shape.stride)+if(op==55){meter::utf8_scan(shape.length)}else{0};
    if(fuel<cost) { return .err(errors::make(8,offset)); }
    let usize slot=frame*16+id;let usize capacity=bytes::len(buffer);
    let owners::Token token=state.tokens[frame*16+root];
    if(op==54) {
        if(loan.tickets[slot].slot!=16 || loan.tickets[slot].generation!=0) { return .err(errors::make(5,offset)); }
        let usize start=cells::unpack(registers[a],offset)?;let usize end=cells::unpack(registers[b],offset)?;
        let owners::View view=switch(owners::view(ref state.owners,token,start,end,capacity)) {
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        if(view.element!=shape.element || view.length!=shape.length) { return .err(errors::make(5,offset)); }
        let slices::Ticket ticket=switch(slices::open_exclusive(ref mut loan.pool,ref mut state.owners,token,start,end,capacity)) {
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };loan.tickets[slot]=ticket;
    } else {
        let slices::Ticket ticket=loan.tickets[slot];
        if(ticket.slot>=16 || ticket.generation==0) { return .err(errors::make(5,offset)); }
        let slices::Slot entry=loan.pool.slots[ticket.slot];
        if(!entry.exclusive || entry.view.root.slot!=token.slot || entry.view.root.generation!=token.generation ||
            entry.view.element!=shape.element || entry.view.length!=shape.length) { return .err(errors::make(5,offset)); }
        if(op==60) {
            let usize index=cells::unpack(registers[a],offset)?;
            let ref mut u8[] data=bytes::view_mut(buffer);
            let usize written=switch(slices::write(ref loan.pool,ticket,ref state.owners,index,registers[b],data)) {
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };
        } else if(op==58) {
            let usize index=cells::unpack(registers[b],offset)?;
            let i64 value=switch(slices::read(ref loan.pool,ticket,ref state.owners,index,bytes::view(buffer))) {
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };registers[dst]=value;
        } else if(op==55) {
            let bool valid=switch(slices::utf8(ref loan.pool,ticket,ref state.owners,bytes::view(buffer))) {
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };registers[dst]=if(valid){1}else{0};
        } else if(op==57) {
            let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)) {
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };let i64 value=cells::pack(length,offset)?;registers[dst]=value;
        } else {
            let usize closed=switch(slices::close(ref mut loan.pool,ticket,ref mut state.owners,capacity)) {
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };loan.tickets[slot]=slices::Ticket{.slot=16,.generation=0};
        }
    }
    return .ok(fuel-cost);
}
