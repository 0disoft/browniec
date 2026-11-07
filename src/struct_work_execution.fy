module struct_work_execution;
import ir as ir;
import struct_work as work;
import struct_vm as prices;
import struct_range as ranges;
import array_fill_cursor as cursor;
import array_owners as owners;
import array_vm as arrays;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import slice_result_record_bindings as records;
import aggregate_place_vm as selected;
import aggregate_places as snapshots;
import place_dispatch as places;
import std::vec as vec;
import errors as errors;

pub fn bool selected_record(ref ir::Program body,usize pc){
    return pc<body.count && pc<256 && (body.code[pc*8]==85 || body.code[pc*8]==87) && body.code[pc*8+4]==4;
}
pub fn bool operation(ref ir::Program body,usize pc){
    if(pc>=body.count || pc>=256){return false;}
    let u8 op=body.code[pc*8];
    return op==41 || op==42 || op==46 || op==47 || op==48 || op==49 || selected_record(body,pc);
}
fn u8 normalized(ref ir::Program body,usize pc){
    return if(selected_record(body,pc)){if(body.code[pc*8]==85){47}else{49}}else{body.code[pc*8]};
}
fn bool fields(u8 op){return op==41 || op==48 || op==49;}
fn usize destination(ref ir::Program body,usize pc){return body.code[pc*8+if(selected_record(body,pc)){2}else{1}] as usize;}
fn Result<usize,errors::Error> nominal(ref ir::Program body,usize pc){
    let usize dst=destination(body,pc);let usize offset=body.offsets[pc];
    if(dst>=16 || dst>=body.records.count){return .err(errors::make(5,offset));}
    let u8 op=body.code[pc*8];
    return .ok(if(selected_record(body,pc)){body.code[pc*8+6] as usize}
        else if(op==47 || op==48 || op==49){body.code[pc*8+3] as usize}else{body.records.records[dst] as usize});
}
fn Result<usize,errors::Error> price(ref ir::Program body,usize pc,ref frames::Frames bindings,ref vec::Vec<usize> place_state){
    if(!operation(body,pc) || bindings.frame==0 || bindings.frame>=32){return .err(errors::make(5,0));}
    return if(selected_record(body,pc)){places::price(body,pc,bindings.functions[bindings.frame],bindings.frame,place_state)}
        else{prices::cost(body.code[pc*8],body.offsets[pc])};
}
// Admission staging is <=1280 bytes. Defer before charging the instruction if
// its complete stage will not fit. Insufficient Fuel never triggers planning.
pub fn Result<usize,errors::Error> required_bytes(ref ir::Program body,usize pc,ref frames::Frames bindings,
    ref vec::Vec<usize> place_state,usize remaining){
    let usize cost=price(body,pc,bindings,place_state)?;
    if(remaining<=cost){return .ok(0);}
    let usize shape=nominal(body,pc)?;
    return switch(work::measure(ref body.records.layouts,shape,fields(normalized(body,pc)))){
        case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,body.offsets[pc]))}
    };
}
pub fn Result<cursor::State,errors::Error> begin(ref ir::Program body,usize pc,ref frames::Frames bindings,
    ref runtime::State state,ref i64[] registers,ref u8[] data,ref vec::Vec<usize> place_state,ref mut usize remaining){
    let usize cost=price(body,pc,bindings,place_state)?;let usize offset=body.offsets[pc];
    if(*remaining<cost){return .err(errors::make(8,offset));}
    let usize frame=bindings.frame;let usize dst=destination(body,pc);let usize shape=nominal(body,pc)?;
    let bool place=selected_record(body,pc);let u8 op=normalized(body,pc);let usize at=pc*8;
    let usize input=body.code[at+if(place){3}else{2}] as usize;
    var usize target_leaf=if(place){body.code[at+5] as usize}else if(op==47 || op==49){body.code[at+4] as usize}else{0};
    let usize source_leaf=if(place && op==47){body.code[at+7] as usize}else if(op==47){body.code[at+5] as usize}else{0};
    var owners::Token target=records::get(ref bindings.records,frame*16+dst);
    if((op==41 || op==42) && target.generation!=0){return .err(errors::make(5,offset));}
    if(place){let snapshots::Place saved=selected::record_selection(body,pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,data.len)?;
        target=saved.root;target_leaf=saved.ordinal;
    }else if(op!=41 && op!=42 && !body.records.mutable[dst]){return .err(errors::make(5,offset));}
    var owners::Token source=owners::Token{.slot=16,.generation=0};
    var usize count=0;var usize first=0;
    if(fields(op)){
        count=ranges::leaves(ref body.records.layouts,shape)?;first=input;
        if(first>registers.len || count>registers.len-first){return .err(errors::make(5,offset));}
    }else{
        if(input>=16 || input>=body.records.count){return .err(errors::make(5,offset));}
        source=records::get(ref bindings.records,frame*16+input);
        let owners::Owner origin=switch(owners::resolve_record(ref body.records.layouts,ref state.runtime.owners,source,data.len)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        if(origin.record!=body.records.records[input] as usize){return .err(errors::make(5,offset));}
    }
    var cursor::State pending=switch(work::begin(ref body.records.layouts,ref state.runtime.owners,op,shape,target,source,
        target_leaf,source_leaf,registers[first..first+count],data)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    pending.pc=pc;pending.frame=frame;pending.destination=dst;pending.offset=offset;
    *remaining-=cost;return .ok(pending);
}
pub fn Result<bool,errors::Error> advance(ref mut cursor::State pending,ref ir::Program body,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,
    ref mut vec::Vec<usize> place_state,usize allowance){
    let usize offset=pending.offset;
    if(!pending.active || pending.frame==0 || pending.frame>=32 || pending.frame!=bindings.frame ||
        pending.destination>=16 || !operation(body,pending.pc)){return .err(errors::make(5,offset));}
    let usize pc=pending.pc;let usize frame=pending.frame;let u8 op=normalized(body,pc);
    let usize shape=nominal(body,pc)?;
    if(op!=pending.op || destination(body,pc)!=pending.destination || shape!=pending.nominal ||
        pending.record!=body.records.records[pending.destination] as usize){return .err(errors::make(5,offset));}
    let bool place=selected_record(body,pc);
    let usize target_leaf=if(place){body.code[pc*8+5] as usize}else if(op==47 || op==49){body.code[pc*8+4] as usize}else{0};
    let usize source_leaf=if(place && op==47){body.code[pc*8+7] as usize}else if(op==47){body.code[pc*8+5] as usize}else{0};
    if(target_leaf!=pending.ordinal || source_leaf!=pending.source_ordinal){return .err(errors::make(5,offset));}
    if(place){let snapshots::Place saved=selected::record_selection(body,pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,data.len)?;
        if(saved.root.slot!=pending.slot || saved.root.generation!=pending.generation || saved.ordinal!=pending.ordinal){return .err(errors::make(5,offset));}
    }else{
        let owners::Token target=records::get(ref bindings.records,frame*16+pending.destination);
        if(op==41 || op==42){if(target.generation!=0){return .err(errors::make(5,offset));}}
        else if(target.slot!=pending.slot || target.generation!=pending.generation){return .err(errors::make(5,offset));}
    }
    if(!fields(op)){
        let usize input=body.code[pc*8+if(place){3}else{2}] as usize;
        if(input>=16 || input>=body.records.count){return .err(errors::make(5,offset));}
        let owners::Token source=records::get(ref bindings.records,frame*16+input);
        if(source.slot!=pending.source_slot || source.generation!=pending.source_generation ||
            pending.source_record!=body.records.records[input] as usize){return .err(errors::make(5,offset));}
    }
    let Option<owners::Token> completed=switch(work::advance(pending,ref body.records.layouts,ref mut state.runtime.owners,data,allowance)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return switch(completed){case .none:{.ok(false)}case .some(token):{
        if(op==41 || op==42){records::bind(ref mut bindings.records,frame*16+pending.destination,token);};
        if(place){let usize finished=selected::finish_record(body,pc,bindings.functions[frame],frame,place_state,ref state.runtime.owners,data.len)?;};
        .ok(true)
    }};
}
