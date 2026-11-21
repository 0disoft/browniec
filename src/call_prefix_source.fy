module call_prefix_source;
import lexer as lexer;
import locals as locals;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import argument_name_work as names_work;
import array_source as arrays;
import struct_value_source as records;

// 256 asks the caller to start ordinary capture lowering without consuming a
// token or changing IR. Bare immutable owners already have stable value bytes;
// they need no hidden lexical binding across subsequent argument evaluation.
pub fn Result<usize,errors::Error> stable(ref u8[] source,ref mut lexer::State s,
    ref ir::Program p,ref locals::Table names,u8 tag,usize length,usize record,usize depth){
    var usize fuel=budget::unlimited();
    return stable_metered(source,s,p,names,tag,length,record,depth,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> stable_metered(ref u8[] source,ref mut lexer::State s,
    ref ir::Program p,ref locals::Table names,u8 tag,usize length,usize record,usize depth,usize deadline,ref mut usize fuel){
    if(s.kind==40 && (length!=0 || record!=0)){return grouped_owner(source,s,p,names,tag,length,record,depth,deadline,fuel);}
    if(s.kind!=2){return .ok(256);}
    let usize index=names_work::local_metered(source,names,s.begin,s.end,deadline,fuel)?;
    var usize value=256;
    if(length!=0 && arrays::binding(names,index)){
        let usize id=names.registers[index]-128;
        if(id<p.arrays.count && !p.arrays.mutable[id] && p.arrays.elements[id]==tag &&
            p.arrays.lengths[id]==length && p.array_functions[id] as usize==names.function){value=128+id;}
    }else if(record!=0 && records::binding(names,index)){
        let usize id=names.registers[index]-144;
        if(id<p.records.count && !p.records.mutable[id] && p.records.records[id] as usize==record-1 &&
            p.record_functions[id] as usize==names.function){value=144+id;}
    }
    if(value==256){return .ok(256);}
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next_metered(source,ref mut look,deadline,fuel)?;
    if(look.kind!=44 && look.kind!=41){return .ok(256);}
    let usize consumed=lexer::next_metered(source,s,deadline,fuel)?;return .ok(value);
}

// Parentheses do not turn an immutable owner into a capture. Keep its lexical
// table snapshot off recursive CALL frames, with the same combined depth limit.
fn Result<usize,errors::Error> grouped_owner(ref u8[] source,ref mut lexer::State s,
    ref ir::Program p,ref locals::Table names,u8 tag,usize length,usize record,usize depth,usize deadline,ref mut usize fuel){
    if(depth>32){return .err(errors::make(4,s.begin));}
    var lexer::State look=lexer::snapshot(s);var usize groups=0;
    while(look.kind==40){if(groups>=32-depth){return .err(errors::make(4,look.begin));}
        let usize next=lexer::next_metered(source,ref mut look,deadline,fuel)?;groups+=1;}
    if(look.kind!=2){return .ok(256);}
    let usize index=names_work::local_metered(source,names,look.begin,look.end,deadline,fuel)?;
    var usize value=256;
    if(length!=0 && arrays::binding(names,index)){let usize id=names.registers[index]-128;
        if(id<16 && id<p.arrays.count && !p.arrays.mutable[id] && p.arrays.elements[id]==tag &&
            p.arrays.lengths[id]==length && p.array_functions[id] as usize==names.function){value=128+id;}}
    else if(record!=0 && records::binding(names,index)){let usize id=names.registers[index]-144;
        if(id<16 && id<p.records.count && !p.records.mutable[id] && p.records.records[id] as usize==record-1 &&
            p.record_functions[id] as usize==names.function){value=144+id;}}
    if(value==256){return .ok(256);}
    let usize name=lexer::next_metered(source,ref mut look,deadline,fuel)?;var usize i=0;
    while(i<groups){if(look.kind!=41){return .ok(256);}let usize next=lexer::next_metered(source,ref mut look,deadline,fuel)?;i+=1;}
    if(look.kind!=44 && look.kind!=41){return .ok(256);}
    i=0;while(i<groups){let usize open=lexer::next_metered(source,s,deadline,fuel)?;i+=1;}
    let usize consumed=lexer::next_metered(source,s,deadline,fuel)?;i=0;
    while(i<groups){let usize close=lexer::next_metered(source,s,deadline,fuel)?;i+=1;}
    return .ok(value);
}
