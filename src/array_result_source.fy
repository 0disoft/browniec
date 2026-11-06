module array_result_source;

import functions as functions;
import ir as ir;
import lexer as lexer;
import locals as locals;
import errors as errors;
import place_source as places;
import array_source as arrays;
import cells as cells;
import std::num as num;

// Forward calls need result shape anchors before any body is lowered. Reuse an
// exact-shape parameter catalog where possible; otherwise reserve one dead site.
pub fn Result<usize,errors::Error> prepare(ref functions::Table signatures,ref mut ir::Program p) {
    var usize f=0;var usize count=0;
    while(f<signatures.count) {
        let usize length=signatures.return_lengths[f];
        if(length!=0) {
            var u8 encoded=0;var usize i=0;
            while(i<signatures.arities[f]) {
                let usize at=f*8+i;
                if(signatures.param_lengths[at]==length && signatures.param_types[at]==signatures.return_types[f]) {
                    encoded=signatures.param_arrays[at];break;
                }
                i+=1;
            }
            if(encoded==0) {
                let usize id=ir::array_in(p,f,signatures.return_types[f],length,false,signatures.begins[f])?;
                let i64 value=cells::pack(id+1,signatures.begins[f])?;
                encoded=switch(num::u8_from_i64(value)) {case .ok(n):{n} case .err(_):{return .err(errors::make(4,signatures.begins[f]));}};
            }
            p.array_results[f]=encoded;count+=1;
        }
        f+=1;
    }
    return .ok(count);
}
pub fn Result<usize,errors::Error> destination(ref functions::Table signatures,usize target,u8 element,usize length,
    bool mutable,ref mut ir::Program p,usize f,usize at) {
    if(target>=signatures.count || signatures.return_lengths[target]!=length || length==0 ||
        signatures.return_types[target]!=element) {return .err(errors::make(3,at));}
    return ir::array_in(p,f,element,length,mutable,at);
}
pub fn Result<usize,errors::Error> returned(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table names,usize at) {
    let usize encoded=p.array_results[names.function] as usize;
    if(encoded==0 || s.kind!=2) {return .err(errors::make(3,s.begin));}
    let usize index=locals::find(source,names,s.begin,s.end);
    if(!arrays::binding(names,index)) {return .err(errors::make(3,s.begin));}
    let usize id=names.registers[index]-128;
    let usize next=lexer::next(source,s)?;
    if(s.kind!=59) {return .err(errors::make(3,s.begin));}
    let usize end=lexer::next(source,s)?;
    return finish(p,names,id,at);
}
// CALL has completed and its captures are released. Preserve the destination's
// owner/extent, copy once, then release the anonymous result.
pub fn Result<usize,errors::Error> assigned(ref mut ir::Program p,usize destination,usize temporary,usize at) {
    let usize copied=arrays::assign(p,destination,temporary,at)?;
    return ir::array_drop(p,temporary,at);
}
// The filler has already been evaluated once; no result exists on its early exits.
pub fn Result<usize,errors::Error> repeated(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table names,usize value,usize at) {
    let usize encoded=p.array_results[names.function] as usize;
    if(encoded==0 || value>=p.registers) {return .err(errors::make(3,at));}
    let usize shape=encoded-1;
    if(p.types[value]!=p.arrays.elements[shape]) {return .err(errors::make(3,at));}
    let usize separator=lexer::punctuation(source,s,59)?;
    let usize length=arrays::count(source,s)?;
    if(length!=p.arrays.lengths[shape]) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;
    let usize end=lexer::punctuation(source,s,59)?;
    let u8 element=p.arrays.elements[shape];
    let usize id=ir::array_in(p,names.function,element,length,false,at)?;
    let usize initialized=ir::array_init(p,id,value,at)?;
    return finish(p,names,id,at);
}
// Named owners, literals and anonymous call results leave through the same cleanup.
// Pending call destinations are absent from names until CALL has executed.
pub fn Result<usize,errors::Error> finish(ref mut ir::Program p,ref locals::Table names,usize id,usize at) {
    let usize encoded=p.array_results[names.function] as usize;
    if(encoded==0 || id>=p.arrays.count || id>=16) {return .err(errors::make(3,at));}
    let usize shape=encoded-1;
    if(p.array_functions[id] as usize!=names.function || p.arrays.elements[id]!=p.arrays.elements[shape] ||
        p.arrays.lengths[id]!=p.arrays.lengths[shape]) {return .err(errors::make(3,at));}
    let usize ended=places::release(names,p,0,at)?;
    var usize i=names.count;
    while(i>0) {
        i-=1;
        if(names.registers[i]!=128+id){let usize dropped=arrays::release_at(names,p,i,at)?;}
    }
    return ir::array_return(p,id,at);
}
