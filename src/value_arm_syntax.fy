module value_arm_syntax;
import lexer as lexer;
import array_source as arrays;
import struct_value_source as records;
import locals as locals;
import errors as errors;

fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){
    return s.kind==2 && lexer::equal(source[s.begin..s.end],name);
}
// Keep keyword spelling scratch outside recursive scalar dispatcher frames.
pub fn u8 operand_kind(ref u8[] source,ref lexer::State s){
    if(word(source,s,b"if")){return 1;}if(word(source,s,b"switch")){return 2;}return 0;
}
// Shared, read-only distinction between an assignment and a final value read.
pub fn Result<bool,errors::Error> regular(ref u8[] source,ref lexer::State s){
    if(word(source,s,b"let") || word(source,s,b"var")){return .ok(true);}
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
    return .ok(look.kind==61 || (look.kind==91 && arrays::indexed_assignment(source,ref look)?) ||
        (look.kind==46 && records::assigned(source,ref look)?));
}
fn Result<usize,errors::Error> balanced(ref u8[] source,ref mut lexer::State s,u8 open,u8 close){
    let usize first=lexer::punctuation(source,s,open)?;var usize depth=1;
    while(depth!=0){if(s.kind==0){return .err(errors::make(2,s.begin));}
        if(s.kind==open){depth+=1;}else if(s.kind==close){depth-=1;}
        let usize next=lexer::next(source,s)?;
    }return .ok(0);
}
fn Result<usize,errors::Error> statement_end(ref u8[] source,ref mut lexer::State s){
    var usize parens=0;var usize braces=0;var usize brackets=0;
    while(true){if(s.kind==0 || (s.kind==125 && braces==0)){return .err(errors::make(2,s.begin));}
        if(s.kind==59 && parens==0 && braces==0 && brackets==0){let usize next=lexer::next(source,s)?;return .ok(0);}
        if(s.kind==40){parens+=1;}else if(s.kind==41 && parens!=0){parens-=1;}
        else if(s.kind==123){braces+=1;}else if(s.kind==125 && braces!=0){braces-=1;}
        else if(s.kind==91){brackets+=1;}else if(s.kind==93 && brackets!=0){brackets-=1;}
        let usize next=lexer::next(source,s)?;
    }return .ok(0);
}
// Called inside a body after finding its value tail. Consume its remaining
// spelling only; actual lowering rechecks types, delimiters, scope and exits.
fn Result<usize,errors::Error> body_end(ref u8[] source,ref mut lexer::State s){
    var usize braces=1;
    while(braces!=0){if(s.kind==0){return .err(errors::make(2,s.begin));}
        if(s.kind==123){braces+=1;}else if(s.kind==125){braces-=1;}
        let usize next=lexer::next(source,s)?;
    }return .ok(0);
}
fn Result<bool,errors::Error> body_value(ref u8[] source,ref mut lexer::State s,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    let usize open=lexer::punctuation(source,s,123)?;
    while(s.kind!=125){if(s.kind==0){return .err(errors::make(2,s.begin));}
        if(word(source,s,b"if")){
            let bool value=conditional(source,s,depth+1)?;
            if(value){let usize end=body_end(source,s)?;return .ok(true);}continue;
        }
        if(word(source,s,b"while") || word(source,s,b"for")){
            let usize keyword=lexer::next(source,s)?;let usize head=balanced(source,s,40,41)?;
            let usize body=balanced(source,s,123,125)?;continue;
        }
        if(s.kind==123){let usize block=balanced(source,s,123,125)?;continue;}
        if(regular(source,s)? || word(source,s,b"return") || word(source,s,b"break") || word(source,s,b"continue")){
            let usize end=statement_end(source,s)?;continue;
        }
        let usize end=body_end(source,s)?;return .ok(true);
    }
    let usize close=lexer::next(source,s)?;return .ok(false);
}
fn Result<bool,errors::Error> conditional(ref u8[] source,ref mut lexer::State s,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    let usize keyword=lexer::word(source,s,b"if")?;let usize condition=balanced(source,s,40,41)?;
    let bool positive=body_value(source,s,depth+1)?;
    if(!word(source,s,b"else")){return .ok(positive);}
    let usize alternative=lexer::next(source,s)?;
    let bool negative=if(word(source,s,b"if")){conditional(source,s,depth+1)?}else{body_value(source,s,depth+1)?};
    return .ok(positive || negative);
}
// Only disambiguates a leading conditional in a value arm. Its lexer copy and
// small boolean result stay outside recursive lowering frames; it emits no IR.
pub fn Result<bool,errors::Error> conditional_value(ref u8[] source,ref lexer::State s){
    var lexer::State look=lexer::snapshot(s);return conditional(source,ref mut look,0);
}
