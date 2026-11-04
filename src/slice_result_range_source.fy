module slice_result_range_source;
import ir as ir;
import slice_builders as shared;
import slice_reborrow_ir as exclusive;
import errors as errors;
import lexer as lexer;

pub struct Bounds { usize lo; usize hi; }

// Select the existing terminal-forward path unless a CALL really has a range
// suffix. The bounded lexical snapshot never evaluates arguments or endpoints.
pub fn Result<bool,errors::Error> follows(ref u8[] source,ref lexer::State s){
    if(s.kind!=40){return .err(errors::make(2,s.begin));}
    var lexer::State look=lexer::snapshot(s);var usize depth=1;
    while(depth!=0){let usize advanced=lexer::next(source,ref mut look)?;
        if(look.kind==0){return .err(errors::make(2,s.begin));}
        if(look.kind==40){depth+=1;}else if(look.kind==41){depth-=1;}
    }
    let usize after=lexer::next(source,ref mut look)?;return .ok(look.kind==91);
}

// Anonymous return ranges use the same site metadata and lexical proof as a
// named subview. Endpoint expressions have completed before acquisition.
pub fn Result<usize,errors::Error> acquire(ref mut ir::Program p,usize parent,
    usize function,usize lo,usize hi,usize offset){
    if(parent>=16){return .err(errors::make(3,offset));}
    let usize root=p.slice_roots[parent] as usize;
    if(root==0){
        if(p.slice_origins[parent]==0 || p.slice_functions[parent] as usize!=function+1){return .err(errors::make(3,offset));}
    }else if(root>16 || root>p.arrays.count || p.array_functions[root-1] as usize!=function ||
        p.slice_origins[parent]!=0 || p.slice_functions[parent]!=0){return .err(errors::make(3,offset));}
    let bool writer=ir::exclusive(p,parent);
    let usize child=if(writer){exclusive::derived(p,parent,offset)?}
        else if(root==0){shared::derived(p,parent,function,offset)?}
        else{ir::slice(p,root-1,offset)?};
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
