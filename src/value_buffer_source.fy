module value_buffer_source;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_context as context;
import value_buffer_source_ops as ops;
import value_source_ops as construction;
import lexer as lexer;
import locals as locals;
import errors as errors;

// Compiler-only argument loans. They never escape into guest values/authority.
pub struct Reference { usize slot; bool temporary; bool writing; usize reads; usize writes; }
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] value){return s.kind==2 && lexer::equal(source[s.begin..s.end],value);}
fn errors::Error wrong(usize at){return errors::make(3,at);}
fn usize bit(usize id){let usize one=1;return one<<id;}
pub fn Reference none(){return Reference{.slot=16,.temporary=false,.writing=false,.reads=0,.writes=0};}
pub fn Result<u8,errors::Error> operation(ref u8[] source,ref mut lexer::State s,ref bindings::State state){
    let usize at=s.begin;
    if(locals::find(source,ref state.names,s.begin,s.end)!=64){return .err(wrong(at));}
    if(word(source,s,b"brownie")){
        let usize name=lexer::next(source,s)?;let usize a=lexer::punctuation(source,s,58)?;
        let usize b=lexer::punctuation(source,s,58)?;
    }
    let usize namespace=lexer::word(source,s,b"bytes")?;
    let usize a=lexer::punctuation(source,s,58)?;let usize b=lexer::punctuation(source,s,58)?;
    let u8 op=if(word(source,s,b"empty")){95}else if(word(source,s,b"len")){99}
        else if(word(source,s,b"read")){100}else if(word(source,s,b"write")){101}
        else if(word(source,s,b"push")){102}else if(word(source,s,b"reserve")){103}
        else if(word(source,s,b"append")){104}else if(word(source,s,b"copy")){105}else{0};
    if(op==0){return .err(wrong(s.begin));}let usize name=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;return .ok(op);
}
pub fn Result<usize,errors::Error> prefix(ref u8[] source,ref mut lexer::State s,bool writing){
    let usize at=s.begin;if(!word(source,s,b"ref")){return .err(wrong(at));}
    let usize keyword=lexer::next(source,s)?;
    if(writing!=word(source,s,b"mut")){return .err(wrong(at));}
    if(writing){let usize modifier=lexer::next(source,s)?;}return .ok(at);
}
pub fn Result<Reference,errors::Error> begin(ref values::Program unit,ref mut bindings::State state,
    context::Value value,bool writing,usize at){
    if(value.nothing || !value.typed || value.exact>=unit.catalog.count ||
        unit.catalog.nodes[value.exact].kind!=4 || value.value>=state.next ||
        !values::slot(unit,value.value,state.names.function) ||
        values::type_id(unit,value.value)!=value.exact || (state.live&bit(value.value))==0){return .err(wrong(at));}
    if(value.binding!=64){let usize index=value.binding;
        if(index>=state.names.count || state.bindings[index] as usize!=value.value+1 ||
            state.names.registers[index]!=208+value.value || (writing && !state.names.mutable[index])){return .err(wrong(at));}
    }
    let usize mask=bit(value.value);
    if((state.writes&mask)!=0 || (writing && (state.reads&mask)!=0)){return .err(wrong(at));}
    let Reference result=Reference{.slot=value.value,.temporary=value.binding==64,
        .writing=writing,.reads=state.reads,.writes=state.writes};
    if(writing){state.writes|=mask;}else{state.reads|=mask;}return .ok(result);
}
pub fn Result<usize,errors::Error> end(ref mut bindings::State state,Reference loan,usize at){
    if(loan.slot>=16){return .err(wrong(at));}let usize mask=bit(loan.slot);
    if(state.reads!=if(loan.writing){loan.reads}else{loan.reads|mask} ||
        state.writes!=if(loan.writing){loan.writes|mask}else{loan.writes} ||
        (state.live&mask)==0){return .err(wrong(at));}
    state.reads=loan.reads;state.writes=loan.writes;return .ok(loan.slot);
}
pub fn Result<context::Value,errors::Error> empty(ref mut values::Program unit,ref mut bindings::State state,
    usize exact,usize at){
    let usize type=context::intern(unit,4,0,0,at)?;
    let context::Value expected=context::expected(context::owned(type,0),exact,at)?;
    let usize id=construction::empty_buffer(unit,state,type,at)?;return .ok(context::owned(type,id));
}
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,
    u8 op,Reference first,Reference second,usize index,usize value,usize exact,usize at){
    if(op==104){let usize ended=end(state,second,at)?;}
    let usize ended=end(state,first,at)?;var context::Value result=context::nothing();
    if(op==99 || op==100){
        let usize type=context::intern(unit,1,if(op==99){12}else{10},0,at)?;
        let usize register=ops::scalar(unit,state,op,first.slot,index,at)?;
        result=context::scalar(type,register);
    }else if(op==101){let usize emitted=ops::write(unit,state,first.slot,index,value,at)?;}
    else{
        let usize success=context::intern(unit,1,12,0,at)?;
        let usize failure=context::intern(unit,1,10,0,at)?;
        let usize type=context::intern(unit,6,context::byte(success),context::byte(failure),at)?;
        let context::Value expected=context::expected(context::owned(type,0),exact,at)?;
        let usize id=ops::grow(unit,state,op,type,first.slot,if(op==104){second.slot}else{value},at)?;
        result=context::owned(type,id);
    }
    if(op==104 && second.temporary){let usize dropped=bindings::drop(unit,state,second.slot,at)?;}
    if(first.temporary){let usize dropped=bindings::drop(unit,state,first.slot,at)?;}
    return if(op==99 || op==100){.ok(result)}else{context::expected(result,exact,at)};
}
