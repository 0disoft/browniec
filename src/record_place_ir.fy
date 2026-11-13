module record_place_ir;
import ir as ir;
import destination_record_work as destination;
import struct_meta as records;
import types as types;
import errors as errors;
import std::num as num;

// Kind 2 uses byte5 for the repeated scalar ordinal. SELECT has b=0;
// READ/STORE repeat the record site in their ordinary root operand. No index
// register, guest owner or payload is reserved by construction.
fn Result<u8,errors::Error> shape(ref ir::Program p,usize site,usize ordinal,usize at) {
    if(site>=16 || site>=p.records.count || !p.records.mutable[site] || ordinal>=128){return .err(errors::make(3,at));}
    let records::Prepared shapes=switch(records::prepare(ref p.records)){
        case .ok(value):{value}case .err(_):{return .err(errors::make(3,at));}
    };
    if(ordinal>=shapes.leaves[site]){return .err(errors::make(3,at));}
    return .ok(shapes.tags[site*128+ordinal]);
}
fn bool scalar(ref ir::Program p,usize r,u8 tag) {
    return r<128 && r<p.registers && p.types[r]==tag && !p.slots[r] &&
        p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0;
}
fn Result<u8,errors::Error> field(usize ordinal,usize at) {
    let i64 wide=switch(num::i64_from_usize(ordinal)){case .ok(v):{v}case .err(_):{return .err(errors::make(3,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(3,at))}};
}
pub fn Result<usize,errors::Error> select_raw(ref mut ir::Program p,usize place,usize site,usize ordinal,usize at) {
    let u8 tag=shape(p,site,ordinal,at)?;let u8 leaf=field(ordinal,at)?;
    if(place>=16){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,83,place,site,0,at)?;p.code[pc*8+4]=2;p.code[pc*8+5]=leaf;return .ok(pc);
}
pub fn Result<usize,errors::Error> select(ref mut ir::Program p,usize place,usize site,usize ordinal,usize at){
    let u8 tag=destination::prepare(p,2,site,0,ordinal,at)?;let u8 leaf=field(ordinal,at)?;
    if(place>=16){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,83,place,site,0,at)?;p.code[pc*8+4]=2;p.code[pc*8+5]=leaf;return .ok(pc);
}
pub fn Result<usize,errors::Error> read(ref mut ir::Program p,usize place,usize site,usize ordinal,usize at) {
    let u8 tag=shape(p,site,ordinal,at)?;let u8 leaf=field(ordinal,at)?;
    if(place>=16){return .err(errors::make(3,at));}
    if(p.registers>=128 || p.count>=256){return .err(errors::make(4,at));}
    let usize dst=p.registers;let usize pc=ir::raw(p,84,dst,place,site,at)?;
    p.code[pc*8+4]=2;p.code[pc*8+5]=leaf;p.types[dst]=tag;p.registers+=1;return .ok(dst);
}
pub fn Result<usize,errors::Error> store(ref mut ir::Program p,usize place,usize site,usize ordinal,usize value,usize at) {
    let u8 tag=shape(p,site,ordinal,at)?;let u8 leaf=field(ordinal,at)?;
    if(place>=16 || !scalar(p,value,tag)){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,85,place,site,value,at)?;p.code[pc*8+4]=2;p.code[pc*8+5]=leaf;return .ok(pc);
}
// The canonical verifier prepared this exact immutable catalog once. Reuse its
// independently reconstructed leaves, never a type supplied by the builder.
pub fn Result<u8,errors::Error> element(ref ir::Program p,ref records::Prepared shapes,
    usize site,usize ordinal,usize function,usize pc) {
    if(function>=16 || function>=p.function_count || site>=16 || site>=p.records.count ||
        p.record_functions[site] as usize!=function || !p.records.mutable[site] ||
        ordinal>=128 || ordinal>=shapes.leaves[site]){return .err(errors::make(5,pc));}
    let u8 tag=shapes.tags[site*128+ordinal];
    if(!types::scalar(tag)){return .err(errors::make(5,pc));}return .ok(tag);
}
