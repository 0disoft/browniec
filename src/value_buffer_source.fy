module value_buffer_source;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_context as context;
import value_buffer_source_ops as ops;
import value_source_ops as construction;
import lexer as lexer;
import locals as locals;
import errors as errors;
import value_view_bindings as views;
import metadata_budget as budget;

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
        else if(word(source,s,b"append")){104}else if(word(source,s,b"copy")){105}
        else if(word(source,s,b"view")){106}else{0};
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
    let usize checked=bindings::authenticate(unit,state,at)?;
    if(value.nothing || !value.typed || value.exact>=unit.catalog.count ||
        unit.catalog.nodes[value.exact].kind!=4 || value.value>=state.next ||
        !values::slot(unit,value.value,state.names.function) ||
        values::type_id(unit,value.value)!=value.exact || (state.live&bit(value.value))==0){return .err(wrong(at));}
    if(value.binding!=64){let usize index=value.binding;
        if(index>=state.names.count || state.bindings[index] as usize!=value.value+1 ||
            state.names.registers[index]!=208+value.value || (writing && !state.names.mutable[index])){return .err(wrong(at));}
    }
    let usize mask=bit(value.value);
    if((state.writes&mask)!=0 || (writing && ((state.reads&mask)!=0 || views::pinned(ref state.views,value.value)))){return .err(wrong(at));}
    let Reference result=Reference{.slot=value.value,.temporary=value.binding==64,
        .writing=writing,.reads=state.reads,.writes=state.writes};
    if(writing){state.writes|=mask;}else{state.reads|=mask;}return .ok(result);
}
pub fn Result<usize,errors::Error> end(ref mut bindings::State state,Reference loan,usize at){
    if(state.next>16 || loan.slot>=state.next || state.live>=65536 || state.maybe>=65536 ||
        (state.maybe&state.live)!=0){return .err(wrong(at));}
    let usize present=state.live|state.maybe;
    if((present>>state.next)!=0 || (state.reads&state.writes)!=0 || (loan.reads&loan.writes)!=0 ||
        ((state.reads|state.writes)&state.live)!=(state.reads|state.writes) ||
        ((loan.reads|loan.writes)&state.live)!=(loan.reads|loan.writes)){return .err(wrong(at));}
    let usize mask=bit(loan.slot);
    if(state.reads!=if(loan.writing){loan.reads}else{loan.reads|mask} ||
        state.writes!=if(loan.writing){loan.writes|mask}else{loan.writes} ||
        (state.live&mask)==0){return .err(wrong(at));}
    state.reads=loan.reads;state.writes=loan.writes;return .ok(loan.slot);
}
pub fn Result<context::Value,errors::Error> empty_raw(ref mut values::Program unit,ref mut bindings::State state,
    usize exact,usize at){
    let usize type=context::intern(unit,4,0,0,at)?;
    let context::Value expected=context::expected(context::owned(type,0),exact,at)?;
    let usize id=construction::empty_buffer(unit,state,type,at)?;return .ok(context::owned(type,id));
}
pub fn Result<context::Value,errors::Error> finish_raw(ref mut values::Program unit,ref mut bindings::State state,
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

// Every stage performs one child service; callers pin the ledger until done.
pub struct Finish { context::Value result; Reference first; Reference second; usize exact; usize at; usize type; usize success; usize failure; usize index; usize value; u8 op; u8 phase; bool done; }
pub fn Finish finishing(u8 op,Reference first,Reference second,usize index,usize value,usize exact,usize at){return Finish{.result=context::nothing(),.first=first,.second=second,.exact=exact,.at=at,.type=64,.success=64,.failure=64,.index=index,.value=value,.op=op,.phase=0,.done=false};}
pub fn Result<context::Value,errors::Error> finish_result(ref Finish w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
pub fn Result<bool,errors::Error> advance_finish(ref mut values::Program unit,ref mut bindings::State state,ref mut Finish w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(!budget::admit(meter,4096,w.at)?){return .ok(false);}let u8 phase=w.phase;let usize at=w.at;
    if(phase==0){if(w.op==95){w.type=context::intern(unit,4,0,0,at)?;w.phase=1;return .ok(false);}if(w.op==104){let usize ended=end(state,w.second,at)?;}w.phase=2;return .ok(false);}
    if(phase==1){let context::Value checked=context::expected(context::owned(w.type,0),w.exact,at)?;w.phase=10;return .ok(false);}
    if(phase==2){let usize ended=end(state,w.first,at)?;w.phase=3;return .ok(false);}
    if(phase==3){if(w.op==99 || w.op==100){w.type=context::intern(unit,1,if(w.op==99){12}else{10},0,at)?;w.phase=4;}
        else if(w.op==101){let usize emitted=ops::write(unit,state,w.first.slot,w.index,w.value,at)?;w.phase=8;}
        else{w.success=context::intern(unit,1,12,0,at)?;w.phase=5;}return .ok(false);}
    if(phase==4){let usize reg=ops::scalar(unit,state,w.op,w.first.slot,w.index,at)?;w.result=context::scalar(w.type,reg);w.phase=8;return .ok(false);}
    if(phase==5){w.failure=context::intern(unit,1,10,0,at)?;w.phase=6;return .ok(false);}
    if(phase==6){w.type=context::intern(unit,6,context::byte(w.success),context::byte(w.failure),at)?;w.phase=7;return .ok(false);}
    if(phase==7){let context::Value checked=context::expected(context::owned(w.type,0),w.exact,at)?;w.phase=11;return .ok(false);}
    if(phase==10){let usize id=construction::empty_buffer(unit,state,w.type,at)?;w.result=context::owned(w.type,id);w.done=true;return .ok(true);}
    if(phase==11){let usize id=ops::grow(unit,state,w.op,w.type,w.first.slot,if(w.op==104){w.second.slot}else{w.value},at)?;w.result=context::owned(w.type,id);w.phase=8;return .ok(false);}
    if(phase==8){if(w.op==104 && w.second.temporary){let usize dropped=bindings::drop(unit,state,w.second.slot,at)?;}w.phase=9;return .ok(false);}
    if(phase==9){if(w.first.temporary){let usize dropped=bindings::drop(unit,state,w.first.slot,at)?;}w.phase=12;return .ok(false);}
    if(phase==12){if(w.op!=99 && w.op!=100){w.result=context::expected(w.result,w.exact,at)?;}w.done=true;return .ok(true);}return .err(errors::make(5,at));
}
fn Result<context::Value,errors::Error> drain(ref mut values::Program unit,ref mut bindings::State state,ref mut Finish w){var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,w.at)?;let bool done=advance_finish(unit,state,w,ref mut meter)?;}return finish_result(w);}
pub fn Result<context::Value,errors::Error> empty(ref mut values::Program unit,ref mut bindings::State state,usize exact,usize at){var Finish w=finishing(95,none(),none(),0,0,exact,at);return drain(unit,state,ref mut w);}
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,u8 op,Reference first,Reference second,usize index,usize value,usize exact,usize at){var Finish w=finishing(op,first,second,index,value,exact,at);return drain(unit,state,ref mut w);}
