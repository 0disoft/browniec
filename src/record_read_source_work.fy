module record_read_source_work;
import ir as ir;
import output_record_metadata_work as metadata;
import errors as errors;
import metadata_budget as budget;
// Reuse the proved layout/flatten cursor; no new SDK scratch class or Bank field.
// Catalog authentication precedes operand checks, preserving raw error priority.
pub struct State { metadata::State metadata; usize id; usize leaf; usize at;
    usize value; usize visits; u8 phase; bool done; }
pub fn State begin(usize id,usize leaf,usize at){return State{.metadata=metadata::empty(),
    .id=id,.leaf=leaf,.at=at,.value=0,.visits=0,.phase=0,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<bool,errors::Error> advance(ref mut ir::Program p,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=metadata::advance(ref mut w.metadata,ref p.records,meter)?;
        if(done){w.phase=2;}return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){let usize started=metadata::begin(ref mut w.metadata,ref p.records)?;w.phase=1;return .ok(false);}
    if(w.phase==2){if(w.id>=p.records.count || w.leaf>=w.metadata.result.leaves[w.id]){return .err(errors::make(3,w.at));}
        w.phase=3;return .ok(false);}
    if(w.phase==3){w.value=ir::emit(p,43,w.id,w.leaf,w.at)?;w.phase=4;return .ok(false);}
    if(w.phase==4){let u8 tag=w.metadata.result.tags[w.id*128+w.leaf];let usize value=w.value;
        p.types[value]=tag;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
