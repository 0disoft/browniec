module mixed_call_vm;
import ir as ir;
import errors as errors;
import slice_call_vm as borrowed;
import slice_vm as loans;
import struct_call_vm as owned;
import struct_vm as records;
import array_vm as arrays;
import std::bytes as bytes;

// Shared atomic admission for owned and readonly borrowed arguments.
// Return the complete charge, including base/scalar, owned and borrowed work.
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize target,usize offset) {
    let usize retention=borrowed::cost(p,target,offset)?;
    let usize copies=owned::cost(p,target,offset)?;
    return .ok(1+p.arities[target]+copies+retention);
}
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize parent,
    ref mut borrowed::Frames frames,ref mut loans::State loan,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,usize fuel) {
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=9) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc]; let usize target=p.code[pc*8+2] as usize;
    let usize site=p.code[pc*8+3] as usize;
    let usize charge=cost(p,target,offset)?;
    if(site>=p.call_count || site>=32 || p.call_arities[site] as usize!=p.arities[target]) {
        return .err(errors::make(5,offset));
    }
    if(fuel<charge) { return .err(errors::make(8,offset)); }
    if(parent>=31) { return .err(errors::make(12,offset)); }
    let usize retention=borrowed::cost(p,target,offset)?;
    if(retention==0) { return owned::step(p,target,site,parent,record_state,state,buffer,fuel,offset); }
    // This plan changes neither original tickets nor existing owner sessions.
    let borrowed::Admission plan=borrowed::prepare(p,pc,parent,frames,loan,state,buffer,retention)?;
    // Owned copying is itself atomic: every possible failure precedes payload
    // writes. It preserves the existing roots/sessions referenced by the plan.
    let usize remaining=owned::step(p,target,site,parent,record_state,state,buffer,fuel-retention,offset)?;
    // No fallible operation follows owned publication. Registers and return
    // frames are deliberately outside this boundary and remain unpublished.
    borrowed::publish(ref plan,frames,loan);
    return .ok(remaining);
}
