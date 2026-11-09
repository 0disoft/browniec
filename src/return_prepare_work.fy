module return_prepare_work;
import return_record_work as record_work;
import struct_layout_work as catalogs;
import struct_layout as layouts;
import return_metadata_execution as returned;
import return_work_cursor as payload_work;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import slice_result_record_bindings as record_bindings;
import reference_return_execution as references;
import static_call_execution as transfer;
import slice_result_bindings as result_bindings;
import array_result_vm as array_results;
import struct_result_vm as record_results;
import array_owners as owners;
import array_vm as arrays;
import input_reference_views as inputs;
import place_vm as places;
import static_ir as statics;
import struct_meta as record_meta;
import array_meta as array_meta;
import ir as ir;
import metadata_budget as budget;
import fuel as meter;
import errors as errors;
import std::vec as vec;

// Private heap Core scratch. The parent pins the exact Program/Sites, caller,
// source data, places and input snapshot, and executes no other guest opcode.
// No live Runtime/frame/input metadata is published by preparation.
pub struct State {
    record_work::State record; owners::Token[16] records; u8[128] scratch;
    usize remaining; usize required; usize base; usize length; usize nominal;
    usize phase; bool active; bool done;
}
pub fn State empty(){return State{.record=record_work::empty(),
    .records=[owners::Token{.slot=0,.generation=0};16],.scratch=[0;128],
    .remaining=0,.required=0,.base=0,.length=0,.nominal=0,.phase=0,.active=false,.done=false};}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn Result<usize,errors::Error> begin(ref mut State w,ref mut returned::State s,usize pc,usize frame,usize fuel){
    if(w.active || s.pending || frame==0 || frame>=32){return .err(invalid(0));}
    w.remaining=fuel;w.required=0;w.base=0;w.length=0;w.nominal=0;w.phase=0;w.active=true;w.done=false;
    *s=returned::empty();s.pc=pc;s.frame=frame;s.pending=true;s.fuel_pinned=fuel;return .ok(0);
}
fn Result<usize,errors::Error> measure(ref mut State w,ref mut returned::State s,ref ir::Program p){
    let usize pc=s.pc;let usize source=p.code[pc*8+2] as usize;let usize offset=p.offsets[pc];
    s.op=p.code[pc*8];
    if(s.op==39){let ref array_meta::Catalog c=ref p.arrays;
        if(source>=c.count || source>=16){return .err(invalid(offset));}
        w.required=if(c.elements[source]==2){c.lengths[source]}else{0};w.phase=2;
    }else if(s.op==50){let ref record_meta::Catalog c=ref p.records;
        if(source>=c.count || source>=16){return .err(invalid(offset));}
        let usize nominal=c.records[source] as usize;w.nominal=nominal;
        let usize begun=record_work::begin(ref mut w.record,nominal)?;w.phase=1;
    }else{w.required=0;w.phase=2;}
    if(w.required>4096){return .err(invalid(offset));}return .ok(0);
}
fn Result<usize,errors::Error> prefix(ref mut State w,ref mut returned::State s,ref ir::Program p,
    ref frames::Frames bindings,ref inputs::State windows,ref vec::Vec<usize> place_state,
    ref payload_work::State counter,ref mut usize remaining){
    let usize offset=p.offsets[s.pc];let usize ready=payload_work::check(counter,w.required,offset)?;
    if(*remaining==0){return .err(errors::make(8,offset));};
    *remaining-=1;w.remaining=*remaining;
    let usize empty=places::empty_frame(place_state,s.frame,offset)?;
    let usize input_work=if(inputs::enabled(windows)){meter::input_frame()}else{0};
    if(*remaining<input_work){return .err(errors::make(8,offset));};
    *remaining-=input_work;w.remaining=*remaining;
    s.next=bindings.continuations[s.frame];s.dst=bindings.destinations[s.frame];w.phase=3;return .ok(0);
}
fn Result<usize,errors::Error> context(ref mut State w,ref mut returned::State s,ref ir::Program p,
    ref statics::Sites sites,ref frames::Frames bindings,ref runtime::State state,usize payload,
    ref inputs::State windows,ref u8[] origins,ref usize[] live,ref u32[] current,ref i64[] registers,
    ref mut usize remaining){
    let usize frame=s.frame;let usize f=bindings.functions[frame];let usize pc=s.pc;
    let usize offset=p.offsets[pc];let usize source=p.code[pc*8+2] as usize;
    if(s.op==65){
        if(live[frame]!=0){return .err(invalid(offset));}
        let usize selected=frames::selected(bindings,source)?;s.selected=bindings.results[selected];
        s.mode=1;s.native_fuel=*remaining;w.phase=8;return .ok(0);
    }
    if(s.op==79){
        if(frame<=1 || s.next==0 || s.next>p.count){return .err(invalid(offset));}
        let usize parent=frame-1;let usize caller=bindings.functions[parent];
        if(sites.results[f]==3){
            let references::Returned r=references::prepare_input(p,sites,pc,f,current[frame*16..frame*16+16],
                live[frame],live[parent],bindings,state,payload,*remaining,windows,origins)?;
            *remaining=r.remaining;w.remaining=r.remaining;s.word=r.word;s.span=r.span;s.dst=r.destination;
            if(r.loan){s.mode=5;s.selected=r.ticket;s.native_fuel=r.remaining;w.phase=8;return .ok(0);}
            s.mode=if(r.input){4}else{3};
        }else{
            let transfer::Returned r=transfer::returned(p,sites,payload,pc,f,current[frame*16..frame*16+16],
                live[frame],s.next-1,caller,s.dst,live[parent],*remaining)?;
            *remaining=r.remaining;w.remaining=r.remaining;s.mode=2;s.word=r.word;s.dst=r.destination;
        }
    }else{
        if(s.op==82 && (frame==1 || p.return_types[f]!=13)){return .err(invalid(offset));}
        if(live[frame]!=0){return .err(invalid(offset));}
        if(s.op==8){if(source>=128){return .err(invalid(offset));}s.value=registers[frame*128+source];}
    }
    w.phase=4;return .ok(0);
}
fn Result<usize,errors::Error> owned_header(ref mut State w,ref mut returned::State s,
    ref ir::Program p,ref frames::Frames bindings){
    let usize offset=p.offsets[s.pc];let u8 op=if(s.op==79){8}else{s.op};
    if(result_bindings::in_frame(ref bindings.loans,s.frame) || (s.frame==1 && op!=8)){return .err(invalid(offset));}
    let usize extra=if(op==39){array_results::cost(p,p.code[s.pc*8+2] as usize,offset)?}
        else if(op==50){record_results::cost()}else{0};
    if(w.remaining<runtime::leave_cost()+extra){return .err(errors::make(8,offset));}
    s.native_fuel=w.remaining-extra;
    let owners::Token[16] tokens=record_bindings::frame_tokens(ref bindings.records,s.frame);
    w.records=tokens;
    var usize i=0;while(i<16){if(op!=50 && tokens[i].generation!=0){return .err(invalid(offset));}i+=1;}
    w.phase=5;return .ok(0);
}
fn Result<usize,errors::Error> transfer_header(ref mut State w,ref mut returned::State s,
    ref ir::Program p,ref frames::Frames bindings){
    let usize frame=s.frame;let usize f=bindings.functions[frame];let usize offset=p.offsets[s.pc];
    let usize source=p.code[s.pc*8+2] as usize;let usize dst=s.dst;let u8 op=s.op;
    let usize child=frame*16;
    if(op==39){let ref array_meta::Catalog c=ref p.arrays;
        if(dst<128 || dst>=144){return .err(invalid(offset));}let usize d=dst-128;
        if(source>=c.count || d>=c.count || source>=16 || d>=16){return .err(invalid(offset));}
        let usize encoded=p.array_results[f] as usize;
        if(encoded==0 || encoded>c.count || p.array_functions[source] as usize!=f){return .err(invalid(offset));}
        let usize shape=encoded-1;
        if(c.elements[source]!=c.elements[shape] || c.lengths[source]!=c.lengths[shape] ||
            c.elements[d]!=c.elements[shape] || c.lengths[d]!=c.lengths[shape]){return .err(invalid(offset));}
        let owners::Token parent=bindings.tokens[(frame-1)*16+d];
        if(parent.generation!=0 || parent.slot!=0){return .err(invalid(offset));}
        var usize i=0;while(i<16){let owners::Token t=bindings.tokens[child+i];
            if(i!=source && (t.generation!=0 || t.slot!=0)){return .err(invalid(offset));}i+=1;}
        s.result=bindings.tokens[child+source];
    }else if(op==50){let ref record_meta::Catalog c=ref p.records;
        if(dst<144 || dst>=160){return .err(invalid(offset));}let usize d=dst-144;
        if(p.function_count>16 || f==p.entry || c.count>16 || source>=c.count || d>=c.count || source>=16 || d>=16){return .err(invalid(offset));}
        let usize encoded=p.record_results[f] as usize;
        if(encoded==0 || encoded>c.count || p.array_results[f]!=0 || p.return_types[f]!=0 ||
            p.record_functions[source] as usize!=f || p.record_functions[encoded-1] as usize!=f){return .err(invalid(offset));}
        let usize nominal=c.records[encoded-1] as usize;
        if(c.records[source] as usize!=nominal || c.records[d] as usize!=nominal){return .err(invalid(offset));}
        let owners::Token parent=record_bindings::get(ref bindings.records,(frame-1)*16+d);
        if(parent.generation!=0 || parent.slot!=0){return .err(invalid(offset));}
        var usize i=0;while(i<16){let owners::Token a=bindings.tokens[child+i];let owners::Token r=w.records[i];
            if(a.generation!=0 || a.slot!=0 || (i!=source && (r.generation!=0 || r.slot!=0))){return .err(invalid(offset));}i+=1;}
        let owners::Token selected=w.records[source];s.result=selected;
    }else{var usize i=0;while(i<16){if(bindings.tokens[child+i].generation!=0){return .err(invalid(offset));}i+=1;}
        w.phase=8;return .ok(0);
    }
    w.phase=6;return .ok(0);
}
fn Result<usize,errors::Error> owner(ref mut State w,ref returned::State s,ref ir::Program p,
    ref owners::Table table,usize capacity){
    let usize offset=p.offsets[s.pc];let usize source=p.code[s.pc*8+2] as usize;
    let owners::Owner value=switch(owners::inspect_return_owner(table,s.result,capacity)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    if(s.op==39){let ref array_meta::Catalog c=ref p.arrays;
        if(value.element==0 || value.writing || value.reading || value.element!=c.elements[source] || value.length!=c.lengths[source]){return .err(invalid(offset));}
    }else{
        if(value.element!=0){return .err(invalid(offset));}
        let ref record_work::State r=ref w.record;let ref catalogs::State built=ref r.catalog;let ref layouts::Plan plan=ref built.plan;
        if(value.record>=plan.count || plan.bytes[value.record]!=value.length || plan.alignments[value.record]!=value.alignment ||
            value.record!=w.nominal){return .err(invalid(offset));}
        if(value.base%r.alignment!=0){return .err(invalid(offset));}
        if(value.base>table.arena.used || r.size>table.arena.used-value.base){return .err(errors::make(14,offset));}
    }
    w.base=value.base;w.length=value.length;w.phase=7;return .ok(0);
}
fn Result<usize,errors::Error> payload(ref mut State w,ref returned::State s,ref u8[] data){
    let usize offset=s.pc; // errors are re-anchored by advance below
    if(s.op==39){if(w.required!=0){var usize i=0;while(i<w.length){if(data[w.base+i]>1){return .err(invalid(offset));}i+=1;}}}
    else if(s.op==50){
        var usize i=0;while(i<128){w.scratch[i]=0;i+=1;}
        i=0;while(i<w.length){w.scratch[i]=0;i+=1;}
        let ref record_work::State r=ref w.record;let u8[128] mask=r.mask;
        i=0;while(i<w.length){if(mask[i]!=0){
            if(mask[i]==2 && data[w.base+i]>1){return .err(invalid(offset));}
            let u8 value=data[w.base+i];w.scratch[i]=value;}i+=1;}
    }w.phase=8;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref mut returned::State s,
    ref ir::Program p,ref statics::Sites sites,ref frames::Frames bindings,ref runtime::State state,
    ref u8[] data,usize literal_bytes,ref inputs::State windows,ref u8[] origins,
    ref usize[] live,ref u32[] current,ref i64[] registers,ref vec::Vec<usize> place_state,
    ref mut usize remaining,ref mut payload_work::State counter,ref mut budget::State allowance,usize room){
    if(room!=4096 || allowance.last!=0){return .ok(false);}
    if(!w.active || w.done || !s.pending || s.phase!=0 || !returned::operation(p,s.pc) ||
        bindings.frame!=s.frame || live.len!=32 || current.len!=512 || registers.len!=4096 || origins.len!=16 ||
        s.frame==0 || s.frame>=32 || bindings.functions[s.frame]>=p.function_count || bindings.functions[s.frame]>=16 ||
        w.phase>8 || *remaining!=w.remaining){return .err(invalid(0));}
    let usize offset=p.offsets[s.pc];
    if(w.phase==1){let ref record_meta::Catalog c=ref p.records;
        switch(record_work::advance(ref mut w.record,ref c.layouts,allowance)){
            case .ok(done):{if(done){let ref record_work::State r=ref w.record;let usize measured=record_work::measured(r);
                w.required=measured;w.phase=2;}}
            case .err(e):{w.active=false;s.pending=false;return .err(errors::make(e.kind,offset));}
        };return .ok(false);
    }
    let usize charge=if(w.phase==7){4096-w.required}else{4096};
    if(charge!=0 && !budget::admit(allowance,charge,offset)?){return .ok(false);}
    let Result<usize,errors::Error> result=if(w.phase==0){measure(w,s,p)}
        else if(w.phase==2){prefix(w,s,p,bindings,windows,place_state,counter,remaining)}
        else if(w.phase==3){context(w,s,p,sites,bindings,state,literal_bytes,windows,origins,live,current,registers,remaining)}
        else if(w.phase==4){owned_header(w,s,p,bindings)}
        else if(w.phase==5){transfer_header(w,s,p,bindings)}
        else if(w.phase==6){owner(w,s,p,ref state.runtime.owners,data.len)}
        else if(w.phase==7){payload(w,s,data)}else{
            let usize checked=payload_work::check(counter,w.required,offset)?;
            s.fuel_pinned=*remaining;s.phase=1;w.active=false;w.done=true;.ok(0)
        };
    switch(result){case .ok(_):{}case .err(e):{w.active=false;s.pending=false;return .err(errors::make(e.kind,offset));}};
    // Record successful payload validation in its actual dispatch, even though
    // context adoption/restoration/publication have not yet completed.
    if(w.phase==8 && !w.done){let usize checked=payload_work::check(counter,w.required,offset)?;
        payload_work::record(counter,w.required,s.pc,s.frame,s.op);}
    return .ok(w.done);
}
