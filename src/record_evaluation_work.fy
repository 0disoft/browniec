module record_evaluation_work;
import lexer as lexer;
import struct_value_source as records;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// Actual constructor field values. Metadata/aggregate children stay explicit:
// 1 next leaf, 2 scalar expression, 3 aggregate child, 4 leaf count, 5 advance.
pub struct State { records::Initializer initializer; usize[16] slots; usize root; usize at;
    usize depth; usize leaves; usize row; usize value; usize visits; u8 tag; u8 phase; u8 request; bool done; }
pub fn State begin(usize root,usize at,usize depth){return State{.initializer=records::initializer(root),.slots=[0;16],.root=root,.at=at,
    .depth=depth,.leaves=0,.row=0,.value=0,.visits=0,.tag=0,.phase=0,.request=0,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.leaves);}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value){if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}
    w.request=0;w.value=value;return .ok(value);}
fn Result<bool,errors::Error> ask(ref mut State w,u8 request,u8 phase){w.request=request;w.phase=phase;return .ok(false);}
pub fn Result<bool,errors::Error> advance(ref mut ir::Program p,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){if(w.depth>32){return .err(errors::make(4,w.at));}return ask(w,4,1);}
    if(w.phase==1){w.leaves=w.value;w.phase=2;return .ok(false);}
    if(w.phase==2){let u8 phase=if(w.row<w.leaves){3}else{9};return ask(w,1,phase);}
    if(w.phase==3){if(w.tag==255){return ask(w,3,7);}let usize slot=ir::slot(p,w.tag,w.at)?;let usize row=w.row;w.slots[row]=slot;return ask(w,2,4);}
    if(w.phase==4){if(p.types[w.value]!=w.tag){return .err(errors::make(3,w.at));}w.phase=5;return .ok(false);}
    if(w.phase==5){let usize stored=ir::raw(p,18,w.slots[w.row],w.value,0,w.at)?;w.row+=1;return ask(w,5,6);}
    if(w.phase==6){w.phase=2;return .ok(false);}
    if(w.phase==7){w.row+=w.value;w.phase=2;return .ok(false);}
    if(w.phase==9){if(w.tag!=0){return .err(errors::make(3,w.at));}w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
