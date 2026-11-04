module slice_result_range_source;
import ir as ir;
import slice_builders as shared;
import slice_reborrow_ir as exclusive;
import errors as errors;

// Anonymous return ranges use the same site metadata and lexical proof as a
// named subview. Endpoint expressions have completed before acquisition.
pub fn Result<usize,errors::Error> acquire(ref mut ir::Program p,usize parent,
    usize function,usize lo,usize hi,usize offset){
    if(parent>=16 || p.slice_roots[parent]!=0 || p.slice_origins[parent]==0 ||
        p.slice_functions[parent] as usize!=function+1){return .err(errors::make(3,offset));}
    let bool writer=ir::exclusive(p,parent);
    let usize child=if(writer){exclusive::derived(p,parent,offset)?}
        else{shared::derived(p,parent,function,offset)?};
    let usize opened=if(writer){exclusive::begin(p,child,parent,lo,hi,offset)?}
        else{ir::slice_sub(p,child,parent,lo,hi,offset)?};
    return .ok(child);
}
// Place this after preparation and before visible parent cleanup. The proxy
// verifier sees normal lexical cleanup; the returned-view VM hands it off in
// its existing transaction rather than prematurely closing the selected view.
pub fn Result<usize,errors::Error> release(ref mut ir::Program p,usize child,usize parent,usize offset){
    if(ir::exclusive(p,child)){return exclusive::end(p,child,parent,offset);}
    return ir::slice_close(p,child,offset);
}
