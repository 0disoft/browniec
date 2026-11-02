module slice_reborrow_context;
import errors as errors;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as sites;
import slice_formal_reborrow_vm as adapter;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import std::bytes as bytes;

// The caller owns three separate roots. Keeping them separate avoids aliases
// between mutable authority and binding parameters in the Fairy C borrow model.
pub fn Result<usize,errors::Error> ready(ref authority::State receipts,ref calls::Bindings call_sites,ref sites::Bindings child_sites,ref loans::State loan,ref shared::Frames frames){
    let usize depth=switch(authority::inspect(receipts)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    if(depth!=0 || receipts.frame!=0){return .err(errors::make(5,0));}
    var usize i=0;while(i<31){if(call_sites.pcs[i]!=256 || child_sites.parents[i]!=16 || child_sites.children[i]!=16 || child_sites.functions[i]!=16){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<248){if(call_sites.detached[i].slot!=16 || call_sites.detached[i].generation!=0){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<512){if(loan.tickets[i].slot!=16 || loan.tickets[i].generation!=0){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<256){if(frames.origins[i].slot!=16 || frames.origins[i].generation!=0){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<16){if(loan.pool.slots[i].live){return .err(errors::make(5,0));}i+=1;}return .ok(0);
}
pub fn Result<i64,errors::Error> finish(ref mut sites::Bindings child_sites,ref mut calls::Bindings call_sites,
    ref mut authority::State receipts,ref mut shared::Frames frames,ref mut loans::State loan,
    ref mut arrays::State arrays,ref bytes::Buffer buffer,Result<i64,errors::Error> outcome){
    return adapter::finish(child_sites,call_sites,receipts,frames,loan,arrays,buffer,outcome);
}
