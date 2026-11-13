module record_field_source_work;
import record_location_work as location;
import source_state_work as states;
import lexer_work as tokens;
import lexer as lexer;
import source_context as context;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// Locate and reconstruct the declaration cursor using bounded children.
pub struct State { location::State locate; states::State state; tokens::State scan; lexer::State token;
    usize record; usize begin; usize end; usize row; usize compared; usize result; u8 phase; u8 resume; bool waiting; bool done; }
pub fn State begin(usize record,usize a,usize b){return State{.locate=location::begin(a,b,record),.state=states::begin(0),
    .scan=tokens::begin(lexer::empty()),.token=lexer::empty(),.record=record,.begin=a,.end=b,.row=0,.compared=0,.result=0,.phase=0,.resume=0,.waiting=false,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.begin));}return .ok(w.result);}
fn void next(ref mut State w,u8 resume){w.scan=tokens::begin(w.token);w.resume=resume;w.waiting=true;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref ir::Program p,ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let bool done=tokens::advance(source,ref mut w.scan,meter)?;if(done){w.token=tokens::prepared(ref w.scan)?;w.phase=w.resume;w.waiting=false;}return .ok(false);}
    if(w.phase==0){let bool done=location::advance(source,scope,ref mut w.locate,meter)?;if(done){w.phase=1;}return .ok(false);}
    if(w.phase==2){let bool done=states::advance(source,scope,ref mut w.state,meter)?;if(done){w.token=states::prepared(ref w.state)?;next(w,3);}return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==1){if(w.record>=p.records.layouts.count || w.locate.record!=w.record){return .err(errors::make(3,w.begin));}w.state=states::begin(w.locate.body);w.phase=2;return .ok(false);}
    if(w.phase==3){if(w.row>=p.records.layouts.fields[w.record] as usize){return .err(errors::make(3,w.begin));}next(w,4);return .ok(false);}
    if(w.phase==4){w.compared=0;w.phase=5;return .ok(false);}
    if(w.phase==5){let usize width=w.end-w.begin;let usize other=w.token.end-w.token.begin;
        if(width!=other){next(w,6);return .ok(false);}var usize n=0;
        while(w.compared<width && n<64){if(source[w.begin+w.compared]!=source[w.token.begin+w.compared]){next(w,6);return .ok(false);}w.compared+=1;n+=1;}
        if(w.compared==width){w.result=w.row;w.done=true;return .ok(true);}return .ok(false);}
    if(w.phase==6){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}next(w,7);return .ok(false);}
    if(w.phase==7){w.row+=1;w.phase=3;return .ok(false);}return .err(errors::make(5,w.begin));
}
