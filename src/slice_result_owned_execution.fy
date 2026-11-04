module slice_result_owned_execution;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import array_vm as arrays;
import struct_call_vm as calls;
import struct_result_vm as record_results;
import struct_vm as records;
import slice_result_record_bindings as record_bindings;
import array_result_vm as results;
import array_range_vm as ranges;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import errors as errors;
import slice_result_bindings as result_bindings;

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
    let usize owned=calls::cost(p,target,p.offsets[pc])?+contract.arity;
    if(fuel<runtime::cost()+owned){return .err(errors::make(8,p.offsets[pc]));}
    let usize parent=bindings.frame;var runtime::Capture[8] captures=[runtime::capture(frames::none(),false,false);8];
    let usize mask=if(p.code[at]==66){p.code[at+4] as usize}else{0};let usize one=1;
    var usize i=0;while(i<contract.arity){let usize source=p.call_args[map*8+i] as usize;
        if(contract.tags[i]!=0){captures[i]=runtime::capture(bindings.sites[parent*16+source-160],(mask&(one<<i))!=0,false);}i+=1;
    }
    var owners::Token[8] sources=[owners::Token{.slot=0,.generation=0};8];
    var layouts::Array[8] shapes=[layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};8];
    var usize[8] destinations=[0;8];var bool[8] record_args=[false;8];var bool records=false;
    var owners::CallArgument[8] arguments=[owners::CallArgument{.source=owners::Token{.slot=0,.generation=0},.element=0,.length=0,.record=0};8];
    var usize count=0;i=0;
    while(i<contract.arity){let usize encoded=p.array_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0){let usize id=encoded-1;let usize destination=(parent+1)*16+id;
            if(bindings.tokens[destination].generation!=0){return .err(errors::make(5,p.offsets[pc]));}
            let usize source=p.call_args[map*8+i] as usize-128;sources[count]=bindings.tokens[parent*16+source];
            shapes[count]=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])){case .ok(v):{v}case .err(_):{return .err(errors::make(5,p.offsets[pc]));}};
            arguments[count]=owners::CallArgument{.source=sources[count],.element=shapes[count].element,.length=shapes[count].length,.record=0};
            destinations[count]=destination;count+=1;
        }
        let usize r=p.record_parameters[p.register_starts[target]+i] as usize;
        if(r!=0){let usize destination=(parent+1)*16+r-1;
            if(record_bindings::get(ref bindings.records,destination).generation!=0){return .err(errors::make(5,p.offsets[pc]));}
            let usize source=p.call_args[map*8+i] as usize-144;
            arguments[count]=owners::CallArgument{.source=record_bindings::get(ref bindings.records,parent*16+source),.element=0,.length=0,.record=p.records.records[r-1] as usize};
            record_args[count]=true;records=true;destinations[count]=destination;count+=1;
        }i+=1;
    }
    let runtime::Entered entered=if(records){runtime::enter_records(state,contract,ref captures[..contract.arity],ref p.records.layouts,ref arguments[..count],data,fuel-owned)?}
        else{runtime::enter_arrays(state,contract,ref captures[..contract.arity],ref sources[..count],ref shapes[..count],data,data.len,fuel-owned)?};
    let usize destination=if(p.code[at]==66){160+p.code[at+5] as usize}else{p.code[at+1] as usize};
    let usize child=frames::push(p,bindings,entered.call,target,destination,map,pc+1)?;
    i=0;while(i<count){if(record_args[i]){record_bindings::bind(ref mut bindings.records,destinations[i],entered.copies.tokens[i]);}
        else{bindings.tokens[destinations[i]]=entered.copies.tokens[i];}i+=1;}
    let usize cleared=suspend(p,map,parent,contract,bindings);return .ok(entered.call.remaining);
}
fn usize suspend(ref ir::Program p,usize map,usize parent,runtime::Contract contract,ref mut frames::Frames bindings){
    var usize i=0;while(i<contract.arity){let usize source=p.call_args[map*8+i] as usize;
        if((contract.tags[i]&128)!=0){bindings.sites[parent*16+source-160]=frames::none();}i+=1;
    }return 0;
}
// ARET moves the sole result token after loan restoration; it never copies the
// array payload. Ordinary source cleanup has already ended other local owners.
pub fn Result<runtime::Resumed,errors::Error> leave(ref ir::Program p,usize pc,u8 op,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref u8[] data,usize fuel){
    let usize frame=bindings.frame;let usize f=bindings.functions[frame];let usize offset=p.offsets[pc];
    if(result_bindings::in_frame(ref bindings.loans,frame) || (frame==1 && op!=8)){return .err(errors::make(5,offset));}
    let usize source=p.code[pc*8+2] as usize;let usize destination=bindings.destinations[frame];
    let usize extra=if(op==39){results::cost(p,source,offset)?}else if(op==50){record_results::cost()}else{0};
    if(fuel<runtime::leave_cost()+extra){return .err(errors::make(8,offset));}
    var arrays::State plan=arrays::State{.owners=state.runtime.owners,.tokens=bindings.tokens};
    var owners::Token result=owners::Token{.slot=0,.generation=0};
    var usize i=0;while(i<16){
        if(op!=50 && record_bindings::get(ref bindings.records,frame*16+i).generation!=0){return .err(errors::make(5,offset));}i+=1;
    }
    if(op==39){
        if(destination<128 || destination>=144){return .err(errors::make(5,offset));}
        let results::Transfer transfer=results::prepare_data(p,f,source,destination-128,frame,ref plan,data,offset)?;
        result=transfer.token;
    }else if(op==50){
        if(destination<144 || destination>=160){return .err(errors::make(5,offset));}
        let records::State record_plan=record_bindings::materialize(ref bindings.records);
        let record_results::Transfer transfer=record_results::prepare_data(p,f,source,destination-144,frame,ref record_plan,ref plan,data,offset)?;
        result=transfer.token;
    }else{i=0;while(i<16){if(plan.tokens[frame*16+i].generation!=0){return .err(errors::make(5,offset));}i+=1;}}
    var runtime::Call call=frames::current(bindings);
    let runtime::Resumed resumed=runtime::leave_call(state,ref mut call,data.len,fuel-extra)?;
    if(frame==1){
        bindings.active[frame]=false;bindings.functions[frame]=16;bindings.frame=0;
    }else{let usize next=frames::pop_call(p,bindings,resumed)?;}
    if(op==39){bindings.tokens[(frame-1)*16+destination-128]=result;}
    if(op==50){record_bindings::bind(ref mut bindings.records,(frame-1)*16+destination-144,result);}
    return .ok(resumed);
}
