module struct_result_vm;

import ir as ir;
import errors as errors;
import array_vm as arrays;
import struct_vm as records;
import array_owners as owners;
import std::bytes as bytes;

pub fn usize cost() {
    // Two complete layout plans, one bounded scalar snapshot, scratch/codec
    // work, both child token sets and owner metadata. No payload copy/reserve.
    return 2 * 18432 + 4096 + 1024 + 129;
}

// Trusted native single-use transfer. Only canonical restoration preserving
// the prepared unique result owner may intervene before publication.
pub struct Transfer { owners::Token token; usize child; usize parent; }
pub fn Result<Transfer,errors::Error> prepare(ref ir::Program p,usize target,usize source,
    usize destination,usize frame,ref records::State record_state,
    ref arrays::State state,ref bytes::Buffer buffer,usize offset) {
    return prepare_data(p,target,source,destination,frame,record_state,state,bytes::view(buffer),offset);
}
pub fn Result<Transfer,errors::Error> prepare_data(ref ir::Program p,usize target,usize source,
    usize destination,usize frame,ref records::State record_state,
    ref arrays::State state,ref u8[] data,usize offset) {
    if(frame==0 || frame>=32 || source>=16 || destination>=16) {
        return .err(errors::make(5,offset));
    }
    let usize child=frame*16;let usize parent=(frame-1)*16+destination;
    return prepare_frame(p,target,source,destination,frame,ref state.owners,
        ref record_state.tokens[child..child+16],ref state.tokens[child..child+16],
        record_state.tokens[parent],data,offset);
}
// Compact child frames contain exactly sixteen tokens each. The caller gathers
// the existing parent destination separately; Transfer retains absolute indices.
pub fn Result<Transfer,errors::Error> prepare_frame(ref ir::Program p,usize target,usize source,
    usize destination,usize frame,ref owners::Table table,
    ref owners::Token[] record_child,ref owners::Token[] array_child,
    owners::Token parent,ref u8[] data,usize offset) {
    if(frame==0 || frame>=32 || p.function_count>16 || target>=p.function_count ||
        target==p.entry || p.records.count>16 || source>=p.records.count || destination>=p.records.count ||
        source>=16 || destination>=16 || record_child.len!=16 || array_child.len!=16) {
        return .err(errors::make(5,offset));
    }
    let usize encoded=p.record_results[target] as usize;
    if(encoded==0 || encoded>p.records.count || p.array_results[target]!=0 ||
        p.return_types[target]!=0 || p.record_functions[source] as usize!=target ||
        p.record_functions[encoded-1] as usize!=target) {return .err(errors::make(5,offset));}
    let usize nominal=p.records.records[encoded-1] as usize;
    if(p.records.records[source] as usize!=nominal || p.records.records[destination] as usize!=nominal) {
        return .err(errors::make(5,offset));
    }
    if(parent.generation!=0 || parent.slot!=0) {
        return .err(errors::make(5,offset));
    }
    var usize i=0;
    while(i<16) {
        if(array_child[i].generation!=0 || array_child[i].slot!=0 ||
            (i!=source && (record_child[i].generation!=0 || record_child[i].slot!=0))) {
            return .err(errors::make(5,offset));
        }
        i+=1;
    }
    let owners::Token token=record_child[source];
    let usize checked=switch(owners::validate_record_result(ref p.records.layouts,
        table,token,nominal,data)) {
        case .ok(n):{n} case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return .ok(Transfer{.token=token,.child=frame*16+source,.parent=(frame-1)*16+destination});
}

pub fn void publish(ref Transfer plan,ref mut records::State state) {
    state.tokens[plan.child]=owners::Token{.slot=0,.generation=0};
    state.tokens[plan.parent]=plan.token;
}
// Preserve legacy prepayment, validation order and remaining Fuel.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize target,usize source,
    usize destination,usize frame,ref mut records::State record_state,
    ref arrays::State state,ref bytes::Buffer buffer,usize fuel,usize offset) {
    let usize work=cost();
    if(fuel<work) {return .err(errors::make(8,offset));}
    let Transfer plan=prepare(p,target,source,destination,frame,record_state,state,buffer,offset)?;
    publish(ref plan,record_state);
    return .ok(fuel-work);
}
