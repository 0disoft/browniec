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
pub fn Result<bool,errors::Error> range_ahead(ref u8[] source,ref lexer::State s){
    if(s.kind!=46){return .ok(false);}var lexer::State look=lexer::snapshot(s);
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==46);
}
pub fn Result<context::Value,errors::Error> begin(ref mut values::Program unit,ref mut bindings::State state,
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
pub fn Result<usize,errors::Error> lexical_roots(ref bindings::State state,usize id,usize at){
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
pub fn Result<context::Value,errors::Error> length(ref u8[] source,ref mut lexer::State s,
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
pub fn Result<context::Value,errors::Error> indexed(ref mut values::Program unit,ref mut bindings::State state,
    usize receiver,usize lo,usize hi,bool range,usize at){
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(range){let usize id=views::range(unit,ref mut state.views,receiver,lo,hi,at)?;
        let usize closed=bindings::close_view(unit,state,receiver,at)?;return .ok(value(id,64));
    }
    let usize result=views::scalar(unit,ref state.views,111,receiver,lo,at)?;
    let usize closed=bindings::close_view(unit,state,receiver,at)?;
    let usize type=context::intern(unit,1,10,0,at)?;return .ok(context::scalar(type,result));
}
