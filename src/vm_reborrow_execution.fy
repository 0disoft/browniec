module vm_reborrow_execution;
import ir as ir;
import errors as errors;
import verifier as verifier;
import slice_reborrow_ir as proof;
import slice_reborrow_context as context;
import slice_authority_call_vm as calls;
import vm_execution as execution;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import std::bytes as bytes;
import slice_authority as authority;
import slice_reborrow_vm as children;
import slice_reborrow_admission_ir as admission;

// Default checked native admission includes supported derived CALLs. The
// public/legacy gates stay separate. Reject unsupported shapes in every function
// before context validation, Fuel, allocation or dispatch.
pub fn Result<proof::Sites,errors::Error> inspect(ref ir::Program p){
    let usize valid=verifier::inspect_reborrow_calls(p)?;let proof::Sites sites=proof::metadata(p)?;
    var usize pc=0;while(pc<p.count){if(p.code[pc*8]==9){
        let usize charge=calls::cost(p,pc,p.offsets[pc])?;
        let usize allowed=admission::call(p,ref sites,pc)?;
    }pc+=1;}
    return .ok(sites);
}
pub fn Result<i64,errors::Error> execute(ref ir::Program p,usize fuel,ref mut arrays::State arrays,
    ref mut bytes::Buffer payload,ref mut loans::State loan,ref mut shared::Frames frames,ref mut authority::State[] receipts,ref mut calls::Bindings[] call_sites,ref mut children::Bindings[] child_sites){
    let proof::Sites sites=inspect(p)?;
    return run(p,ref sites,fuel,arrays,payload,loan,frames,receipts,call_sites,child_sites);
}
fn Result<i64,errors::Error> run(ref ir::Program p,ref proof::Sites sites,usize fuel,ref mut arrays::State arrays,
    ref mut bytes::Buffer payload,ref mut loans::State loan,ref mut shared::Frames frames,ref mut authority::State[] receipts,ref mut calls::Bindings[] call_sites,ref mut children::Bindings[] child_sites){
    if(receipts.len!=1 || call_sites.len!=1 || child_sites.len!=1){return .err(errors::make(5,0));}
    let usize fresh=context::ready(ref receipts[0],ref call_sites[0],ref child_sites[0],loan,frames)?;
    let Result<i64,errors::Error> outcome=execution::execute_canonical(p,sites,fuel,arrays,payload,loan,frames,receipts,call_sites,child_sites);
    return context::finish(ref mut child_sites[0],ref mut call_sites[0],ref mut receipts[0],frames,loan,arrays,payload,outcome);
}

// Compatibility names share the default checked native admission and execution.
pub fn Result<proof::Sites,errors::Error> inspect_derived(ref ir::Program p){
    return inspect(p);
}
pub fn Result<i64,errors::Error> execute_derived(ref ir::Program p,usize fuel,ref mut arrays::State arrays,
    ref mut bytes::Buffer payload,ref mut loans::State loan,ref mut shared::Frames frames,ref mut authority::State[] receipts,ref mut calls::Bindings[] call_sites,ref mut children::Bindings[] child_sites){
    return execute(p,fuel,arrays,payload,loan,frames,receipts,call_sites,child_sites);
}
