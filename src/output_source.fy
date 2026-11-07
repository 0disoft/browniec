module output_source;
import lexer as lexer;
import locals as locals;
import functions as functions;
import source_context as context;
import errors as errors;
import ir as ir;
import slice_source as slices;

// Only the exact unresolved namespace spelling denotes the private builtin.
// Imported aliases (even aliases without emit) and real functions take precedence.
pub fn bool candidate(ref u8[] source,ref lexer::State s,ref locals::Table names,ref functions::Table signatures){
    if(s.kind!=5){return false;}
    let ref u8[] query=source[s.begin..s.end];var lexer::State name=lexer::empty();
    if(!lexer::next(query,ref mut name).is_ok || name.kind!=2 || !lexer::equal(query[name.begin..name.end],b"output") ||
        !lexer::next(query,ref mut name).is_ok || name.kind!=58 ||
        !lexer::next(query,ref mut name).is_ok || name.kind!=58 ||
        !lexer::next(query,ref mut name).is_ok || name.kind!=2 || !lexer::equal(query[name.begin..name.end],b"emit") ||
        !lexer::next(query,ref mut name).is_ok || name.kind!=0){return false;}
    return functions::find(source,signatures,s.begin,s.end)==16 &&
        !context::imported(source,ref signatures.context,s.begin,b"output") &&
        locals::find(source,names,s.begin,s.begin+6)==64;
}
pub fn Result<usize,errors::Error> head(ref u8[] source,ref mut lexer::State s,
    ref functions::Table signatures,u8 terminator,u8 result_type){
    let usize at=s.begin;
    if(!signatures.output || terminator!=59 || result_type==0){return .err(errors::make(3,at));}
    let usize name=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let usize prefix=lexer::word(source,s,b"ref")?;
    return .ok(at);
}
// An existing exclusive byte loan may be observed without creating or closing it.
pub fn u8 access(ref u8[] source,ref lexer::State s,ref locals::Table names,ref ir::Program p){
    let usize id=locals::find(source,names,s.begin,s.end);
    return if(slices::binding(names,id) && ir::exclusive(p,names.registers[id]-160)){138}else{10};
}

// Text's builtin namespace is a view expression only with a following ::.
// A caller's ordinary array named text keeps its existing owner path.
pub fn Result<bool,errors::Error> image(ref u8[] source,ref lexer::State s,ref locals::Table names){
    if(s.kind==3 || s.kind==4 || s.kind==40){return .ok(true);}
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"text")){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==58);
}
