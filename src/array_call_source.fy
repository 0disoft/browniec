module array_call_source;

import functions as functions;
import locals as locals;
import lexer as lexer;
import ir as ir;
import errors as errors;
import array_source as arrays;
import cells as cells;
import argument_name_work as names_work;
import metadata_budget as budget;
import std::num as num;

// Predeclare every parameter shape, including forward and mutually recursive
// targets. Register positions are assigned later in each function body.
pub fn Result<usize,errors::Error> prepare(ref mut functions::Table signatures,ref mut ir::Program p) {
    var usize f=0;var usize count=0;
    while(f<signatures.count) {
        var usize i=0;
        while(i<signatures.arities[f]) {
            let usize at=f*8+i;
            if(signatures.param_lengths[at]!=0) {
                let usize id=ir::array_in(p,f,signatures.param_types[at],signatures.param_lengths[at],false,signatures.param_begins[at])?;
                let i64 encoded=cells::pack(id+1,signatures.param_begins[at])?;
                let u8 value=switch(num::u8_from_i64(encoded)) {
                    case .ok(n):{n} case .err(_):{return .err(errors::make(4,signatures.param_begins[at]));}
                };
                signatures.param_arrays[at]=value;count+=1;
            }
            i+=1;
        }
        f+=1;
    }
    return .ok(count);
}
pub fn Result<usize,errors::Error> bind(ref functions::Table signatures,usize at,ref mut ir::Program p,ref mut locals::Table names) {
    let usize register=p.registers;
    let u8 encoded=signatures.param_arrays[at];
    let usize binding=if(encoded==0){register}else{127+encoded as usize};
    let usize declared=locals::declare(names,signatures.param_begins[at],signatures.param_ends[at],binding,false)?;
    p.types[register]=signatures.param_types[at];
    p.array_parameters[register]=encoded;p.registers+=1;
    return .ok(declared);
}
// Source array arguments are bare names, with exact element and length matches.
// An immutable owner is already stable. Mutable owners need a private snapshot
// before any later argument executes. Empty name spans cannot match guest names.
pub fn Result<usize,errors::Error> capture_raw(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table names,u8 element,usize length) {
    let usize at=s.begin;
    if(s.kind!=2) {return .err(errors::make(3,at));}
    let usize index=locals::find(source,names,s.begin,s.end);
    if(!arrays::binding(names,index)) {return .err(errors::make(3,at));}
    let usize id=names.registers[index]-128;
    if(p.arrays.elements[id]!=element || p.arrays.lengths[id]!=length ||
        p.array_functions[id] as usize!=names.function) {return .err(errors::make(3,at));}
    let usize next=lexer::next(source,s)?;
    if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
    return capture_id(p,names,id,element,length,at);
}
pub fn Result<usize,errors::Error> capture(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table names,u8 element,usize length,usize deadline,ref mut usize fuel) {
    let usize at=s.begin;
    if(s.kind!=2) {return .err(errors::make(3,at));}
    let usize index=names_work::local_metered(source,names,s.begin,s.end,deadline,fuel)?;
    if(!arrays::binding(names,index)) {return .err(errors::make(3,at));}
    let usize id=names.registers[index]-128;
    if(p.arrays.elements[id]!=element || p.arrays.lengths[id]!=length ||
        p.array_functions[id] as usize!=names.function) {return .err(errors::make(3,at));}
    let usize next=lexer::next_metered(source,s,deadline,fuel)?;
    if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
    return capture_id_metered(p,names,id,element,length,at,deadline,fuel);
}
// Grouping and bare names snapshot mutable sources at the same argument point.
pub fn Result<usize,errors::Error> capture_id(ref mut ir::Program p,ref mut locals::Table names,
    usize source,u8 element,usize length,usize at){
    var usize fuel=budget::unlimited();
    return capture_id_metered(p,names,source,element,length,at,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> capture_id_metered(ref mut ir::Program p,ref mut locals::Table names,
    usize source,u8 element,usize length,usize at,usize deadline,ref mut usize fuel){
    if(source>=16 || source>=p.arrays.count || p.arrays.elements[source]!=element || p.arrays.lengths[source]!=length ||
        p.array_functions[source] as usize!=names.function){return .err(errors::make(3,at));}
    var usize id=source;
    if(p.arrays.mutable[id]) {
        if(names.count>=64) {return .err(errors::make(4,at));}
        id=arrays::copy_metered(p,names.function,id,element,length,false,at,deadline,fuel)?;
        let usize anonymous=locals::declare(names,at,at,128+id,false)?;
    }
    return .ok(128+id);
}
