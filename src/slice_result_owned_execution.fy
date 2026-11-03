module slice_result_owned_execution;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import array_vm as arrays;
import array_call_vm as calls;
import array_result_vm as results;
import array_range_vm as ranges;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import errors as errors;

// These arrays::State values are unpublished metadata plans. Runtime owns the
// sole owner table; actual backing bytes are always the original mutable view.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref mut i64[] registers,ref mut u8[] data,usize fuel){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(op==52 || op==53){let arrays::State plan=arrays::State{.owners=state.runtime.owners,.tokens=bindings.tokens};
        return ranges::step_data(p,pc,bindings.frame,ref plan,data,registers,fuel);
    }
    let usize id=if(op==35 || op==51){a}else{dst};let usize cost=arrays::cost(ref p.arrays,op,id,p.offsets[pc])?;
    if(fuel<cost){return .err(errors::make(8,p.offsets[pc]));}
    var arrays::State plan=arrays::State{.owners=state.runtime.owners,.tokens=bindings.tokens};
    let usize executed=arrays::execute_data(op,dst,a,b,bindings.frame,ref p.arrays,ref mut plan,data,registers,p.offsets[pc])?;
    state.runtime.owners=plan.owners;bindings.tokens=plan.tokens;return .ok(fuel-cost);
}
pub fn Result<usize,errors::Error> enter(ref ir::Program p,usize pc,runtime::Contract contract,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let usize at=pc*8;let usize target=p.code[at+2] as usize;let usize map=p.code[at+3] as usize;
    let usize owned=calls::cost(p,target,p.offsets[pc])?;
    if(fuel<runtime::cost()+owned){return .err(errors::make(8,p.offsets[pc]));}
    let usize parent=bindings.frame;var runtime::Capture[8] captures=[runtime::capture(frames::none(),false,false);8];
    var usize i=0;while(i<contract.arity){let usize source=p.call_args[map*8+i] as usize;
        if(contract.tags[i]!=0){captures[i]=runtime::capture(bindings.sites[parent*16+source-160],false,false);}i+=1;
    }
    var owners::Token[8] sources=[owners::Token{.slot=0,.generation=0};8];
    var layouts::Array[8] shapes=[layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};8];
    var usize[8] destinations=[0;8];var usize count=0;i=0;
    while(i<contract.arity){let usize encoded=p.array_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0){let usize id=encoded-1;let usize destination=(parent+1)*16+id;
            if(bindings.tokens[destination].generation!=0){return .err(errors::make(5,p.offsets[pc]));}
            let usize source=p.call_args[map*8+i] as usize-128;sources[count]=bindings.tokens[parent*16+source];
            shapes[count]=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])){case .ok(v):{v}case .err(_):{return .err(errors::make(5,p.offsets[pc]));}};
            destinations[count]=destination;count+=1;
        }i+=1;
    }
    let runtime::Entered entered=runtime::enter_arrays(state,contract,ref captures[..contract.arity],ref sources[..count],ref shapes[..count],data,data.len,fuel-owned)?;
    let usize child=frames::push(p,bindings,entered.call,target,p.code[at+1] as usize,map,pc+1)?;
    i=0;while(i<count){bindings.tokens[destinations[i]]=entered.copies.tokens[i];i+=1;}
    let usize cleared=suspend(p,map,parent,contract,bindings);return .ok(entered.call.remaining);
}
fn usize suspend(ref ir::Program p,usize map,usize parent,runtime::Contract contract,ref mut frames::Frames bindings){
    var usize i=0;while(i<contract.arity){let usize source=p.call_args[map*8+i] as usize;
        if((contract.tags[i]&128)!=0){bindings.sites[parent*16+source-160]=frames::none();}i+=1;
    }return 0;
}
// ARET moves the sole result token after loan restoration; it never copies the
// array payload. Ordinary source cleanup has already ended other local owners.
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize pc,bool array,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref u8[] data,usize fuel){
    let usize frame=bindings.frame;let usize f=bindings.functions[frame];let usize offset=p.offsets[pc];
    let usize source=p.code[pc*8+2] as usize;let usize destination=bindings.destinations[frame];
    let usize extra=if(array){results::cost(p,source,offset)?}else{0};
    if(fuel<runtime::cost()+extra){return .err(errors::make(8,offset));}
    var arrays::State plan=arrays::State{.owners=state.runtime.owners,.tokens=bindings.tokens};
    var owners::Token result=owners::Token{.slot=0,.generation=0};
    if(array){
        if(destination<128 || destination>=144){return .err(errors::make(5,offset));}
        let results::Transfer transfer=results::prepare_data(p,f,source,destination-128,frame,ref plan,data,offset)?;
        result=transfer.token;
    }else{var usize i=0;while(i<16){if(plan.tokens[frame*16+i].generation!=0){return .err(errors::make(5,offset));}i+=1;}}
    var runtime::Call call=frames::current(bindings);
    let runtime::Resumed resumed=runtime::leave_call(state,ref mut call,data.len,fuel-extra)?;
    let usize next=frames::pop_call(p,bindings,resumed)?;
    if(array){bindings.tokens[(frame-1)*16+destination-128]=result;}
    return .ok(resumed.remaining);
}
