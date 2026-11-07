module output_execution;
import ir as ir;
import static_ir as statics;
import static_views as spans;
import reference_access as access;
import reference_execution as references;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import input_reference_views as inputs;
import array_slices as slices;
import array_vm as arrays;
import runtime_output as output;
import output_copy_cursor as copy;
import fuel as fuel;
import errors as errors;

// Private output failures, not newly exposed public CLI/ABI status values.
pub fn errors::Error failure(output::Error e,usize offset){
    return errors::make(switch(e){
        case .State:{5}case .Denied:{19}case .Limit:{20}
        case .Fuel:{8}case .Allocation:{15}
    },offset);
}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn Result<spans::Span,errors::Error> loan(ref access::Source selected,ref runtime::State state,usize capacity,usize offset){
    let slices::Ticket ticket=selected.ticket;
    let usize length=switch(slices::length(ref state.runtime.pool,ticket,ref state.runtime.owners,capacity)){
        case .ok(value):{value}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    if(ticket.slot>=16){return .err(invalid(offset));}
    let ref slices::Slot slot=ref state.runtime.pool.slots[ticket.slot];
    if(slot.view.element!=10 || slot.view.root.slot>=16){return .err(invalid(offset));}
    let usize base=state.runtime.owners.slots[slot.view.root.slot].base;
    if(base>capacity || slot.view.start>capacity-base){return .err(invalid(offset));}
    let usize begin=base+slot.view.start;
    let spans::Span relative=if(selected.window){selected.span}else{spans::Span{.start=0,.length=length}};
    if(relative.start>length || relative.length>length-relative.start ||
        relative.start>capacity-begin || relative.length>capacity-begin-relative.start){return .err(invalid(offset));}
    return .ok(spans::Span{.start=begin+relative.start,.length=relative.length});
}
fn Result<usize,errors::Error> append(ref mut output::Transaction staged,ref u8[] data,
    spans::Span span,ref mut usize remaining,usize offset){
    if(span.start>data.len || span.length>data.len-span.start){return .err(invalid(offset));}
    // No copy or payload access precedes the complete byte/Fuel admission in
    // the reserved transaction. The borrowed source cannot alias its staging.
    return switch(output::emit_metered(staged,data[span.start..span.start+span.length],remaining)){
        case .ok(value):{.ok(value)}case .err(e):{.err(failure(e,offset))}
    };
}
// Resolve provenance once, including the complete source span, before either
// atomic or resumable byte/Fuel admission. This never reads payload bytes.
struct Resolved { u8 storage; spans::Span span; usize offset; }
fn Result<Resolved,errors::Error> resolve(ref ir::Program body,ref statics::Sites sites,usize pc,usize function,
    ref frames::Frames bindings,ref runtime::State state,ref u32[] words,usize live,
    ref inputs::State windows,ref u8[] guest,ref u8[] literals,ref u8[] data,
    ref mut usize remaining){
    if(pc>=body.count || function>=body.function_count || bindings.frame==0 || bindings.frame>=32 ||
        bindings.functions[bindings.frame]!=function || pc<body.starts[function] || pc>=body.ends[function]){return .err(invalid(0));}
    let usize offset=body.offsets[pc];let usize at=pc*8;
    if(body.code[at]!=116 || body.code[at+1]!=0 || body.code[at+2]>=16 ||
        (body.code[at+3]!=1 && body.code[at+3]!=2) || body.code[at+4]!=0 ||
        body.code[at+5]!=0 || body.code[at+6]!=0 || body.code[at+7]!=0){return .err(invalid(offset));}
    if(*remaining<fuel::output_access()+fuel::output_emit(0)){return .err(errors::make(8,offset));};
    *remaining-=fuel::output_access();
    let usize site=body.code[at+2] as usize;
    let access::Source selected=if(body.code[at+3]==2){
        access::loan(bindings.sites[bindings.frame*16+site])
    }else{references::source_input(body,sites,function,site,words,live,bindings,literals.len,windows,offset)?};
    if(selected.storage<1 || selected.storage>3){return .err(invalid(offset));}
    let spans::Span span=if(selected.storage==3){selected.span}
        else if(selected.storage==2){loan(ref selected,state,data.len,offset)?}
        else{spans::live(sites,selected.site,function,1,words,live,literals.len,offset)?};
    let usize capacity=if(selected.storage==3){guest.len}else if(selected.storage==2){data.len}else{literals.len};
    if(span.start>capacity || span.length>capacity-span.start){return .err(invalid(offset));}
    return .ok(Resolved{.storage=selected.storage,.span=span,.offset=offset});
}
// The legacy entry point still admits and copies the complete emit atomically.
pub fn Result<usize,errors::Error> emit(ref ir::Program body,ref statics::Sites sites,usize pc,usize function,
    ref frames::Frames bindings,ref runtime::State state,ref u32[] words,usize live,
    ref inputs::State windows,ref u8[] guest,ref u8[] literals,ref u8[] data,
    ref mut output::Transaction staged,ref mut usize remaining){
    let Resolved selected=resolve(body,sites,pc,function,bindings,state,words,live,windows,guest,literals,data,remaining)?;
    if(selected.storage==3){return append(staged,guest,selected.span,remaining,selected.offset);}
    if(selected.storage==2){return append(staged,data,selected.span,remaining,selected.offset);}
    return append(staged,literals,selected.span,remaining,selected.offset);
}
pub fn Result<copy::State,errors::Error> begin(ref ir::Program body,ref statics::Sites sites,usize pc,usize function,
    ref frames::Frames bindings,ref runtime::State state,ref u32[] words,usize live,
    ref inputs::State windows,ref u8[] guest,ref u8[] literals,ref u8[] data,
    ref mut output::Transaction staged,ref mut usize remaining){
    let Resolved selected=resolve(body,sites,pc,function,bindings,state,words,live,windows,guest,literals,data,remaining)?;
    // Full quota and Fuel admission precedes every chunk and any payload read.
    switch(output::begin_emit_metered(staged,selected.span.length,remaining)){
        case .ok(_):{}case .err(e):{return .err(failure(e,selected.offset));}
    };
    return .ok(copy::State{.active=selected.span.length!=0,.storage=selected.storage,
        .start=selected.span.start,.length=selected.span.length,.copied=0,
        .offset=selected.offset,.total=0,.last=0});
}
// The VM pins these sources and dispatches no other guest opcode until done.
// total spans emits; last is the caller's per-drive 4096-byte work counter.
pub fn Result<bool,errors::Error> advance(ref mut copy::State pending,
    ref u8[] guest,ref u8[] literals,ref u8[] data,ref mut output::Transaction staged){
    return advance_limited(pending,guest,literals,data,staged,4096);
}
// Array initialization shares the dispatcher's byte allowance with output.
pub fn Result<bool,errors::Error> advance_limited(ref mut copy::State pending,
    ref u8[] guest,ref u8[] literals,ref u8[] data,ref mut output::Transaction staged,usize allowance){
    let usize offset=pending.offset;
    if(!pending.active || pending.storage<1 || pending.storage>3 ||
        pending.copied>=pending.length || pending.last>4096 || allowance>4096){return .err(invalid(offset));}
    let ref u8[] source=if(pending.storage==1){literals}else if(pending.storage==2){data}else{guest};
    if(pending.start>source.len || pending.length>source.len-pending.start){return .err(invalid(offset));}
    if(pending.last==4096 || allowance==0){return .ok(false);}
    let usize left=pending.length-pending.copied;
    let usize available=4096-pending.last;let usize room=if(allowance<available){allowance}else{available};
    let usize count=if(left<room){left}else{room};
    if(count>18446744073709551615-pending.total){return .err(invalid(offset));}
    if(count!=0){
        let usize start=pending.start+pending.copied;
        switch(output::append_emit_chunk(staged,source[start..start+count])){
            case .ok(_):{}case .err(e):{return .err(failure(e,offset));}
        };
    }
    // The source and remaining-length guards also prove copied/last cannot wrap.
    pending.copied+=count;pending.total+=count;pending.last+=count;
    if(pending.copied==pending.length){pending.active=false;return .ok(true);}
    return .ok(false);
}
