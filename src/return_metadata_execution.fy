module return_metadata_execution;
import ir as ir;
import static_ir as statics;
import static_views as views;
import static_call_execution as transfer;
import reference_return_execution as reference_returns;
import reference_receipts as receipts;
import reference_words as words;
import input_reference_views as inputs;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import slice_result_owned_execution as owned;
import slice_result_record_execution as records;
import slice_result_bindings as loans;
import slice_result_call_ir as recipes;
import call_capture_plan as captures;
import array_slices as slices;
import array_owners as owners;
import runtime_metadata_work as metadata;
import metadata_budget as budget;
import fuel as meter;
import errors as errors;

// One compact pending result; the preallocated owning Core supplies the one
// shared metadata Work. No Frames/Runtime/Work copy or backing pointer is kept.
// mode: 0 ordinary, 1 RET65, 2 static79, 3 image-reference79, 4 input79, 5 loan79.
pub struct State {
    bool pending; bool done; bool view; bool complete; u8 phase; u8 mode; u8 op;
    usize pc; usize frame; usize next; usize dst; usize native_fuel; usize fuel_pinned;
    i64 value; slices::Ticket selected; owners::Token result; u32 word; views::Span span;
}
pub fn State empty(){return State{.pending=false,.done=false,.view=false,.complete=false,.phase=0,.mode=0,.op=0,
    .pc=0,.frame=0,.next=0,.dst=0,.native_fuel=0,.fuel_pinned=0,.value=0,
    .selected=slices::Ticket{.slot=16,.generation=0},.result=owners::Token{.slot=0,.generation=0},
    .word=0,.span=views::Span{.start=0,.length=0}};}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn bool operation(ref ir::Program p,usize pc){
    if(pc>=p.count || pc>=256){return false;}let u8 op=p.code[pc*8];
    return op==8 || op==39 || op==50 || op==65 || op==79 || op==82;
}
fn bool borrowed(ref State s){return s.mode==1 || s.mode==5;}
// The reference79 branch historically propagates native offsets unchanged.
// Ordinary/static79 and RET65 re-anchor handoff/leave errors to the RET offset.
fn errors::Error native_error(ref State s,errors::Error e,usize offset){
    return if(s.mode==3 || s.mode==4 || s.mode==5){e}else{errors::make(e.kind,offset)};
}
fn Result<usize,errors::Error> prepare_owned(ref mut State s,ref ir::Program p,ref frames::Frames bindings,
    ref runtime::State state,ref u8[] data,usize fuel,u8 op){
    let owned::LeavePlan prepared=owned::prepare_leave(p,s.pc,op,bindings,ref state.runtime.owners,data,fuel)?;
    s.result=prepared.result;s.native_fuel=prepared.fuel;return .ok(0);
}

// Parent already charged the opcode and checked place::empty_frame. It also
// admitted the existing payload-validation work and records it once on success.
// Legacy result/layout/reference preparation is NOT a complete <=4096 metadata
// contract. Only the separate restoration stages below have that kernel bound.
pub fn Result<usize,errors::Error> begin(ref mut State s,ref ir::Program p,ref statics::Sites sites,usize pc,
    ref frames::Frames bindings,ref runtime::State state,ref u8[] data,usize payload,
    ref inputs::State windows,ref u8[] origins,ref usize[] live,ref u32[] current,ref i64[] registers,
    ref mut usize remaining){
    let usize frame=bindings.frame;
    if(s.pending || !operation(p,pc) || live.len!=32 || current.len!=512 ||
        !frames::has_register_frame(registers.len,frame) || origins.len!=16){return .err(invalid(0));}
    let usize f=bindings.functions[frame];
    if(f>=p.function_count || f>=16){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let u8 op=p.code[pc*8];let usize a=p.code[pc*8+2] as usize;
    let usize input_work=if(inputs::enabled(windows)){meter::input_frame()}else{0};
    if(*remaining<input_work){return .err(errors::make(8,offset));};*remaining-=input_work;
    var State next=empty();next.pc=pc;next.frame=frame;next.op=op;
    next.next=bindings.continuations[frame];next.dst=bindings.destinations[frame];
    if(op==65){
        if(live[frame]!=0){return .err(invalid(offset));}
        let usize selected=frames::selected(bindings,a)?;
        next.selected=bindings.results[selected];next.mode=1;next.native_fuel=*remaining;
    }else if(op==79){
        if(frame<=1 || next.next==0 || next.next>p.count){return .err(invalid(offset));}
        let usize parent=frame-1;let usize caller=bindings.functions[parent];
        if(sites.results[f]==3){
            let reference_returns::Returned prepared=reference_returns::prepare_input(p,sites,pc,f,
                current[frame*16..frame*16+16],live[frame],live[parent],bindings,state,payload,*remaining,windows,origins)?;
            *remaining=prepared.remaining;next.word=prepared.word;next.span=prepared.span;next.dst=prepared.destination;
            if(prepared.loan){next.mode=5;next.selected=prepared.ticket;next.native_fuel=prepared.remaining;}
            else{next.mode=if(prepared.input){4}else{3};let usize prepared_owned=prepare_owned(ref mut next,p,bindings,state,data,*remaining,8)?;}
        }else{
            let transfer::Returned prepared=transfer::returned(p,sites,payload,pc,f,
                current[frame*16..frame*16+16],live[frame],next.next-1,caller,next.dst,live[parent],*remaining)?;
            *remaining=prepared.remaining;next.mode=2;next.word=prepared.word;next.dst=prepared.destination;
            let usize prepared_owned=prepare_owned(ref mut next,p,bindings,state,data,*remaining,8)?;
        }
    }else{
        if(op==82 && (frame==1 || p.return_types[f]!=13)){return .err(invalid(offset));}
        if(live[frame]!=0){return .err(invalid(offset));}
        if(op==8){if(a>=128){return .err(invalid(offset));}next.value=registers[frame*128+a];}
        let usize prepared_owned=prepare_owned(ref mut next,p,bindings,state,data,*remaining,op)?;
    }
    next.fuel_pinned=*remaining;next.pending=true;next.phase=1;*s=next;return .ok(0);
}

fn usize location_frame(usize location){return if(location<512){location/16}else if(location>=1024 && location<1536){(location-1024)/16}else{32};}
// Mirror the sparse receipt store without cloning its 47 Held values. Only
// receipts actually consumed before the matching legacy store count as free.
fn Result<usize,errors::Error> check_store(ref loans::State bank,usize location,usize anchor,runtime::Held held,
    usize parent,usize consumed,usize retired,bool universal,usize offset){
    if(!held.active || held.frame!=location_frame(location) || held.issued.slot>=16 || held.issued.generation==0){return .err(invalid(offset));}
    if(universal){if(held.exclusive || held.view.element!=10){return .err(invalid(offset));}}
    else if(location>=512 || anchor>=512 || location==anchor || location/16!=anchor/16){return .err(invalid(offset));}
    let usize one=1;var bool free=false;var usize i=0;
    while(i<47){let runtime::Held old=bank.held[i];let usize at=bank.locations[i];
        let bool removed=(retired<32 && location_frame(at)==retired) || (at<512 && at/16==parent && (consumed&(one<<(at%16)))!=0);
        if(!old.active || removed){free=true;}
        else if(at==location || (old.issued.slot==held.issued.slot && old.issued.generation==held.issued.generation)){return .err(invalid(offset));}
        i+=1;
    }
    if(!free){return .err(errors::make(12,offset));}return .ok(0);
}
// Pure mirror of the checks in pop_cached. The cached owning path is bounded;
// the raw fallback intentionally retains legacy binding/chain discovery and
// is not evidence of a complete bounded RET/public R03 implementation.
fn Result<usize,errors::Error> check_borrowed(ref State s,ref ir::Program p,ref frames::Frames bindings,
    ref runtime::Returned result,ref captures::Plan plans){
    let usize child=s.frame;let runtime::Held held=result.held;
    if(!bindings.prepared[child] || !held.active || held.frame!=child-1){return .err(invalid(0));}
    let usize parent=child-1;if(parent==0){return .ok(0);}
    let usize map=bindings.maps[child];let usize dst=bindings.destinations[child];
    if(map>=p.call_count || (dst>=128 && (dst<160 || dst>=176)) || bindings.prepared[parent]){return .err(invalid(0));}
    let usize call=if(s.next>0 && s.next<=p.count && p.code[(s.next-1)*8]==66){s.next-1}else{256};
    let usize mask=if(call!=256){p.code[call*8+4] as usize}else{0};let usize one=1;
    var captures::Entry recipe=captures::Entry{.ends=[0;8],.parents=[16;8],.required=0,.absent=0};var usize consumed=0;
    if(call!=256 && plans.ready){recipe=captures::lookup(plans,p,call)?;consumed=recipe.required|recipe.absent;}
    else if(call!=256){let usize end=recipes::binding(p,call)?;var usize at=call+1;
        while(at<end){if(p.code[at*8]==68){let usize site=p.code[at*8+1] as usize;
            if(site>=16){return .err(invalid(0));}consumed|=one<<site;
        }at+=1;}
    }
    // Resolve every restore destination, including those not equal to the
    // result site, before the publication helper can perform any write.
    var usize[8] restored=[16;8];var usize i=0;
    while(i<bindings.arities[child]){let usize argument=p.call_args[map*8+i] as usize;
        if(argument>=160 && argument<176){var usize site=argument-160;
            if((mask&(one<<i))!=0){if(plans.ready){site=recipe.parents[i] as usize;}
                else{let recipes::Chain chain=recipes::chain(p,call,i)?;site=chain.parent;}}
            if(site>=16){return .err(invalid(0));}restored[i]=site;
        }i+=1;
    }
    if(dst>=160){let usize chosen=bindings.selected[child];
        if(chosen==0 || chosen>bindings.arities[child]){return .err(invalid(0));}
        let usize source=p.call_args[map*8+chosen-1] as usize;let usize site=dst-160;
        if(source<160 || source>=176){return .err(invalid(0));}
        var slices::Ticket target=bindings.sites[parent*16+site];
        if((consumed&(one<<site))!=0){target=frames::none();}
        i=0;while(i<bindings.arities[child]){if(restored[i]==site){target=result.resumed[i];}i+=1;}
        if(target.slot!=16){return .err(invalid(0));}
        let usize anchor=if(call!=256){p.code[call*8+6] as usize}else{source-160};
        if(anchor>=16){return .err(invalid(0));}
        let usize checked=check_store(ref bindings.loans,parent*16+site,parent*16+anchor,held,parent,consumed,32,false,0)?;
    }else if(!bindings.active[parent] || held.issued.slot>=16 || held.issued.generation==0){return .err(invalid(0));}
    return .ok(0);
}
fn Result<usize,errors::Error> check_finish(ref State s,ref ir::Program p,ref frames::Frames bindings,
    ref runtime::Returned result,ref inputs::State windows,ref usize[] live,ref captures::Plan plans){
    let usize frame=s.frame;let usize offset=p.offsets[s.pc];
    if(!bindings.active[frame] || bindings.arities[frame]>8 || bindings.continuations[frame]!=s.next || bindings.destinations[frame]!=s.dst){return .err(invalid(0));}
    if(s.mode==1){return check_borrowed(s,p,bindings,result,plans);}
    if(s.mode==5){
        if(frame<=1 || bindings.prepared[frame] || bindings.selected[frame]==0 || !result.held.active || result.held.exclusive ||
            result.held.frame!=frame-1 || s.dst>=16 || bindings.maps[frame]>=p.call_count){return .err(invalid(0));}
        let runtime::Held held=result.held;let usize one=1;
        if(live[frame-1]>=65536 || (live[frame-1]&(one<<s.dst))!=0 || held.view.start>held.view.end){return .err(invalid(offset));}
        let usize length=held.view.end-held.view.start;
        if(s.span.start>length || s.span.length>length-s.span.start){return .err(invalid(offset));}
        let u32 packed=words::pack_result(s.dst,s.span,offset)?;
        let usize checked=check_store(ref bindings.loans,1024+(frame-1)*16+s.dst,512,held,frame-1,0,frame,true,offset)?;
        return .ok(0);
    }
    if(frame>1 && (bindings.prepared[frame] || bindings.selected[frame]!=0 ||
        loans::in_frame(ref bindings.loans,frame) || bindings.maps[frame]>=p.call_count)){return .err(invalid(0));}
    if(s.op==8 && frame>1 && s.dst>=128){return .err(invalid(0));}
    if(s.mode==4){
        if(!inputs::accepts(windows,s.span) || inputs::get(windows,frame-1,s.dst,offset).is_ok){return .err(invalid(offset));}
    }
    return .ok(0);
}

fn Result<usize,errors::Error> finish(ref mut State s,ref metadata::State work,ref ir::Program p,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut inputs::State windows,
    ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,ref mut usize remaining,ref captures::Plan plans){
    let usize frame=s.frame;let usize parent=frame-1;let usize offset=p.offsets[s.pc];
    // All Result-returning frame/output helpers below are trusted publication
    // boundaries after check_finish against the same frozen metadata. There is
    // no yield, allocation, payload access, or external callback in this block.
    metadata::publish(work,state);*remaining=work.returned.remaining;
    if(s.mode==1){let usize next=frames::pop_cached(p,bindings,work.returned,plans)?;s.next=next;}
    else if(s.mode==5){let usize next=frames::pop_reference(p,bindings,work.returned)?;s.next=next;
        live[parent]=receipts::publish(ref mut bindings.loans,parent,s.dst,work.returned.held,s.span,
            current[parent*16..parent*16+16],live[parent],offset)?;
    }else{
        let owned::LeavePlan prepared=owned::LeavePlan{.result=s.result,.frame=frame,.destination=s.dst,
            .fuel=s.native_fuel,.op=if(s.op==79){8}else{s.op}};
        let runtime::Resumed resumed=runtime::Resumed{.tickets=work.returned.resumed,.remaining=work.returned.remaining};
        let usize next=owned::finish_leave(p,bindings,ref prepared,resumed)?;s.next=next;
        if(s.op==79 && s.mode!=2){
            current[parent*16+s.dst]=s.word;let usize one=1;live[parent]|=one<<s.dst;
        }
    }
    // The result replaces an active child site, so clear the child before
    // publishing its caller view. The final live descriptor count cannot grow.
    let usize cleared=inputs::clear_frame(windows,frame,offset)?;
    if(s.mode==4){let usize installed=inputs::put(windows,parent,s.dst,s.span,offset)?;}
    if(s.op==79){live[frame]=0;var usize i=0;while(i<16){current[frame*16+i]=0;i+=1;}
        if(s.mode==2){current[parent*16+s.dst]=s.word;let usize one=1;live[parent]|=one<<s.dst;}
    }
    if(s.op==8 && frame>1){registers[parent*128+s.dst]=s.value;}
    s.complete=bindings.frame==0;s.view=s.complete && s.mode==1;s.pending=false;s.done=true;s.phase=4;return .ok(0);
}

// The parent resets allowance only once per outer dispatch and shares its
// remaining payload room. Each call consumes at most one fresh metadata stage;
// partial room defers without changing the pending recipe or banking credit.
pub fn Result<bool,errors::Error> advance(ref mut State s,ref mut metadata::State work,ref mut budget::State allowance,
    ref ir::Program p,ref statics::Sites sites,ref mut frames::Frames bindings,ref mut runtime::State state,usize capacity,
    ref mut inputs::State windows,ref u8[] origins,ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,
    ref mut usize remaining,usize byte_allowance,ref captures::Plan plans){
    let Result<bool,errors::Error> result=progress(s,work,allowance,p,sites,bindings,state,capacity,windows,origins,
        live,current,registers,remaining,byte_allowance,plans);
    return switch(result){case .ok(v):{.ok(v)}case .err(e):{s.pending=false;s.done=false;.err(e)}};
}
fn Result<bool,errors::Error> progress(ref mut State s,ref mut metadata::State work,ref mut budget::State allowance,
    ref ir::Program p,ref statics::Sites sites,ref mut frames::Frames bindings,ref mut runtime::State state,usize capacity,
    ref mut inputs::State windows,ref u8[] origins,ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,
    ref mut usize remaining,usize byte_allowance,ref captures::Plan plans){
    if(!s.pending || s.done || !operation(p,s.pc) || s.phase<1 || s.phase>3 || s.frame==0 || s.frame>=32 ||
        s.frame!=bindings.frame || p.code[s.pc*8]!=s.op || live.len!=32 || current.len!=512 || !frames::has_register_frame(registers.len,s.frame) || origins.len!=16){return .err(invalid(0));}
    let usize offset=p.offsets[s.pc];
    if(*remaining!=s.fuel_pinned || byte_allowance>4096 || allowance.last>4096 || allowance.last>allowance.total || allowance.stages>allowance.total){return .err(invalid(offset));}
    if(byte_allowance<4096 || allowance.last!=0){return .ok(false);}
    if(s.phase==1){
        if(!budget::admit(allowance,4096,offset)?){return .ok(false);}
        var owners::Token[16] roots=[owners::Token{.slot=0,.generation=0};16];var usize count=0;
        // Preserve root-compaction errors before the handoff Fuel gate.
        if(borrowed(s)){count=switch(records::compact_roots(bindings,ref mut roots)){
            case .ok(v):{v}case .err(e):{return .err(native_error(s,e,offset));}};}
        let runtime::Call call=frames::current(bindings);
        let usize started=switch(metadata::start_return(work,state,ref call,s.selected,ref roots[..count],capacity,s.native_fuel,borrowed(s))){
            case .ok(v):{v}case .err(e):{return .err(native_error(s,e,offset));}
        };s.phase=2;return .ok(false);
    }
    if(work.capacity!=capacity || work.fuel!=s.native_fuel || work.call.frame!=s.frame-1 || work.mode!=if(borrowed(s)){3}else{2}){return .err(invalid(offset));}
    if(s.phase==2){let bool finished=switch(metadata::advance(work,allowance)){
        case .ok(v):{v}case .err(e):{return .err(native_error(s,e,offset));}
    };if(finished){s.phase=3;}return .ok(false);}
    if(!work.done || work.active){return .err(invalid(offset));}
    if(!budget::admit(allowance,4096,offset)?){return .ok(false);}
    let usize checked=switch(check_finish(s,p,bindings,ref work.returned,windows,live,plans)){
        case .ok(v):{v}case .err(e):{return .err(if(s.mode==0 || s.mode==2){errors::make(e.kind,offset)}else{e});}
    };
    let usize published=finish(s,work,p,bindings,state,windows,live,current,registers,remaining,plans)?;return .ok(true);
}
