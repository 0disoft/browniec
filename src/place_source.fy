module place_source;
import ir as ir;
import destination_place_work as destinations;
import destination_record_work as metadata;
import metadata_budget as budget;
import slice_place_ir as slices;
import record_place_ir as records;
import aggregate_place_ir as aggregates;
import locals as locals;
import errors as errors;

// Ten statement-only integer compounds reuse existing checked scalar operations.
pub fn u8 compound(u8 kind){
    if(kind>=136 && kind<=140){return kind-134;}
    if(kind==141){return 31;}if(kind==142){return 32;}
    if(kind==143){return 28;}if(kind==144){return 29;}if(kind==145){return 30;}
    return 0;
}

// Compiler construction state only. Final IR independently proves every ID,
// selecting PC, root and phase. This mask consumes no guest local/register.
pub fn Result<usize,errors::Error> select(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize index,usize at){
    return select_kind(p,names,root,index,at,0,0);
}
pub fn Result<usize,errors::Error> slice(ref mut ir::Program p,ref mut locals::Table names,
    usize site,usize index,usize at){
    return select_kind(p,names,site,index,at,1,0);
}
pub fn Result<usize,errors::Error> record(ref mut ir::Program p,ref mut locals::Table names,
    usize site,usize ordinal,usize at){return select_kind(p,names,site,ordinal,at,2,0);}
pub fn Result<usize,errors::Error> array(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize at){return select_kind(p,names,root,0,at,3,0);}
pub fn Result<usize,errors::Error> record_value(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize nominal,usize ordinal,usize at){return select_kind(p,names,root,ordinal,at,4,nominal);}
pub fn Result<usize,errors::Error> select_kind_raw(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize index,usize at,u8 kind,usize nominal){
    if(names.pending_places>65535){return .err(errors::make(4,at));}
    let usize one=1;var usize id=0;
    while(id<16 && (names.pending_places&(one<<id))!=0){id+=1;}
    if(id==16){return .err(errors::make(4,at));}
    let usize selected=if(kind==4){aggregates::select_record_raw(p,id,root,nominal,index,at)?}
        else if(kind==3){aggregates::select_array(p,id,root,at)?}else if(kind==2){records::select_raw(p,id,root,index,at)?}
        else if(kind==1){slices::select(p,id,root,index,at)?}else{ir::place_select(p,id,root,index,at)?};
    names.pending_places|=one<<id;return .ok(id);
}
fn Result<usize,errors::Error> select_kind(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize index,usize at,u8 kind,usize nominal){
    var destinations::State w=destinations::begin(kind,root,index,nominal,at);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;
        let bool done=destinations::advance(p,names,ref mut w,ref mut meter)?;
        if(w.request==1){let u8 checked=metadata::prepare(p,kind,root,nominal,index,at)?;let usize resumed=destinations::resume(ref mut w)?;}}
    return destinations::prepared(ref w);
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
