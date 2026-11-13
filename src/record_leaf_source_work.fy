module record_leaf_source_work;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// One original DFS visit per admission, including pop and error visits.
pub struct State { usize[16] records; usize[16] fields; usize depth; usize count; usize visits; usize at; bool done; }
pub fn State begin(usize root,usize at){var State w=State{.records=[0;16],.fields=[0;16],.depth=1,.count=0,.visits=0,.at=at,.done=false};w.records[0]=root;return w;}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.count);}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.visits>=4096){return .err(errors::make(4,w.at));}w.visits+=1;
    let usize level=w.depth-1;let usize record=w.records[level];
    if(record>=p.records.layouts.count){return .err(errors::make(3,w.at));}
    if(w.fields[level]>=p.records.layouts.fields[record] as usize){w.depth-=1;if(w.depth==0){w.done=true;}return .ok(w.done);}
    let usize slot=record*16+w.fields[level];w.fields[level]+=1;
    if(p.records.layouts.kinds[slot]==0){if(w.count>=16){return .err(errors::make(4,w.at));}w.count+=1;}
    else{if(w.depth>=16){return .err(errors::make(4,w.at));}let usize child_depth=w.depth;w.records[child_depth]=p.records.layouts.types[slot] as usize;w.fields[child_depth]=0;w.depth+=1;}
    return .ok(false);
}
