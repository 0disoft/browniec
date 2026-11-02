module array_result_vm;

import ir as ir;
import errors as errors;
import array_vm as arrays;
import array_owners as owners;
import std::bytes as bytes;

pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize source,usize offset) {
    if(source>=p.arrays.count) {return .err(errors::make(5,offset));}
    // Prepay the frame token scan, owner metadata validation and bool traversal.
    return .ok(65+if(p.arrays.elements[source]==2){p.arrays.lengths[source]}else{0});
}
// Trusted native, single-use plan: no owner/token mutation may intervene except
// canonical loan restoration, which must preserve this unique result owner.
pub struct Transfer { owners::Token token; usize child; usize parent; usize bytes; }
// Verified ARET retains only its result owner. Preparation does not mutate state.
pub fn Result<Transfer,errors::Error> prepare(ref ir::Program p,usize target,usize source,usize destination,usize frame,
    ref arrays::State state,ref bytes::Buffer buffer,usize offset) {
    if(frame==0 || frame>=32 || target>=p.function_count || source>=p.arrays.count || destination>=p.arrays.count) {
        return .err(errors::make(5,offset));
    }
    let usize encoded=p.array_results[target] as usize;
    if(encoded==0 || encoded>p.arrays.count || p.array_functions[source] as usize!=target) {return .err(errors::make(5,offset));}
    let usize shape=encoded-1;
    if(p.arrays.elements[source]!=p.arrays.elements[shape] || p.arrays.lengths[source]!=p.arrays.lengths[shape] ||
        p.arrays.elements[destination]!=p.arrays.elements[shape] || p.arrays.lengths[destination]!=p.arrays.lengths[shape]) {
        return .err(errors::make(5,offset));
    }
    let usize child=frame*16;let usize parent=(frame-1)*16+destination;
    if(state.tokens[parent].generation!=0 || state.tokens[parent].slot!=0) {return .err(errors::make(5,offset));}
    var usize i=0;
    while(i<16) {
        if(i!=source && (state.tokens[child+i].generation!=0 || state.tokens[child+i].slot!=0)) {return .err(errors::make(5,offset));}
        i+=1;
    }
    let owners::Token token=state.tokens[child+source];
    let usize checked=switch(owners::validate_result(ref state.owners,token,p.arrays.elements[shape],p.arrays.lengths[shape],bytes::view(buffer))) {
        case .ok(n):{n} case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return .ok(Transfer{.token=token,.child=child+source,.parent=parent,.bytes=checked});
}

// Infallible publication after preparation and any canonical loan restoration.
pub fn usize publish(ref Transfer plan,ref mut arrays::State state) {
    state.tokens[plan.child]=owners::Token{.slot=0,.generation=0};
    state.tokens[plan.parent]=plan.token;
    return plan.bytes;
}
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize target,usize source,usize destination,usize frame,
    ref mut arrays::State state,ref bytes::Buffer buffer,usize offset) {
    let Transfer plan=prepare(p,target,source,destination,frame,state,buffer,offset)?;
    return .ok(publish(ref plan,state));
}
