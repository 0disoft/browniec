module array_results;

import ir as ir;
import errors as errors;
import runtime_clock as clock;
import array_parameters as parameters;

fn bool shape(ref ir::Program p,usize a,usize b) {
    return p.arrays.elements[a]==p.arrays.elements[b] && p.arrays.lengths[a]==p.arrays.lengths[b];
}
// Catalog ownership and register partitions have already been checked.
pub fn Result<usize,errors::Error> metadata(ref ir::Program p) {
    return metadata_until(p,0);
}
pub fn Result<usize,errors::Error> metadata_until(ref ir::Program p,usize deadline) {
    var usize f=0;var usize count=0;
    while(f<16) {
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize encoded=p.array_results[f] as usize;
        if(encoded!=0) {
            if(f>=p.function_count || f==p.entry || encoded>p.arrays.count) {return .err(errors::make(5,0));}
            let usize id=encoded-1;
            if(p.array_functions[id] as usize!=f || p.return_types[f]!=p.arrays.elements[id]) {return .err(errors::make(5,0));}
            count+=1;
        }
        f+=1;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return .ok(count);
}
pub fn Result<usize,errors::Error> call(ref ir::Program p,usize target,usize dst,usize f,usize live,usize pc) {
    if(dst<128 || target>=p.function_count || p.array_results[target]==0) {return .err(errors::make(5,pc));}
    let usize id=dst-128;
    let usize result=(p.array_results[target] as usize)-1;
    if(id>=p.arrays.count || p.array_functions[id] as usize!=f || !shape(p,id,result)) {return .err(errors::make(5,pc));}
    let usize one=1;let usize mask=one<<id;
    if((live & mask)!=0 || (parameters::initial(p,f) & mask)!=0) {return .err(errors::make(5,pc));}
    return .ok(live|mask);
}
pub fn Result<usize,errors::Error> returned(ref ir::Program p,usize source,usize f,usize live,usize pc) {
    let usize encoded=p.array_results[f] as usize;
    if(encoded==0 || source>=p.arrays.count || p.array_functions[source] as usize!=f) {return .err(errors::make(5,pc));}
    let usize one=1;
    if(live!=(one<<source) || !shape(p,source,encoded-1)) {return .err(errors::make(5,pc));}
    return .ok(source);
}
