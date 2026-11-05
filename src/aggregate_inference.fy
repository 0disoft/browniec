module aggregate_inference;
import lexer as lexer;
import locals as locals;
import ir as ir;
import functions as functions;
import errors as errors;
import array_source as arrays;
import struct_value_source as records;

// Advisory source classification only. Scalar expressions use the ordinary
// expression parser. Every aggregate still follows existing lowering/admission.
pub struct Shape { u8 element; usize length; usize record; }
fn Shape scalar(){return Shape{.element=0,.length=0,.record=0};}
fn Result<usize,errors::Error> after_call(ref u8[] source,ref mut lexer::State look){
    var usize depth=1;let usize first=lexer::next(source,look)?;
    while(depth!=0){
        if(look.kind==0){return .err(errors::make(2,look.begin));}
        if(look.kind==40){depth+=1;}else if(look.kind==41){depth-=1;}
        let usize next=lexer::next(source,look)?;
    }
    return .ok(look.begin);
}
pub fn Result<Shape,errors::Error> inspect(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    if(s.kind!=2 && s.kind!=5){return .ok(scalar());}
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
    if(look.kind==123){let usize record=records::named(source,s,ref signatures.context)?;
        return .ok(Shape{.element=0,.length=0,.record=record+1});}
    let usize local=locals::find(source,names,s.begin,s.end);
    var usize record=0;var usize length=0;var u8 element=0;
    if(look.kind==40 && local==64){
        let usize target=functions::find(source,signatures,s.begin,s.end);
        if(target>=signatures.count){return .ok(scalar());}
        record=signatures.return_records[target] as usize;length=signatures.return_lengths[target];
        if(record==0 && length==0){return .ok(scalar());}
        element=signatures.return_types[target];let usize end=after_call(source,ref mut look)?;
    }else if(arrays::binding(names,local)){
        let usize id=names.registers[local]-128;
        if(id>=p.arrays.count || p.array_functions[id] as usize!=names.function){return .err(errors::make(3,s.begin));}
        length=p.arrays.lengths[id];element=p.arrays.elements[id];
    }else if(records::binding(names,local)){
        let usize id=names.registers[local]-144;
        if(id>=p.records.count || p.record_functions[id] as usize!=names.function){return .err(errors::make(3,s.begin));}
        record=p.records.records[id] as usize+1;
    }else{return .ok(scalar());}
    if(record!=0 && look.kind==46){record=records::inferred_endpoint(source,ref mut look,p,record-1,s.begin,ref signatures.context)?;}
    if(look.kind!=59){return .ok(scalar());}
    return .ok(Shape{.element=element,.length=length,.record=record});
}
