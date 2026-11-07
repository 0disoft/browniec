module array_list_execution;
import ir as ir;
import array_list_ir as lists;
import array_list_vm as prices;
import array_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import array_fill_cursor as cursor;
import array_list_work as work;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import aggregate_place_vm as selected;
import aggregate_places as snapshots;
import place_dispatch as places;
import std::vec as vec;
import std::bytes as bytes;
import errors as errors;

pub fn bool selected_list(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && body.code[pc*8]==87 && body.code[pc*8+4]==3 && body.code[pc*8+5]==1;
}
pub fn bool operation(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && (body.code[pc*8]==80 || body.code[pc*8]==81 || selected_list(body,pc));
}
// Pin the existing list cells/scratch and immutable operands/register bank. No
// gathering, encoding or payload publication occurs during admission.
pub fn Result<cursor::State,errors::Error> begin(ref ir::Program body,usize pc,
    ref frames::Frames bindings,ref runtime::State state,usize capacity,
    ref vec::Vec<i64> cells,ref bytes::Buffer scratch,ref vec::Vec<usize> place_state,
    ref mut usize remaining){
    if(!operation(body,pc) || bindings.frame==0 || bindings.frame>=32){return .err(errors::make(5,0));}
    let usize offset=body.offsets[pc];let usize dst=lists::destination(body,pc);let usize frame=bindings.frame;
    let bool place=selected_list(body,pc);let u8 op=if(place){81}else{body.code[pc*8]};
    if(dst>=16 || dst>=body.arrays.count){return .err(errors::make(5,offset));}
    let usize price=if(place){places::price(body,pc,bindings.functions[frame],frame,place_state)?}else{prices::cost(body,pc)?};
    if(*remaining<price){return .err(errors::make(8,offset));}
    let layouts::Array layout=switch(layouts::scalar(body.arrays.elements[dst],body.arrays.lengths[dst])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
    };
    let usize start=lists::start(body,pc);
    if(body.list_used>4096 || start>body.list_used || layout.length>body.list_used-start ||
        vec::len<i64>(cells)<layout.length || bytes::len(scratch)<layout.bytes){return .err(errors::make(5,offset));}
    var owners::Token target=bindings.tokens[frame*16+dst];
    if(op==80 && target.generation!=0){return .err(errors::make(5,offset));}
    if(place){let snapshots::Place saved=selected::array_selection(body,pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,capacity)?;target=saved.root;}
    var cursor::State pending=switch(work::begin(ref state.runtime.owners,op,ref layout,target,capacity)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    pending.pc=pc;pending.frame=frame;pending.destination=dst;pending.offset=offset;
    *remaining-=price;return .ok(pending);
}
pub fn Result<bool,errors::Error> advance(ref mut cursor::State pending,ref ir::Program body,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,ref mut vec::Vec<usize> place_state,usize allowance){
    let usize offset=pending.offset;
    if(!pending.active || pending.frame==0 || pending.frame>=32 || pending.frame!=bindings.frame ||
        pending.destination>=16 || !operation(body,pending.pc)){return .err(errors::make(5,offset));}
    let bool place=selected_list(body,pending.pc);let usize frame=pending.frame;
    let usize dst=lists::destination(body,pending.pc);let u8 op=if(place){81}else{body.code[pending.pc*8]};
    if(op!=pending.op || dst!=pending.destination || dst>=body.arrays.count ||
        body.arrays.elements[dst]!=pending.element || body.arrays.lengths[dst]!=pending.length){return .err(errors::make(5,offset));}
    if(place){let snapshots::Place saved=selected::array_selection(body,pending.pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,data.len)?;
        if(saved.root.slot!=pending.slot || saved.root.generation!=pending.generation){return .err(errors::make(5,offset));}
    }else if(op==81){let owners::Token target=bindings.tokens[frame*16+dst];
        if(target.slot!=pending.slot || target.generation!=pending.generation){return .err(errors::make(5,offset));}
    }else if(bindings.tokens[frame*16+dst].generation!=0){return .err(errors::make(5,offset));}
    let usize start=lists::start(body,pending.pc);
    if(body.list_used>4096 || start>body.list_used || pending.length>body.list_used-start){return .err(errors::make(5,offset));}
    let usize length=pending.length;
    let Option<owners::Token> completed=switch(work::advance(pending,ref mut state.runtime.owners,data,
        ref body.list_operands[start..start+length],registers,vec::view_mut_i64(cells),bytes::view_mut(scratch),allowance)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return switch(completed){case .none:{.ok(false)}case .some(token):{
        if(op==80){bindings.tokens[frame*16+dst]=token;};
        if(place){let usize finished=selected::finish_fill(body,pending.pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,data.len)?;};
        .ok(true)
    }};
}
