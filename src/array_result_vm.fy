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
// Verified ARET retains only its result owner. All fallible work precedes both
// token writes. The descriptor, generation, arena and payload remain unchanged.
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize target,usize source,usize destination,usize frame,
    ref mut arrays::State state,ref bytes::Buffer buffer,usize offset) {
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
    state.tokens[child+source]=owners::Token{.slot=0,.generation=0};
    state.tokens[parent]=token;
    return .ok(checked);
}
