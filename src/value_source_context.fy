module value_source_context;
import value_ir as values;
import value_properties as properties;
import value_source_bindings as bindings;
import value_source_ops as ops;
import lexer as lexer;
import locals as locals;
import ir as ir;
import errors as errors;
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn errors::Error wrong(usize at){return errors::make(3,at);}

pub struct Value { usize exact; usize value; bool typed; bool nothing; usize binding; }
pub fn Value scalar(usize exact,usize value){return Value{.exact=exact,.value=value,.typed=false,.nothing=false,.binding=64};}
pub fn Value owned(usize exact,usize value){return Value{.exact=exact,.value=value,.typed=true,.nothing=false,.binding=64};}
pub fn Value nothing(){return Value{.exact=64,.value=256,.typed=false,.nothing=true,.binding=64};}


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
    if((value.nothing && exact!=64) || (exact!=64 && value.exact!=exact)){return .err(wrong(at));}return .ok(value);
}
pub fn Result<usize,errors::Error> capture(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.binding==64){return .ok(value.value);}
    let usize to=bindings::allocate(unit,state,value.exact,at)?;
    return bindings::use_binding(unit,state,value.binding,to,at);
}
pub fn Result<usize,errors::Error> as_scalar(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.nothing || value.exact>=unit.catalog.count || unit.catalog.nodes[value.exact].kind!=1){return .err(wrong(at));}
    if(!value.typed){return .ok(value.value);}
    let usize id=capture(unit,state,value,at)?;
    let usize result=ops::scalar_read(unit,state,id,at)?;
    let usize dropped=bindings::drop(unit,state,id,at)?;return .ok(result);
}
pub fn Result<usize,errors::Error> as_value(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.nothing){return .err(wrong(at));}if(value.typed){return capture(unit,state,value,at);}
    return ops::scalar_value(unit,state,value.value,value.exact,at);
}
pub fn Result<usize,errors::Error> discard_value(ref mut values::Program unit,ref mut bindings::State state,Value value,usize at){
    if(value.nothing){return .err(wrong(at));}
    if(value.typed){let usize id=capture(unit,state,value,at)?;
        let usize handled=bindings::handle(unit,state,id,at)?;return bindings::drop(unit,state,id,at);}return .ok(0);
}
pub fn u8 precedence(u8 kind){
    return if(kind==124){1}else if(kind==94){2}else if(kind==38){3}
        else if(kind==128 || kind==129){4}else if(kind==60 || kind==62 || kind==130 || kind==131){5}
        else if(kind==134 || kind==135){6}else if(kind==43 || kind==45){7}
        else if(kind==42 || kind==47 || kind==37){8}else{0};
}
pub fn Result<bool,errors::Error> postfix_receiver(ref u8[] source,ref lexer::State cursor){
    var lexer::State look=lexer::snapshot(cursor);var usize parens=0;var usize braces=0;var bool started=false;var bool control=false;
    while(look.kind!=0){
        if(parens==0 && braces==0){
            if(word(source,ref look,b"if") || word(source,ref look,b"switch")){control=true;}
            if(look.kind==63){return .ok(true);}
            if(look.kind==46 && started){let usize dot=lexer::next(source,ref mut look)?;
                if(word(source,ref look,b"is_some") || word(source,ref look,b"is_none") ||
                    word(source,ref look,b"is_ok") || word(source,ref look,b"is_err")){return .ok(true);}
                continue;
            }
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
