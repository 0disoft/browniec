module value_view_source_work;
import value_source_context as context;
import value_source_bindings as bindings;
import value_buffer_source as buffers;
import value_buffer_source_ops as buffer_ops;
import value_view_bindings as views;
import value_ir as values;
import lexer as lexer;
import lexer_work as tokens;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
pub struct Range { tokens::State token; u8 phase; bool dot; bool result; bool done; }
pub fn Range range(lexer::State s){return Range{.token=tokens::begin(s),.phase=0,.dot=s.kind==46,.result=false,.done=false};}
pub fn Result<bool,errors::Error> advance_range(ref u8[] source,ref mut Range w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=tokens::advance(source,ref mut w.token,meter)?;if(done){let lexer::State s=tokens::prepared(ref w.token)?;w.result=s.kind==46;w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}if(!w.dot){w.done=true;return .ok(true);}w.phase=1;return .ok(false);
}
pub struct Index { tokens::State token; context::Value child; usize at; usize depth; usize receiver; usize type; usize lo; usize hi; usize number; u8 phase; u8 request; bool range; bool lexing; bool done; }
pub fn Index index(context::Value input,usize depth,usize at){return Index{.token=tokens::begin(lexer::empty()),.child=input,.at=at,.depth=depth,.receiver=16,.type=64,.lo=0,.hi=0,.number=0,.phase=0,.request=0,.range=false,.lexing=false,.done=false};}
fn Result<bool,errors::Error> ask(ref mut Index w,u8 request,u8 phase){w.request=request;w.phase=phase;return .ok(false);}
fn Result<bool,errors::Error> take(ref lexer::State s,ref mut Index w,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> resume_index(ref mut Index w,u8 request,context::Value child,usize number){if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.child=child;w.number=number;w.request=0;return .ok(number);}
pub fn Result<context::Value,errors::Error> index_result(ref Index w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.child);}
pub fn Result<bool,errors::Error> advance_index(ref u8[] source,ref mut lexer::State s,ref mut Index w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}let u8 phase=w.phase;
    if(phase==0){return ask(w,1,1);}if(phase==1){w.receiver=w.number;return take(s,w,0,2);}if(phase==2){return ask(w,2,3);}
    if(phase==3){w.type=w.number;return ask(w,3,4);}if(phase==4){if(w.number==1){return ask(w,4,5);}return ask(w,5,6);}
    if(phase==5){w.lo=w.number;w.phase=7;return .ok(false);}if(phase==6 || phase==13){if(w.child.bottom){return take(s,w,93,90);}return ask(w,6,if(phase==6){8}else{14});}
    if(phase==8){w.lo=w.number;w.phase=7;return .ok(false);}if(phase==7){return ask(w,3,9);}
    if(phase==9){w.range=w.number==1;if(w.range){return take(s,w,46,10);}return take(s,w,93,20);}
    if(phase==10){return take(s,w,46,11);}if(phase==11){if(s.kind==93){return ask(w,7,12);}return ask(w,5,13);}
    if(phase==12 || phase==14){w.hi=w.number;return take(s,w,93,20);}if(phase==20){return ask(w,8,81);}
    if(phase==81 || phase==90){w.done=true;return .ok(true);}return .err(errors::make(5,s.begin));
}
// Modes: Buffer loan to whole view, .len suffix, index/range result.
pub struct Effect { tokens::State token; context::Value input; context::Value result; buffers::Reference loan; usize exact; usize at; usize lo; usize hi; usize id; usize reg; usize type; u8 mode; u8 phase; u8 request; bool range; bool lexing; bool done; }
pub fn Effect effect(u8 mode,context::Value input,buffers::Reference loan,usize exact,usize lo,usize hi,bool range,usize at){return Effect{.token=tokens::begin(lexer::empty()),.input=input,.result=context::nothing(),.loan=loan,.exact=exact,.at=at,.lo=lo,.hi=hi,.id=16,.reg=0,.type=64,.mode=mode,.phase=0,.request=0,.range=range,.lexing=false,.done=false};}
fn context::Value view(usize id){return context::Value{.exact=65,.value=id,.typed=false,.nothing=false,.bottom=false,.binding=64};}
pub fn Result<context::Value,errors::Error> effect_result(ref Effect w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
pub fn Result<bool,errors::Error> advance_effect(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,ref mut Effect w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.request=1;return .ok(false);
}
pub fn Result<bool,errors::Error> service_effect(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,ref mut Effect w){
    if(w.done || w.request!=1){return .err(errors::make(5,w.at));}let u8 phase=w.phase;let usize at=w.at;
    if(phase==0){let usize checked=bindings::authenticate(unit,state,at)?;w.phase=1;w.request=0;return .ok(false);}
    if(w.mode==0){
        if(phase==1){if(w.loan.writing || (w.exact!=64 && w.exact!=65)){return .err(errors::make(3,at));}w.phase=2;}
        else if(phase==2){let usize ended=buffers::end(state,w.loan,at)?;w.phase=3;}
        else if(phase==3){w.lo=ir::integer(ref mut unit.body,0,12,at)?;w.phase=4;}
        else if(phase==4){w.hi=buffer_ops::scalar(unit,state,99,w.loan.slot,0,at)?;w.phase=5;}
        else if(phase==5){w.id=views::begin(unit,ref mut state.views,w.loan.slot,w.lo,w.hi,at)?;w.phase=7;}
        else if(phase==7){w.result=view(w.id);w.done=true;}else{return .err(errors::make(5,at));}w.request=0;return .ok(w.done);
    }
    if(w.mode==1){
        if(phase==1 || phase==2){if(phase==2 && (s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"len"))){return .err(errors::make(2,s.begin));}
            w.token=tokens::begin(*s);w.lexing=true;w.phase=phase+1;}
        else if(phase==3){let usize roots=views::roots(ref state.views,w.input.value,at)?;w.phase=4;}
        else if(phase==4){w.reg=views::scalar(unit,ref state.views,110,w.input.value,0,at)?;w.phase=5;}
        else if(phase==5){if(w.input.binding==64){let usize closed=bindings::close_view(unit,state,w.input.value,at)?;}w.phase=6;}
        else if(phase==6){w.type=context::intern(unit,1,12,0,at)?;w.phase=7;}
        else if(phase==7){w.result=context::scalar(w.type,w.reg);w.done=true;}else{return .err(errors::make(5,at));}w.request=0;return .ok(w.done);
    }
    if(w.mode==2){
        if(phase==1){if(w.range){w.id=views::range(unit,ref mut state.views,w.input.value,w.lo,w.hi,at)?;}
            else{w.reg=views::scalar(unit,ref state.views,111,w.input.value,w.lo,at)?;}w.phase=2;}
        else if(phase==2){let usize closed=bindings::close_view(unit,state,w.input.value,at)?;w.phase=if(w.range){7}else{6};}
        else if(phase==6){w.type=context::intern(unit,1,10,0,at)?;w.phase=7;}
        else if(phase==7){w.result=if(w.range){view(w.id)}else{context::scalar(w.type,w.reg)};w.done=true;}else{return .err(errors::make(5,at));}w.request=0;return .ok(w.done);
    }return .err(errors::make(5,at));
}
