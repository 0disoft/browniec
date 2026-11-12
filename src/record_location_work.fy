module record_location_work;
import struct_locate_work as single;
import source_context as context;
import source_context_check_work as checking;
import source_name_work as names;
import source_state_work as states;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
// Resumable locate_scoped, including the single-source declaration walk.
pub struct State { single::State single; checking::State check; names::State name; states::State state;
    tokens::State scan; lexer::State token; usize begin; usize selected; usize record; usize body; u8 phase; bool done; }
pub fn State begin(usize a,usize b,usize selected){return State{.single=single::begin(a,b,selected),.check=checking::empty(),
    .name=names::begin(a,b,true),.state=states::begin(0),.scan=tokens::begin(lexer::empty()),.token=lexer::empty(),
    .begin=a,.selected=selected,.record=32,.body=0,.phase=0,.done=false};}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(scope.modules==0){let bool done=single::advance(source,ref mut w.single,meter)?;if(done){let single::Location v=single::prepared(ref w.single)?;
            w.record=v.record;w.body=v.body;w.done=true;}return .ok(done);}
    if(w.phase==0){let bool done=checking::advance(source,scope,ref mut w.check,meter)?;
        if(done){if(!w.check.result){return .err(errors::make(5,w.begin));}w.phase=if(w.selected<32){2}else{1};}return .ok(false);}
    if(w.phase==1){let bool done=names::advance(source,scope,ref mut w.name,meter)?;if(done){w.phase=2;}return .ok(false);}
    if(w.phase==3){let bool done=states::advance(source,scope,ref mut w.state,meter)?;
        if(done){let lexer::State s=states::prepared(ref w.state)?;w.scan=tokens::begin(s);w.phase=4;}return .ok(false);}
    if(w.phase==4 || w.phase==5 || w.phase==7){let bool done=tokens::advance(source,ref mut w.scan,meter)?;
        if(done){w.token=tokens::prepared(ref w.scan)?;let lexer::State s=w.token;
            if(w.phase==4){w.scan=tokens::begin(s);w.phase=5;}else{w.phase=if(w.phase==5){6}else{8};}}return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==2){let usize id=if(w.selected<32){w.selected}else{w.name.result};
        if(id>=scope.record_count){w.done=true;return .ok(true);}w.record=id;
        w.state=states::begin(context::begin(scope.records[id]));w.phase=3;return .ok(false);}
    if(w.phase==6){if(w.token.kind!=123){return .err(errors::make(2,w.token.begin));}let lexer::State s=w.token;w.scan=tokens::begin(s);w.phase=7;return .ok(false);}
    if(w.phase==8){w.body=w.token.begin;w.done=true;return .ok(true);}return .err(errors::make(5,w.begin));
}
