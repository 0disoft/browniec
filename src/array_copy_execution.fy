module array_copy_execution;
import ir as ir;
import array_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import array_fill_cursor as cursor;
import array_copy_work as work;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import place_dispatch as places;
import aggregate_place_vm as selected;
import aggregate_places as snapshots;
import std::vec as vec;
import errors as errors;

pub fn bool selected_copy(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && body.code[pc*8]==85 && body.code[pc*8+4]==3;
}
pub fn bool operation(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && (body.code[pc*8]==34 || body.code[pc*8]==38 || selected_copy(body,pc));
}
// A bool source has at most 4096 bytes. Its complete validation stays before
// mutation/debit; defer the instruction when an earlier operation used that room.
pub fn usize begin_bytes(ref ir::Program body,usize pc){
    if(!operation(body,pc)){return 0;}
    let usize root=body.code[pc*8+if(selected_copy(body,pc)){2}else{1}] as usize;
    if(root>=16 || root>=body.arrays.count || body.arrays.elements[root]!=2){return 0;}
    return body.arrays.lengths[root];
}
pub fn Result<cursor::State,errors::Error> begin(ref ir::Program body,usize pc,
    ref frames::Frames bindings,ref runtime::State state,ref u8[] data,
    ref mut vec::Vec<usize> place_state,ref mut usize remaining){
    if(!operation(body,pc) || bindings.frame==0 || bindings.frame>=32){return .err(errors::make(5,0));}
    let usize at=pc*8;let usize offset=body.offsets[pc];let u8 op=body.code[at];
    let bool place=selected_copy(body,pc);let usize frame=bindings.frame;let usize function=bindings.functions[frame];
    let usize dst=body.code[at+if(place){2}else{1}] as usize;let usize source=body.code[at+if(place){3}else{2}] as usize;
    if(dst>=16 || source>=16 || dst>=body.arrays.count || source>=body.arrays.count){return .err(errors::make(5,offset));}
    let usize price=if(place){places::price(body,pc,function,frame,place_state)?}else{arrays::cost(ref body.arrays,op,dst,offset)?};
    if(*remaining<price){return .err(errors::make(8,offset));}
    let layouts::Array layout=switch(layouts::scalar(body.arrays.elements[dst],body.arrays.lengths[dst])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
    };
    var owners::Token target=bindings.tokens[frame*16+dst];
    if(place){let snapshots::Place saved=selected::array_selection(body,pc,function,frame,place_state,ref state.runtime.owners,data.len)?;target=saved.root;}
    var cursor::State pending=switch(work::begin(ref state.runtime.owners,if(place){38}else{op},ref layout,target,bindings.tokens[frame*16+source],data)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    pending.pc=pc;pending.frame=frame;pending.destination=dst;pending.offset=offset;
    if(!pending.active && place){let usize finished=selected::finish_fill(body,pc,function,frame,place_state,ref state.runtime.owners,data.len)?;};
    *remaining-=price;return .ok(pending);
}
pub fn Result<bool,errors::Error> advance(ref mut cursor::State pending,ref ir::Program body,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,
    ref mut vec::Vec<usize> place_state,usize allowance){
    let usize offset=pending.offset;
    if(!pending.active || pending.frame==0 || pending.frame>=32 || pending.frame!=bindings.frame ||
        pending.destination>=16 || !operation(body,pending.pc)){return .err(errors::make(5,offset));}
    let bool place=selected_copy(body,pending.pc);let usize frame=pending.frame;let usize function=bindings.functions[frame];
    let usize source=body.code[pending.pc*8+if(place){3}else{2}] as usize;
    if(source>=16){return .err(errors::make(5,offset));}
    let owners::Token origin=bindings.tokens[frame*16+source];
    if(origin.slot!=pending.source_slot || origin.generation!=pending.source_generation){return .err(errors::make(5,offset));}
    if(place){let snapshots::Place saved=selected::array_selection(body,pending.pc,function,frame,place_state,ref state.runtime.owners,data.len)?;
        if(saved.root.slot!=pending.slot || saved.root.generation!=pending.generation){return .err(errors::make(5,offset));}
    }else if(pending.op==38){let owners::Token target=bindings.tokens[frame*16+pending.destination];
        if(target.slot!=pending.slot || target.generation!=pending.generation){return .err(errors::make(5,offset));}
    }
    let Option<owners::Token> completed=switch(work::advance(pending,ref mut state.runtime.owners,data,allowance)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return switch(completed){case .none:{.ok(false)}case .some(token):{
        if(pending.op==34){bindings.tokens[frame*16+pending.destination]=token;};
        if(place){let usize finished=selected::finish_fill(body,pending.pc,function,frame,place_state,ref state.runtime.owners,data.len)?;};
        .ok(true)
    }};
}
