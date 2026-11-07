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
// One bounded provenance authentication followed by one contiguous copy. No
// per-byte ticket lookup or intermediate payload allocation is introduced.
pub fn Result<usize,errors::Error> emit(ref ir::Program body,ref statics::Sites sites,usize pc,usize function,
    ref frames::Frames bindings,ref runtime::State state,ref u32[] words,usize live,
    ref inputs::State windows,ref u8[] guest,ref u8[] literals,ref u8[] data,
    ref mut output::Transaction staged,ref mut usize remaining){
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
    if(selected.storage==3){return append(staged,guest,selected.span,remaining,offset);}
    if(selected.storage==2){return append(staged,data,loan(ref selected,state,data.len,offset)?,remaining,offset);}
    if(selected.storage!=1){return .err(invalid(offset));}
    let spans::Span span=spans::live(sites,selected.site,function,1,words,live,literals.len,offset)?;
    return append(staged,literals,span,remaining,offset);
}
