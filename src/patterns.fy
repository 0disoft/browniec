module patterns;

import errors as errors;
import lexer as lexer;
import locals as locals;
import types as types;

pub struct Pattern {u8 variant; usize begin; usize end; bool binding;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name) {
    return s.kind==2 && lexer::equal(source[s.begin..s.end],name);
}
pub fn Result<Pattern,errors::Error> parse(ref u8[] source,ref mut lexer::State s,u8 tag) {
    let usize keyword=lexer::word(source,s,b"case")?;
    let usize dot=lexer::punctuation(source,s,46)?;
    let usize at=s.begin;
    let bool positive=word(source,s,b"some") || word(source,s,b"ok");
    if(tag<=4) {
        if(!word(source,s,b"some") && !word(source,s,b"none")) {return .err(errors::make(3,at));}
    } else if(!word(source,s,b"ok") && !word(source,s,b"err")) {return .err(errors::make(3,at));}
    let u8 variant=if(positive) {1} else {0};
    let usize name=lexer::next(source,s)?;
    var Pattern p=Pattern {.variant=variant,.begin=0,.end=0,.binding=false};
    if(types::payload(tag,variant)!=0) {
        let usize open=lexer::punctuation(source,s,40)?;
        let bool ignored=word(source,s,b"_");
        if(s.kind!=2 || (!ignored && locals::reserved(source[s.begin..s.end]))) {return .err(errors::make(2,s.begin));}
        p.begin=s.begin; p.end=s.end; p.binding=!ignored;
        let usize bind=lexer::next(source,s)?;
        let usize close=lexer::punctuation(source,s,41)?;
    }
    let usize colon=lexer::punctuation(source,s,58)?;
    return .ok(p);
}
