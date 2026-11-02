module slice_reborrow_admission_ir;
import ir as ir;
import errors as errors;
import slice_reborrow_ir as proof;

// Immutable classification after complete metadata and CALL descriptor proof.
pub fn bool required(ref ir::Program p,ref proof::Sites sites,usize pc){
    let usize target=p.code[pc*8+2] as usize;let usize args=p.code[pc*8+3] as usize;var usize i=0;
    while(i<p.arities[target]){
        let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0 && ir::exclusive(p,encoded-1)){
            let usize source=(p.call_args[args*8+i] as usize)-160;
            if(sites.parents[source]!=16){return true;}
        }
        i+=1;
    }
    return false;
}
// Executable subset shared by checked native and public admission. Ordinary
// CALLs retain owned arguments and aggregate results, even in a suspended scope.
pub fn Result<usize,errors::Error> call(ref ir::Program p,ref proof::Sites sites,usize pc){
    if(!required(p,sites,pc)){return .ok(0);}
    let usize target=p.code[pc*8+2] as usize;let usize offset=p.offsets[pc];
    if(p.array_results[target]!=0 || p.record_results[target]!=0){return .err(errors::make(5,offset));}
    var usize i=0;while(i<p.arities[target]){
        let usize formal=p.register_starts[target]+i;
        if(p.array_parameters[formal]!=0 || p.record_parameters[formal]!=0){return .err(errors::make(5,offset));}
        i+=1;
    }
    return .ok(0);
}
