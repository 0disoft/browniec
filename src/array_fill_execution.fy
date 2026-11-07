module array_fill_execution;
import ir as ir;
import array_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import array_fill_cursor as cursor;
import array_fill_work as work;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import errors as errors;
import place_dispatch as places;
import aggregate_place_vm as selected;
import aggregate_places as snapshots;
import std::vec as vec;

pub fn bool selected_fill(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && body.code[pc*8]==87 && body.code[pc*8+4]==3 && body.code[pc*8+5]==0;
}

// Trusted canonical dispatcher bridge. Payload and unpublished owner work stay
// private until completion; the PC, frame and source register cannot change.
pub fn Result<cursor::State,errors::Error> begin(ref ir::Program body,usize pc,
    ref frames::Frames bindings,ref runtime::State state,ref i64[] registers,
    usize capacity,ref vec::Vec<usize> place_state,ref mut usize remaining){
    if(pc>=body.count || pc>=256 || bindings.frame==0 || bindings.frame>=32){return .err(errors::make(5,0));}
    let usize at=pc*8;let usize offset=body.offsets[pc];let u8 op=body.code[at];
    let bool place=selected_fill(body,pc);
    let usize dst=body.code[at+if(place){2}else{1}] as usize;
    let usize value=body.code[at+if(place){3}else{2}] as usize;
    if((op!=33 && op!=40 && !place) || dst>=body.arrays.count || dst>=16 || value>=registers.len){return .err(errors::make(5,offset));}
    let usize function=bindings.functions[bindings.frame];
    let usize price=if(place){places::price(body,pc,function,bindings.frame,place_state)?}else{arrays::cost(ref body.arrays,op,dst,offset)?};
    if(*remaining<price){return .err(errors::make(8,offset));}
    let layouts::Array layout=switch(layouts::scalar(body.arrays.elements[dst],body.arrays.lengths[dst])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
    };
    var owners::Token target=bindings.tokens[bindings.frame*16+dst];
    if(place){let snapshots::Place saved=selected::fill_selection(body,pc,function,bindings.frame,place_state,ref state.runtime.owners,capacity)?;target=saved.root;}
    var cursor::State pending=switch(work::begin(ref state.runtime.owners,if(place){40}else{op},ref layout,target,registers[value],capacity)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    pending.pc=pc;pending.frame=bindings.frame;pending.destination=dst;pending.offset=offset;
    *remaining-=price;return .ok(pending);
}
pub fn Result<bool,errors::Error> advance(ref mut cursor::State pending,
    ref ir::Program body,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,
    ref mut vec::Vec<usize> place_state,usize allowance){
    let usize offset=pending.offset;
    if(!pending.active || pending.frame!=bindings.frame || pending.frame==0 || pending.frame>=32 ||
        pending.destination>=16){return .err(errors::make(5,offset));}
    let bool place=selected_fill(body,pending.pc);let usize function=bindings.functions[bindings.frame];
    if(place){let snapshots::Place saved=selected::fill_selection(body,pending.pc,function,pending.frame,place_state,ref state.runtime.owners,data.len)?;
        if(saved.root.slot!=pending.slot || saved.root.generation!=pending.generation){return .err(errors::make(5,offset));}
    }else if(pending.op==40){let owners::Token target=bindings.tokens[pending.frame*16+pending.destination];
        if(target.slot!=pending.slot || target.generation!=pending.generation){return .err(errors::make(5,offset));}
    }
    let Option<owners::Token> completed=switch(work::advance(pending,ref mut state.runtime.owners,data,allowance)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return switch(completed){
        case .none:{.ok(false)}case .some(token):{
            if(pending.op==33){bindings.tokens[pending.frame*16+pending.destination]=token;};
            if(place){let usize finished=selected::finish_fill(body,pending.pc,function,pending.frame,place_state,ref state.runtime.owners,data.len)?;};
            .ok(true)
        }
    };
}
