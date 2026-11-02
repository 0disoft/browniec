module slice_reborrow_call_vm;
import ir as ir;
import errors as errors;
import array_vm as arrays;
import struct_vm as records;
import array_slices as slices;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_ir as proof;
import slice_reborrow_call_admission as admission;
import std::bytes as bytes;

// Native loan handoff only, after independent inspect_reborrow_calls/Sites proof.
// Caller preflights scalar/control state separately. Prepare and publication are
// one synchronous operation: no external plan, callbacks or intervening mutation.
// Existing canonical view/release/leave/finish authenticate and restore the CALL.
pub fn Result<usize,errors::Error> enter(ref ir::Program p,ref proof::Sites sites,usize pc,usize frame,
    ref children::Bindings child_sites,ref mut calls::Bindings call_sites,ref mut authority::State receipts,
    ref mut shared::Frames frames,ref mut loans::State loan,ref arrays::State state,
    ref records::State record_state,ref bytes::Buffer buffer,usize fuel){
    let admission::Prepared plan=admission::prepare(p,sites,pc,frame,child_sites,call_sites,receipts,frames,loan,state,record_state,buffer,fuel)?;
    // Immutable metadata was checked by prepare. Nothing fallible follows it.
    let usize target=p.code[pc*8+2] as usize;let usize args=p.code[pc*8+3] as usize;
    let slices::Arguments issued=authority::publish_call(receipts,plan.receipt);
    loan.pool.slots=plan.pool.slots;call_sites.pcs[plan.depth]=pc;
    var usize nw=0;var usize nr=0;var usize i=0;
    while(i<p.arities[target]){
        let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0){
            if(ir::exclusive(p,encoded-1)){
                let usize source=(p.call_args[args*8+i] as usize)-160;
                loan.tickets[frame*16+source]=slices::Ticket{.slot=16,.generation=0};
                loan.tickets[(frame+1)*16+encoded-1]=issued.tickets[nw];nw+=1;
            }else{loan.tickets[(frame+1)*16+encoded-1]=plan.retained.tickets[nr];nr+=1;}
            frames.origins[(frame+1)*8+i]=plan.roots[i];
        }
        i+=1;
    }
    return .ok(plan.remaining);
}

// Call only after independent metadata proof and CALL cost/descriptor validation.
// Classification is static; suspended callers with no derived arguments can
// continue using the existing scalar/shared/owned/result transaction.
pub fn bool required(ref ir::Program p,ref proof::Sites sites,usize pc){
    let usize target=p.code[pc*8+2] as usize;let usize args=p.code[pc*8+3] as usize;var usize i=0;
    while(i<p.arities[target]){
        let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0 && ir::exclusive(p,encoded-1)){
            let usize source=(p.call_args[args*8+i] as usize)-160;
            if(sites.parents[source]!=16){return true;}
        }
        i+=1;
    }
    return false;
}
