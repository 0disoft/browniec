module value_source_context;
import value_ir as values;
import value_properties as properties;
import value_source_bindings as bindings;
import value_source_ops as ops;
import value_view_bindings as views;
import lexer as lexer;
import locals as locals;
import ir as ir;
import errors as errors;
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn errors::Error wrong(usize at){return errors::make(3,at);}

pub struct Value { usize exact; usize value; bool typed; bool nothing; bool bottom; usize binding; }
pub fn Value scalar(usize exact,usize value){return Value{.exact=exact,.value=value,.typed=false,.nothing=false,.bottom=false,.binding=64};}
pub fn Value owned(usize exact,usize value){return Value{.exact=exact,.value=value,.typed=true,.nothing=false,.bottom=false,.binding=64};}
// Bottom has no value, binding, owner or destination. It is not a void call.
pub fn Value bottom(){return Value{.exact=64,.value=256,.typed=false,.nothing=false,.bottom=true,.binding=64};}
pub fn Value nothing(){return Value{.exact=64,.value=256,.typed=false,.nothing=true,.bottom=false,.binding=64};}


pub fn u8 byte(usize value){var u8 b=0;var usize i=0;while(i<value){b+=1;i+=1;}return b;}
pub fn Result<usize,errors::Error> intern(ref mut values::Program unit,u8 kind,u8 first,u8 second,usize at){
    var usize i=0;while(i<unit.catalog.count){let properties::Node n=unit.catalog.nodes[i];
        if(n.kind==kind && n.first==first && n.second==second && n.extent==0){return .ok(i);}i+=1;
    }
    if(unit.catalog.count>=64){return .err(errors::make(4,at));}
    let usize id=unit.catalog.count;unit.catalog.nodes[id]=properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
    unit.catalog.count+=1;
    if(!properties::inspect(ref unit.catalog).is_ok){return .err(wrong(at));}return .ok(id);
}
pub fn Result<Value,errors::Error> expected(Value value,usize exact,usize at){
    if(value.bottom){return .ok(value);}
    if((value.nothing && exact!=64) || (exact!=64 && value.exact!=exact)){return .err(wrong(at));}return .ok(value);
}
pub fn Result<usize,errors::Error> capture(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.bottom){return .err(wrong(at));}
    if(value.exact==65){
        let usize roots=views::roots(ref state.views,value.value,at)?;
        if(value.binding==64){return .ok(value.value);}
        if(value.binding>=state.names.count || state.views.names[value.binding] as usize!=value.value+1){return .err(wrong(at));}
        return views::alias(unit,ref mut state.views,value.value,at);
    }
    if(value.binding==64){return .ok(value.value);}
    let usize to=bindings::allocate(unit,state,value.exact,at)?;
    return bindings::use_binding(unit,state,value.binding,to,at);
}
pub fn Result<usize,errors::Error> as_scalar(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.bottom || value.nothing || value.exact>=unit.catalog.count || unit.catalog.nodes[value.exact].kind!=1){return .err(wrong(at));}
    if(!value.typed){return .ok(value.value);}
    let usize id=capture(unit,state,value,at)?;
    let usize result=ops::scalar_read(unit,state,id,at)?;
    let usize dropped=bindings::drop(unit,state,id,at)?;return .ok(result);
}
pub fn Result<usize,errors::Error> as_value(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.bottom || value.nothing || value.exact==65){return .err(wrong(at));}if(value.typed){return capture(unit,state,value,at);}
    return ops::scalar_value(unit,state,value.value,value.exact,at);
}
pub fn Result<usize,errors::Error> discard_value(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.bottom || value.nothing){return .err(wrong(at));}
    if(value.exact==65){
        if(value.binding==64){return bindings::close_view(unit,state,value.value,at);}
        let usize roots=views::roots(ref state.views,value.value,at)?;return .ok(0);
    }
    if(value.typed){let usize id=capture(unit,state,value,at)?;
        let usize handled=bindings::handle(unit,state,id,at)?;return bindings::drop(unit,state,id,at);}return .ok(0);
}
pub fn u8 precedence(u8 kind){
    return if(kind==133){1}else if(kind==132){2}else if(kind==124){3}else if(kind==94){4}else if(kind==38){5}
        else if(kind==128 || kind==129){6}else if(kind==60 || kind==62 || kind==130 || kind==131){7}
        else if(kind==134 || kind==135){8}else if(kind==43 || kind==45){9}
        else if(kind==42 || kind==47 || kind==37){10}else{0};
}
pub fn Result<bool,errors::Error> postfix_receiver(ref u8[] source,ref lexer::State cursor){
    var lexer::State look=lexer::snapshot(cursor);var usize parens=0;var usize braces=0;var bool started=false;var bool control=false;
    while(look.kind!=0){
        if(parens==0 && braces==0){
            if(word(source,ref look,b"if") || word(source,ref look,b"switch")){control=true;}
            if(look.kind==63){return .ok(true);}
            if(look.kind==46 && started){let usize dot=lexer::next(source,ref mut look)?;
                if(look.kind==46){return .ok(false);}
                if(word(source,ref look,b"len") || word(source,ref look,b"is_some") || word(source,ref look,b"is_none") ||
                    word(source,ref look,b"is_ok") || word(source,ref look,b"is_err")){return .ok(true);}
                continue;
            }
            if(look.kind==91 && started){return .ok(true);}
            if(look.kind==59 || look.kind==44 || look.kind==41 || look.kind==125 || look.kind==93 || (look.kind==123 && !control)){return .ok(false);}
            if(started && precedence(look.kind)!=0){return .ok(false);}
        }
        if(look.kind==123){braces+=1;}else if(look.kind==125){if(braces==0){return .ok(false);}braces-=1;}
        if(look.kind==40){parens+=1;}else if(look.kind==41){if(parens==0){return .ok(false);}parens-=1;}
        started=true;let usize next=lexer::next(source,ref mut look)?;
    }return .ok(false);
}
pub fn u8 compound(u8 token){
    return if(token==136){2}else if(token==137){3}else if(token==138){4}else if(token==139){5}
        else if(token==140){6}else if(token==141){31}else if(token==142){32}
        else if(token==143){28}else if(token==144){29}else{30};
}

// Distinguish a final control expression from earlier statement control inside
// a value arm. Only lexical lookahead is performed; the real parser emits once.
pub fn Result<bool,errors::Error> tail_control(ref u8[] source,ref lexer::State cursor){
    var lexer::State look=lexer::snapshot(cursor);var usize parens=0;var usize braces=0;
    var bool body=false;
    while(look.kind!=0){
        if(look.kind==40){parens+=1;}else if(look.kind==41 && parens!=0){parens-=1;}
        if(look.kind==123 && (body || parens==0)){braces+=1;body=true;}
        else if(look.kind==125 && body){
            braces-=1;
            if(braces==0){
                let usize next=lexer::next(source,ref mut look)?;
                if(word(source,ref look,b"else")){body=false;continue;}
                return .ok(look.kind==125 || look.kind==41 || look.kind==44 || look.kind==93 ||
                    look.kind==46 || look.kind==63 || precedence(look.kind)!=0);
            }
        }
        let usize next=lexer::next(source,ref mut look)?;
    }return .ok(false);
}

// Earlier void calls are statements and must not inherit the arm's value type.
pub fn Result<bool,errors::Error> tail_expression(ref u8[] source,ref lexer::State cursor){
    var lexer::State look=lexer::snapshot(cursor);var usize parens=0;var usize braces=0;
    while(look.kind!=0){
        if(parens==0 && braces==0){
            if(look.kind==59){return .ok(false);}if(look.kind==125){return .ok(true);}
        }
        if(look.kind==40){parens+=1;}else if(look.kind==41){if(parens==0){return .ok(false);}parens-=1;}
        if(look.kind==123){braces+=1;}else if(look.kind==125){if(braces==0){return .ok(false);}braces-=1;}
        let usize next=lexer::next(source,ref mut look)?;
    }return .ok(false);
}

pub struct Join { usize exact; usize destination; bool have; }

pub fn u8 opcode(u8 kind){
    return if(kind==134){31}else if(kind==135){32}else if(kind==38){28}else if(kind==94){29}else if(kind==124){30}
        else if(kind==128){11}else if(kind==129){12}else if(kind==60){13}else if(kind==130){14}
        else if(kind==62){15}else if(kind==131){16}else if(kind==43){2}else if(kind==45){3}
        else if(kind==42){4}else if(kind==47){5}else{6};
}

pub fn Result<Value,errors::Error> buffer(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
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
    let usize type=intern(unit,4,0,0,at)?;
    let Value result=expected(owned(type,0),exact,at)?;
    let usize id=ops::empty_buffer(unit,state,type,at)?;return .ok(owned(type,id));
}

pub fn Result<Value,errors::Error> predicate(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,
    ref mut bindings::State state,Value value){
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
    let usize boolean=intern(unit,1,2,0,at)?;return .ok(scalar(boolean,result));
}

pub fn Result<bool,errors::Error> assignment_ahead(ref u8[] source,ref lexer::State s){
    if(s.kind!=2 || word(source,s,b"_")){return .ok(false);}var lexer::State look=lexer::snapshot(s);
    let usize next=lexer::next(source,ref mut look)?;
    return .ok(look.kind==61 || (look.kind>=136 && look.kind<=145));
}

pub fn Join joining(usize exact){return Join{.exact=exact,.destination=128,.have=false};}

pub fn Result<usize,errors::Error> publish(ref mut values::Program unit,ref mut bindings::State state,
    ref mut Join output,Value value,usize at){
    if(value.bottom){return .err(wrong(at));}
    if(!value.nothing && value.exact==65 && (output.exact==64 || output.exact==65)){
        if(!output.have){output.destination=views::reserve(unit,ref mut state.views,at)?;
            output.exact=65;output.have=true;}
        let usize id=capture(unit,state,value,at)?;
        return views::move_to(unit,ref mut state.views,id,output.destination,at);
    }
    if(value.nothing || value.exact>=unit.catalog.count ||
        (output.exact!=64 && value.exact!=output.exact)){return .err(wrong(at));}
    let bool scalar=unit.catalog.nodes[value.exact].kind==1;
    let u8 tag=unit.catalog.nodes[value.exact].first;
    if(!output.have){
        output.destination=if(scalar){ir::slot(ref mut unit.body,tag,at)?}
            else{bindings::allocate(unit,state,value.exact,at)?};
        output.exact=value.exact;output.have=true;
    }
    if(scalar){let usize reg=as_scalar(unit,state,value,at)?;
        return ir::raw(ref mut unit.body,18,output.destination,reg,0,at);
    }
    if(value.binding!=64){return bindings::use_binding(unit,state,value.binding,output.destination,at);}
    let usize id=as_value(unit,state,value,at)?;
    return bindings::move_value(unit,state,output.destination,id,at);
}

pub fn Result<Value,errors::Error> joined(ref mut values::Program unit,ref mut bindings::State state,
    ref Join output,usize at){
    if(!output.have){return .err(wrong(at));}
    if(output.exact==65){
        let usize roots=views::roots(ref state.views,output.destination,at)?;
        let usize released=views::unreserve(ref mut state.views,output.destination,at)?;
        return .ok(Value{.exact=65,.value=output.destination,.typed=false,.nothing=false,.bottom=false,.binding=64});
    }
    if(unit.catalog.nodes[output.exact].kind==1){
        let usize reg=ir::emit(ref mut unit.body,17,output.destination,0,at)?;
        return .ok(scalar(output.exact,reg));
    }
    return .ok(owned(output.exact,output.destination));
}

fn u8 register_type(ref values::Program unit,usize index){let ref ir::Program body=ref unit.body;return body.types[index];}
