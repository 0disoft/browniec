module value_view_source;
import value_ir as values;
import value_source_bindings as bindings;
import value_view_bindings as views;
import value_source_context as context;
import value_buffer_source as buffers;
import value_buffer_source_ops as buffer_ops;
import lexer as lexer;
import errors as errors;
import ir as ir;
import value_view_source_work as work;
import metadata_budget as budget;

// The compiler-only reference domain is separate from the canonical owning DAG.
// 64 remains the existing inferred context; 65 denotes readonly ref u8[].
pub fn usize type_id(){return 65;}
pub fn bool reference(context::Value value){return !value.nothing && !value.typed && value.exact==65;}
pub fn context::Value value(usize id,usize binding){
    return context::Value{.exact=65,.value=id,.typed=false,.nothing=false,.bottom=false,.binding=binding};
}
fn errors::Error wrong(usize at){return errors::make(3,at);}
pub fn Result<usize,errors::Error> annotation(ref u8[] source,ref mut lexer::State s){
    let usize at=s.begin;let usize keyword=lexer::word(source,s,b"ref")?;
    if(s.kind==2 && lexer::equal(source[s.begin..s.end],b"mut")){return .err(wrong(at));}
    let usize byte=lexer::word(source,s,b"u8")?;
    let usize open=lexer::punctuation(source,s,91)?;let usize close=lexer::punctuation(source,s,93)?;
    return .ok(type_id());
}
pub fn Result<bool,errors::Error> range_ahead_raw(ref u8[] source,ref lexer::State s){
    if(s.kind!=46){return .ok(false);}var lexer::State look=lexer::snapshot(s);
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==46);
}
pub fn Result<context::Value,errors::Error> begin_raw(ref mut values::Program unit,ref mut bindings::State state,
    buffers::Reference loan,usize exact,usize at){
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(loan.writing || (exact!=64 && exact!=65)){return .err(wrong(at));}
    let usize ended=buffers::end(state,loan,at)?;
    let usize lo=ir::integer(ref mut unit.body,0,12,at)?;
    let usize hi=buffer_ops::scalar(unit,state,99,loan.slot,0,at)?;
    let usize id=views::begin(unit,ref mut state.views,loan.slot,lo,hi,at)?;
    return .ok(value(id,64));
}
pub fn Result<context::Value,errors::Error> named(ref bindings::State state,usize index,usize at){
    if(index>=state.names.count || state.views.names[index]==0){return .err(wrong(at));}
    let usize id=(state.views.names[index] as usize)-1;
    let usize roots=views::roots(ref state.views,id,at)?;
    let usize locals=views::local_roots(ref state.views,id);
    if(state.next>16 || state.views.function!=state.names.function ||
        (locals&(state.live|state.maybe))!=locals || (locals>>state.next)!=0){return .err(wrong(at));}
    return .ok(value(id,index));
}
// Capture BEFORE evaluating an index/endpoint. A later expression can rebind
// the lexical reference without changing this receiver's bytes or root lease.
pub fn Result<usize,errors::Error> capture(ref mut values::Program unit,ref mut bindings::State state,
    context::Value input,usize at){
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(!reference(input)){return .err(wrong(at));}
    let usize roots=views::roots(ref state.views,input.value,at)?;
    if(input.binding==64){return .ok(input.value);}
    let context::Value checked=named(state,input.binding,at)?;
    if(checked.value!=input.value){return .err(wrong(at));}
    return views::alias(unit,ref mut state.views,input.value,at);
}
pub fn Result<usize,errors::Error> lexical_origin(ref bindings::State state,usize id,usize at){
    let usize checked=lexical_roots(state,id,at)?;return views::origin(ref state.views,id,at);
}
pub fn Result<usize,errors::Error> lexical_roots_raw(ref bindings::State state,usize id,usize at){
    let usize roots=views::roots(ref state.views,id,at)?;
    if(state.next>16 || state.names.count>64 || state.views.function!=state.names.function){return .err(wrong(at));}
    let usize locals=views::local_roots(ref state.views,id);
    let usize retained=views::retained_roots(ref state.views,id);let usize one=1;var usize owner=0;
    while(owner<16){let usize bit=one<<owner;if((locals&bit)!=0){
        if(owner>=state.next || ((state.live|state.maybe)&bit)==0){return .err(wrong(at));}
        var bool allowed=(retained&bit)!=0;var usize i=0;
        while(i<state.names.count){if(state.bindings[i] as usize==owner+1){allowed=true;}i+=1;}
        if(!allowed){return .err(wrong(at));}
    }owner+=1;}
    // A view of an anonymous Buffer may be inspected within its full expression,
    // but only an explicit CALL result may extend that temporary into a name.
    return .ok(roots);
}
pub fn Result<context::Value,errors::Error> length_raw(ref u8[] source,ref mut lexer::State s,
    ref mut values::Program unit,ref mut bindings::State state,context::Value input){
    let usize at=s.begin;
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    let usize dot=lexer::next(source,s)?;
    let usize name=lexer::word(source,s,b"len")?;
    let usize roots=views::roots(ref state.views,input.value,at)?;
    let usize result=views::scalar(unit,ref state.views,110,input.value,0,at)?;
    if(input.binding==64){let usize closed=bindings::close_view(unit,state,input.value,at)?;}
    let usize type=context::intern(unit,1,12,0,at)?;return .ok(context::scalar(type,result));
}
pub fn Result<context::Value,errors::Error> indexed_raw(ref mut values::Program unit,ref mut bindings::State state,
    usize receiver,usize lo,usize hi,bool range,usize at){
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(range){let usize id=views::range(unit,ref mut state.views,receiver,lo,hi,at)?;
        let usize closed=bindings::close_view(unit,state,receiver,at)?;return .ok(value(id,64));
    }
    let usize result=views::scalar(unit,ref state.views,111,receiver,lo,at)?;
    let usize closed=bindings::close_view(unit,state,receiver,at)?;
    let usize type=context::intern(unit,1,10,0,at)?;return .ok(context::scalar(type,result));
}

pub fn Result<bool,errors::Error> range_ahead(ref u8[] source,ref lexer::State s){var work::Range w=work::range(*s);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,s.begin)?;let bool done=work::advance_range(source,ref mut w,ref mut meter)?;}return .ok(w.result);}
fn Result<context::Value,errors::Error> drain(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,ref mut work::Effect w){var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,w.at)?;let bool done=work::advance_effect(source,s,unit,state,w,ref mut meter)?;if(w.request!=0){let bool serviced=work::service_effect(source,s,unit,state,w)?;}}return work::effect_result(w);}
pub fn Result<context::Value,errors::Error> begin(ref mut values::Program unit,ref mut bindings::State state,buffers::Reference loan,usize exact,usize at){
    var work::Effect w=work::effect(0,context::nothing(),loan,exact,0,0,false,at);var lexer::State s=lexer::empty();return drain(b"",ref mut s,unit,state,ref mut w);}
pub fn Result<context::Value,errors::Error> length(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,context::Value input){
    var work::Effect w=work::effect(1,input,buffers::none(),64,0,0,false,s.begin);return drain(source,s,unit,state,ref mut w);}
pub fn Result<context::Value,errors::Error> indexed(ref mut values::Program unit,ref mut bindings::State state,usize receiver,usize lo,usize hi,bool range,usize at){
    var work::Effect w=work::effect(2,value(receiver,64),buffers::none(),64,lo,hi,range,at);var lexer::State s=lexer::empty();return drain(b"",ref mut s,unit,state,ref mut w);}
pub struct Lexical { usize roots; usize locals; usize retained; usize owner; usize row; usize id; usize at; u8 phase; u8 request; bool allowed; bool done; }
pub fn Lexical lexical(usize id,usize at){return Lexical{.roots=0,.locals=0,.retained=0,.owner=0,.row=0,.id=id,.at=at,.phase=0,.request=0,.allowed=false,.done=false};}
pub fn Result<bool,errors::Error> advance_lexical(ref bindings::State state,ref mut Lexical w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}if(!budget::admit(meter,4096,w.at)?){return .ok(false);}let usize at=w.at;
    if(w.phase==0){w.request=1;w.phase=1;return .ok(false);}
    if(w.phase==1){if(state.next>16 || state.names.count>64 || state.views.function!=state.names.function){return .err(wrong(at));}
        w.locals=views::local_roots(ref state.views,w.id);w.retained=views::retained_roots(ref state.views,w.id);w.phase=2;return .ok(false);}
    if(w.phase==2){if(w.owner==16){w.done=true;return .ok(true);}let usize one=1;let usize bit=one<<w.owner;
        if((w.locals&bit)!=0){if(w.owner>=state.next || ((state.live|state.maybe)&bit)==0){return .err(wrong(at));}w.allowed=(w.retained&bit)!=0;w.row=0;w.phase=3;}
        else{w.owner+=1;}return .ok(false);}
    if(w.phase==3){if(w.row==state.names.count){if(!w.allowed){return .err(wrong(at));}w.owner+=1;w.phase=2;return .ok(false);}
        if(state.bindings[w.row] as usize==w.owner+1){w.allowed=true;}w.row+=1;return .ok(false);}return .err(errors::make(5,at));
}
pub fn Result<usize,errors::Error> lexical_roots(ref bindings::State state,usize id,usize at){var Lexical w=lexical(id,at);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,at)?;let bool done=advance_lexical(state,ref mut w,ref mut meter)?;if(w.request!=0){let usize serviced=service_lexical(state,ref mut w)?;}}return .ok(w.roots);}

pub fn Result<usize,errors::Error> service_lexical(ref bindings::State state,ref mut Lexical w){if(w.done || w.request!=1){return .err(errors::make(5,w.at));}
    let usize roots=views::roots(ref state.views,w.id,w.at)?;w.roots=roots;w.request=0;return .ok(roots);}
