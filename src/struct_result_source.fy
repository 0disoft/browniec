module struct_result_source;
import functions as functions;
import ir as ir;
import lexer as lexer;
import locals as locals;
import errors as errors;
import array_source as arrays;
import struct_value_source as values;
import cells as cells;
import std::num as num;
import source_context as source_context;

// Formals are already reserved in ordinal order. Reuse an exact nominal formal
// as the shape anchor, or reserve a dead site before lowering any function body.
pub fn Result<usize,errors::Error> prepare(ref functions::Table signatures,ref mut ir::Program p) {
    var usize f=0;var usize count=0;
    while(f<signatures.count) {
        let usize encoded=signatures.return_records[f] as usize;
        if(encoded!=0) {
            let usize nominal=encoded-1;
            let usize leaves=values::leaf_count(p,nominal,signatures.begins[f])?;
            var usize site=0;
            while(site<p.records.count) {
                if(p.record_functions[site] as usize==f && p.records.records[site] as usize==nominal) {break;}
                site+=1;
            }
            if(site==p.records.count) {site=ir::record_in(p,f,nominal,false,signatures.begins[f])?;}
            let i64 value=cells::pack(site+1,signatures.begins[f])?;
            p.record_results[f]=switch(num::u8_from_i64(value)) {
                case .ok(n):{n}case .err(_):{return .err(errors::make(4,signatures.begins[f]));}
            };
            count+=1;
        }
        f+=1;
    }
    return .ok(count);
}
// 0 is the existing for-header restriction; 1..12 are scalar/wrapper contexts.
// 255 marks an enclosing record result and is never a scalar/IR type tag.
pub fn u8 context(ref ir::Program p,usize f) {
    return if(p.record_results[f]!=0){255}else{p.return_types[f]};
}
pub fn Result<usize,errors::Error> destination(ref functions::Table signatures,usize target,
    usize nominal,bool mutable,ref mut ir::Program p,usize f,usize at) {
    if(target>=signatures.count || signatures.return_records[target] as usize!=nominal+1) {
        return .err(errors::make(3,at));
    }
    return ir::record_in(p,f,nominal,mutable,at);
}
// Keep the destination live through CALL and capture cleanup, overwrite its
// existing owner once, then release the anonymous result.
pub fn Result<usize,errors::Error> assigned(ref mut ir::Program p,usize destination,usize temporary,usize at) {
    if(destination>=p.records.count || temporary>=p.records.count || destination==temporary ||
        !p.records.mutable[destination] || p.record_functions[destination]!=p.record_functions[temporary] ||
        p.records.records[destination]!=p.records.records[temporary]) {return .err(errors::make(3,at));}
    let usize copied=ir::record_assign(p,destination,temporary,at)?;
    return ir::record_drop(p,temporary,at);
}
// Copy the entire returned root into an exact nominal destination subrecord,
// retaining the destination owner and releasing the anonymous result afterward.
pub fn Result<usize,errors::Error> subassigned(ref mut ir::Program p,usize destination,
    usize temporary,values::Leaf leaf,usize at) {
    if(destination>=p.records.count || temporary>=p.records.count || destination==temporary ||
        !p.records.mutable[destination] || leaf.tag!=0 ||
        p.record_functions[destination]!=p.record_functions[temporary] ||
        p.records.records[temporary] as usize!=leaf.record) {return .err(errors::make(3,at));}
    let usize copied=ir::record_subassign(p,destination,temporary,leaf.record,leaf.ordinal,0,at)?;
    return ir::record_drop(p,temporary,at);
}
// Bare bindings, subrecord copies, direct-call results and constructors share the
// finisher. General record expressions remain unavailable.
pub fn Result<usize,errors::Error> returned(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,usize at,ref source_context::Table scope) {
    if(s.kind!=2) {return .err(errors::make(3,s.begin));}
    var lexer::State look=lexer::snapshot(s);
    let usize next_token=lexer::next(source,ref mut look)?;
    if(look.kind==46) {
        let usize encoded=p.record_results[names.function] as usize;
        if(encoded==0) {return .err(errors::make(3,at));}
        let usize record=p.records.records[encoded-1] as usize;
        let usize extracted=values::extracted(source,s,p,names,record,false,at,scope)?;
        return finish(p,names,extracted,at);
    }
    let usize index=locals::find(source,names,s.begin,s.end);
    if(!values::binding(names,index)) {return .err(errors::make(3,s.begin));}
    let usize id=names.registers[index]-144;
    let usize next=lexer::next(source,s)?;
    if(s.kind!=59) {return .err(errors::make(3,s.begin));}
    let usize end=lexer::next(source,s)?;
    return finish(p,names,id,at);
}
// Pending call destinations stay absent from names until CALL and capture
// cleanup complete. Keep the returned token and drop other mixed bindings.
pub fn Result<usize,errors::Error> finish(ref mut ir::Program p,
    ref locals::Table names,usize id,usize at) {
    let usize encoded=p.record_results[names.function] as usize;
    if(encoded==0 || id>=p.records.count || id>=16 || p.record_functions[id] as usize!=names.function ||
        p.records.records[id]!=p.records.records[encoded-1]) {return .err(errors::make(3,at));}
    var usize i=names.count;
    while(i>0) {
        i-=1;
        if(names.registers[i]!=144+id){let usize dropped=arrays::release_at(names,p,i,at)?;}
    }
    return ir::record_return(p,id,at);
}
