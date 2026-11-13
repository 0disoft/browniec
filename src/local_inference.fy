module local_inference;
import lexer as lexer;
import declaration_name_work as headers;
import locals as locals;
import ir as ir;
import types as types;
import errors as errors;

pub struct Header { usize begin; usize end; }
// One token of lookahead distinguishes a binder from an explicit type. It
// never evaluates the initializer or changes the active lexer/IR.
pub fn Result<bool,errors::Error> follows_raw(ref u8[] source,ref lexer::State s){
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
    return .ok(look.kind==61);
}
pub fn Result<Header,errors::Error> header_raw(ref u8[] source,ref mut lexer::State s,ref locals::Table names){
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}
    let usize begin=s.begin;let usize end=s.end;
    if(locals::find(source,names,begin,end)!=64){return .err(errors::make(3,begin));}
    if(names.count>=64){return .err(errors::make(4,begin));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    return .ok(Header{.begin=begin,.end=end});
}
pub fn Result<bool,errors::Error> follows(ref u8[] source,ref lexer::State s){if(source.len>4096){return follows_raw(source,s);}return headers::follows(source,s);}
pub fn Result<Header,errors::Error> header(ref u8[] source,ref mut lexer::State s,ref locals::Table names){
    if(source.len>4096){return header_raw(source,s,names);}
    let usize end=s.end;let usize begin=headers::prepare(source,s,names,false)?;return .ok(Header{.begin=begin,.end=end});
}
// Scalar/wrapper inference uses the already checked expression's exact type.
// Publication follows complete initialization, just like annotated locals.
pub fn Result<usize,errors::Error> bind(ref mut ir::Program p,ref mut locals::Table names,
    Header name,usize value,bool mutable,bool pure){
    if(value>=p.registers || value>=128 || !types::valid(p.types[value]) ||
        (pure && !types::scalar(p.types[value]))){return .err(errors::make(3,name.begin));}
    let u8 tag=p.types[value];var usize binding=value;
    if(mutable){binding=ir::slot(p,tag,name.begin)?;
        let usize stored=ir::raw(p,18,binding,value,0,name.begin)?;}
    return locals::declare(names,name.begin,name.end,binding,mutable);
}
