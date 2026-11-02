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

// Native-only admission. No public verifier, source grammar or CLI capability
// changes. Reject unsupported signatures/CALL shapes before any execution effect.
pub fn Result<proof::Sites,errors::Error> inspect(ref ir::Program p){
    let usize valid=verifier::inspect(p)?;
    var usize i=0;while(i<p.function_count){if(p.array_results[i]!=0 || p.record_results[i]!=0){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<p.count){if(p.code[i*8]==9){let usize charge=calls::cost(p,i,p.offsets[i])?;}i+=1;}
    return proof::metadata(p);
}
pub fn Result<i64,errors::Error> execute(ref ir::Program p,usize fuel,ref mut arrays::State arrays,
    ref mut bytes::Buffer payload,ref mut loans::State loan,ref mut shared::Frames frames,ref mut authority::State[] receipts,ref mut calls::Bindings[] call_sites,ref mut children::Bindings[] child_sites){
    let proof::Sites sites=inspect(p)?;
    if(receipts.len!=1 || call_sites.len!=1 || child_sites.len!=1){return .err(errors::make(5,0));}
    let usize fresh=context::ready(ref receipts[0],ref call_sites[0],ref child_sites[0],loan,frames)?;
    let Result<i64,errors::Error> outcome=execution::execute_canonical(p,ref sites,fuel,arrays,payload,loan,frames,receipts,call_sites,child_sites);
    return context::finish(ref mut child_sites[0],ref mut call_sites[0],ref mut receipts[0],frames,loan,arrays,payload,outcome);
}
