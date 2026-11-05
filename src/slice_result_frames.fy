module slice_result_frames;
import slice_result_runtime as runtime;
import array_slices as slices;
import ir as ir;
import array_owners as owners;
import errors as errors;
import slice_result_record_bindings as records;
import slice_result_bindings as loans;
import slice_result_call_ir as calls;

// Invocation-private bindings. Result identities never enter scalar registers.
// Calls and prepared tickets are linear receipts; this object must not escape.
pub struct Frames {
    runtime::Capture[256] captures; owners::View[256] views;
    slices::Ticket[256] issued; slices::Ticket[512] before;
    u8[256] tags; usize[32] arities; usize[32] selected;
    usize[32] depths; usize[32] remaining; bool[32] active;
    owners::Token[512] tokens; records::State records; loans::State loans;
    slices::Ticket[512] sites;
    slices::Ticket[32] results;
    usize[32] functions; usize[32] continuations; usize[32] maps;
    usize[32] destinations; usize[32] identities; bool[32] prepared;
    usize frame;
}
pub fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
pub fn Frames empty(ref runtime::State state){
    let ref slices::Pool pool=ref state.runtime.pool;
    return Frames{.captures=[runtime::capture(none(),false,false);256],
        .views=[pool.slots[0].view;256],.issued=[none();256],.before=[none();512],
        .tags=[0;256],.arities=[0;32],.selected=[0;32],.depths=[0;32],.remaining=[0;32],.active=[false;32],
        .records=records::empty(),.loans=loans::empty(),.tokens=[owners::Token{.slot=0,.generation=0};512],.sites=[none();512],.results=[none();32],
        .functions=[16;32],.continuations=[0;32],.maps=[32;32],
        .destinations=[128;32],.identities=[128;32],.prepared=[false;32],.frame=0};
}
// The driver checks bounds before runtime::enter. Failure never publishes a
// result; its invocation cleanup drains any entered native transaction.
pub fn Result<usize,errors::Error> push(ref ir::Program p,ref mut Frames bindings,
    runtime::Call call,usize function,usize destination,usize map,usize continuation){
    let usize child=bindings.frame+1;
    if(child>=32 || function>=p.function_count || !call.active || call.frame!=bindings.frame ||
        (child>1 && (destination>=176 || map>=p.call_count || bindings.prepared[bindings.frame] ||
            (destination>=160 && (call.contract.selected==0 || bindings.sites[bindings.frame*16+destination-160].slot!=16))))){
        return .err(errors::make(5,0));
    }
    var usize argument=0;while(argument<8){
        bindings.captures[child*8+argument]=call.captures[argument];bindings.views[child*8+argument]=call.views[argument];
        bindings.issued[child*8+argument]=call.issued[argument];bindings.tags[child*8+argument]=call.contract.tags[argument];argument+=1;
    }
    argument=0;while(argument<16){bindings.before[child*16+argument]=call.before[argument];argument+=1;}
    bindings.arities[child]=call.contract.arity;bindings.selected[child]=call.contract.selected;
    bindings.depths[child]=call.depth;bindings.remaining[child]=call.remaining;bindings.active[child]=true;
    bindings.functions[child]=function;
    bindings.destinations[child]=destination;bindings.maps[child]=map;
    bindings.continuations[child]=continuation;bindings.prepared[child]=false;
    bindings.identities[child]=128;bindings.results[child]=none();
    var usize i=0;while(i<16){bindings.sites[child*16+i]=none();bindings.tokens[child*16+i]=owners::Token{.slot=0,.generation=0};i+=1;}
    records::clear_frame(ref mut bindings.records,child);
    i=0;while(i<call.contract.arity){
        let usize parameter=p.slice_parameters[p.register_starts[function]+i] as usize;
        if(parameter!=0){bindings.sites[child*16+parameter-1]=call.issued[i];}i+=1;
    }
    bindings.frame=child;return .ok(child);
}
pub fn Result<usize,errors::Error> prepare(ref mut Frames bindings,usize identity,slices::Ticket selected){
    let usize f=bindings.frame;
    if(f==0 || f>=32 || bindings.prepared[f] || identity>=128 || selected.slot>=16 || selected.generation==0){return .err(errors::make(5,0));}
    bindings.results[f]=selected;bindings.identities[f]=identity;bindings.prepared[f]=true;return .ok(identity);
}
pub fn Result<usize,errors::Error> selected(ref Frames bindings,usize identity){
    let usize f=bindings.frame;
    if(f==0 || f>=32 || !bindings.prepared[f] || bindings.identities[f]!=identity || !bindings.active[f]){return .err(errors::make(5,0));}
    return .ok(f);
}
// Called only after successful native handoff. Restore named actual bindings
// from the fresh resumed tickets and consume the callee's private frame.
pub fn Result<usize,errors::Error> pop(ref ir::Program p,ref mut Frames bindings,runtime::Returned returned){
    let usize child=bindings.frame;
    if(child==0 || child>=32 || !bindings.prepared[child] || !returned.held.active || returned.held.frame!=child-1){return .err(errors::make(5,0));}
    let usize parent=child-1;let usize next=bindings.continuations[child];
    if(parent!=0){
        let usize map=bindings.maps[child];let usize destination=bindings.destinations[child];
        if(map>=p.call_count || (destination>=128 && (destination<160 || destination>=176)) || bindings.prepared[parent]){return .err(errors::make(5,0));}
        let usize call=if(next>0 && next<=p.count && p.code[(next-1)*8]==66){next-1}else{256};
        let usize mask=if(call!=256){p.code[call*8+4] as usize}else{0};let usize one=1;
        if(call!=256){
            let usize end=calls::binding(p,call)?;var usize at=call+1;
            while(at<end){if(p.code[at*8]==68){
                let usize site=p.code[at*8+1] as usize;
                loans::consumed(ref mut bindings.loans,parent*16+site);
                bindings.sites[parent*16+site]=none();
            }at+=1;}
        }
        var usize i=0;while(i<bindings.arities[child]){
            let usize argument=p.call_args[map*8+i] as usize;
            if(argument>=160 && argument<176){
                var usize site=argument-160;
                if((mask&(one<<i))!=0){
                    let calls::Chain ended=calls::chain(p,call,i)?;
                    site=ended.parent;
                }
                bindings.sites[parent*16+site]=returned.resumed[i];
            }i+=1;
        }
        if(destination>=160){
            let usize chosen=bindings.selected[child];
            if(chosen==0 || chosen>bindings.arities[child]){return .err(errors::make(5,0));}
            let usize source=p.call_args[map*8+chosen-1] as usize;
            let usize location=parent*16+destination-160;
            if(source<160 || source>=176 || bindings.sites[location].slot!=16){return .err(errors::make(5,0));}
            let usize anchor=if(call!=256){p.code[call*8+6] as usize}else{source-160};
            if(anchor>=16){return .err(errors::make(5,0));}
            let usize retained=loans::retain(ref mut bindings.loans,location,parent*16+anchor,returned.held)?;
            bindings.sites[location]=returned.held.issued;
        }else{let usize staged=prepare_parent(bindings,parent,destination,returned.held.issued)?;}
    }
    loans::transferred(ref mut bindings.loans,child);
    bindings.active[child]=false;bindings.prepared[child]=false;
    bindings.results[child]=none();bindings.identities[child]=128;bindings.functions[child]=16;
    var usize i=0;while(i<16){bindings.sites[child*16+i]=none();bindings.tokens[child*16+i]=owners::Token{.slot=0,.generation=0};i+=1;}
    records::clear_frame(ref mut bindings.records,child);bindings.frame=parent;return .ok(next);
}
fn Result<usize,errors::Error> prepare_parent(ref mut Frames bindings,usize parent,usize identity,slices::Ticket selected){
    if(parent==0 || parent>=32 || !bindings.active[parent] || selected.slot>=16 || selected.generation==0){return .err(errors::make(5,0));}
    bindings.results[parent]=selected;bindings.identities[parent]=identity;bindings.prepared[parent]=true;return .ok(identity);
}

// Reconstruct one unpublished transaction for the active native handoff.
pub fn runtime::Call current(ref Frames bindings){
    let usize f=bindings.frame;
    var runtime::Call call=runtime::Call{.captures=[runtime::capture(none(),false,false);8],
        .views=[bindings.views[f*8];8],.issued=[none();8],.before=[none();16],
        .contract=runtime::Contract{.tags=[0;8],.arity=bindings.arities[f],.selected=bindings.selected[f]},
        .depth=bindings.depths[f],.frame=f-1,.remaining=bindings.remaining[f],.active=bindings.active[f]};
    var usize i=0;while(i<8){call.captures[i]=bindings.captures[f*8+i];call.views[i]=bindings.views[f*8+i];
        call.issued[i]=bindings.issued[f*8+i];call.contract.tags[i]=bindings.tags[f*8+i];i+=1;}
    i=0;while(i<16){call.before[i]=bindings.before[f*16+i];i+=1;}return call;
}

// Ordinary scalar/array return has no prepared borrowed destination.
pub fn Result<usize,errors::Error> pop_call(ref ir::Program p,ref mut Frames bindings,runtime::Resumed resumed){
    let usize child=bindings.frame;
    if(child<=1 || child>=32 || bindings.prepared[child] || !bindings.active[child] || bindings.selected[child]!=0 || loans::in_frame(ref bindings.loans,child)){return .err(errors::make(5,0));}
    let usize parent=child-1;let usize map=bindings.maps[child];let usize next=bindings.continuations[child];
    if(map>=p.call_count){return .err(errors::make(5,0));}
    var usize i=0;while(i<bindings.arities[child]){let usize source=p.call_args[map*8+i] as usize;
        if(source>=160 && source<176){bindings.sites[parent*16+source-160]=resumed.tickets[i];}i+=1;
    }
    bindings.active[child]=false;bindings.functions[child]=16;
    i=0;while(i<16){bindings.sites[child*16+i]=none();bindings.tokens[child*16+i]=owners::Token{.slot=0,.generation=0};i+=1;}
    records::clear_frame(ref mut bindings.records,child);bindings.frame=parent;return .ok(next);
}

// Finalizers are prepaid by the successful handoff that issued each receipt.
pub fn bool result_bound(ref Frames bindings,usize site){
    if(site>=16){return false;}let usize location=bindings.frame*16+site;return loans::find(ref bindings.loans,location)!=47;
}
pub fn Result<usize,errors::Error> close_result(ref mut Frames bindings,ref mut runtime::State state,usize site,usize capacity,usize fuel){
    if(site>=16 || bindings.frame==0){return .err(errors::make(5,0));}
    let usize location=bindings.frame*16+site;
    let slices::Ticket current=bindings.sites[location];
    let loans::Closed closed=loans::close(ref mut bindings.loans,state,location,current,capacity,fuel)?;
    if(closed.location<512){bindings.sites[closed.location]=closed.parent;}
    bindings.sites[location]=none();return .ok(closed.remaining);
}

// Generic shared handoff has its own universal-site destination. Restore only
// ordinary actual bindings, retire consumed child receipts, then let the caller
// publish its new universal word in the disjoint receipt namespace.
pub fn Result<usize,errors::Error> pop_reference(ref ir::Program p,ref mut Frames bindings,runtime::Returned returned){
    let usize child=bindings.frame;
    if(child<=1 || child>=32 || !bindings.active[child] || bindings.prepared[child] ||
        bindings.selected[child]==0 || !returned.held.active || returned.held.exclusive || returned.held.frame!=child-1 ||
        bindings.destinations[child]>=16 || bindings.maps[child]>=p.call_count){return .err(errors::make(5,0));}
    let usize parent=child-1;let usize map=bindings.maps[child];let usize next=bindings.continuations[child];
    var usize i=0;while(i<bindings.arities[child]){let usize actual=p.call_args[map*8+i] as usize;
        if(actual>=160 && actual<176){bindings.sites[parent*16+actual-160]=returned.resumed[i];}i+=1;}
    loans::transferred(ref mut bindings.loans,child);bindings.active[child]=false;bindings.functions[child]=16;
    bindings.results[child]=none();bindings.identities[child]=128;
    i=0;while(i<16){bindings.sites[child*16+i]=none();bindings.tokens[child*16+i]=owners::Token{.slot=0,.generation=0};i+=1;}
    records::clear_frame(ref mut bindings.records,child);bindings.frame=parent;return .ok(next);
}
