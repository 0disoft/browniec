module destination_place_work;
import ir as ir;
import locals as locals;
import slice_place_ir as slices;
import aggregate_place_ir as aggregates;
import errors as errors;
import metadata_budget as budget;
import std::num as num;
// One pending bit, record-metadata request, SELECT transaction or publication
// per stage. Parent advances cannot replay a pending metadata request.
pub struct State { usize root; usize index; usize nominal; usize at; usize id; usize pc;
    usize visits; u8 kind; u8 phase; u8 request; bool done; }
pub fn State begin(u8 kind,usize root,usize index,usize nominal,usize at){return State{
    .root=root,.index=index,.nominal=nominal,.at=at,.id=0,.pc=0,.visits=0,.kind=kind,.phase=0,.request=0,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.id);}
pub fn Result<usize,errors::Error> resume(ref mut State w){if(w.done || w.request!=1){return .err(errors::make(5,w.at));}
    w.request=0;return .ok(0);}
fn Result<u8,errors::Error> leaf(ref State w){let u8 kind=if(w.kind==2){3}else{5};
    let i64 wide=switch(num::i64_from_usize(w.index)){case .ok(v):{v}case .err(_):{return .err(errors::make(kind,w.at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(kind,w.at))}};
}
pub fn Result<bool,errors::Error> advance(ref mut ir::Program p,ref mut locals::Table names,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(w.request!=0 || meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){if(w.kind>4){return .err(errors::make(5,w.at));}
        if(names.pending_places>65535){return .err(errors::make(4,w.at));}w.phase=1;return .ok(false);}
    if(w.phase==1){if(w.id==16){return .err(errors::make(4,w.at));}let usize one=1;
        if((names.pending_places&(one<<w.id))!=0){w.id+=1;}else{w.phase=2;}return .ok(false);}
    if(w.phase==2){w.phase=3;if(w.kind==2 || w.kind==4){w.request=1;}return .ok(false);}
    if(w.phase==3){if(w.kind==2 || w.kind==4){let u8 ordinal=leaf(w)?;
            w.pc=ir::raw(p,83,w.id,w.root,if(w.kind==4){w.nominal}else{0},w.at)?;
            p.code[w.pc*8+4]=w.kind;p.code[w.pc*8+5]=ordinal;
            if(w.kind==4){p.code[w.pc*8+6]=0;p.code[w.pc*8+7]=0;}
        }else if(w.kind==3){w.pc=aggregates::select_array(p,w.id,w.root,w.at)?;}
        else if(w.kind==1){w.pc=slices::select(p,w.id,w.root,w.index,w.at)?;}
        else{w.pc=ir::place_select(p,w.id,w.root,w.index,w.at)?;}
        w.phase=4;return .ok(false);}
    if(w.phase==4){let usize one=1;names.pending_places|=one<<w.id;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
