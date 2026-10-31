module slice_lifecycle_vm;
import ir as ir;
import errors as errors;
import slice_call_vm as calls;
import slice_vm as loans;
import array_vm as arrays;
import array_owners as owners;
import std::bytes as bytes;

// Successful borrowed admission prepaid this frame's cleanup. Ordinary frames
// keep their existing source-lowered closes and exact instruction Fuel prices.
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize function,usize frame,
    ref mut calls::Frames frames,ref mut loans::State loan,ref mut arrays::State state,
    ref bytes::Buffer buffer,usize offset) {
    if(frame>=32) { return .err(errors::make(5,offset)); }
    let usize reserve=calls::cost(p,function,offset)?;
    if(reserve==0) { return .ok(0); }
    return calls::leave(p,function,frame,frames,loan,state,buffer,offset);
}

// Clear all sessions atomically through the existing pool operation. Preserve
// the exact execution outcome after successful cleanup; cleanup failure stays
// visible and retains root bindings for diagnosis alongside the failed tables.
pub fn Result<i64,errors::Error> finish(ref mut calls::Frames frames,
    ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer,
    Result<i64,errors::Error> outcome) {
    var bool failed=false; var errors::Error failure=errors::make(0,0);
    let i64 value=switch(outcome) { case .ok(v):{v} case .err(e):{failed=true;failure=e;0} };
    let usize closed=loans::drain(loan,state,buffer)?;
    var usize i=0;
    while(i<256) { frames.origins[i]=owners::Token{.slot=16,.generation=0}; i+=1; }
    if(failed) { return .err(failure); }
    return .ok(value);
}
