module reference_return_execution;
import ir as ir;
import static_ir as statics;
import static_views as views;
import reference_words as words;
import reference_access as access;
import reference_execution as references;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import array_slices as slices;
import array_owners as owners;
import fuel as fuel;
import errors as errors;

pub struct Returned { bool loan; u32 word; slices::Ticket ticket; views::Span span; usize destination; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
// Complete Fuel precedes receipt lookup/authentication or native publication.
// The exact frame, sole source and recipient CALL come from complete proof.
pub fn Result<Returned,errors::Error> prepare(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref u32[] current,usize live,usize caller_live,
    ref frames::Frames bindings,ref runtime::State state,usize payload,usize remaining){
    let usize frame=bindings.frame;
    if(pc>=p.count || pc>=256 || frame<=1 || frame>=32 || current.len!=16 || f>=p.function_count ||
        bindings.functions[frame]!=f || !bindings.active[frame] || sites.results[f]!=3 || p.code[pc*8]!=79){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize source=p.code[pc*8+2] as usize;let usize next=bindings.continuations[frame];
    let usize dst=bindings.destinations[frame];let usize caller=bindings.functions[frame-1];let usize one=1;
    if(source>=16 || dst>=16 || live!=(one<<source) || caller_live>=65536 || (caller_live&(one<<dst))!=0 ||
        caller>=p.function_count || sites.functions[source]!=f || sites.functions[dst]!=caller || sites.kinds[dst]!=3 ||
        (sites.kinds[source]!=1 && sites.kinds[source]!=3) || next==0 || next>p.count ||
        p.code[(next-1)*8]!=78 || p.code[(next-1)*8+2] as usize!=f || p.code[(next-1)*8+1] as usize!=dst ||
        sites.definitions[dst]!=next-1){return .err(invalid(offset));}
    let bool loan=words::runtime(current[source]);let usize price=fuel::reference_return();
    let usize native=if(loan){runtime::handoff_cost()}else{runtime::leave_cost()};
    if(remaining<price+native){return .err(errors::make(8,offset));}
    let access::Source selected=references::source(p,sites,f,source,current,live,bindings,payload,offset)?;
    if(loan){
        if(bindings.selected[frame]==0 || selected.storage!=2 || !selected.window || selected.ticket.slot>=16){return .err(invalid(offset));}
        // This bounded snapshot checks only the selected relative span. Native
        // handoff still authenticates full generation, root, lease and origin.
        let owners::View view=state.runtime.pool.slots[selected.ticket.slot].view;
        if(view.start>view.end || selected.span.start>view.end-view.start ||
            selected.span.length>view.end-view.start-selected.span.start){return .err(invalid(offset));}
        let u32 word=words::pack_result(dst,selected.span,offset)?;
        return .ok(Returned{.loan=true,.word=word,.ticket=selected.ticket,.span=selected.span,.destination=dst,.remaining=remaining-price});
    }
    if(bindings.selected[frame]!=0 || selected.storage!=1){return .err(invalid(offset));}
    let views::Span span=views::inspect(sites,dst,caller,1,current[source],payload,offset)?;
    return .ok(Returned{.loan=false,.word=current[source],.ticket=frames::none(),.span=span,.destination=dst,.remaining=remaining-price});
}
