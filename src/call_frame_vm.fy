module call_frame_vm;
import ir as ir;
import errors as errors;
import mixed_call_vm as mixed;
import slice_mutable_call_vm as mutable;
import slice_call_vm as borrowed;
import slice_vm as loans;
import struct_vm as records;
import array_vm as arrays;
import std::bytes as bytes;
import slice_authority_call_vm as canonical;
import slice_reborrow_ir as proof;
import slice_authority as authority;
import slice_reborrow_vm as children;
import slice_reborrow_call_vm as derived;

// Shared immutable preflight. No register/control state is published before
// all scalar checks and the selected owner/loan transaction succeed.
struct Prepared { i64[8] values; usize child; usize target; usize pc; usize dst; }
fn Result<Prepared,errors::Error> prepare(ref ir::Program p,usize pc,usize parent,
    ref i64[] registers,ref usize[] return_pcs,ref usize[] return_dsts,usize fuel,usize charge) {
    if(p.count>256 || pc>=p.count || p.code[pc*8]!=9) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc]; let usize target=p.code[pc*8+2] as usize;
    let usize site=p.code[pc*8+3] as usize; let usize dst=p.code[pc*8+1] as usize;
    if(site>=p.call_count || site>=32 || p.call_arities[site] as usize!=p.arities[target]) {
        return .err(errors::make(5,offset));
    }
    if(fuel<charge) { return .err(errors::make(8,offset)); }
    if(parent>=31) { return .err(errors::make(12,offset)); }
    let usize child=parent+1;
    if(registers.len<(child+1)*128 || return_pcs.len<=child || return_dsts.len<=child) {
        return .err(errors::make(5,offset));
    }
    var usize caller=0;
    while(caller<p.function_count && (pc<p.starts[caller] || pc>=p.ends[caller])) { caller+=1; }
    if(caller==p.function_count || p.registers>128 || p.register_starts[caller]>p.register_ends[caller] ||
        p.register_ends[caller]>p.registers || p.register_starts[target]>p.register_ends[target] ||
        p.register_ends[target]>p.registers || p.arities[target]>p.register_ends[target]-p.register_starts[target]) {
        return .err(errors::make(5,offset));
    }
    if(p.record_results[target]!=0) {
        if(dst<144 || dst>=160) { return .err(errors::make(5,offset)); }
    } else if(p.array_results[target]!=0) {
        if(dst<128 || dst>=144) { return .err(errors::make(5,offset)); }
    } else if(dst<p.register_starts[caller] || dst>=p.register_ends[caller] ||
        p.types[dst]!=p.return_types[target] || p.slots[dst] || p.array_parameters[dst]!=0 ||
        p.record_parameters[dst]!=0 || p.slice_parameters[dst]!=0) { return .err(errors::make(5,offset)); }
    var i64[8] values=[0;8]; var usize i=0;
    while(i<p.arities[target]) {
        let usize formal=p.register_starts[target]+i;
        if(p.array_parameters[formal]==0 && p.record_parameters[formal]==0 && p.slice_parameters[formal]==0) {
            let usize source=p.call_args[site*8+i] as usize;
            if(source<p.register_starts[caller] || source>=p.register_ends[caller] ||
                p.types[source]!=p.types[formal] || p.slots[source] || p.array_parameters[source]!=0 ||
                p.record_parameters[source]!=0 || p.slice_parameters[source]!=0) { return .err(errors::make(5,offset)); }
            values[i]=registers[parent*128+source];
        }
        i+=1;
    }
    return .ok(Prepared{.values=values,.child=child,.target=target,.pc=pc+1,.dst=dst});
}
fn void publish(ref ir::Program p,ref Prepared plan,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts){
    var usize i=0;while(i<p.arities[plan.target]){
        let usize formal=p.register_starts[plan.target]+i;
        if(p.array_parameters[formal]==0 && p.record_parameters[formal]==0 && p.slice_parameters[formal]==0){registers[plan.child*128+formal]=plan.values[i];}
        i+=1;
    }
    return_pcs[plan.child]=plan.pc;return_dsts[plan.child]=plan.dst;
}
// Legacy readonly/public entry point retains its signature and exact prices.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize parent,
    ref mut borrowed::Frames frames,ref mut loans::State loan,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts,usize fuel){
    if(p.count>256 || pc>=p.count || p.code[pc*8]!=9){return .err(errors::make(5,0));}
    let usize charge=mixed::cost(p,p.code[pc*8+2] as usize,p.offsets[pc])?;
    let Prepared plan=prepare(p,pc,parent,registers,return_pcs,return_dsts,fuel,charge)?;
    let usize remaining=mixed::step(p,pc,parent,frames,loan,record_state,state,buffer,fuel)?;
    publish(p,ref plan,registers,return_pcs,return_dsts);return .ok(remaining);
}
// Private mutable CALL: atomic loan/owner publication precedes only infallible
// scalar/return-frame writes from the same checked preflight as the legacy path.
pub fn Result<usize,errors::Error> step_mutable(ref ir::Program p,usize pc,usize parent,
    ref mut mutable::Frame receipt,ref mut borrowed::Frames frames,ref mut loans::State loan,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts,usize fuel){
    if(p.count>256 || pc>=p.count || p.code[pc*8]!=9){return .err(errors::make(5,0));}
    let usize charge=mutable::cost(p,p.code[pc*8+2] as usize,p.offsets[pc])?;
    let Prepared plan=prepare(p,pc,parent,registers,return_pcs,return_dsts,fuel,charge)?;
    let usize remaining=mutable::enter(p,pc,parent,receipt,frames,loan,record_state,state,buffer,fuel)?;
    publish(p,ref plan,registers,return_pcs,return_dsts);return .ok(remaining);
}

// Reuse scalar/control preflight; canonical loan preparation precedes atomic
// owned copying. Only infallible authority/register/control publication follows.
pub fn Result<usize,errors::Error> step_canonical(ref ir::Program p,ref proof::Sites sites,usize pc,usize parent,
    ref mut canonical::Bindings bindings,ref mut authority::State receipts,ref mut borrowed::Frames frames,ref mut loans::State loan,
    ref mut records::State record_state,ref mut arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts,usize fuel){
    let usize charge=canonical::cost(p,pc,if(pc<p.count && pc<256){p.offsets[pc]}else{0})?;
    let Prepared plan=prepare(p,pc,parent,registers,return_pcs,return_dsts,fuel,charge)?;
    let usize remaining=canonical::enter_owned(p,sites,pc,parent,bindings,receipts,frames,loan,state,record_state,buffer,fuel)?;
    publish(p,ref plan,registers,return_pcs,return_dsts);return .ok(remaining);
}

// Same scalar/control preflight and publication as existing CALLs. New derived
// loan preparation precedes atomic owned copying; only infallible metadata and
// scalar/control writes follow. Ordinary signatures retain their transaction.
pub fn Result<usize,errors::Error> step_canonical_derived(ref ir::Program p,ref proof::Sites sites,usize pc,usize parent,
    ref children::Bindings child_sites,ref mut canonical::Bindings bindings,ref mut authority::State receipts,
    ref mut borrowed::Frames frames,ref mut loans::State loan,ref mut records::State record_state,
    ref mut arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts,usize fuel){
    let usize charge=canonical::cost(p,pc,if(pc<p.count && pc<256){p.offsets[pc]}else{0})?;
    let Prepared plan=prepare(p,pc,parent,registers,return_pcs,return_dsts,fuel,charge)?;
    let usize remaining=if(derived::required(p,sites,pc)){
        derived::enter_owned(p,sites,pc,parent,child_sites,bindings,receipts,frames,loan,state,record_state,buffer,fuel)?
    }else{canonical::enter_owned(p,sites,pc,parent,bindings,receipts,frames,loan,state,record_state,buffer,fuel)?};
    publish(p,ref plan,registers,return_pcs,return_dsts);return .ok(remaining);
}
