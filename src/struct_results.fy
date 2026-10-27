module struct_results;
import ir as ir;
import errors as errors;
import struct_parameters as parameters;

// Catalog ownership and function/register partitions have already been checked.
pub fn Result<usize,errors::Error> metadata(ref ir::Program p) {
    var usize f=0;var usize count=0;
    while(f<16) {
        let usize encoded=p.record_results[f] as usize;
        if(encoded!=0) {
            if(f>=p.function_count || f==p.entry || encoded>p.records.count ||
                p.array_results[f]!=0 || p.return_types[f]!=0) {return .err(errors::make(5,0));}
            if(p.record_functions[encoded-1] as usize!=f) {return .err(errors::make(5,0));}
            count+=1;
        }
        f+=1;
    }
    return .ok(count);
}
pub fn Result<usize,errors::Error> call(ref ir::Program p,usize target,usize dst,usize f,usize live,usize pc) {
    if(dst<144 || target>=p.function_count || p.record_results[target]==0) {return .err(errors::make(5,pc));}
    let usize id=dst-144;let usize shape=(p.record_results[target] as usize)-1;
    if(id>=p.records.count || p.record_functions[id] as usize!=f ||
        p.records.records[id]!=p.records.records[shape]) {return .err(errors::make(5,pc));}
    let usize one=1;let usize mask=one<<(16+id);
    if((live & mask)!=0 || (parameters::initial(p,f) & mask)!=0) {return .err(errors::make(5,pc));}
    return .ok(live|mask);
}
pub fn Result<usize,errors::Error> returned(ref ir::Program p,usize source,usize f,usize live,usize pc) {
    let usize encoded=p.record_results[f] as usize;
    if(encoded==0 || source>=p.records.count || p.record_functions[source] as usize!=f) {return .err(errors::make(5,pc));}
    let usize one=1;
    if(live!=(one<<(16+source)) || p.records.records[source]!=p.records.records[encoded-1]) {return .err(errors::make(5,pc));}
    return .ok(source);
}
