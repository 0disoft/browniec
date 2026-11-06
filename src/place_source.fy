module place_source;
import ir as ir;
import locals as locals;
import errors as errors;

// Compiler construction state only. Final IR independently proves every ID,
// selecting PC, root and phase. This mask consumes no guest local/register.
pub fn Result<usize,errors::Error> select(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize index,usize at){
    if(names.pending_places>65535){return .err(errors::make(4,at));}
    let usize one=1;var usize id=0;
    while(id<16 && (names.pending_places&(one<<id))!=0){id+=1;}
    if(id==16){return .err(errors::make(4,at));}
    let usize selected=ir::place_select(p,id,root,index,at)?;
    names.pending_places|=one<<id;return .ok(id);
}
pub fn Result<usize,errors::Error> end(ref mut ir::Program p,ref mut locals::Table names,usize id,usize at){
    let usize one=1;
    if(id>=16 || names.pending_places>65535 || (names.pending_places&(one<<id))==0){return .err(errors::make(3,at));}
    let usize ended=ir::place_end(p,id,at)?;
    names.pending_places&=~(one<<id);return .ok(ended);
}
// Exit emission never mutates lexical construction state: other value arms
// still compile from the same pending set. Aborts use runtime drain instead.
pub fn Result<usize,errors::Error> release(ref locals::Table names,ref mut ir::Program p,usize keep,usize at){
    if(names.pending_places>65535 || (keep&~names.pending_places)!=0){return .err(errors::make(3,at));}
    let usize pending=names.pending_places&~keep;
    if(pending==0){return .ok(0);}
    let usize one=1;var usize id=16;var usize count=0;
    while(id>0){id-=1;if((pending&(one<<id))!=0){let usize ended=ir::place_end(p,id,at)?;count+=1;}}
    return .ok(count);
}
// Loop metadata reuses its existing word: seven low bits hold 0..64 bindings,
// then sixteen bits hold selections surrounding the loop. A break/continue
// preserves those selections even when the body declares no additional locals.
pub fn usize scope(ref locals::Table names){return names.count|(names.pending_places<<7);}
pub fn Result<usize,errors::Error> leave_loop(ref locals::Table names,ref mut ir::Program p,usize scope,usize at){
    let usize first=scope&127;let usize keep=scope>>7;
    if(first>64 || first>names.count || keep>65535){return .err(errors::make(3,at));}
    let usize ended=release(names,p,keep,at)?;return .ok(first);
}
