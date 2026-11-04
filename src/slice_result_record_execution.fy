module slice_result_record_execution;
import ir as ir;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import struct_vm as records;
import slice_result_record_bindings as record_bindings;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import errors as errors;

// Record and array maps are identities only; Runtime holds their one owner table.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref mut i64[] registers,ref mut u8[] data,usize fuel){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let ref owners::Table original_owners=ref state.runtime.owners;
    var arrays::State plan=arrays::State{.owners=*original_owners,.tokens=bindings.tokens};
    var records::State record_plan=record_bindings::materialize(ref bindings.records);
    let usize remaining=if(op==47){records::subassign_data(dst,a,b,p.code[at+4] as usize,p.code[at+5] as usize,
        bindings.frame,ref p.records,ref mut record_plan,ref mut plan,data,fuel,p.offsets[pc])?}
        else if(op==49){records::subreplace_data(dst,a,b,p.code[at+4] as usize,bindings.frame,
            ref p.records,ref mut record_plan,ref mut plan,data,registers,fuel,p.offsets[pc])?}
        else{records::step_data(op,dst,a,b,bindings.frame,ref p.records,ref mut record_plan,
            ref mut plan,data,registers,fuel,p.offsets[pc])?};
    let usize location=bindings.frame*16+dst;
    if(op==45){record_bindings::forget(ref mut bindings.records,location);}
    if(op==41 || op==42){let owners::Token token=record_plan.tokens[location];record_bindings::bind(ref mut bindings.records,location,token);}
    state.runtime.owners=plan.owners;return .ok(remaining);
}
// Compact both frame maps into the existing sixteen-owner terminal transaction.
// Never drop records before handoff: cleanup failure must roll back all metadata.
pub fn Result<runtime::Returned,errors::Error> handoff(ref frames::Frames bindings,
    ref mut runtime::State state,ref mut runtime::Call call,slices::Ticket selected,usize capacity,usize fuel){
    var owners::Token[16] roots=[owners::Token{.slot=0,.generation=0};16];var usize count=0;
    var usize i=0;while(i<32){let usize at=bindings.frame*16+i%16;
        let owners::Token token=if(i<16){bindings.tokens[at]}else{record_bindings::get(ref bindings.records,at)};
        if(token.generation!=0){if(count>=16){return .err(errors::make(5,0));}roots[count]=token;count+=1;}i+=1;
    }
    return runtime::handoff_roots(state,call,selected,ref roots[..count],capacity,fuel);
}
