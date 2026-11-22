module patterns;

import errors as errors;
import lexer as lexer;
import locals as locals;
import metadata_budget as budget;

pub struct Pattern {u8 variant; usize begin; usize end; bool binding;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name) {
    return s.kind==2 && lexer::equal(source[s.begin..s.end],name);
}
pub fn Result<Pattern,errors::Error> parse(ref u8[] source,ref mut lexer::State s,u8 tag) {
    var usize fuel=budget::unlimited();
    return parse_metered(source,s,tag,0,ref mut fuel);
}
pub fn Result<Pattern,errors::Error> parse_result(ref u8[] source,ref mut lexer::State s){
    var usize fuel=budget::unlimited();
    return parse_choice(source,s,false,0,ref mut fuel);
}
pub fn Result<Pattern,errors::Error> parse_result_metered(ref u8[] source,ref mut lexer::State s,
    usize deadline,ref mut usize fuel){
    return parse_choice(source,s,false,deadline,fuel);
}
pub fn Result<Pattern,errors::Error> parse_metered(ref u8[] source,ref mut lexer::State s,
    u8 tag,usize deadline,ref mut usize fuel){
    return parse_choice(source,s,tag<=4,deadline,fuel);
}
fn Result<usize,errors::Error> take(ref u8[] source,ref mut lexer::State s,
    u8 kind,usize deadline,ref mut usize fuel){
    if(s.kind!=kind){return .err(errors::make(2,s.begin));}
    if(deadline==0 && *fuel==budget::unlimited()){return lexer::next(source,s);}
    return lexer::next_metered(source,s,deadline,fuel);
}
fn Result<Pattern,errors::Error> parse_choice(ref u8[] source,ref mut lexer::State s,
    bool option,usize deadline,ref mut usize fuel){
    if(!word(source,s,b"case")){return .err(errors::make(2,s.begin));}
    discard take(source,s,2,deadline,fuel)?;
    let usize dot=take(source,s,46,deadline,fuel)?;
    let usize at=s.begin;
    let bool positive=word(source,s,b"some") || word(source,s,b"ok");
    if(option) {
        if(!word(source,s,b"some") && !word(source,s,b"none")) {return .err(errors::make(3,at));}
    } else if(!word(source,s,b"ok") && !word(source,s,b"err")) {return .err(errors::make(3,at));}
    let u8 variant=if(positive) {1} else {0};
    discard take(source,s,2,deadline,fuel)?;
    var Pattern p=Pattern {.variant=variant,.begin=0,.end=0,.binding=false};
    if(!option || positive) {
        let usize open=take(source,s,40,deadline,fuel)?;
        let bool ignored=word(source,s,b"_");
        if(s.kind!=2 || (!ignored && locals::reserved(source[s.begin..s.end]))) {return .err(errors::make(2,s.begin));}
        p.begin=s.begin; p.end=s.end; p.binding=!ignored;
        discard take(source,s,2,deadline,fuel)?;
        let usize close=take(source,s,41,deadline,fuel)?;
    }
    let usize colon=take(source,s,58,deadline,fuel)?;
    return .ok(p);
}
