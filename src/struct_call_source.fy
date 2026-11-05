module struct_call_source;
import functions as functions;
import locals as locals;
import lexer as lexer;
import ir as ir;
import errors as errors;
import struct_value_source as values;
import cells as cells;
import std::num as num;

// Reserve formals before any body so forward and mutual calls have stable sites.
// Sites stay ordered by formal position within each owning function. Binding
// finds that ordinal in the sixteen-site catalog; no extra parameter map needed.
pub fn Result<usize,errors::Error> prepare(ref functions::Table signatures,ref mut ir::Program p) {
    var usize f=0;var usize count=0;
    while(f<signatures.count) {
        var usize i=0;
        while(i<signatures.arities[f]) {
            let usize at=f*8+i;let usize encoded=signatures.param_records[at] as usize;
            if(encoded!=0) {
                let usize leaves=values::leaf_count(p,encoded-1,signatures.param_begins[at])?;
                let usize site=ir::record_in(p,f,encoded-1,false,signatures.param_begins[at])?;
                count+=1;
            }
            i+=1;
        }
        f+=1;
    }
    return .ok(count);
}
pub fn Result<usize,errors::Error> bind(ref functions::Table signatures,usize at,
    ref mut ir::Program p,ref mut locals::Table names) {
    let usize f=at/8;var usize ordinal=0;var usize i=f*8;
    while(i<at){if(signatures.param_records[i]!=0){ordinal+=1;}i+=1;}
    i=0;
    while(i<p.records.count) {
        if(p.record_functions[i] as usize==f) {
            if(ordinal==0) {
                let usize reg=p.registers;
                let usize declared=locals::declare(names,signatures.param_begins[at],signatures.param_ends[at],144+i,false)?;
                let i64 value=cells::pack(i+1,signatures.param_begins[at])?;
                p.record_parameters[reg]=switch(num::u8_from_i64(value)) {
                    case .ok(n):{n}case .err(_):{return .err(errors::make(4,signatures.param_begins[at]));}
                };
                p.types[reg]=0;p.array_parameters[reg]=0;p.registers+=1;
                return .ok(declared);
            }
            ordinal-=1;
        }
        i+=1;
    }
    return .err(errors::make(3,signatures.param_begins[at]));
}
pub fn Result<usize,errors::Error> capture(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,usize record) {
    let usize at=s.begin;
    if(s.kind!=2){return .err(errors::make(3,at));}
    let usize index=locals::find(source,names,s.begin,s.end);
    if(!values::binding(names,index)){return .err(errors::make(3,at));}
    let usize id=names.registers[index]-144;
    if(id>=p.records.count || p.records.records[id] as usize!=record ||
        p.record_functions[id] as usize!=names.function){return .err(errors::make(3,at));}
    let usize next=lexer::next(source,s)?;
    if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
    return capture_id(p,names,id,record,at);
}
pub fn Result<usize,errors::Error> capture_id(ref mut ir::Program p,ref mut locals::Table names,usize source,usize record,usize at){
    if(source>=16 || source>=p.records.count || p.records.records[source] as usize!=record || p.record_functions[source] as usize!=names.function){return .err(errors::make(3,at));}
    var usize id=source;
    if(p.records.mutable[id]) {
        if(names.count>=64){return .err(errors::make(4,at));}
        let usize destination=ir::record_in(p,names.function,record,false,at)?;
        let usize copied=ir::record_copy(p,destination,id,at)?;
        let usize anonymous=locals::declare(names,at,at,144+destination,false)?;
        id=destination;
    }
    return .ok(144+id);
}
