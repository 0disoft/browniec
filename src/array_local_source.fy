module array_local_source;
import lexer as lexer;
import locals as locals;
import local_inference as inference;
import array_source as arrays;
import ir as ir;
import types as types;
import errors as errors;

// Classify only the first outer separator. Comments/literals and nested
// expressions belong to the lexer; lookahead never lowers a guest expression.
pub fn Result<bool,errors::Error> is_repeated(ref u8[] source,ref lexer::State s){
    if(s.kind!=91){return .err(errors::make(2,s.begin));}
    var lexer::State look=lexer::snapshot(s);let usize open=lexer::next(source,ref mut look)?;
    var usize depth=0;
    while(look.kind!=0){
        let u8 kind=look.kind;
        if(depth==0 && (kind==59 || kind==44 || kind==93)){return .ok(kind==59);}
        if(kind==40 || kind==91 || kind==123){depth+=1;}
        else if(kind==41 || kind==93 || kind==125){
            if(depth==0){return .err(errors::make(2,look.begin));}depth-=1;
        }
        let usize next=lexer::next(source,ref mut look)?;
    }
    return .err(errors::make(2,look.begin));
}

// No lexical owner/name exists during evaluation of any cell. Complete
// initialization is the single publication point, as for repeated arrays.
pub fn Result<usize,errors::Error> list(ref mut ir::Program p,usize function,
    ref usize[] values,u8 element,usize expected,bool mutable,usize at){
    if(values.len==0 || (expected!=0 && expected!=values.len) || !types::scalar(element)){
        return .err(errors::make(3,at));}
    let usize id=ir::array_in(p,function,element,values.len,mutable,at)?;
    let usize initialized=ir::array_values(p,id,values,at)?;
    return .ok(id);
}

// The filler is already evaluated once. Zero expected length means infer the
// exact shape from the same positive literal used by annotated repeated arrays.
pub fn Result<usize,errors::Error> repeated(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,inference::Header name,
    usize value,u8 element,usize expected,bool mutable,u8 terminator){
    if(value>=p.registers || value>=128 || !types::scalar(element) || p.types[value]!=element || terminator!=59){
        return .err(errors::make(3,name.begin));}
    let usize separator=lexer::punctuation(source,s,59)?;
    let usize length=arrays::count(source,s)?;
    if(expected!=0 && expected!=length){return .err(errors::make(3,name.begin));}
    let usize close=lexer::punctuation(source,s,93)?;let usize end=lexer::punctuation(source,s,terminator)?;
    let usize id=ir::array_in(p,names.function,element,length,mutable,name.begin)?;
    let usize initialized=ir::array_init(p,id,value,name.begin)?;
    return locals::declare(names,name.begin,name.end,128+id,mutable);
}
