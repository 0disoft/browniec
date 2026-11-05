module array_local_source;
import lexer as lexer;
import locals as locals;
import local_inference as inference;
import array_source as arrays;
import ir as ir;
import types as types;
import errors as errors;

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
