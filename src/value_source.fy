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
import value_source_calls as source_calls;
import value_buffer_source as buffers;
import value_buffer_copy_source as buffer_copy;
import value_view_source as view_source;
import value_view_bindings as view_bindings;
import value_source_boolean as boolean;
import value_source_loops as looping;
import value_source_headers as headers;
import functions as signatures;
import slice_result_source_origins as reference_origins;
import lexer as lexer;
import locals as locals;
import ir as ir;
import types as types;
import casts as casts;
import errors as errors;
import std::vec as vec;
import value_walk_work as walk;
import value_expression_work as evaluation;
import value_call_source_work as call_work;
import operand_preflight_work as preflight;
import argument_name_work as name_work;
import metadata_budget as budget;

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

fn Result<context::Value,errors::Error> buffer_call(ref u8[] source,ref mut lexer::State s,
    ref mut values::Program unit,ref mut bindings::State state,ref signatures::Table table,
    ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,
    usize exact,usize depth,bool staged){
    let usize at=s.begin;let u8 op=buffers::operation(source,s,state)?;
    if(op==95){let usize close=lexer::punctuation(source,s,41)?;return buffers::empty(unit,state,exact,at);}
    let usize type=context::intern(unit,4,0,0,at)?;let bool writing=op>=101 && op<=104;
    let usize prefix=buffers::prefix(source,s,writing)?;
    let usize input_type=if(op==105){64}else{type};
    let context::Value receiver=expression(source,s,unit,state,table,plan,paths,flow,input_type,1,depth+1,staged)?;
    if(receiver.bottom){
        if(op!=99 && op!=105 && op!=106){return .err(wrong(at));}
        let usize close=lexer::punctuation(source,s,41)?;return .ok(receiver);
    }
    if(op==105 && view_source::reference(receiver)){
        let usize close=lexer::punctuation(source,s,41)?;
        let usize captured=view_source::capture(unit,state,receiver,at)?;
        return buffer_copy::finish_view(unit,state,paths,flow,captured,exact,at);
    }
    let buffers::Reference first=buffers::begin(unit,state,receiver,writing,at)?;
    var buffers::Reference second=buffers::none();var usize index=0;var usize value=0;
    if(op!=99 && op!=105 && op!=106){let usize comma=lexer::punctuation(source,s,44)?;
        if(op==104){
            let usize borrowed=buffers::prefix(source,s,false)?;
            let context::Value argument=expression(source,s,unit,state,table,plan,paths,flow,type,1,depth+1,staged)?;
            if(argument.bottom){let usize close=lexer::punctuation(source,s,41)?;return .ok(argument);}
            second=buffers::begin(unit,state,argument,false,at)?;
        }else{
            let usize scalar=context::intern(unit,1,if(op==102){10}else{12},0,at)?;
            let context::Value argument=expression(source,s,unit,state,table,plan,paths,flow,scalar,1,depth+1,staged)?;
            if(argument.bottom){
                if(op==101){return .err(wrong(at));}
                let usize close=lexer::punctuation(source,s,41)?;return .ok(argument);
            }
            let usize register=context::as_scalar(unit,state,argument,at)?;
            if(op==100 || op==101){index=register;}else{value=register;}
        }
    }
    if(op==101){let usize comma=lexer::punctuation(source,s,44)?;
        let usize scalar=context::intern(unit,1,10,0,at)?;
        let context::Value argument=expression(source,s,unit,state,table,plan,paths,flow,scalar,1,depth+1,staged)?;
        if(argument.bottom){let usize close=lexer::punctuation(source,s,41)?;return .ok(argument);}
        value=context::as_scalar(unit,state,argument,at)?;
    }
    let usize close=lexer::punctuation(source,s,41)?;
    if(op==105){return buffer_copy::finish(unit,state,paths,flow,first,exact,at);}
    if(op==106){return view_source::begin(unit,state,first,exact,at);}
    return buffers::finish(unit,state,op,first,second,index,value,exact,at);
}

fn Result<context::Value,errors::Error> expression_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,u8 minimum,usize depth,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}
    var context::Value left=converted(source,s,unit,state,table,plan,paths,flow,exact,depth,staged)?;
    while(context::precedence(s.kind)>=minimum && context::precedence(s.kind)!=0){
        let u8 operation=s.kind;let u8 priority=context::precedence(operation);let usize at=s.begin;
        let usize a=context::as_scalar(unit,state,left,at)?;let usize next=lexer::next(source,s)?;
        if(operation==132 || operation==133){
            let boolean::Pending pending=boolean::begin(unit,state,paths,operation,a,at)?;
            let context::Value right=expression(source,s,unit,state,table,plan,paths,flow,64,priority+1,depth+1,staged)?;
            left=raw_boolean_finish(unit,state,paths,flow,left,right,pending,at)?;continue;
        }
        let context::Value right=expression(source,s,unit,state,table,plan,paths,flow,left.exact,priority+1,depth+1,staged)?;
        if(right.bottom){return .ok(right);}
        left=raw_binary_finish(unit,state,left,right,operation,a,at)?;
    }
    return context::expected(left,exact,s.begin);
}
// Keep casts outside atom: recursive unary operands must finish before widening.
// Clear literal context only for this operand, as in the public scalar compiler.
fn Result<context::Value,errors::Error> converted_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    let bool explicit=casts::follows(source,s)?;
    let usize expected=if(explicit){64}else{exact};
    var context::Value value=atom(source,s,unit,state,table,plan,paths,flow,expected,depth,staged)?;
    return raw_cast_suffix(source,s,unit,state,value);
}
fn Result<context::Value,errors::Error> constructor_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
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
        let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,child,1,depth+1,staged)?;
        let usize close=lexer::punctuation(source,s,41)?;
        if(value.bottom){return .ok(value);}
        if(exact==64){wrapper=context::intern(unit,5,context::byte(value.exact),0,at)?;}
        payload=context::as_value(unit,state,value,at)?;
    }
    let usize built=ops::tag(unit,state,wrapper,payload,if(some || ok){1}else{0},at)?;
    if(payload!=16){let usize released=bindings::drop(unit,state,payload,at)?;}
    return .ok(context::owned(wrapper,built));
}

fn Result<context::Value,errors::Error> call_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize target,usize at,usize depth,bool staged){
    if(target>=table.count){return .err(wrong(at));}
    let usize open=lexer::punctuation(source,s,40)?;
    var usize[8] arguments=[0;8];var usize[8] captures=[16;8];var usize i=0;var bool extended=false;
    while(i<table.arities[target]){
        if(i!=0){let usize comma=lexer::punctuation(source,s,44)?;}
        let usize exact=plan.parameters[target*8+i]-1;
        if(exact==65){let usize prefix=lexer::word(source,s,b"ref")?;
            if(word(source,s,b"mut")){return .err(wrong(s.begin));}}
        let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,exact,1,depth+1,staged)?;
        if(value.bottom){
            if(i+1!=table.arities[target]){return .err(wrong(s.begin));}
            let usize close=lexer::punctuation(source,s,41)?;return .ok(value);
        }
        if(exact==65){let usize id=view_source::capture(unit,state,value,at)?;
            arguments[i]=224+id;captures[i]=17+id;extended=true;
        }else if(unit.catalog.nodes[exact].kind==1){arguments[i]=context::as_scalar(unit,state,value,at)?;}
        else{let usize id=context::as_value(unit,state,value,at)?;arguments[i]=208+id;captures[i]=id;extended=true;}
        i+=1;
    }
    let usize close=lexer::punctuation(source,s,41)?;
    if(staged){return source_calls::finish(unit,state,table,plan,target,ref arguments,ref captures,i,extended,at);}return source_calls::finish_raw(unit,state,table,plan,target,ref arguments,ref captures,i,extended,at);
}

// Look only across the current primary/unary operand. A postfix receiver cannot
// inherit its final bool/payload context; nested arguments own their contexts.
// The real parser still validates/evaluates every token exactly once.
fn Result<context::Value,errors::Error> atom_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    let usize context=if(context::postfix_receiver(source,s)?){64}else{exact};
    var context::Value value=primary(source,s,unit,state,table,plan,paths,flow,context,depth,staged)?;
    return raw_postfix_suffix(source,s,unit,state,table,plan,paths,flow,value,depth,staged);
}
fn Result<context::Value,errors::Error> view_index(ref u8[] source,ref mut lexer::State s,
    ref mut values::Program unit,ref mut bindings::State state,ref signatures::Table table,
    ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,
    context::Value input,usize depth,bool staged){
    let usize at=s.begin;let usize receiver=view_source::capture(unit,state,input,at)?;
    let usize open=lexer::next(source,s)?;
    let usize type=context::intern(unit,1,12,0,at)?;
    var usize lo=0;
    if(view_source::range_ahead(source,s)?){lo=ir::integer(ref mut unit.body,0,12,at)?;}
    else{let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,type,1,depth+1,staged)?;
        if(value.bottom){let usize close=lexer::punctuation(source,s,93)?;return .ok(value);}
        lo=context::as_scalar(unit,state,value,at)?;
    }
    let bool range=view_source::range_ahead(source,s)?;var usize hi=0;
    if(range){let usize dot=lexer::punctuation(source,s,46)?;let usize second=lexer::punctuation(source,s,46)?;
        if(s.kind==93){hi=view_bindings::scalar(unit,ref state.views,110,receiver,0,at)?;}
        else{let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,type,1,depth+1,staged)?;
            if(value.bottom){let usize close=lexer::punctuation(source,s,93)?;return .ok(value);}
            hi=context::as_scalar(unit,state,value,at)?;
        }
    }
    let usize close=lexer::punctuation(source,s,93)?;
    return view_source::indexed(unit,state,receiver,lo,hi,range,at);
}
fn Result<context::Value,errors::Error> primary_leaf_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    if(word(source,s,b"ref")){
        let usize prefix=lexer::next(source,s)?;if(word(source,s,b"mut")){return .err(wrong(at));}
        let context::Value input=atom(source,s,unit,state,table,plan,paths,flow,65,depth+1,staged)?;
        return context::expected(input,exact,at);
    }
    if(word(source,s,b"if")){return if_value(source,s,unit,state,table,plan,paths,flow,exact,depth,staged);}
    if(word(source,s,b"switch")){return switch_value(source,s,unit,state,table,plan,paths,flow,exact,depth,staged);}
    if(s.kind==46){return constructor(source,s,unit,state,table,plan,paths,flow,exact,depth,staged);}
    if(s.kind==40){let usize open=lexer::next(source,s)?;
        let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,exact,1,depth+1,staged)?;
        let usize close=lexer::punctuation(source,s,41)?;return .ok(value);
    }
    if(s.kind==45 || s.kind==33 || s.kind==126){let u8 op=s.kind;let usize next=lexer::next(source,s)?;
        if(op==45 && s.kind==1){
            let u8 tag=if(exact<context::catalog_count(unit) && context::catalog_node(unit,exact).kind==1){context::catalog_node(unit,exact).first}else{1};
            if(!types::signed(tag)){return .err(wrong(at));}
            if(s.min_magnitude || s.value==2147483648){
                if(s.min_magnitude && tag!=9){return .err(wrong(at));}
                let i64 number=if(s.min_magnitude){-9223372036854775808}else{-2147483648};
                let usize reg=ir::integer(ref mut unit.body,number,tag,at)?;
                let usize type=context::intern(unit,1,tag,0,at)?;let usize advanced=lexer::next(source,s)?;
                return .ok(context::scalar(type,reg));
            }
        }
        let context::Value value=atom(source,s,unit,state,table,plan,paths,flow,exact,depth+1,staged)?;
        if(value.bottom){return .ok(value);}
        let usize reg=context::as_scalar(unit,state,value,at)?;
        if((op==33 && register_type(unit,reg)!=2) || (op==45 && !types::signed(register_type(unit,reg))) || (op==126 && !types::integer(register_type(unit,reg)))){return .err(wrong(at));}
        let usize result=ir::emit(ref mut unit.body,if(op==45){7}else if(op==33){10}else{27},reg,0,at)?;
        return .ok(context::scalar(value.exact,result));
    }
    if(s.kind==1 || word(source,s,b"true") || word(source,s,b"false")){
        let bool boolean=s.kind!=1;
        let u8 tag=if(boolean){2}else if(exact<context::catalog_count(unit) && context::catalog_node(unit,exact).kind==1 && types::integer(context::catalog_node(unit,exact).first)){context::catalog_node(unit,exact).first}else{1};
        let usize type=context::intern(unit,1,tag,0,at)?;
        if(!boolean && (s.min_magnitude || (!types::unsigned(tag) && s.value<0))){return .err(wrong(at));}
        let usize reg=if(boolean){ir::boolean(ref mut unit.body,word(source,s,b"true"),at)?}else{ir::integer(ref mut unit.body,s.value,tag,at)?};
        let usize next=lexer::next(source,s)?;return .ok(context::scalar(type,reg));
    }
    if(s.kind!=2){return .err(errors::make(2,at));}
    var lexer::State look=lexer::snapshot(s);let usize peek=lexer::next(source,ref mut look)?;
    if((word(source,s,b"bytes") || word(source,s,b"brownie")) && look.kind==58){return buffer_call(source,s,unit,state,table,plan,paths,flow,exact,depth,staged);}
    let usize begin=s.begin;let usize end=s.end;let usize next=lexer::next(source,s)?;
    if(s.kind==40){let usize target=if(staged){name_work::target(source,table,begin,end)?}else{signatures::find(source,table,begin,end)};
        return call(source,s,unit,state,table,plan,paths,flow,target,at,depth,staged);
    }
    let usize index=if(staged){name_work::local(source,ref state.names,begin,end)?}else{locals::find(source,ref state.names,begin,end)};
    if(index==64){return .err(wrong(at));}
    if(state.views.names[index]!=0){return view_source::named(state,index,at);}
    if(state.bindings[index]!=0){let usize from=(state.bindings[index] as usize)-1;
        return .ok(context::Value{.exact=values::type_id(unit,from),.value=from,.typed=true,.nothing=false,.bottom=false,.binding=index});
    }
    let usize binding=state.names.registers[index];
    let usize reg=if(state.names.mutable[index]){ir::emit(ref mut unit.body,17,binding,0,at)?}else{binding};
    let u8 tag=register_type(unit,reg);let usize type=context::intern(unit,1,tag,0,at)?;return .ok(context::scalar(type,reg));
}
// Declaration result 64 means the initializer has no continuing edge. No name
// or initialized destination is created on that path.
fn Result<usize,errors::Error> declaration(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,bool staged){
    let bool mutable=word(source,s,b"var");let usize keyword=lexer::next(source,s)?;var usize type=64;
    var lexer::State look=lexer::snapshot(s);let usize peek=lexer::next(source,ref mut look)?;
    if(look.kind!=61){type=if(word(source,s,b"ref")){view_source::annotation(source,s)?}
        else{annotations::parse(source,s,ref mut unit.catalog)?};}
    if(s.kind!=2 || !lexer::simple(source,s.begin,s.end) || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}
    let usize begin=s.begin;let usize end=s.end;
    if(locals::find(source,ref state.names,begin,end)!=64){return .err(wrong(begin));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,type,1,0,staged)?;
    let usize terminator=lexer::punctuation(source,s,59)?;
    if(value.bottom){return .ok(64);}
    if(view_source::reference(value)){
        let usize id=view_source::capture(unit,state,value,begin)?;
        let usize roots=view_source::lexical_roots(state,id,begin)?;
        return bindings::declare_view(unit,state,source,begin,end,id,mutable);
    }
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

// Assignment result 256 is terminal parser control, beyond every instruction
// index. The RHS terminal edge has already performed cleanup.
fn Result<usize,errors::Error> assignment(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,u8 terminator,bool staged){
    let usize at=s.begin;let usize index=locals::find(source,ref state.names,s.begin,s.end);
    if(index==64 || !state.names.mutable[index]){return .err(wrong(at));}
    let usize next=lexer::next(source,s)?;let u8 token=s.kind;let usize advanced=lexer::next(source,s)?;
    if(state.views.names[index]!=0){
        if(token!=61){return .err(wrong(at));}
        let context::Value rhs=expression(source,s,unit,state,table,plan,paths,flow,view_source::type_id(),1,0,staged)?;
        let usize semi=lexer::punctuation(source,s,terminator)?;
        if(rhs.bottom){return .ok(256);}
        let usize id=view_source::capture(unit,state,rhs,at)?;
        let usize roots=view_source::lexical_roots(state,id,at)?;
        return bindings::assign_view(unit,state,index,id,at);
    }
    let bool typed=state.bindings[index]!=0;let usize dst=state.names.registers[index];
    let usize type=if(typed){values::type_id(unit,(state.bindings[index] as usize)-1)}else{
        let u8 tag=register_type(unit,dst);context::intern(unit,1,tag,0,at)?
    };
    if(typed && token!=61){return .err(wrong(at));}
    var usize left=0;
    if(token!=61){if(!types::integer(register_type(unit,dst))){return .err(wrong(at));}
        left=ir::emit(ref mut unit.body,17,dst,0,at)?;
    }
    let context::Value rhs=expression(source,s,unit,state,table,plan,paths,flow,type,1,0,staged)?;
    let usize semi=lexer::punctuation(source,s,terminator)?;
    if(rhs.bottom){return .ok(256);}
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




fn Result<bool,errors::Error> value_condition_paths(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize depth,ref mut context::Join output,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;let usize f=function_id(state);
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value condition=expression(source,s,unit,state,table,plan,paths,flow,64,1,depth+1,staged)?;
    let usize test=context::as_scalar(unit,state,condition,at)?;
    if(register_type(unit,test)!=2){return .err(wrong(at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize guard=ir::raw(ref mut unit.body,20,0,test,0,at)?;
    let usize mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    let bool terminal=scope(source,s,unit,state,table,plan,paths,flow,f,depth+1,output,true,staged)?;
    let usize end=lexer::punctuation(source,s,125)?;
    let branches::Exit left=exit_arm(unit,state,paths,terminal,at)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize alternative=position(unit);let usize patched=ir::patch(ref mut unit.body,guard,alternative,at)?;
    let usize otherwise=lexer::word(source,s,b"else")?;var bool ended=false;
    if(word(source,s,b"if")){ended=value_condition_paths(source,s,unit,state,table,plan,paths,flow,depth+1,output,staged)?;}
    else{let usize opening=lexer::punctuation(source,s,123)?;
        ended=scope(source,s,unit,state,table,plan,paths,flow,f,depth+1,output,true,staged)?;
        let usize closing=lexer::punctuation(source,s,125)?;
    }
    let branches::Exit right=exit_arm(unit,state,paths,ended,at)?;
    let bool result=branches::join(unit,state,paths,ref left,ref right,at)?;
    let usize freed=looping::release(paths,flow,mark,at)?;return .ok(result);
}
fn Result<context::Value,errors::Error> if_value(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    let usize at=s.begin;var context::Join output=context::joining(exact);
    let bool terminal=value_condition_paths(source,s,unit,state,table,plan,paths,flow,depth,ref mut output,staged)?;
    if(terminal){return .ok(context::bottom());}
    return context::joined(unit,state,ref output,at);
}
fn Result<bool,errors::Error> block(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,bool staged){
    var context::Join unused=context::joining(64);return scope(source,s,unit,state,table,plan,paths,flow,f,depth,ref mut unused,false,staged);
}
fn Result<bool,errors::Error> selection(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,bool staged){
    var context::Join unused=context::joining(64);return selection_paths(source,s,unit,state,table,plan,paths,flow,f,depth,ref mut unused,false,staged);
}
fn Result<context::Value,errors::Error> switch_value(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    let usize at=s.begin;let usize f=function_id(state);var context::Join output=context::joining(exact);
    let bool terminal=selection_paths(source,s,unit,state,table,plan,paths,flow,f,depth,ref mut output,true,staged)?;
    if(terminal){return .ok(context::bottom());}
    return context::joined(unit,state,ref output,at);
}
fn Result<bool,errors::Error> conditional(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value condition=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
    let usize test=context::as_scalar(unit,state,condition,at)?;
    if(register_type(unit,test)!=2){return .err(wrong(at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize guard=ir::raw(ref mut unit.body,20,0,test,0,at)?;
    let usize pool_mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    let bool ended=block(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;
    let usize end=lexer::punctuation(source,s,125)?;
    let branches::Exit left=exit_arm(unit,state,paths,ended,at)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize alternative=position(unit);let usize patched=ir::patch(ref mut unit.body,guard,alternative,at)?;
    var bool terminal=false;
    if(word(source,s,b"else")){
        let usize otherwise=lexer::next(source,s)?;
        if(word(source,s,b"if")){terminal=conditional(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;}
        else{let usize open_else=lexer::punctuation(source,s,123)?;
            terminal=block(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;
            let usize end_else=lexer::punctuation(source,s,125)?;
        }
    }
    let branches::Exit right=exit_arm(unit,state,paths,terminal,at)?;
    let bool result=branches::join(unit,state,paths,ref left,ref right,at)?;
    let usize freed=looping::release(paths,flow,pool_mark,at)?;return .ok(result);
}
struct Arm { branches::Exit exit; usize instruction; u8 variant; }
fn Result<Arm,errors::Error> selected_arm(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,usize subject,ref mut context::Join output,bool yields,bool staged){
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
    let bool terminal=scope(source,s,unit,state,table,plan,paths,flow,f,depth+1,output,yields,staged)?;
    let usize close=lexer::punctuation(source,s,125)?;
    if(!terminal){let usize released=bindings::leave_scope(unit,state,mark,at)?;}
    let branches::Exit exit=exit_arm(unit,state,paths,terminal,at)?;
    return .ok(Arm{.exit=exit,.instruction=branch.instruction,.variant=variant});
}
fn Result<bool,errors::Error> selection_paths(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,ref mut context::Join output,bool yields,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize at=s.begin;
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
    if(value.nothing || value.exact>=unit.catalog.count ||
        (unit.catalog.nodes[value.exact].kind!=5 && unit.catalog.nodes[value.exact].kind!=6)){return .err(wrong(at));}
    let usize subject=context::as_value(unit,state,value,at)?;
    let usize close=lexer::punctuation(source,s,41)?;let usize brace=lexer::punctuation(source,s,123)?;
    let usize pool_mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    let Arm first=selected_arm(source,s,unit,state,table,plan,paths,flow,f,depth,subject,output,yields,staged)?;
    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize next=position(unit);let usize patched=ops::patch_case(unit,first.instruction,next,at)?;
    let Arm second=selected_arm(source,s,unit,state,table,plan,paths,flow,f,depth,subject,output,yields,staged)?;
    if(first.variant==second.variant){return .err(wrong(at));}
    let usize end=lexer::punctuation(source,s,125)?;
    let usize failure=ir::raw(ref mut unit.body,25,0,0,0,at)?;
    let usize failed=ops::patch_case(unit,second.instruction,failure,at)?;
    let bool result=branches::join(unit,state,paths,ref first.exit,ref second.exit,at)?;
    let usize freed=looping::release(paths,flow,pool_mark,at)?;return .ok(result);
}
fn Result<usize,errors::Error> checked_post(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,bool staged){
    let usize at=s.begin;let usize checked=headers::pure(source,s,41)?;
    if(!context::assignment_ahead(source,s)?){return .err(errors::make(2,at));}
    let usize index=locals::find(source,ref state.names,s.begin,s.end);
    if(index==64 || state.bindings[index]!=0){return .err(wrong(at));}
    let headers::Scratch before=headers::scratch(unit);
    let usize assigned=assignment(source,s,unit,state,table,plan,paths,flow,41,staged)?;
    return headers::rewind(unit,before,at);
}
fn Result<bool,errors::Error> control_loop(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,bool classic,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}
    let usize at=s.begin;let usize outer=name_count(state);let usize pool=branches::mark(paths);
    let usize keyword=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    if(classic){
        let usize checked=headers::pure(source,s,59)?;
        if(s.kind==59){let usize empty=lexer::next(source,s)?;}
        else if(word(source,s,b"let") || word(source,s,b"var")){
            let usize declared=declaration(source,s,unit,state,table,plan,paths,flow,staged)?;
            if(state.bindings[declared]!=0){return .err(wrong(at));}
        }else{let usize index=locals::find(source,ref state.names,s.begin,s.end);
            if(index==64 || state.bindings[index]!=0){return .err(wrong(at));}
            let usize assigned=assignment(source,s,unit,state,table,plan,paths,flow,59,staged)?;
        }
    }
    let usize head=position(unit);let usize level=looping::begin(unit,state,paths,flow,head,classic,at)?;
    if(classic){let usize pure=headers::pure(source,s,59)?;}
    let usize test=if(classic && s.kind==59){ir::boolean(ref mut unit.body,true,at)?}else{
        let context::Value condition=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
        context::as_scalar(unit,state,condition,at)?
    };
    if(register_type(unit,test)!=2){return .err(wrong(at));}
    let usize separator=lexer::punctuation(source,s,if(classic){59}else{41})?;
    let usize guard=ir::raw(ref mut unit.body,20,0,test,0,at)?;
    let usize condition=branches::save(paths,state,at)?;
    let bool has_post=classic && s.kind!=41;let lexer::State post=lexer::snapshot(s);
    if(classic){
        if(has_post){let usize checked=checked_post(source,s,unit,state,table,plan,paths,flow,staged)?;}
        else{let usize empty=lexer::next(source,s)?;}
    }
    let usize brace=lexer::punctuation(source,s,123)?;
    let bool terminal=block(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;
    let usize close=lexer::punctuation(source,s,125)?;
    if(!terminal){let usize repeated=looping::transfer(unit,state,paths,flow,false,at)?;}
    if(classic){
        let bool reachable=looping::post(unit,state,paths,flow,at)?;
        if(reachable){
            if(has_post){var lexer::State cursor=lexer::snapshot(ref post);
                let usize emitted=assignment(source,ref mut cursor,unit,state,table,plan,paths,flow,41,staged)?;}
            let usize repeated=looping::repeat(unit,state,paths,flow,at)?;
        }
    }
    let usize inferred=looping::infer(unit,paths,flow,condition,guard,at)?;
    let usize completed=looping::finish(unit,state,paths,flow,condition,guard,at)?;
    let usize released=looping::release(paths,flow,pool,at)?;
    if(classic){let usize dropped=bindings::leave_scope(unit,state,outer,at)?;}
    return .ok(false);
}
fn Result<bool,errors::Error> scope_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,ref mut context::Join output,bool yields,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}let usize mark=name_count(state);var bool terminal=false;var bool produced=false;
    while(s.kind!=125){
        let usize at=s.begin;if(terminal || s.kind==0){return .err(errors::make(2,at));}
        if(word(source,s,b"let") || word(source,s,b"var")){let usize named=declaration(source,s,unit,state,table,plan,paths,flow,staged)?;terminal=named==64;}
        else if(word(source,s,b"while") || word(source,s,b"for")){
            let bool classic=word(source,s,b"for");terminal=control_loop(source,s,unit,state,table,plan,paths,flow,f,depth,classic,staged)?;
        }else if(word(source,s,b"break") || word(source,s,b"continue")){
            let bool leave=word(source,s,b"break");let usize keyword=lexer::next(source,s)?;
            let usize semi=lexer::punctuation(source,s,59)?;
            let usize jumped=looping::transfer(unit,state,paths,flow,leave,at)?;terminal=true;
        }
        else if(word(source,s,b"if") && !(yields && context::tail_control(source,s)?)){terminal=conditional(source,s,unit,state,table,plan,paths,flow,f,depth,staged)?;}
        else if(word(source,s,b"switch") && !(yields && context::tail_control(source,s)?)){terminal=selection(source,s,unit,state,table,plan,paths,flow,f,depth,staged)?;}
        else if(context::assignment_ahead(source,s)?){let usize assigned=assignment(source,s,unit,state,table,plan,paths,flow,59,staged)?;terminal=assigned==256;}
        else if(word(source,s,b"return")){
            state.reads=0;state.writes=0;
            let usize next=lexer::next(source,s)?;let usize result=plan.results[f];var context::Value value=context::nothing();
            if(result!=0){value=expression(source,s,unit,state,table,plan,paths,flow,result-1,1,0,staged)?;}
            else if(s.kind!=59){
                value=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
                if(!value.bottom){return .err(wrong(at));}
            }
            let usize semi=lexer::punctuation(source,s,59)?;
            if(value.bottom){terminal=true;continue;}
            if(result==66){
                let usize captured=view_source::capture(unit,state,value,at)?;
                let usize selected=view_bindings::take_return(unit,ref mut state.views,captured,at)?;
                let usize cleaned=propagation::finish_function(unit,state,16,at)?;
                let usize returned=ir::raw(ref mut unit.body,113,0,selected,0,at)?;
                terminal=true;continue;
            }
            let usize closed=bindings::close_views(unit,state,at)?;
            let usize scalar_result=if(result!=0 && !value.typed){value.value}else{0};
            let usize keep=if(value.typed){context::as_value(unit,state,value,at)?}else{16};
            let usize dropped=propagation::finish_function(unit,state,keep,at)?;
            let usize returned=ir::raw(ref mut unit.body,if(value.typed){94}else if(value.nothing){82}else{8},0,
                if(value.typed){keep}else{scalar_result},0,at)?;terminal=true;
        }else if(word(source,s,b"_")){
            let usize name=lexer::next(source,s)?;let usize eq=lexer::punctuation(source,s,61)?;
            let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
            let usize semi=lexer::punctuation(source,s,59)?;
            if(value.bottom){terminal=true;continue;}
            let usize dropped=context::discard_value(unit,state,value,at)?;
        }else if(s.kind==123){
            let usize open=lexer::next(source,s)?;terminal=block(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;
            let usize close=lexer::punctuation(source,s,125)?;
        }else{
            let usize exact=if(yields && context::tail_expression(source,s)?){output.exact}else{64};
            let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,exact,1,if(yields){depth+1}else{0},staged)?;
            if(value.bottom){
                terminal=true;
                if(s.kind==59){let usize semi=lexer::next(source,s)?;}
                continue;
            }
            if(yields && s.kind==125 && !value.nothing){
                let usize published=context::publish(unit,state,output,value,at)?;produced=true;break;
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
fn Result<walk::Outcome,errors::Error> walk_statement(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,ref mut context::Join output,bool yields,bool staged){
    let usize at=s.begin;var bool terminal=false;
        if(word(source,s,b"let") || word(source,s,b"var")){let usize named=declaration(source,s,unit,state,table,plan,paths,flow,staged)?;terminal=named==64;}
        else if(word(source,s,b"while") || word(source,s,b"for")){
            let bool classic=word(source,s,b"for");terminal=control_loop(source,s,unit,state,table,plan,paths,flow,f,depth,classic,staged)?;
        }else if(word(source,s,b"break") || word(source,s,b"continue")){
            let bool leave=word(source,s,b"break");let usize keyword=lexer::next(source,s)?;
            let usize semi=lexer::punctuation(source,s,59)?;
            let usize jumped=looping::transfer(unit,state,paths,flow,leave,at)?;terminal=true;
        }
        else if(word(source,s,b"if") && !(yields && context::tail_control(source,s)?)){terminal=conditional(source,s,unit,state,table,plan,paths,flow,f,depth,staged)?;}
        else if(word(source,s,b"switch") && !(yields && context::tail_control(source,s)?)){terminal=selection(source,s,unit,state,table,plan,paths,flow,f,depth,staged)?;}
        else if(context::assignment_ahead(source,s)?){let usize assigned=assignment(source,s,unit,state,table,plan,paths,flow,59,staged)?;terminal=assigned==256;}
        else if(word(source,s,b"return")){
            state.reads=0;state.writes=0;
            let usize next=lexer::next(source,s)?;let usize result=plan.results[f];var context::Value value=context::nothing();
            if(result!=0){value=expression(source,s,unit,state,table,plan,paths,flow,result-1,1,0,staged)?;}
            else if(s.kind!=59){
                value=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
                if(!value.bottom){return .err(wrong(at));}
            }
            let usize semi=lexer::punctuation(source,s,59)?;
            if(value.bottom){terminal=true;return .ok(walk::outcome(terminal,false));}
            if(result==66){
                let usize captured=view_source::capture(unit,state,value,at)?;
                let usize selected=view_bindings::take_return(unit,ref mut state.views,captured,at)?;
                let usize cleaned=propagation::finish_function(unit,state,16,at)?;
                let usize returned=ir::raw(ref mut unit.body,113,0,selected,0,at)?;
                terminal=true;return .ok(walk::outcome(terminal,false));
            }
            let usize closed=bindings::close_views(unit,state,at)?;
            let usize scalar_result=if(result!=0 && !value.typed){value.value}else{0};
            let usize keep=if(value.typed){context::as_value(unit,state,value,at)?}else{16};
            let usize dropped=propagation::finish_function(unit,state,keep,at)?;
            let usize returned=ir::raw(ref mut unit.body,if(value.typed){94}else if(value.nothing){82}else{8},0,
                if(value.typed){keep}else{scalar_result},0,at)?;terminal=true;
        }else if(word(source,s,b"_")){
            let usize name=lexer::next(source,s)?;let usize eq=lexer::punctuation(source,s,61)?;
            let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,64,1,0,staged)?;
            let usize semi=lexer::punctuation(source,s,59)?;
            if(value.bottom){terminal=true;return .ok(walk::outcome(terminal,false));}
            let usize dropped=context::discard_value(unit,state,value,at)?;
        }else if(s.kind==123){
            let usize open=lexer::next(source,s)?;terminal=block(source,s,unit,state,table,plan,paths,flow,f,depth+1,staged)?;
            let usize close=lexer::punctuation(source,s,125)?;
        }else{
            let usize exact=if(yields && context::tail_expression(source,s)?){output.exact}else{64};
            let context::Value value=expression(source,s,unit,state,table,plan,paths,flow,exact,1,if(yields){depth+1}else{0},staged)?;
            if(value.bottom){
                terminal=true;
                if(s.kind==59){let usize semi=lexer::next(source,s)?;}
                return .ok(walk::outcome(terminal,false));
            }
            if(yields && s.kind==125 && !value.nothing){
                let usize published=context::publish(unit,state,output,value,at)?;return .ok(walk::outcome(false,true));
            }
            if(!value.nothing){
                if(value.typed && unit.catalog.nodes[value.exact].kind==6){return .err(errors::make(18,at));}
                return .err(wrong(at));
            }let usize semi=lexer::punctuation(source,s,59)?;
        }
    return .ok(walk::outcome(terminal,false));
}
fn Result<bool,errors::Error> scope(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize f,usize depth,ref mut context::Join output,bool yields,bool staged){
    if(!staged || source.len>4096){return scope_raw(source,s,unit,state,table,plan,paths,flow,f,depth,output,yields,false);}
    var walk::Scope w=walk::scope(depth,yields);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=walk::advance_scope(s,name_count(state),ref mut w,ref mut meter)?;
        if(w.request==1){let Result<walk::Outcome,errors::Error> result=walk_statement(source,s,unit,state,table,plan,paths,flow,f,depth,output,yields,staged);
            let usize resumed=walk::resume_scope(ref mut w,1,result?)?;}
        else if(w.request==2){let usize dropped=bindings::leave_scope(unit,state,w.mark,s.begin)?;
            let usize resumed=walk::resume_scope(ref mut w,2,walk::outcome(false,false))?;}
    }return walk::scope_result(ref w);
}
fn Result<usize,errors::Error> lower_raw(ref u8[] source,ref mut values::Program unit,bool staged){
    var signatures::Table table=signatures::scan_values(source,ref mut unit.catalog)?;
    table.reference_returns=true;
    let usize inferred=reference_origins::infer(source,ref mut table)?;
    let functions::Plan plan=functions::prepare(ref unit.catalog,ref table)?;
    unit.body.function_count=table.count;unit.body.entry=table.entry;
    var usize f=0;while(f<table.count){let usize result=plan.results[f];
        let u8 tag=if(result==0){13}else if(result==66){0}else if(unit.catalog.nodes[result-1].kind==1){unit.catalog.nodes[result-1].first}else{0};
        if(result==66){unit.results[f]=context::byte(16+table.return_slice_inputs[f] as usize);}
        unit.body.return_types[f]=tag;f+=1;
    }
    var bindings::State state=bindings::empty();
    let usize enforced=bindings::enable_results(unit,ref mut state,0)?;
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();var looping::State flow=looping::empty();f=0;
    while(f<table.count){
        let usize begun=functions::begin(unit,ref mut state,source,ref table,ref plan,f)?;
        var lexer::State cursor=lexer::empty();cursor.cursor=table.bodies[f];let usize first=lexer::next(source,ref mut cursor)?;
        let bool terminal=block(source,ref mut cursor,unit,ref mut state,ref table,ref plan,ref mut paths,ref mut flow,f,0,staged)?;
        if(cursor.begin!=table.body_ends[f]){return .err(errors::make(2,cursor.begin));}
        if(!terminal){if(plan.results[f]!=0){return .err(errors::make(2,cursor.begin));}
            let usize dropped=propagation::finish_function(unit,ref mut state,16,cursor.begin)?;
            let usize returned=ir::raw(ref mut unit.body,82,0,0,0,cursor.begin)?;
        }
        let usize ended=functions::finish(unit,ref state,f,cursor.begin)?;f+=1;
    }
    return .ok(position(unit));
}
fn Result<usize,errors::Error> lower(ref u8[] source,ref mut values::Program unit,bool staged){
    if(!staged || source.len>4096){return lower_raw(source,unit,false);}
    var signatures::Table table=signatures::scan_values(source,ref mut unit.catalog)?;table.reference_returns=true;
    let usize inferred=reference_origins::infer(source,ref mut table)?;
    let functions::Plan plan=functions::prepare(ref unit.catalog,ref table)?;
    var bindings::State state=bindings::empty();var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    var looping::State flow=looping::empty();var lexer::State cursor=lexer::empty();
    var walk::Program w=walk::program();var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,cursor.begin)?;
        let bool done=walk::advance_program(source,unit,ref table,ref plan,ref mut cursor,ref mut w,ref mut meter)?;
        if(w.request==1){let usize enforced=bindings::enable_results(unit,ref mut state,0)?;let usize resumed=walk::resume_program(ref mut w,1,false)?;}
        else if(w.request==2){let usize begun=functions::begin(unit,ref mut state,source,ref table,ref plan,w.row)?;let usize resumed=walk::resume_program(ref mut w,2,false)?;}
        else if(w.request==3){let bool terminal=block(source,ref mut cursor,unit,ref mut state,ref table,ref plan,ref mut paths,ref mut flow,w.row,0,staged)?;
            let usize resumed=walk::resume_program(ref mut w,3,terminal)?;}
        else if(w.request==4){let usize dropped=propagation::finish_function(unit,ref mut state,16,cursor.begin)?;
            let usize returned=ir::raw(ref mut unit.body,82,0,0,0,cursor.begin)?;let usize resumed=walk::resume_program(ref mut w,4,false)?;}
        else if(w.request==5){let usize ended=functions::finish(unit,ref state,w.row,cursor.begin)?;let usize resumed=walk::resume_program(ref mut w,5,false)?;}
    }return .ok(position(unit));
}
pub fn Result<values::Program,errors::Error> compile(ref u8[] source){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    let usize lowered=lower(source,ref mut unit,true)?;return .ok(unit);
}

// Independent old traversal loops for private regression checks; never retry.
pub fn Result<values::Program,errors::Error> compile_raw(ref u8[] source){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    let usize lowered=lower_raw(source,ref mut unit,false)?;return .ok(unit);
}

// Mutated candidates are observable only to private regression checks.
pub fn Result<usize,errors::Error> lower_candidate(ref u8[] source,ref mut values::Program unit,bool staged){return lower(source,unit,staged);}

fn Result<context::Value,errors::Error> expression(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,u8 minimum,usize depth,bool staged){
    if(!staged || source.len>4096){return expression_raw(source,s,unit,state,table,plan,paths,flow,exact,minimum,depth,false);}
    return evaluate(source,s,unit,state,table,plan,paths,flow,exact,minimum,depth,0,staged);
}

fn Result<context::Value,errors::Error> converted(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(!staged || source.len>4096){return converted_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
    return evaluate(source,s,unit,state,table,plan,paths,flow,exact,1,depth,1,staged);
}

fn Result<context::Value,errors::Error> atom(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(!staged || source.len>4096){return atom_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
    return evaluate(source,s,unit,state,table,plan,paths,flow,exact,1,depth,2,staged);
}

fn Result<context::Value,errors::Error> primary(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(!staged || source.len>4096){return primary_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
    return evaluate(source,s,unit,state,table,plan,paths,flow,exact,1,depth,3,staged);
}

// Only the cast half of the existing lexical preflight. Stop at its explicit
// phase-10 boundary before primary-context probing, retaining the old bool.
fn Result<bool,errors::Error> cast_follows(ref u8[] source,ref lexer::State s){
    var preflight::State w=preflight::begin(*s,1,false);var budget::State meter=budget::empty();
    while(w.phase!=10 || w.waiting){let usize reset=budget::reset(ref mut meter,s.begin)?;let bool done=preflight::advance(source,ref mut w,ref mut meter)?;}
    return .ok(w.context==0);
}
fn Result<context::Value,errors::Error> evaluate(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,
    usize exact,u8 minimum,usize depth,u8 mode,bool staged){
    var evaluation::Scratch scratch=evaluation::scratch();
    return evaluate_inner(source,s,unit,state,table,plan,paths,flow,exact,minimum,depth,mode,staged,ref mut scratch);
}
fn Result<context::Value,errors::Error> evaluate_inner(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,
    usize exact,u8 minimum,usize depth,u8 mode,bool staged,ref mut evaluation::Scratch scratch){
    if(!staged || source.len>4096){if(mode==0){return expression_raw(source,s,unit,state,table,plan,paths,flow,exact,minimum,depth,false);}
        if(mode==1){return converted_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
        if(mode==2){return atom_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}return primary_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
    var evaluation::State w=evaluation::begin(exact,minimum,depth,mode);
    var evaluation::State[3] parents=[evaluation::begin(64,1,0,0);3];var usize level=0;var budget::State meter=budget::empty();
    while(true){
        if(w.done){let context::Value value=evaluation::prepared(ref w)?;if(level==0){return .ok(value);}
            level-=1;w=parents[level];let usize resumed=evaluation::resume_value(ref mut w,1,value)?;continue;}
        let usize reset=budget::reset(ref mut meter,s.begin)?;let bool done=evaluation::advance(source,s,unit,ref mut w,scratch,ref mut meter)?;
        let u8 request=w.request;

        if(request==1){
            if(w.child_depth==depth && w.child_mode==w.mode+1 && w.mode<3){
                let usize child_exact=w.expected;let u8 child_minimum=w.child_minimum;let u8 child_mode=w.child_mode;
                parents[level]=w;level+=1;w=evaluation::begin(child_exact,child_minimum,depth,child_mode);continue;}
            let context::Value value=evaluate_inner(source,s,unit,state,table,plan,paths,flow,w.expected,w.child_minimum,w.child_depth,w.child_mode,true,scratch)?;
            let usize resumed=evaluation::resume_value(ref mut w,request,value)?;}
        else if(request==5 || request==14 || request==15){let context::Value value=evaluation_leaf(source,s,unit,state,table,plan,paths,flow,ref w)?;
            let usize resumed=evaluation::resume_value(ref mut w,request,value)?;}
        else if(request!=0){let usize result=evaluation_ownership(source,s,unit,state,table,plan,paths,flow,ref mut w)?;
            let usize resumed=evaluation::resume_scalar(ref mut w,request,result)?;}
    }
    return .err(errors::make(5,s.begin));
}

fn Result<context::Value,errors::Error> call(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize target,usize at,usize depth,bool staged){
    if(!staged || source.len>4096){return call_raw(source,s,unit,state,table,plan,paths,flow,target,at,depth,false);}
    return call_staged(source,s,unit,state,table,plan,paths,flow,target,at,depth,true);
}
fn Result<context::Value,errors::Error> call_staged(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize target,usize at,usize depth,bool staged){
    var call_work::Arguments w=call_work::arguments(target,at,depth);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,at)?;let bool done=call_work::advance_arguments(source,s,unit,table,plan,ref mut w,ref mut meter)?;
        let u8 request=w.request;if(request!=0){var context::Value value=w.value;var usize number=0;
            if(request==1){value=expression(source,s,unit,state,table,plan,paths,flow,w.exact,1,depth+1,true)?;}
            else if(request==2){number=if(w.exact==65){view_source::capture(unit,state,value,at)?}else if(unit.catalog.nodes[w.exact].kind==1){context::as_scalar(unit,state,value,at)?}else{context::as_value(unit,state,value,at)?};}
            else{value=source_calls::finish(unit,state,table,plan,target,ref w.arguments,ref w.captures,w.row,w.extended,at)?;}
            let usize resumed=call_work::resume_argument(ref mut w,request,value,number)?;}
    }return call_work::arguments_result(ref w);
}
fn Result<context::Value,errors::Error> constructor(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(!staged || source.len>4096){return constructor_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,false);}
    return constructor_staged(source,s,unit,state,table,plan,paths,flow,exact,depth,true);
}
fn Result<context::Value,errors::Error> constructor_staged(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    var call_work::Constructor w=call_work::constructor(exact,depth);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,s.begin)?;let bool done=call_work::advance_constructor(source,s,unit,ref mut w,ref mut meter)?;
        let u8 request=w.request;if(request!=0){var context::Value value=w.value;var usize number=0;
            if(request==1){value=expression(source,s,unit,state,table,plan,paths,flow,w.expected,1,depth+1,true)?;}
            else if(request==2){number=context::intern(unit,5,context::byte(value.exact),0,w.at)?;}
            else if(request==3){number=context::as_value(unit,state,value,w.at)?;}
            else if(request==4){number=ops::tag(unit,state,w.wrapper,w.payload,if(w.some || w.ok){1}else{0},w.at)?;}
            else{number=bindings::drop(unit,state,w.payload,w.at)?;}
            let usize resumed=call_work::resume_constructor(ref mut w,request,value,number)?;}
    }return call_work::constructor_result(ref w);
}

// Keep non-recursive ownership/CFG service temporaries off every live operand
// frame. The raw fast paths above likewise never enter the stateful driver.
fn Result<context::Value,errors::Error> evaluation_leaf(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,ref evaluation::State w){
    if(w.request==5){return primary_raw(source,s,unit,state,table,plan,paths,flow,w.exact,w.depth,true);}
    if(w.request==14){return view_index(source,s,unit,state,table,plan,paths,flow,w.left,w.depth,true);}
    if(view_source::reference(w.left)){return view_source::length(source,s,unit,state,w.left);}return context::predicate(source,s,unit,state,w.left);
}
fn Result<usize,errors::Error> evaluation_ownership(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,ref mut evaluation::State w){
    let u8 request=w.request;
            let usize result=if(request==6){if(cast_follows(source,s)?){1}else{0}}
                else if(request==7){if(context::postfix_receiver(source,s)?){1}else{0}}
                else if(request==8){context::as_scalar(unit,state,if(w.phase==7 || w.phase==71){w.child}else{w.left},w.at)?}
                else if(request==9){context::intern(unit,1,w.tag,0,w.at)?}
                else if(request==10){w.pending=boolean::begin(unit,state,paths,w.operation,w.a,w.at)?;0}
                else if(request==11){boolean::finish(unit,state,paths,flow,w.pending,w.number,w.at)?}
                else if(request==12){
                    let branches::Exit evaluated=branches::capture(paths,state,true,0,w.at)?;
                    let usize selected=branches::select(unit,state,paths,w.pending.entry,w.at)?;
                    let usize target=position(unit);let usize patched=ir::patch(ref mut unit.body,w.pending.guard,target,w.at)?;
                    let usize skip=ir::raw(ref mut unit.body,19,0,0,0,w.at)?;
                    let branches::Exit skipped=branches::capture(paths,state,false,skip,w.at)?;
                    let bool joined=branches::join(unit,state,paths,ref evaluated,ref skipped,w.at)?;
                    let usize freed=looping::release(paths,flow,w.pending.pool,w.at)?;
                    ir::emit(ref mut unit.body,17,w.pending.slot,0,w.at)?}
                else if(request==13){if(view_source::range_ahead(source,s)?){1}else{0}}
                else if(request==16){let usize f=function_id(state);let usize result=if(plan.results[f]==0){64}else{plan.results[f]-1};
                    w.expanded=propagation::lower(unit,state,paths,w.a,result,w.at)?;0}
                else if(request==17){context::as_value(unit,state,w.left,w.at)?}
                else if(request==18){ops::scalar_read(unit,state,w.expanded.payload,w.at)?}
                else{bindings::drop(unit,state,w.expanded.payload,w.at)?};

    return .ok(result);
}

fn Result<context::Value,errors::Error> primary_raw(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize exact,usize depth,bool staged){
    if(depth>32){return .err(errors::make(4,s.begin));}
    if(s.kind==2 && !word(source,s,b"ref") && !word(source,s,b"if") && !word(source,s,b"switch") && !word(source,s,b"true") && !word(source,s,b"false")){
        var lexer::State look=lexer::snapshot(s);let usize peek=lexer::next(source,ref mut look)?;
        if(look.kind==40){let usize begin=s.begin;let usize end=s.end;let usize next=lexer::next(source,s)?;
            let usize target=if(staged){name_work::target(source,table,begin,end)?}else{signatures::find(source,table,begin,end)};
            return call(source,s,unit,state,table,plan,paths,flow,target,begin,depth,staged);}
    }
    return primary_leaf_raw(source,s,unit,state,table,plan,paths,flow,exact,depth,staged);
}

fn Result<context::Value,errors::Error> raw_boolean_finish(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,context::Value left,context::Value right,boolean::Pending pending,usize at){
            if(right.bottom){
                let branches::Exit evaluated=branches::capture(paths,state,true,0,at)?;
                let usize selected=branches::select(unit,state,paths,pending.entry,at)?;
                let usize target=position(unit);let usize patched=ir::patch(ref mut unit.body,pending.guard,target,at)?;
                let usize skip=ir::raw(ref mut unit.body,19,0,0,0,at)?;
                let branches::Exit skipped=branches::capture(paths,state,false,skip,at)?;
                let bool joined=branches::join(unit,state,paths,ref evaluated,ref skipped,at)?;
                let usize freed=looping::release(paths,flow,pending.pool,at)?;
                let usize result=ir::emit(ref mut unit.body,17,pending.slot,0,at)?;
                return .ok(context::scalar(left.exact,result));
            }
            let usize b=context::as_scalar(unit,state,right,at)?;
            let usize result=boolean::finish(unit,state,paths,flow,pending,b,at)?;
            return .ok(context::scalar(left.exact,result));

}
fn Result<context::Value,errors::Error> raw_binary_finish(ref mut values::Program unit,ref mut bindings::State state,context::Value left,context::Value right,u8 operation,usize a,usize at){
        let usize b=context::as_scalar(unit,state,right,at)?;
        if(left.exact!=right.exact || (!types::integer(register_type(unit,a)) && operation!=128 && operation!=129)){
            return .err(wrong(at));
        }
        let usize result=ir::emit(ref mut unit.body,context::opcode(operation),a,b,at)?;
        let usize type=if(operation==128 || operation==129 || operation==60 || operation==62 || operation==130 || operation==131){
            context::intern(unit,1,2,0,at)?}else{left.exact};return .ok(context::scalar(type,result));
}
fn Result<context::Value,errors::Error> raw_cast_suffix(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,context::Value input){
    var context::Value value=input;
    while(word(source,s,b"as")){
        let usize at=s.begin;let usize keyword=lexer::next(source,s)?;
        let u8 target=types::parse(source,s)?;
        if(!types::scalar(target)){return .err(wrong(at));}
        // Terminal work was already emitted. Validate every suffix without
        // inventing a register/capture/destination or replaying that work.
        if(value.bottom){continue;}
        let usize input=context::as_scalar(unit,state,value,at)?;
        let usize result=ir::widen(ref mut unit.body,input,target,at)?;
        let usize type=context::intern(unit,1,target,0,at)?;
        value=context::scalar(type,result);
    }
    return .ok(value);
}
fn Result<context::Value,errors::Error> raw_postfix_suffix(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut bindings::State state,ref signatures::Table table,ref functions::Plan plan,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,context::Value input,usize depth,bool staged){
    var context::Value value=input;
    while(s.kind==46 || s.kind==63 || s.kind==91){
        if(value.bottom){return .err(wrong(s.begin));}
        if(s.kind==46 && view_source::range_ahead(source,s)?){break;}
        if(s.kind==91){value=view_index(source,s,unit,state,table,plan,paths,flow,value,depth,staged)?;}
        else if(s.kind==46){value=if(view_source::reference(value)){view_source::length(source,s,unit,state,value)?}
            else{context::predicate(source,s,unit,state,value)?};}
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
