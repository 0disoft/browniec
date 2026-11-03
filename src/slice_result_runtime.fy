module slice_result_runtime;
import array_slices as slices;
import array_owners as owners;
import slice_authority as authority;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import array_vm as arrays;
import errors as errors;

// Invocation-private coordinator. All copies below are unpublished metadata
// transactions, never independently usable owners. Backing bytes are not copied.
pub struct Runtime { authority::State authority; slices::Pool pool; owners::Table owners; }
pub struct State { Runtime runtime; }
pub struct Contract { u8[8] tags; usize arity; usize selected; }
pub struct Capture { slices::Ticket ticket; bool close; bool drop; }
pub struct Call {
    Capture[8] captures; owners::View[8] views; slices::Ticket[8] issued;
    slices::Ticket[16] before; Contract contract; usize depth; usize frame; usize remaining; bool active;
}
pub struct Held {
    slices::Ticket issued; owners::View view; bool exclusive; bool close_parent;
    bool drop; usize depth; usize frame; bool active;
}
pub struct Returned { Held held; slices::Ticket[8] resumed; usize remaining; }
pub struct Closed { slices::Ticket parent; usize remaining; }
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool same(slices::Ticket a,slices::Ticket b){return a.slot==b.slot && a.generation==b.generation;}
fn bool root(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
fn bool view(owners::View a,owners::View b){return root(a.root,b.root) && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end;}
fn Result<usize,errors::Error> size(Result<usize,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Arguments,errors::Error> arguments(Result<slices::Arguments,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
pub fn State empty(usize capacity){return State{.runtime=Runtime{.authority=authority::empty(),.pool=slices::empty(),.owners=owners::empty(capacity)}};}
pub fn Capture capture(slices::Ticket value,bool close,bool drop){return Capture{.ticket=value,.close=close,.drop=drop};}
// Private conservative metadata admission; not a public opcode/cost revision.
pub fn usize cost(){return 65537*80;}
pub fn Result<Contract,errors::Error> contract(ref ir::Program unit,usize function){
    let verifier::Proof checked=verifier::inspect(unit)?;
    if(function>=unit.body.function_count || function>=16 || unit.elements[function]==0){return .err(errors::make(5,0));}
    var Contract result=Contract{.tags=[0;8],.arity=unit.body.arities[function],.selected=unit.parameters[function] as usize};
    var usize i=0;while(i<result.arity){
        let usize site=unit.body.slice_parameters[unit.body.register_starts[function]+i] as usize;
        if(site!=0){result.tags[i]=unit.body.slice_elements[site-1];}i+=1;
    }return .ok(result);
}
pub fn Result<Call,errors::Error> enter(ref mut State state,Contract binding,ref Capture[] captures,usize capacity,usize fuel){
    if(fuel<cost()){return .err(errors::make(8,0));}
    if(binding.arity==0 || binding.arity>8 || captures.len!=binding.arity || binding.selected==0 || binding.selected>binding.arity || binding.tags[binding.selected-1]==0){return .err(errors::make(5,0));}
    let usize depth=size(authority::inspect(ref state.runtime.authority))?;
    let usize frame=state.runtime.authority.frame;
    var Call result=Call{.captures=[capture(none(),false,false);8],.views=[state.runtime.pool.slots[0].view;8],
        .issued=[none();8],.before=[none();16],.contract=binding,.depth=depth,.frame=frame,.remaining=fuel-cost(),.active=true};
    var usize i=0;while(i<16){if(state.runtime.pool.slots[i].live){result.before[i]=slices::Ticket{.slot=i,.generation=state.runtime.pool.slots[i].generation};}i+=1;}
    var slices::Ticket[8] writers=[none();8];var usize count=0;i=0;
    // Authenticate all original actuals before any staged retain/rotation.
    while(i<captures.len){
        let Capture c=captures[i];result.captures[i]=c;
        if(binding.tags[i]==0){if(!same(c.ticket,none()) || c.close || c.drop){return .err(errors::make(5,0));}}
        else{
            let usize length=size(slices::length(ref state.runtime.pool,c.ticket,ref state.runtime.owners,capacity))?;
            let slices::Slot entry=state.runtime.pool.slots[c.ticket.slot];
            let u8 tag=entry.view.element | if(entry.exclusive){128}else{0};
            if(tag!=binding.tags[i] || (c.drop && !c.close)){return .err(errors::make(5,0));}
            var usize prior=0;while(prior<i){if(same(c.ticket,captures[prior].ticket) && c.close!=captures[prior].close){return .err(errors::make(5,0));}prior+=1;}
            result.views[i]=entry.view;
            if(entry.exclusive){writers[count]=c.ticket;count+=1;}
        }i+=1;
    }
    var authority::State next_authority=state.runtime.authority;
    var slices::Pool next_pool=state.runtime.pool;
    var owners::Table next_owners=state.runtime.owners;
    let slices::Arguments moved=arguments(authority::enter_call(ref mut next_authority,ref mut next_pool,ref writers[..count],ref next_owners,capacity,frame))?;
    var usize writer=0;i=0;
    while(i<captures.len){
        if(binding.tags[i]!=0){
            if((binding.tags[i]&128)!=0){result.issued[i]=moved.tickets[writer];writer+=1;}
            else{let usize length=result.views[i].end-result.views[i].start;result.issued[i]=ticket(slices::subslice(ref mut next_pool,captures[i].ticket,ref next_owners,0,length,capacity))?;}
        }i+=1;
    }
    state.runtime=Runtime{.authority=next_authority,.pool=next_pool,.owners=next_owners};return .ok(result);
}

// Caller supplies the live descriptor selected by independently verified IR.
// Native Contracts/Calls/Held values are linear coordinator receipts, not a C ABI.
pub fn Result<Returned,errors::Error> handoff(ref mut State state,ref mut Call call,slices::Ticket selected,usize capacity,usize fuel){
    if(fuel<cost()){return .err(errors::make(8,0));}
    let usize depth=size(authority::inspect(ref state.runtime.authority))?;
    if(!call.active || call.contract.arity>8 || call.contract.selected==0 || call.contract.selected>call.contract.arity ||
        call.depth>=31 || call.frame>=31 || depth<=call.depth || state.runtime.authority.frame!=call.frame+1 ||
        state.runtime.authority.kinds[call.depth]!=1 || state.runtime.authority.frames[call.depth]!=call.frame){return .err(errors::make(5,0));}
    let usize chosen=call.contract.selected-1;
    let usize length=size(slices::length(ref state.runtime.pool,selected,ref state.runtime.owners,capacity))?;
    let slices::Slot entry=state.runtime.pool.slots[selected.slot];let owners::View expected=call.views[chosen];
    if(!root(entry.view.root,expected.root) || entry.view.element!=expected.element || entry.view.length!=expected.length ||
        entry.view.start<expected.start || entry.view.end>expected.end || entry.exclusive!=((call.contract.tags[chosen]&128)!=0) ||
        (!entry.exclusive && same(call.before[selected.slot],selected))){return .err(errors::make(5,0));}
    if(entry.exclusive && selected.slot!=call.issued[chosen].slot){return .err(errors::make(5,0));}
    var authority::State next_authority=state.runtime.authority;
    var slices::Pool next_pool=state.runtime.pool;
    var owners::Table next_owners=state.runtime.owners;
    // Unwind callee lexical children privately; no caller parent becomes usable
    // in the live runtime before the final selected child has been installed.
    while(next_authority.depth>call.depth+1){
        let usize top=next_authority.depth-1;
        if(next_authority.kinds[top]!=2 || next_authority.frames[top]!=call.frame+1){return .err(errors::make(5,0));}
        let usize slot=next_authority.children[top].issued.slot;
        if(slot>=16){return .err(errors::make(5,0));}
        let slices::Ticket current=slices::Ticket{.slot=slot,.generation=next_pool.slots[slot].generation};
        let slices::Ticket restored=ticket(authority::leave_child(ref mut next_authority,ref mut next_pool,current,ref next_owners,capacity,call.frame+1))?;
    }
    var slices::Ticket[8] writers=[none();8];var usize count=0;var usize i=0;
    while(i<call.contract.arity){
        if(call.contract.tags[i]!=0){
            let slices::Ticket issued=call.issued[i];
            if(issued.slot>=16){return .err(errors::make(5,0));}
            if((call.contract.tags[i]&128)!=0){
                let usize index=call.depth*8+count;
                if(!same(next_authority.tickets[index],issued)){return .err(errors::make(5,0));}
                let slices::Ticket current=slices::Ticket{.slot=issued.slot,.generation=next_pool.slots[issued.slot].generation};
                let usize valid=size(slices::length(ref next_pool,current,ref next_owners,capacity))?;
                if(!view(next_pool.slots[issued.slot].view,call.views[i])){return .err(errors::make(5,0));}
                writers[count]=current;count+=1;
            }else{let usize valid=size(slices::length(ref next_pool,issued,ref next_owners,capacity))?;}
        }i+=1;
    }
    let slices::Arguments restored=arguments(authority::leave_call(ref mut next_authority,ref mut next_pool,ref writers[..count],ref next_owners,capacity,call.frame+1))?;
    var slices::Ticket[8] resumed=[none();8];var usize writer=0;i=0;
    while(i<call.contract.arity){if(call.contract.tags[i]!=0){if((call.contract.tags[i]&128)!=0){resumed[i]=restored.tickets[writer];writer+=1;}else{resumed[i]=call.captures[i].ticket;}}i+=1;}
    var slices::Ticket issued=selected;
    if(entry.exclusive){
        let owners::View parent=call.views[chosen];
        issued=ticket(authority::enter_child(ref mut next_authority,ref mut next_pool,resumed[chosen],ref next_owners,entry.view.start-parent.start,entry.view.end-parent.start,capacity,call.frame))?;
        resumed[chosen]=none();
    }else{
        // Transfer the selected slot without another slot or read session. The
        // callee's handle becomes stale, even when every pool slot is occupied.
        if(selected.generation==18446744073709551615){return .err(errors::make(5,0));}
        issued=slices::Ticket{.slot=selected.slot,.generation=selected.generation+1};next_pool.slots[selected.slot].generation=issued.generation;
    }
    // All readonly handles created in this callee are its cleanup domain.
    i=16;while(i>0){i-=1;let slices::Slot slot=next_pool.slots[i];
        if(slot.live && !slot.exclusive && i!=issued.slot && !same(call.before[i],slices::Ticket{.slot=i,.generation=slot.generation})){
            let usize closed=size(slices::close(ref mut next_pool,slices::Ticket{.slot=i,.generation=slot.generation},ref mut next_owners,capacity))?;
        }
    }
    var usize closed_mask=0;let usize one=1;var bool drop=false;i=call.contract.arity;
    while(i>0){i-=1;if(call.contract.tags[i]!=0){
        let Capture c=call.captures[i];let bool retained=entry.exclusive && i==chosen;
        if(c.drop && root(call.views[i].root,entry.view.root)){drop=true;}
        if(c.close && !retained && (closed_mask&(one<<resumed[i].slot))==0){
            let usize closed=size(slices::close(ref mut next_pool,resumed[i],ref mut next_owners,capacity))?;
            closed_mask|=one<<resumed[i].slot;
        }
        if(c.close){resumed[i]=none();}
    }}
    var usize dropped=0;i=call.contract.arity;
    while(i>0){i-=1;if(call.captures[i].drop && call.contract.tags[i]!=0 && !root(call.views[i].root,entry.view.root)){
        let owners::Token token=call.views[i].root;
        if((dropped&(one<<token.slot))==0){let usize released=size(owners::release(ref mut next_owners,token,capacity))?;dropped|=one<<token.slot;}
    }}
    let Held held=Held{.issued=issued,.view=entry.view,.exclusive=entry.exclusive,.close_parent=call.captures[chosen].close,
        .drop=drop,.depth=call.depth,.frame=call.frame,.active=true};
    state.runtime=Runtime{.authority=next_authority,.pool=next_pool,.owners=next_owners};call.active=false;return .ok(Returned{.held=held,.resumed=resumed,.remaining=fuel-cost()});
}

pub fn Result<Closed,errors::Error> close(ref mut State state,ref mut Held held,slices::Ticket current,usize capacity,usize fuel){
    if(fuel<cost()){return .err(errors::make(8,0));}
    if(!held.active || current.slot!=held.issued.slot || current.generation<held.issued.generation || (!held.exclusive && !same(current,held.issued))){return .err(errors::make(5,0));}
    let usize length=size(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,capacity))?;
    if(!view(state.runtime.pool.slots[current.slot].view,held.view)){return .err(errors::make(5,0));}
    var authority::State next_authority=state.runtime.authority;
    var slices::Pool next_pool=state.runtime.pool;
    var owners::Table next_owners=state.runtime.owners;var slices::Ticket parent=none();
    if(held.exclusive){
        let usize depth=size(authority::inspect(ref next_authority))?;
        if(held.depth>=31 || depth!=held.depth+1 || next_authority.kinds[held.depth]!=2 || next_authority.frame!=held.frame ||
            !same(next_authority.children[held.depth].issued,held.issued)){return .err(errors::make(5,0));}
        parent=ticket(authority::leave_child(ref mut next_authority,ref mut next_pool,current,ref next_owners,capacity,held.frame))?;
        if(held.close_parent){let usize closed=size(slices::close(ref mut next_pool,parent,ref mut next_owners,capacity))?;parent=none();}
    }else{let usize closed=size(slices::close(ref mut next_pool,current,ref mut next_owners,capacity))?;}
    if(held.drop){let usize released=size(owners::release(ref mut next_owners,held.view.root,capacity))?;}
    state.runtime=Runtime{.authority=next_authority,.pool=next_pool,.owners=next_owners};held.active=false;return .ok(Closed{.parent=parent,.remaining=fuel-cost()});
}
// Terminal cleanup uses the admission reserve even with zero execution Fuel.
pub fn Result<usize,errors::Error> abort(ref mut State state,usize capacity,usize fuel){
    var authority::State next_authority=state.runtime.authority;
    var slices::Pool next_pool=state.runtime.pool;
    var owners::Table next_owners=state.runtime.owners;
    let usize cleared=size(authority::finish(ref mut next_authority,ref mut next_pool,ref mut next_owners,capacity))?;
    let usize released=size(owners::clear(ref mut next_owners,capacity))?;
    state.runtime=Runtime{.authority=next_authority,.pool=next_pool,.owners=next_owners};return .ok(fuel);
}
