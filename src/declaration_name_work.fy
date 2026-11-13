module declaration_name_work;
import lexer as lexer;
import lexer_work as tokens;
import argument_name_work as lookup;
import locals as locals;
import errors as errors;
import metadata_budget as budget;
// mode 0 consumes a binder and equals; mode 1 is advisory inference lookahead.
// Names stay immutable and no IR/name publication occurs here.
pub struct State { tokens::State token; lookup::State name; usize begin; usize end;
    u8 mode; u8 phase; u8 resume; bool full; bool waiting; bool matched; bool done; }
pub fn State begin(lexer::State s,bool full,u8 mode){return State{.token=tokens::begin(s),.name=lookup::begin(0,0,64),
    .begin=0,.end=0,.mode=mode,.phase=0,.resume=0,.full=full,.waiting=false,.matched=false,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.begin));}return .ok(w.begin);}
fn void next(ref mut State w,ref lexer::State s,u8 phase){w.token=tokens::begin(*s);w.resume=phase;w.waiting=true;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref locals::Table names,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.waiting=false;w.phase=w.resume;}return .ok(false);}};}
    if(w.phase==1){let bool done=lookup::advance(source,ref names.begins,ref names.ends,names.count,ref mut w.name,meter)?;
        if(done){w.phase=2;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    if(w.phase==0){if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){
            if(w.mode==1){w.done=true;return .ok(true);}return .err(errors::make(2,s.begin));}
        w.begin=s.begin;w.end=s.end;
        if(w.mode==1){next(w,s,10);return .ok(false);}
        w.name=lookup::begin(s.begin,s.end,64);w.phase=1;return .ok(false);}
    if(w.phase==2){if(w.name.result!=64){return .err(errors::make(3,w.begin));}w.phase=3;return .ok(false);}
    if(w.phase==3){if(names.count>=64 || w.full){return .err(errors::make(4,w.begin));}next(w,s,4);return .ok(false);}
    if(w.phase==4){if(s.kind!=61){return .err(errors::make(2,s.begin));}next(w,s,5);return .ok(false);}
    if(w.phase==5){w.done=true;return .ok(true);}
    if(w.phase==10){w.matched=s.kind==61;w.done=true;return .ok(true);}
    return .err(errors::make(5,s.begin));
}
pub fn Result<usize,errors::Error> prepare(ref u8[] source,ref mut lexer::State s,ref locals::Table names,bool full){
    var State w=begin(*s,full,0);var budget::State meter=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=advance(source,s,names,ref mut w,ref mut meter)?;}return prepared(ref w);
}
pub fn Result<bool,errors::Error> follows(ref u8[] source,ref lexer::State s){var lexer::State look=*s;
    let locals::Table names=locals::empty();var State w=begin(look,false,1);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,look.begin)?;
        let bool done=advance(source,ref mut look,ref names,ref mut w,ref mut meter)?;}return .ok(w.matched);
}
