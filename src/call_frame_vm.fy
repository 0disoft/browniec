module call_frame_vm;
import ir as ir;
import errors as errors;
import mixed_call_vm as mixed;
import slice_call_vm as borrowed;
import slice_vm as loans;
import struct_vm as records;
import array_vm as arrays;
import std::bytes as bytes;

// Private boundary for an immutable independently inspected Program. Complete
// every register/control check before the mixed owner/loan transaction publishes.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize parent,
    ref mut borrowed::Frames frames,ref mut loans::State loan,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,ref mut i64[] registers,
    ref mut usize[] return_pcs,ref mut usize[] return_dsts,usize fuel) {
    if(p.count>256 || pc>=p.count || p.code[pc*8]!=9) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc]; let usize target=p.code[pc*8+2] as usize;
    let usize site=p.code[pc*8+3] as usize; let usize dst=p.code[pc*8+1] as usize;
    let usize charge=mixed::cost(p,target,offset)?;
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
    let usize remaining=mixed::step(p,pc,parent,frames,loan,record_state,state,buffer,fuel)?;
    // Only bounded, infallible writes follow mixed publication. Borrowed and
    // aggregate formals never become scalar cells, even when frames are reused.
    i=0;
    while(i<p.arities[target]) {
        let usize formal=p.register_starts[target]+i;
        if(p.array_parameters[formal]==0 && p.record_parameters[formal]==0 && p.slice_parameters[formal]==0) {
            registers[child*128+formal]=values[i];
        }
        i+=1;
    }
    return_pcs[child]=pc+1; return_dsts[child]=dst;
    return .ok(remaining);
}
