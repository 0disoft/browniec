module struct_call_vm;
import ir as ir;
import errors as errors;
import array_call_vm as array_calls;
import array_vm as arrays;
import struct_vm as records;
import array_owners as owners;
import std::bytes as bytes;

// Only independently verified immutable programs enter this private boundary.
// Cost calculation reads bounded metadata; it never plans a catalog or reads
// payload. Array-only and scalar-only calls retain their existing exact prices.
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize target,usize offset) {
    if(target>=p.function_count || target>=16 || p.arities[target]>8 ||
        p.register_starts[target]>128 || p.arities[target]>128-p.register_starts[target]) {
        return .err(errors::make(5,offset));
    }
    var usize count=0;var usize arg=0;
    while(arg<p.arities[target]) {
        if(p.record_parameters[p.register_starts[target]+arg]!=0){count+=1;}
        arg+=1;
    }
    let usize array_work=array_calls::cost(p,target,offset)?;
    // Two complete plans (2*18432), a bounded snapshot traversal (4096),
    // scalar staging/copy/padding and owner scans (2048) per record.
    // The batch covers 1024 scratch bytes and staged metadata publication.
    return .ok(if(count==0){array_work}else{2048+count*43008+array_work});
}

fn Result<usize,errors::Error> enter(ref ir::Program p,usize target,usize site,usize parent,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,usize offset) {
    var owners::CallArgument[8] arguments=[owners::CallArgument{
        .source=owners::Token{.slot=0,.generation=0},.element=0,.length=0,.record=0};8];
    var usize[8] destinations=[0;8];var bool[8] record_args=[false;8];
    let usize child=(parent+1)*16;
    var usize i=0;
    while(i<16) {
        if(state.tokens[child+i].generation!=0 || record_state.tokens[child+i].generation!=0) {
            return .err(errors::make(5,offset));
        }
        i+=1;
    }
    var usize count=0;var usize arg=0;
    while(arg<p.arities[target]) {
        let usize formal=p.register_starts[target]+arg;
        let usize r=p.record_parameters[formal] as usize;
        let usize a=p.array_parameters[formal] as usize;
        let usize source=p.call_args[site*8+arg] as usize;
        if(r!=0) {
            if(r>p.records.count || r>16 || source<144 || source-144>=p.records.count || source>=160) {
                return .err(errors::make(5,offset));
            }
            arguments[count]=owners::CallArgument{.source=record_state.tokens[parent*16+source-144],
                .element=0,.length=0,.record=p.records.records[r-1] as usize};
            destinations[count]=child+r-1;record_args[count]=true;count+=1;
        } else if(a!=0) {
            if(a>p.arrays.count || a>16 || source<128 || source-128>=p.arrays.count || source>=144) {
                return .err(errors::make(5,offset));
            }
            arguments[count]=owners::CallArgument{.source=state.tokens[parent*16+source-128],
                .element=p.arrays.elements[a-1],.length=p.arrays.lengths[a-1],.record=0};
            destinations[count]=child+a-1;count+=1;
        }
        arg+=1;
    }
    let ref mut u8[] data=bytes::view_mut(buffer);
    let owners::Copies copies=switch(owners::copy_call_arguments(ref p.records.layouts,
        ref arguments[..count],data,ref mut state.owners)) {
        case .ok(c):{c}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    i=0;
    while(i<count) {
        if(record_args[i]){record_state.tokens[destinations[i]]=copies.tokens[i];}
        else{state.tokens[destinations[i]]=copies.tokens[i];}
        i+=1;
    }
    return .ok(count);
}

// Prepay the entire CALL before frame admission, traversal, source resolution,
// scratch or owner mutation. Register/return-frame publication stays in the VM
// and occurs only after this transaction succeeds.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize target,usize site,usize parent,
    ref mut records::State record_state,ref mut arrays::State state,
    ref mut bytes::Buffer buffer,usize fuel,usize offset) {
    if(site>=p.call_count || site>=32 || p.call_arities[site]>8) {return .err(errors::make(5,offset));}
    let usize work=cost(p,target,offset)?;
    let usize charged=1+(p.call_arities[site] as usize)+work;
    if(fuel<charged){return .err(errors::make(8,offset));}
    if(parent>=31){return .err(errors::make(12,offset));}
    if(work!=0) {
        var bool record_call=false;var usize arg=0;
        while(arg<p.arities[target]) {
            if(p.record_parameters[p.register_starts[target]+arg]!=0){record_call=true;}
            arg+=1;
        }
        if(record_call) {
            let usize copied=enter(p,target,site,parent,record_state,state,buffer,offset)?;
        } else {
            let usize copied=array_calls::enter(p,target,site,parent,state,buffer,offset)?;
        }
    }
    return .ok(fuel-charged);
}
