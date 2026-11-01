module slice_mutable_frame_vm;
import ir as ir;
import errors as errors;
import cells as cells;
import array_layout as layouts;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import slice_call_vm as shared;
import slice_mutable_call_vm as calls;
import slice_vm as loans;
import std::bytes as bytes;

// Private mutable formal dispatch over immutable independently inspected IR.
// Owner sessions remain held across formal close until CALL return restores them.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize function,usize pc,usize frame,
    ref mut calls::Frame receipt,ref shared::Frames frames,ref mut loans::State loan,
    ref arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] registers,usize fuel){
    if(pc>=p.count || pc>=256){return .err(errors::make(5,0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize site=if(op==55 || op==57 || op==58){a}else{dst};
    if(p.function_count>16 || function>=p.function_count || pc<p.starts[function] || pc>=p.ends[function] || frame==0 || frame>=32 || registers.len>128 || site>=16 ||
        !ir::exclusive(p,site) || p.slice_roots[site]!=0 || p.slice_origins[site] as usize!=site+1 || p.slice_functions[site] as usize!=function+1 ||
        op<55 || op>60 || op==59 || p.code[at+4]!=0 || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        ((op==55 || op==57) && (dst>=registers.len || b!=0)) || (op==58 && (dst>=registers.len || b>=registers.len)) ||
        (op==60 && (a>=registers.len || b>=registers.len)) || (op==56 && (a!=0 || b!=0))){return .err(errors::make(5,offset));}
    let u8 tag=ir::borrow_element(p,site);let layouts::Array shape=switch(layouts::scalar(tag,1)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    if(op==55 && tag!=10){return .err(errors::make(5,offset));}
    let usize base=if(op==58){4130+shape.stride}else if(op==60){4130+2*shape.stride}else{4097};
    if(fuel<base){return .err(errors::make(8,offset));}
    let owners::View view=calls::view(p,function,frame,site,receipt,frames,loan,state,bytes::len(buffer),offset)?;
    let usize work=base+if(op==55){4*view.length}else{0};if(fuel<work){return .err(errors::make(8,offset));}
    let slices::Ticket ticket=loan.tickets[frame*16+site];
    if(op==56){return calls::release(p,function,frame,site,receipt,frames,loan,state,buffer,fuel,offset);}
    if(op==60){let usize index=cells::unpack(registers[a],offset)?;let usize written=switch(slices::write(ref loan.pool,ticket,ref state.owners,index,registers[b],bytes::view_mut(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};}
    else if(op==58){let usize index=cells::unpack(registers[b],offset)?;let i64 value=switch(slices::read(ref loan.pool,ticket,ref state.owners,index,bytes::view(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};registers[dst]=value;}
    else if(op==57){let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,bytes::len(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};let i64 value=cells::pack(length,offset)?;registers[dst]=value;}
    else{let bool valid=switch(slices::utf8(ref loan.pool,ticket,ref state.owners,bytes::view(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};registers[dst]=if(valid){1}else{0};}
    return .ok(fuel-work);
}
