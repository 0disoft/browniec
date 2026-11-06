module value_source;

import value_ir as values;
import value_properties as properties;
import value_type_source as annotations;
import value_source_bindings as bindings;
import value_source_functions as functions;
import value_source_ops as ops;
import value_source_control as branches;
import value_source_propagation as propagation;
import value_source_context as context;
import functions as signatures;
import lexer as lexer;
import locals as locals;
import ir as ir;
import types as types;
import errors as errors;
import std::vec as vec;

// Private source lowering to the existing independently verified value dialect.
// Exact types are canonical node IDs; ordinary scalars remain ordinary registers.
// The complete candidate is discarded on any error. Public compiler routes do
// not select this path or retry a failed compile under another dialect.
// A named typed value is a compiler-only delayed capture, never an owner alias.
// Postfix inspection reads it in place; value consumers capture before evaluating
// any later operand, argument or cleanup. This also preserves `(name).is_ok`.
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn errors::Error wrong(usize at){return errors::make(3,at);}
// Borrow nested metadata before scalar projections to bound recursive frames.
fn usize position(ref values::Program unit){let ref ir::Program body=ref unit.body;return body.count;}
fn usize register_count(ref values::Program unit){let ref ir::Program body=ref unit.body;return body.registers;}
fn usize call_count(ref values::Program unit){let ref ir::Program body=ref unit.body;return body.call_count;}
fn u8 register_type(ref values::Program unit,usize index){let ref ir::Program body=ref unit.body;return body.types[index];}
fn usize name_count(ref bindings::State state){let ref locals::Table names=ref state.names;return names.count;}
fn usize function_id(ref bindings::State state){let ref locals::Table names=ref state.names;return names.function;}
fn u8 opcode(u8 kind){
    return if(kind==134){31}else if(kind==135){32}else if(kind==38){28}else if(kind==94){29}else if(kind==124){30}
        else if(kind==128){11}else if(kind==129){12}else if(kind==60){13}else if(kind==130){14}
        else if(kind==62){15}else if(kind==131){16}else if(kind==43){2}else if(kind==45){3}
        else if(kind==42){4}else if(kind==47){5}else{6};
}
fn Result<context::Value,errors::Error> expression(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize exact,u8 minimum,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    var context::Value left=atom(source,s,unit,state,table,plan,paths,exact,depth)?;
    while(context::precedence(s.kind)>=minimum && context::precedence(s.kind)!=0){
        let u8 operation=s.kind;let u8 priority=context::precedence(operation);let usize at=s.begin;
        let usize a=context::as_scalar(unit,state,left,at)?;let usize next=lexer::next(source,s)?;
        let context::Value right=expression(source,s,unit,state,table,plan,paths,left.exact,priority+1,depth+1)?;
        let usize b=context::as_scalar(unit,state,right,at)?;
        if(left.exact!=right.exact || (!types::integer(register_type(unit,a)) && operation!=128 && operation!=129)){
            return .err(wrong(at));
        }
        let usize result=ir::emit(ref mut unit.body,opcode(operation),a,b,at)?;
        let usize type=if(operation==128 || operation==129 || operation==60 || operation==62 || operation==130 || operation==131){
            context::intern(unit,1,2,0,at)?}else{left.exact};left=context::scalar(type,result);
    }
    return context::expected(left,exact,s.begin);
}
fn Result<context::Value,errors::Error> constructor(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize exact,usize depth){
    let usize at=s.begin;let usize dot=lexer::next(source,s)?;
    let bool some=word(source,s,b"some");let bool none=word(source,s,b"none");
    let bool ok=word(source,s,b"ok");let bool err=word(source,s,b"err");
    if(!some && !none && !ok && !err){return .err(wrong(at));}
    if(exact==64 && !some){return .err(wrong(at));}
    if(exact!=64 && (exact>=unit.catalog.count ||
        unit.catalog.nodes[exact].kind!=if(some || none){5}else{6})){return .err(wrong(at));}
    let usize name=lexer::next(source,s)?;var usize wrapper=exact;var usize payload=16;
    if(!none){
        let usize open=lexer::punctuation(source,s,40)?;
        let usize child=if(exact==64){64}else if(err){unit.catalog.nodes[exact].second as usize}else{unit.catalog.nodes[exact].first as usize};
        let context::Value value=expression(source,s,unit,state,table,plan,paths,child,1,depth+1)?;
        let usize close=lexer::punctuation(source,s,41)?;
        if(exact==64){wrapper=context::intern(unit,5,context::byte(value.exact),0,at)?;}
        payload=context::as_value(unit,state,value,at)?;
    }
    let usize built=ops::tag(unit,state,wrapper,payload,if(some || ok){1}else{0},at)?;
    if(payload!=16){let usize released=bindings::drop(unit,state,payload,at)?;}
    return .ok(context::owned(wrapper,built));
}
fn Result<context::Value,errors::Error> buffer(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,usize exact){
    let usize at=s.begin;
    if(word(source,s,b"brownie")){
        let usize a=lexer::next(source,s)?;let usize b=lexer::punctuation(source,s,58)?;
        let usize c=lexer::punctuation(source,s,58)?;
    }
    let usize bytes=lexer::word(source,s,b"bytes")?;
    let usize a=lexer::punctuation(source,s,58)?;let usize b=lexer::punctuation(source,s,58)?;
    let usize name=lexer::word(source,s,b"empty")?;
    let usize open=lexer::punctuation(source,s,40)?;let usize close=lexer::punctuation(source,s,41)?;
    let usize type=context::intern(unit,4,0,0,at)?;
    let context::Value result=context::expected(context::owned(type,0),exact,at)?;
    let usize id=ops::empty_buffer(unit,state,type,at)?;return .ok(context::owned(type,id));
}
fn Result<context::Value,errors::Error> call(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize target,usize at,usize depth){
    if(target>=table.count){return .err(wrong(at));}
    let usize open=lexer::punctuation(source,s,40)?;
    var usize[8] arguments=[0;8];var usize[8] captures=[16;8];var usize i=0;var bool extended=false;
    while(i<table.arities[target]){
        if(i!=0){let usize comma=lexer::punctuation(source,s,44)?;}
        let usize exact=plan.parameters[target*8+i]-1;
        let context::Value value=expression(source,s,unit,state,table,plan,paths,exact,1,depth+1)?;
        if(unit.catalog.nodes[exact].kind==1){arguments[i]=context::as_scalar(unit,state,value,at)?;}
        else{let usize id=context::as_value(unit,state,value,at)?;arguments[i]=208+id;captures[i]=id;extended=true;}
        i+=1;
    }
    let usize close=lexer::punctuation(source,s,41)?;
    let usize result=plan.results[target];var context::Value returned=context::nothing();
    if(result!=0 && unit.catalog.nodes[result-1].kind!=1){extended=true;
        returned=context::owned(result-1,bindings::allocate(unit,state,result-1,at)?);
    }else if(result!=0){
        if(register_count(unit)>=128){return .err(errors::make(4,at));}
        let usize reg=register_count(unit);unit.body.registers=reg+1;
        let u8 tag=unit.catalog.nodes[result-1].first;unit.body.types[reg]=tag;returned=context::scalar(result-1,reg);
    }
    if(call_count(unit)>=32 || position(unit)>=256){return .err(errors::make(4,at));}
    let usize map=call_count(unit);unit.body.call_count=map+1;unit.body.call_arities[map]=context::byte(i);
    var usize j=0;while(j<i){unit.body.call_args[map*8+j]=context::byte(arguments[j]);j+=1;}
    let usize emitted=ir::raw(ref mut unit.body,if(extended){93}else{9},if(returned.nothing){0}else{returned.value},target,map,at)?;
    let properties::Plan properties= switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(wrong(at));}
    };
    j=0;while(j<i){if(captures[j]!=16){let usize id=captures[j];
        // A later argument can exit before CALL; transfer the obligation only
        // after this CALL is published, never while evaluating its arguments.
        let usize handled=bindings::handle(unit,state,id,at)?;
        if(properties.properties[values::type_id(unit,id)].copyable){let usize dropped=bindings::drop(unit,state,id,at)?;}
        else{let usize consumed=bindings::consume(unit,state,id,at)?;}
    }j+=1;}
    if(returned.typed){let usize initialized=bindings::initialize(unit,state,returned.value,at)?;}
    return .ok(returned);
}
fn Result<context::Value,errors::Error> predicate(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,context::Value value){
    let usize at=s.begin;let usize dot=lexer::next(source,s)?;
    if(s.kind!=2){return .err(errors::make(2,s.begin));}
    if(!value.typed || value.nothing || value.exact>=unit.catalog.count){return .err(wrong(at));}
    let u8 kind=unit.catalog.nodes[value.exact].kind;
    let bool positive=word(source,s,if(kind==5){b"is_some"}else{b"is_ok"});
    let bool negative=word(source,s,if(kind==5){b"is_none"}else{b"is_err"});
    if((kind!=5 && kind!=6) || (!positive && !negative)){return .err(wrong(at));}
    let usize name=lexer::next(source,s)?;
    let usize result=ops::tag_test(unit,state,value.value,if(positive){1}else{0},at)?;
    if(value.binding==64){let usize dropped=bindings::drop(unit,state,value.value,at)?;}
    let usize boolean=context::intern(unit,1,2,0,at)?;return .ok(context::scalar(boolean,result));
}
// Look only across the current primary/unary operand. A postfix receiver cannot
// inherit its final bool/payload context; nested arguments own their contexts.
// The real parser still validates/evaluates every token exactly once.
fn Result<context::Value,errors::Error> atom(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize exact,usize depth){
    let usize context=if(context::postfix_receiver(source,s)?){64}else{exact};
    var context::Value value=primary(source,s,unit,state,table,plan,paths,context,depth)?;
    while(s.kind==46 || s.kind==63){
        if(s.kind==46){value=predicate(source,s,unit,state,value)?;}
        else{
            let usize at=s.begin;let usize question=lexer::next(source,s)?;
            if(value.nothing || !value.typed){return .err(wrong(at));}
            let usize f=function_id(state);
            let usize result=if(plan.results[f]==0){64}else{plan.results[f]-1};
            let usize subject=context::as_value(unit,state,value,at)?;
            let propagation::Expanded expanded=propagation::lower(unit,state,paths,subject,result,at)?;
            if(unit.catalog.nodes[expanded.exact].kind==1){
                let usize read=ops::scalar_read(unit,state,expanded.payload,at)?;
                let usize dropped=bindings::drop(unit,state,expanded.payload,at)?;
                value=context::scalar(expanded.exact,read);
            }else{value=context::owned(expanded.exact,expanded.payload);}
        }
    }
    return .ok(value);
}
fn Result<context::Value,errors::Error> primary(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize exact,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    if(word(source,s,b"if")){return if_value(source,s,unit,state,table,plan,paths,exact,depth);}
    if(word(source,s,b"switch")){return switch_value(source,s,unit,state,table,plan,paths,exact,depth);}
    if(s.kind==46){return constructor(source,s,unit,state,table,plan,paths,exact,depth);}
    if(s.kind==40){let usize open=lexer::next(source,s)?;
        let context::Value value=expression(source,s,unit,state,table,plan,paths,exact,1,depth+1)?;
        let usize close=lexer::punctuation(source,s,41)?;return .ok(value);
    }
    if(s.kind==45 || s.kind==33 || s.kind==126){let u8 op=s.kind;let usize next=lexer::next(source,s)?;
        if(op==45 && s.kind==1){
            let u8 tag=if(exact<unit.catalog.count && unit.catalog.nodes[exact].kind==1){unit.catalog.nodes[exact].first}else{1};
            if(!types::signed(tag)){return .err(wrong(at));}
            if(s.min_magnitude || s.value==2147483648){
                if(s.min_magnitude && tag!=9){return .err(wrong(at));}
                let i64 number=if(s.min_magnitude){-9223372036854775808}else{-2147483648};
                let usize reg=ir::integer(ref mut unit.body,number,tag,at)?;
                let usize type=context::intern(unit,1,tag,0,at)?;let usize advanced=lexer::next(source,s)?;
                return .ok(context::scalar(type,reg));
            }
        }
        let context::Value value=atom(source,s,unit,state,table,plan,paths,exact,depth+1)?;
        let usize reg=context::as_scalar(unit,state,value,at)?;
        if((op==33 && register_type(unit,reg)!=2) || (op==45 && !types::signed(register_type(unit,reg))) || (op==126 && !types::integer(register_type(unit,reg)))){return .err(wrong(at));}
        let usize result=ir::emit(ref mut unit.body,if(op==45){7}else if(op==33){10}else{27},reg,0,at)?;
        return .ok(context::scalar(value.exact,result));
    }
    if(s.kind==1 || word(source,s,b"true") || word(source,s,b"false")){
        let bool boolean=s.kind!=1;
        let u8 tag=if(boolean){2}else if(exact<unit.catalog.count && unit.catalog.nodes[exact].kind==1 && types::integer(unit.catalog.nodes[exact].first)){unit.catalog.nodes[exact].first}else{1};
        let usize type=context::intern(unit,1,tag,0,at)?;
        if(!boolean && (s.min_magnitude || (!types::unsigned(tag) && s.value<0))){return .err(wrong(at));}
        let usize reg=if(boolean){ir::boolean(ref mut unit.body,word(source,s,b"true"),at)?}else{ir::integer(ref mut unit.body,s.value,tag,at)?};
        let usize next=lexer::next(source,s)?;return .ok(context::scalar(type,reg));
    }
    if(s.kind!=2){return .err(errors::make(2,at));}
    var lexer::State look=lexer::snapshot(s);let usize peek=lexer::next(source,ref mut look)?;
    if((word(source,s,b"bytes") || word(source,s,b"brownie")) && look.kind==58){return buffer(source,s,unit,state,exact);}
    let usize begin=s.begin;let usize end=s.end;let usize next=lexer::next(source,s)?;
    if(s.kind==40){let usize target=signatures::find(source,table,begin,end);
        return call(source,s,unit,state,table,plan,paths,target,at,depth);
    }
    let usize index=locals::find(source,ref state.names,begin,end);
    if(index==64){return .err(wrong(at));}
    if(state.bindings[index]!=0){let usize from=(state.bindings[index] as usize)-1;
        return .ok(context::Value{.exact=values::type_id(unit,from),.value=from,.typed=true,.nothing=false,.binding=index});
    }
    let usize binding=state.names.registers[index];
    let usize reg=if(state.names.mutable[index]){ir::emit(ref mut unit.body,17,binding,0,at)?}else{binding};
    let u8 tag=register_type(unit,reg);let usize type=context::intern(unit,1,tag,0,at)?;return .ok(context::scalar(type,reg));
}
fn Result<usize,errors::Error> declaration(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths){
    let bool mutable=word(source,s,b"var");let usize keyword=lexer::next(source,s)?;var usize type=64;
    var lexer::State look=lexer::snapshot(s);let usize peek=lexer::next(source,ref mut look)?;
    if(look.kind!=61){type=annotations::parse(source,s,ref mut unit.catalog)?;}
    if(s.kind!=2 || !lexer::simple(source,s.begin,s.end) || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}
    let usize begin=s.begin;let usize end=s.end;
    if(locals::find(source,ref state.names,begin,end)!=64){return .err(wrong(begin));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    let context::Value value=expression(source,s,unit,state,table,plan,paths,type,1,0)?;
    let usize terminator=lexer::punctuation(source,s,59)?;
    if(value.typed){let usize id=context::as_value(unit,state,value,begin)?;
        return if(mutable){bindings::declare_mut(unit,state,source,begin,end,id,value.exact)}
        else{bindings::declare(unit,state,source,begin,end,id,value.exact)};}
    let usize reg=context::as_scalar(unit,state,value,begin)?;
    if(mutable){let u8 tag=register_type(unit,reg);let usize slot=ir::slot(ref mut unit.body,tag,begin)?;
        let usize stored=ir::raw(ref mut unit.body,18,slot,reg,0,begin)?;
        return locals::declare(ref mut state.names,begin,end,slot,true);
    }
    return locals::declare(ref mut state.names,begin,end,reg,false);
}
fn Result<bool,errors::Error> assignment_ahead(ref u8[] source,ref lexer::State s){
    if(s.kind!=2 || word(source,s,b"_")){return .ok(false);}var lexer::State look=lexer::snapshot(s);
    let usize next=lexer::next(source,ref mut look)?;
    return .ok(look.kind==61 || (look.kind>=136 && look.kind<=145));
}
fn Result<usize,errors::Error> assignment(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths){
    let usize at=s.begin;let usize index=locals::find(source,ref state.names,s.begin,s.end);
    if(index==64 || !state.names.mutable[index]){return .err(wrong(at));}
    let usize next=lexer::next(source,s)?;let u8 token=s.kind;let usize advanced=lexer::next(source,s)?;
    let bool typed=state.bindings[index]!=0;let usize dst=state.names.registers[index];
    let usize type=if(typed){values::type_id(unit,(state.bindings[index] as usize)-1)}else{
        let u8 tag=register_type(unit,dst);context::intern(unit,1,tag,0,at)?
    };
    if(typed && token!=61){return .err(wrong(at));}
    var usize left=0;
    if(token!=61){if(!types::integer(register_type(unit,dst))){return .err(wrong(at));}
        left=ir::emit(ref mut unit.body,17,dst,0,at)?;
    }
    let context::Value rhs=expression(source,s,unit,state,table,plan,paths,type,1,0)?;
    let usize semi=lexer::punctuation(source,s,59)?;
    if(typed){let usize value=context::as_value(unit,state,rhs,at)?;return bindings::assign(unit,state,index,value,at);}
    let usize right=context::as_scalar(unit,state,rhs,at)?;
    let usize value=if(token==61){right}else{ir::emit(ref mut unit.body,context::compound(token),left,right,at)?};
    return ir::raw(ref mut unit.body,18,dst,value,0,at);
}
fn Result<branches::Exit,errors::Error> exit_arm(ref mut values::Program unit,ref bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,bool terminal,usize at){
    let usize jump=if(terminal){0}else{ir::raw(ref mut unit.body,19,0,0,0,at)?};
    return branches::capture(paths,state,terminal,jump,at);
}
// One destination belongs to every yielding edge. Terminal edges never initialize
// or read it. Exact type and allocation are established by the first yielded value.
struct Join { usize exact; usize destination; bool have; }
fn Join joining(usize exact){return Join{.exact=exact,.destination=128,.have=false};}
fn Result<usize,errors::Error> publish(ref mut values::Program unit,ref mut bindings::State state,
    ref mut Join output,context::Value value,usize at){
    if(value.nothing || value.exact>=unit.catalog.count ||
        (output.exact!=64 && value.exact!=output.exact)){return .err(wrong(at));}
    let bool scalar=unit.catalog.nodes[value.exact].kind==1;
    let u8 tag=unit.catalog.nodes[value.exact].first;
    if(!output.have){
        output.destination=if(scalar){ir::slot(ref mut unit.body,tag,at)?}
            else{bindings::allocate(unit,state,value.exact,at)?};
        output.exact=value.exact;output.have=true;
    }
    if(scalar){let usize reg=context::as_scalar(unit,state,value,at)?;
        return ir::raw(ref mut unit.body,18,output.destination,reg,0,at);
    }
    if(value.binding!=64){return bindings::use_binding(unit,state,value.binding,output.destination,at);}
    let usize id=context::as_value(unit,state,value,at)?;
    return bindings::move_value(unit,state,output.destination,id,at);
}
fn Result<context::Value,errors::Error> joined(ref mut values::Program unit,ref bindings::State state,
    ref Join output,usize at){
    if(!output.have){return .err(wrong(at));}
    if(unit.catalog.nodes[output.exact].kind==1){
        let usize reg=ir::emit(ref mut unit.body,17,output.destination,0,at)?;
        return .ok(context::scalar(output.exact,reg));
    }
    return .ok(context::owned(output.exact,output.destination));
}
fn Result<bool,errors::Error> value_condition_paths(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,usize depth,ref mut Join output){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;let usize f=function_id(state);
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value condition=expression(source,s,unit,state,table,plan,paths,64,1,depth+1)?;
    let usize test=context::as_scalar(unit,state,condition,at)?;
    if(register_type(unit,test)!=2){return .err(wrong(at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize guard=ir::raw(ref mut unit.body,20,0,test,0,at)?;
    let usize mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    let bool terminal=scope(source,s,unit,state,table,plan,paths,f,depth+1,output,true)?;
    let usize end=lexer::punctuation(source,s,125)?;
    let branches::Exit left=exit_arm(unit,state,paths,terminal,at)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize alternative=position(unit);let usize patched=ir::patch(ref mut unit.body,guard,alternative,at)?;
    let usize otherwise=lexer::word(source,s,b"else")?;var bool ended=false;
    if(word(source,s,b"if")){ended=value_condition_paths(source,s,unit,state,table,plan,paths,depth+1,output)?;}
    else{let usize opening=lexer::punctuation(source,s,123)?;
        ended=scope(source,s,unit,state,table,plan,paths,f,depth+1,output,true)?;
        let usize closing=lexer::punctuation(source,s,125)?;
    }
    let branches::Exit right=exit_arm(unit,state,paths,ended,at)?;
    let bool result=branches::join(unit,state,paths,ref left,ref right,at)?;
    let usize freed=branches::release(paths,mark,at)?;return .ok(result);
}
fn Result<context::Value,errors::Error> if_value(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,usize exact,usize depth){
    let usize at=s.begin;var Join output=joining(exact);
    let bool terminal=value_condition_paths(source,s,unit,state,table,plan,paths,depth,ref mut output)?;
    return joined(unit,state,ref output,at);
}
fn Result<bool,errors::Error> block(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth){
    var Join unused=joining(64);return scope(source,s,unit,state,table,plan,paths,f,depth,ref mut unused,false);
}
fn Result<bool,errors::Error> selection(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth){
    var Join unused=joining(64);return selection_paths(source,s,unit,state,table,plan,paths,f,depth,ref mut unused,false);
}
fn Result<context::Value,errors::Error> switch_value(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,usize exact,usize depth){
    let usize at=s.begin;let usize f=function_id(state);var Join output=joining(exact);
    let bool terminal=selection_paths(source,s,unit,state,table,plan,paths,f,depth,ref mut output,true)?;
    return joined(unit,state,ref output,at);
}
fn Result<bool,errors::Error> conditional(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value condition=expression(source,s,unit,state,table,plan,paths,64,1,0)?;
    let usize test=context::as_scalar(unit,state,condition,at)?;
    if(register_type(unit,test)!=2){return .err(wrong(at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize guard=ir::raw(ref mut unit.body,20,0,test,0,at)?;
    let usize pool_mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    let bool ended=block(source,s,unit,state,table,plan,paths,f,depth+1)?;
    let usize end=lexer::punctuation(source,s,125)?;
    let branches::Exit left=exit_arm(unit,state,paths,ended,at)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize alternative=position(unit);let usize patched=ir::patch(ref mut unit.body,guard,alternative,at)?;
    var bool terminal=false;
    if(word(source,s,b"else")){
        let usize otherwise=lexer::next(source,s)?;
        if(word(source,s,b"if")){terminal=conditional(source,s,unit,state,table,plan,paths,f,depth+1)?;}
        else{let usize open_else=lexer::punctuation(source,s,123)?;
            terminal=block(source,s,unit,state,table,plan,paths,f,depth+1)?;
            let usize end_else=lexer::punctuation(source,s,125)?;
        }
    }
    let branches::Exit right=exit_arm(unit,state,paths,terminal,at)?;
    let bool result=branches::join(unit,state,paths,ref left,ref right,at)?;
    let usize freed=branches::release(paths,pool_mark,at)?;return .ok(result);
}
struct Arm { branches::Exit exit; usize instruction; u8 variant; }
fn Result<Arm,errors::Error> selected_arm(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth,usize subject,ref mut Join output,bool yields){
    let usize at=s.begin;let usize mark=name_count(state);
    let usize keyword=lexer::word(source,s,b"case")?;let usize dot=lexer::punctuation(source,s,46)?;
    let bool option=unit.catalog.nodes[values::type_id(unit,subject)].kind==5;
    let bool positive=word(source,s,if(option){b"some"}else{b"ok"});
    if(!positive && !word(source,s,if(option){b"none"}else{b"err"})){return .err(wrong(s.begin));}
    let u8 variant=if(positive){1}else{0};let usize name=lexer::next(source,s)?;
    let ops::Case branch=ops::case_value(unit,state,subject,variant,at)?;
    let usize release=bindings::drop(unit,state,subject,at)?;
    if(branch.payload!=16){
        let usize open=lexer::punctuation(source,s,40)?;
        if(s.kind!=2){return .err(errors::make(2,s.begin));}
        let usize begin=s.begin;let usize end=s.end;
        if(word(source,s,b"_")){let usize handled=bindings::handle(unit,state,branch.payload,at)?;
            let usize dropped=bindings::drop(unit,state,branch.payload,at)?;}
        else{
            if(locals::reserved(source[begin..end]) || locals::find(source,ref state.names,begin,end)!=64){return .err(wrong(begin));}
            let usize type=values::type_id(unit,branch.payload);
            if(unit.catalog.nodes[type].kind==1){
                let usize value=ops::scalar_read(unit,state,branch.payload,at)?;
                let usize dropped=bindings::drop(unit,state,branch.payload,at)?;
                let usize bound=locals::declare(ref mut state.names,begin,end,value,false)?;
            }else{let usize bound=bindings::declare(unit,state,source,begin,end,branch.payload,type)?;}
        }
        let usize capture=lexer::next(source,s)?;let usize close=lexer::punctuation(source,s,41)?;
    }
    let usize colon=lexer::punctuation(source,s,58)?;let usize brace=lexer::punctuation(source,s,123)?;
    let bool terminal=scope(source,s,unit,state,table,plan,paths,f,depth+1,output,yields)?;
    let usize close=lexer::punctuation(source,s,125)?;
    if(!terminal){let usize released=bindings::leave_scope(unit,state,mark,at)?;}
    let branches::Exit exit=exit_arm(unit,state,paths,terminal,at)?;
    return .ok(Arm{.exit=exit,.instruction=branch.instruction,.variant=variant});
}
fn Result<bool,errors::Error> selection_paths(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth,ref mut Join output,bool yields){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value value=expression(source,s,unit,state,table,plan,paths,64,1,0)?;
    if(value.nothing || value.exact>=unit.catalog.count ||
        (unit.catalog.nodes[value.exact].kind!=5 && unit.catalog.nodes[value.exact].kind!=6)){return .err(wrong(at));}
    let usize subject=context::as_value(unit,state,value,at)?;
    let usize close=lexer::punctuation(source,s,41)?;let usize brace=lexer::punctuation(source,s,123)?;
    let usize pool_mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let Arm first=selected_arm(source,s,unit,state,table,plan,paths,f,depth,subject,output,yields)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize next=position(unit);let usize patched=ops::patch_case(unit,first.instruction,next,at)?;
    let Arm second=selected_arm(source,s,unit,state,table,plan,paths,f,depth,subject,output,yields)?;
    if(first.variant==second.variant){return .err(wrong(at));}
    let usize end=lexer::punctuation(source,s,125)?;
    let usize failure=ir::raw(ref mut unit.body,25,0,0,0,at)?;
    let usize failed=ops::patch_case(unit,second.instruction,failure,at)?;
    let bool result=branches::join(unit,state,paths,ref first.exit,ref second.exit,at)?;
    let usize freed=branches::release(paths,pool_mark,at)?;return .ok(result);
}
fn Result<bool,errors::Error> scope(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,usize f,usize depth,ref mut Join output,bool yields){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize mark=name_count(state);var bool terminal=false;var bool produced=false;
    while(s.kind!=125){
        let usize at=s.begin;if(terminal || s.kind==0){return .err(errors::make(2,at));}
        if(word(source,s,b"let") || word(source,s,b"var")){let usize named=declaration(source,s,unit,state,table,plan,paths)?;}
        else if(word(source,s,b"if") && !(yields && context::tail_control(source,s)?)){terminal=conditional(source,s,unit,state,table,plan,paths,f,depth)?;}
        else if(word(source,s,b"switch") && !(yields && context::tail_control(source,s)?)){terminal=selection(source,s,unit,state,table,plan,paths,f,depth)?;}
        else if(assignment_ahead(source,s)?){let usize assigned=assignment(source,s,unit,state,table,plan,paths)?;}
        else if(word(source,s,b"return")){
            let usize next=lexer::next(source,s)?;let usize result=plan.results[f];var context::Value value=context::nothing();
            if(result!=0){value=expression(source,s,unit,state,table,plan,paths,result-1,1,0)?;}
            let usize semi=lexer::punctuation(source,s,59)?;
            let usize scalar_result=if(result!=0 && !value.typed){value.value}else{0};
            let usize keep=if(value.typed){context::as_value(unit,state,value,at)?}else{16};
            let usize dropped=propagation::finish_function(unit,state,keep,at)?;
            let usize returned=ir::raw(ref mut unit.body,if(value.typed){94}else if(value.nothing){82}else{8},0,
                if(value.typed){keep}else{scalar_result},0,at)?;terminal=true;
        }else if(word(source,s,b"_")){
            let usize name=lexer::next(source,s)?;let usize eq=lexer::punctuation(source,s,61)?;
            let context::Value value=expression(source,s,unit,state,table,plan,paths,64,1,0)?;
            let usize semi=lexer::punctuation(source,s,59)?;let usize dropped=context::discard_value(unit,state,value,at)?;
        }else if(s.kind==123){
            let usize open=lexer::next(source,s)?;terminal=block(source,s,unit,state,table,plan,paths,f,depth+1)?;
            let usize close=lexer::punctuation(source,s,125)?;
        }else{
            let usize exact=if(yields && context::tail_expression(source,s)?){output.exact}else{64};
            let context::Value value=expression(source,s,unit,state,table,plan,paths,exact,1,if(yields){depth+1}else{0})?;
            if(yields && s.kind==125 && !value.nothing){
                let usize published=publish(unit,state,output,value,at)?;produced=true;break;
            }
            if(!value.nothing){
                if(value.typed && unit.catalog.nodes[value.exact].kind==6){return .err(errors::make(18,at));}
                return .err(wrong(at));
            }let usize semi=lexer::punctuation(source,s,59)?;
        }
    }
    if(yields && !terminal && !produced){return .err(wrong(s.begin));}
    if(!terminal){let usize dropped=bindings::leave_scope(unit,state,mark,s.begin)?;}
    return .ok(terminal);
}
fn Result<usize,errors::Error> lower(ref u8[] source,ref mut values::Program unit){
    let signatures::Table table=signatures::scan_values(source,ref mut unit.catalog)?;
    let functions::Plan plan=functions::prepare(ref unit.catalog,ref table)?;
    unit.body.function_count=table.count;unit.body.entry=table.entry;
    var usize f=0;while(f<table.count){let usize result=plan.results[f];
        let u8 tag=if(result==0){13}else if(unit.catalog.nodes[result-1].kind==1){unit.catalog.nodes[result-1].first}else{0};
        unit.body.return_types[f]=tag;f+=1;
    }
    var bindings::State state=bindings::empty();
    let usize enforced=bindings::enable_results(unit,ref mut state,0)?;
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();f=0;
    while(f<table.count){
        let usize begun=functions::begin(unit,ref mut state,source,ref table,ref plan,f)?;
        var lexer::State cursor=lexer::empty();cursor.cursor=table.bodies[f];let usize first=lexer::next(source,ref mut cursor)?;
        let bool terminal=block(source,ref mut cursor,unit,ref mut state,ref table,ref plan,ref mut paths,f,0)?;
        if(cursor.begin!=table.body_ends[f]){return .err(errors::make(2,cursor.begin));}
        if(!terminal){if(plan.results[f]!=0){return .err(errors::make(2,cursor.begin));}
            let usize dropped=propagation::finish_function(unit,ref mut state,16,cursor.begin)?;
            let usize returned=ir::raw(ref mut unit.body,82,0,0,0,cursor.begin)?;
        }
        let usize ended=functions::finish(unit,ref state,f,cursor.begin)?;f+=1;
    }
    return .ok(position(unit));
}
pub fn Result<values::Program,errors::Error> compile(ref u8[] source){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    let usize lowered=lower(source,ref mut unit)?;return .ok(unit);
}
