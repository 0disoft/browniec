module slice_result_runtime;
import array_slices as slices;
import array_owners as owners;
import slice_authority as authority;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import array_vm as arrays;
import array_layout as layouts;
import errors as errors;
import fuel as meter;
import struct_layout as records;

// Invocation-private coordinator. All copies below are unpublished metadata
// transactions, never independently usable owners. Backing bytes are not copied.
pub struct Runtime { authority::State authority; slices::Pool pool; owners::Table owners; }
pub struct State { Runtime runtime; }
pub struct Contract { u8[8] tags; usize arity; usize selected; }
pub struct Capture { slices::Ticket ticket; bool close; bool drop; usize ends; }
pub struct Call {
    Capture[8] captures; owners::View[8] views; slices::Ticket[8] issued;
    slices::Ticket[16] before; Contract contract; usize depth; usize frame; usize remaining; bool active;
}
pub struct Entered { Call call; owners::Copies copies; }
pub struct Held {
    slices::Ticket issued; owners::View view; bool exclusive; bool close_parent;
    bool drop; usize depth; usize frame; bool active;
}
pub struct Returned { Held held; slices::Ticket[8] resumed; usize remaining; }
pub struct Resumed { slices::Ticket[8] tickets; usize remaining; }
pub struct Closed { slices::Ticket parent; usize remaining; }
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool same(slices::Ticket a,slices::Ticket b){return a.slot==b.slot && a.generation==b.generation;}
fn bool root(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
fn bool view(owners::View a,owners::View b){return root(a.root,b.root) && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end;}
fn Result<usize,errors::Error> size(Result<usize,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Arguments,errors::Error> loan_arguments(Result<slices::Arguments,owners::Error> value){return switch(value){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
pub fn State empty(usize capacity){return State{.runtime=Runtime{.authority=authority::empty(),.pool=slices::empty(),.owners=owners::empty(capacity)}};}
pub fn Capture capture(slices::Ticket value,bool close,bool drop){return Capture{.ticket=value,.close=close,.drop=drop,.ends=if(close){1}else{0}};}
// Private guest recipe count, independently proved before constructing this.
pub fn Capture chain_capture(slices::Ticket value,usize count){return Capture{.ticket=value,.close=count!=0,.drop=false,.ends=count};}
// Entry includes emergency cleanup. Handoff additionally prepays Held.close.
pub fn usize cost(){return meter::result_enter();}
pub fn usize handoff_cost(){return meter::result_handoff();}
pub fn usize leave_cost(){return meter::result_leave();}
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
    if(binding.selected==0 || binding.selected>binding.arity){return .err(errors::make(5,0));}
    return enter_call(state,binding,captures,capacity,fuel);
}
// Ordinary calls use selected=0, including zero-argument calls. Borrowed-result
// calls still require a nonzero selected formal through enter/IR admission.
pub fn Result<Call,errors::Error> enter_call(ref mut State state,Contract binding,ref Capture[] captures,usize capacity,usize fuel){
    let owners::Token[1] sources=[owners::Token{.slot=0,.generation=0};1];
    let layouts::Array[1] shapes=[layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};1];var u8[1] data=[0];
    let Entered entered=enter_arrays(state,binding,captures,ref sources[..0],ref shapes[..0],ref mut data[..0],capacity,fuel)?;
    return .ok(entered.call);
}
// Borrowed authority and owned value arguments commit in one metadata plan.
// copy_arguments validates every source/reservation before its first byte write.
pub fn Result<Entered,errors::Error> enter_arrays(ref mut State state,Contract binding,ref Capture[] captures,
    ref owners::Token[] sources,ref layouts::Array[] shapes,ref mut u8[] data,usize capacity,usize fuel){
    let records::Catalog catalog=records::empty();
    let owners::CallArgument[1] arguments=[owners::CallArgument{.source=owners::Token{.slot=0,.generation=0},.element=0,.length=0,.record=0}];
    return enter_values(state,binding,captures,sources,shapes,ref catalog,ref arguments[..0],data,capacity,fuel);
}
pub fn Result<Entered,errors::Error> enter_records(ref mut State state,Contract binding,ref Capture[] captures,
    ref records::Catalog catalog,ref owners::CallArgument[] arguments,ref mut u8[] data,usize fuel){
    let owners::Token[1] sources=[owners::Token{.slot=0,.generation=0}];
    let layouts::Array[1] shapes=[layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}];
    return enter_values(state,binding,captures,ref sources[..0],ref shapes[..0],catalog,arguments,data,data.len,fuel);
}
// One authority/pool/owner plan for the whole mixed argument batch. Nothing
// fallible follows its validated payload copy before metadata publication.
fn Result<Entered,errors::Error> enter_values(ref mut State state,Contract binding,ref Capture[] captures,
    ref owners::Token[] sources,ref layouts::Array[] shapes,ref records::Catalog catalog,
    ref owners::CallArgument[] arguments,ref mut u8[] data,usize capacity,usize fuel){
    // Borrow original fields once. Chained Runtime reads and whole-Runtime
    // construction materialize large native temporaries in the pinned backend.
    let ref authority::State original_authority=ref state.runtime.authority;
    let ref slices::Pool original_pool=ref state.runtime.pool;
    let ref owners::Table original_owners=ref state.runtime.owners;
    if(arguments.len>binding.arity || (arguments.len!=0 && (sources.len!=0 || data.len!=capacity))){return .err(errors::make(5,0));}
    if(sources.len>binding.arity || sources.len!=shapes.len || (sources.len!=0 && data.len!=capacity)){return .err(errors::make(5,0));}
    if(fuel<cost()){return .err(errors::make(8,0));}
    if(binding.arity>8 || captures.len!=binding.arity || binding.selected>binding.arity ||
        (binding.selected!=0 && binding.tags[binding.selected-1]==0)){return .err(errors::make(5,0));}
    let usize depth=size(authority::inspect(original_authority))?;
    let usize frame=original_authority.frame;
    var Call result=Call{.captures=[capture(none(),false,false);8],.views=[original_pool.slots[0].view;8],
        .issued=[none();8],.before=[none();16],.contract=binding,.depth=depth,.frame=frame,.remaining=fuel-cost(),.active=true};
    var usize i=0;while(i<16){if(original_pool.slots[i].live){result.before[i]=slices::Ticket{.slot=i,.generation=original_pool.slots[i].generation};}i+=1;}
    var slices::Ticket[8] writers=[none();8];var usize count=0;i=0;
    // Authenticate all original actuals before any staged retain/rotation.
    while(i<captures.len){
        let Capture c=captures[i];result.captures[i]=c;
        if(c.ends>16 || c.close!=(c.ends!=0) || (c.ends>1 && (c.drop || binding.selected==0))){return .err(errors::make(5,0));}
        if(binding.tags[i]==0){if(!same(c.ticket,none()) || c.close || c.drop){return .err(errors::make(5,0));}}
        else{
            let usize length=size(slices::length(original_pool,c.ticket,original_owners,capacity))?;
            let slices::Slot entry=original_pool.slots[c.ticket.slot];
            let u8 tag=entry.view.element | if(entry.exclusive){128}else{0};
            if(tag!=binding.tags[i] || (c.drop && !c.close) || (c.ends>1 && !entry.exclusive)){return .err(errors::make(5,0));}
            var usize prior=0;while(prior<i){if(same(c.ticket,captures[prior].ticket) && c.close!=captures[prior].close){return .err(errors::make(5,0));}prior+=1;}
            result.views[i]=entry.view;
            if(entry.exclusive){writers[count]=c.ticket;count+=1;}
        }i+=1;
    }
    var authority::State next_authority=*original_authority;
    var slices::Pool next_pool=*original_pool;
    var owners::Table next_owners=*original_owners;
    let slices::Arguments moved=loan_arguments(authority::enter_call(ref mut next_authority,ref mut next_pool,ref writers[..count],ref next_owners,capacity,frame))?;
    var usize writer=0;i=0;
    while(i<captures.len){
        if(binding.tags[i]!=0){
            if((binding.tags[i]&128)!=0){result.issued[i]=moved.tickets[writer];writer+=1;}
            else{let usize length=result.views[i].end-result.views[i].start;result.issued[i]=ticket(slices::subslice(ref mut next_pool,captures[i].ticket,ref next_owners,0,length,capacity))?;}
        }i+=1;
    }
    var owners::Copies copies=owners::Copies{.tokens=[owners::Token{.slot=0,.generation=0};8],.count=0};
    if(sources.len!=0){copies=switch(owners::copy_arguments(sources,shapes,data,ref mut next_owners)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}
    };}
    if(arguments.len!=0){copies=switch(owners::copy_call_arguments(catalog,arguments,data,ref mut next_owners)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}
    };}
    // All fallible work has finished. Publish staged metadata without another
    // complete Runtime value; these plain assignments cannot fail or call out.
    state.runtime.authority=next_authority;state.runtime.pool=next_pool;state.runtime.owners=next_owners;
    return .ok(Entered{.call=result,.copies=copies});
}

// Caller supplies the live descriptor selected by independently verified IR.
// Native Contracts/Calls/Held values are linear coordinator receipts, not a C ABI.
pub fn Result<Returned,errors::Error> handoff(ref mut State state,ref mut Call call,slices::Ticket selected,usize capacity,usize fuel){
    let owners::Token[1] empty=[owners::Token{.slot=0,.generation=0};1];
    return handoff_roots(state,call,selected,ref empty[..0],capacity,fuel);
}
pub fn Result<Returned,errors::Error> handoff_roots(ref mut State state,ref mut Call call,slices::Ticket selected,
    ref owners::Token[] roots,usize capacity,usize fuel){
    let ref authority::State original_authority=ref state.runtime.authority;
    let ref slices::Pool original_pool=ref state.runtime.pool;
    let ref owners::Table original_owners=ref state.runtime.owners;
    if(fuel<handoff_cost()){return .err(errors::make(8,0));}
    let usize depth=size(authority::inspect(original_authority))?;
    if(!call.active || call.contract.arity>8 || call.contract.selected==0 || call.contract.selected>call.contract.arity ||
        call.depth>=31 || call.frame>=31 || depth<=call.depth || original_authority.frame!=call.frame+1 ||
        original_authority.kinds[call.depth]!=1 || original_authority.frames[call.depth]!=call.frame){return .err(errors::make(5,0));}
    let usize chosen=call.contract.selected-1;
    let usize length=size(slices::length(original_pool,selected,original_owners,capacity))?;
    let slices::Slot entry=original_pool.slots[selected.slot];let owners::View expected=call.views[chosen];
    if(!root(entry.view.root,expected.root) || entry.view.element!=expected.element || entry.view.length!=expected.length ||
        entry.view.start<expected.start || entry.view.end>expected.end || entry.exclusive!=((call.contract.tags[chosen]&128)!=0) ||
        (!entry.exclusive && same(call.before[selected.slot],selected))){return .err(errors::make(5,0));}
    if(entry.exclusive && selected.slot!=call.issued[chosen].slot){return .err(errors::make(5,0));}
    var authority::State next_authority=*original_authority;
    var slices::Pool next_pool=*original_pool;
    var owners::Table next_owners=*original_owners;
    let slices::Arguments restored=restore(ref mut next_authority,ref mut next_pool,ref next_owners,call,capacity)?;
    var slices::Ticket[8] resumed=[none();8];var usize writer=0;var usize i=0;
    while(i<call.contract.arity){if(call.contract.tags[i]!=0){if((call.contract.tags[i]&128)!=0){resumed[i]=restored.tickets[writer];writer+=1;}else{resumed[i]=call.captures[i].ticket;}}i+=1;}
    // Anonymous mutable range arguments own a caller reborrow, not its whole
    // write session. End these in reverse capture order before installing the
    // returned child; otherwise a retained later argument would block cleanup.
    var bool[8] restored_capture=[false;8];
    var usize closed_mask=0;let usize one=1;var bool drop=false;i=call.contract.arity;
    while(i>0){i-=1;if(call.contract.tags[i]!=0){
        let Capture c=call.captures[i];
        if(c.drop && root(call.views[i].root,entry.view.root)){drop=true;}
        if(c.close && (call.contract.tags[i]&128)!=0){
            var bool pending=false;var usize at=0;
            while(at<next_authority.depth){
                if(next_authority.kinds[at]==2 && next_authority.children[at].issued.slot==resumed[i].slot){pending=true;}
                at+=1;
            }
            if(pending){
                var usize ended=0;while(ended<c.ends){
                    let usize depth=next_authority.depth;
                    if(c.drop || depth==0 || next_authority.kinds[depth-1]!=2 ||
                        next_authority.frames[depth-1]!=call.frame ||
                        next_authority.children[depth-1].issued.slot!=resumed[i].slot){return .err(errors::make(5,0));}
                    resumed[i]=ticket(authority::leave_child(ref mut next_authority,ref mut next_pool,resumed[i],ref next_owners,capacity,call.frame))?;
                    ended+=1;
                }restored_capture[i]=true;
            }else if(c.ends>1){return .err(errors::make(5,0));}
            else if(!(entry.exclusive && i==chosen)){
                let usize closed=size(slices::close(ref mut next_pool,resumed[i],ref mut next_owners,capacity))?;resumed[i]=none();
            }
        }else if(c.close){
            if((closed_mask&(one<<resumed[i].slot))==0){
                let usize closed=size(slices::close(ref mut next_pool,resumed[i],ref mut next_owners,capacity))?;closed_mask|=one<<resumed[i].slot;
            }
            resumed[i]=none();
        }
    }}
    var slices::Ticket issued=selected;let usize result_depth=next_authority.depth;
    if(entry.exclusive){
        let owners::View parent=next_pool.slots[resumed[chosen].slot].view;
        if(!root(parent.root,entry.view.root) || entry.view.start<parent.start || entry.view.end>parent.end){return .err(errors::make(5,0));}
        issued=ticket(authority::enter_child(ref mut next_authority,ref mut next_pool,resumed[chosen],ref next_owners,entry.view.start-parent.start,entry.view.end-parent.start,capacity,call.frame))?;
        resumed[chosen]=none();
    }else{
        // Transfer in place without a spare slot or another read session.
        if(selected.generation==18446744073709551615){return .err(errors::make(5,0));}
        issued=slices::Ticket{.slot=selected.slot,.generation=selected.generation+1};next_pool.slots[selected.slot].generation=issued.generation;
    }
    // All readonly handles created in this callee are its cleanup domain.
    i=16;while(i>0){i-=1;let slices::Slot slot=next_pool.slots[i];
        if(slot.live && !slot.exclusive && i!=issued.slot && !same(call.before[i],slices::Ticket{.slot=i,.generation=slot.generation})){
            let usize closed=size(slices::close(ref mut next_pool,slices::Ticket{.slot=i,.generation=slot.generation},ref mut next_owners,capacity))?;
        }
    }
    var usize dropped=0;i=call.contract.arity;
    while(i>0){i-=1;if(call.captures[i].drop && call.contract.tags[i]!=0 && !root(call.views[i].root,entry.view.root)){
        let owners::Token token=call.views[i].root;
        if((dropped&(one<<token.slot))==0){let usize released=size(owners::release(ref mut next_owners,token,capacity))?;dropped|=one<<token.slot;}
    }}
    let usize released=release_roots(ref mut next_pool,ref mut next_owners,call,roots,capacity)?;
    let Held held=Held{.issued=issued,.view=entry.view,.exclusive=entry.exclusive,.close_parent=call.captures[chosen].close && !restored_capture[chosen],
        .drop=drop,.depth=result_depth,.frame=call.frame,.active=true};
    state.runtime.authority=next_authority;state.runtime.pool=next_pool;state.runtime.owners=next_owners;call.active=false;return .ok(Returned{.held=held,.resumed=resumed,.remaining=fuel-handoff_cost()});
}

pub fn Result<Closed,errors::Error> close(ref mut State state,ref mut Held held,slices::Ticket current,usize capacity,usize fuel){
    let ref authority::State original_authority=ref state.runtime.authority;
    let ref slices::Pool original_pool=ref state.runtime.pool;
    let ref owners::Table original_owners=ref state.runtime.owners;
    // Only a successful, funded handoff issues this linear cleanup receipt.
    if(!held.active || current.slot!=held.issued.slot || current.generation<held.issued.generation || (!held.exclusive && !same(current,held.issued))){return .err(errors::make(5,0));}
    let usize length=size(slices::length(original_pool,current,original_owners,capacity))?;
    if(!view(original_pool.slots[current.slot].view,held.view)){return .err(errors::make(5,0));}
    var authority::State next_authority=*original_authority;
    var slices::Pool next_pool=*original_pool;
    var owners::Table next_owners=*original_owners;var slices::Ticket parent=none();
    if(held.exclusive){
        let usize depth=size(authority::inspect(ref next_authority))?;
        if(held.depth>=31 || depth!=held.depth+1 || next_authority.kinds[held.depth]!=2 || next_authority.frame!=held.frame ||
            !same(next_authority.children[held.depth].issued,held.issued)){return .err(errors::make(5,0));}
        parent=ticket(authority::leave_child(ref mut next_authority,ref mut next_pool,current,ref next_owners,capacity,held.frame))?;
        if(held.close_parent){let usize closed=size(slices::close(ref mut next_pool,parent,ref mut next_owners,capacity))?;parent=none();}
    }else{let usize closed=size(slices::close(ref mut next_pool,current,ref mut next_owners,capacity))?;}
    if(held.drop){let usize released=size(owners::release(ref mut next_owners,held.view.root,capacity))?;}
    state.runtime.authority=next_authority;state.runtime.pool=next_pool;state.runtime.owners=next_owners;held.active=false;return .ok(Closed{.parent=parent,.remaining=fuel});
}
// Terminal cleanup uses the admission reserve even with zero execution Fuel.
pub fn Result<usize,errors::Error> abort(ref mut State state,usize capacity,usize fuel){
    let ref authority::State original_authority=ref state.runtime.authority;
    let ref slices::Pool original_pool=ref state.runtime.pool;
    let ref owners::Table original_owners=ref state.runtime.owners;
    var authority::State next_authority=*original_authority;
    var slices::Pool next_pool=*original_pool;
    var owners::Table next_owners=*original_owners;
    let usize cleared=size(authority::finish(ref mut next_authority,ref mut next_pool,ref mut next_owners,capacity))?;
    let usize released=size(owners::clear(ref mut next_owners,capacity))?;
    state.runtime.authority=next_authority;state.runtime.pool=next_pool;state.runtime.owners=next_owners;return .ok(fuel);
}

// Shared restoration for owned/scalar and borrowed returns. All arguments are
// unpublished metadata until the outer transaction commits.
fn Result<slices::Arguments,errors::Error> restore(ref mut authority::State stack,ref mut slices::Pool pool,
    ref owners::Table table,ref Call call,usize capacity){
    // Unwind callee lexical children privately; no caller parent becomes usable
    // in the live runtime before the final selected child has been installed.
    while(stack.depth>call.depth+1){
        let usize top=stack.depth-1;
        if(stack.kinds[top]!=2 || stack.frames[top]!=call.frame+1){return .err(errors::make(5,0));}
        let usize slot=stack.children[top].issued.slot;
        if(slot>=16){return .err(errors::make(5,0));}
        let slices::Ticket current=slices::Ticket{.slot=slot,.generation=pool.slots[slot].generation};
        let slices::Ticket restored=ticket(authority::leave_child(stack,pool,current,table,capacity,call.frame+1))?;
    }
    var slices::Ticket[8] writers=[none();8];var usize count=0;var usize i=0;
    while(i<call.contract.arity){
        if(call.contract.tags[i]!=0){
            let slices::Ticket issued=call.issued[i];
            if(issued.slot>=16){return .err(errors::make(5,0));}
            if((call.contract.tags[i]&128)!=0){
                let usize index=call.depth*8+count;
                if(!same(stack.tickets[index],issued)){return .err(errors::make(5,0));}
                let slices::Ticket current=slices::Ticket{.slot=issued.slot,.generation=pool.slots[issued.slot].generation};
                let usize valid=size(slices::length(pool,current,table,capacity))?;
                if(!view(pool.slots[issued.slot].view,call.views[i])){return .err(errors::make(5,0));}
                writers[count]=current;count+=1;
            }else{let usize valid=size(slices::length(pool,issued,table,capacity))?;}
        }i+=1;
    }
    let slices::Arguments restored=loan_arguments(authority::leave_call(stack,pool,ref writers[..count],table,capacity,call.frame+1))?;
    return .ok(restored);
}
fn Result<usize,errors::Error> release_roots(ref mut slices::Pool pool,ref mut owners::Table table,
    ref Call call,ref owners::Token[] roots,usize capacity){
    if(roots.len>16){return .err(errors::make(5,0));}
    var usize i=0;while(i<roots.len){let owners::Token token=roots[i];
        if(token.generation!=0){
            var usize a=0;while(a<call.contract.arity){if(call.contract.tags[a]!=0 && root(token,call.views[a].root)){return .err(errors::make(5,0));}a+=1;}
            var usize prior=0;while(prior<i){if(root(token,roots[prior])){return .err(errors::make(5,0));}prior+=1;}
            var usize slot=16;while(slot>0){slot-=1;if(pool.slots[slot].live && root(pool.slots[slot].view.root,token)){
                let slices::Ticket current=slices::Ticket{.slot=slot,.generation=pool.slots[slot].generation};
                let usize closed=size(slices::close(pool,current,table,capacity))?;
            }}
            let usize released=size(owners::release(table,token,capacity))?;
        }i+=1;
    }return .ok(roots.len);
}
pub fn Result<Resumed,errors::Error> leave_call(ref mut State state,ref mut Call call,usize capacity,usize fuel){
    if(fuel<leave_cost()){return .err(errors::make(8,0));}
    // Borrow through the nested Runtime once. Chained value reads otherwise
    // materialize large Runtime/authority temporaries in the native debug lane.
    let ref authority::State observed=ref state.runtime.authority;
    let usize depth=size(authority::inspect(observed))?;
    if(!call.active || call.contract.selected!=0 || call.contract.arity>8 || call.depth>=31 || call.frame>=31 ||
        depth<=call.depth || observed.frame!=call.frame+1 || observed.kinds[call.depth]!=1 ||
        observed.frames[call.depth]!=call.frame){return .err(errors::make(5,0));}
    var authority::State stack=*observed;
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let slices::Arguments restored=restore(ref mut stack,ref mut pool,ref table,call,capacity)?;
    var slices::Ticket[8] resumed=[none();8];var usize writer=0;var usize i=0;
    while(i<call.contract.arity){
        if(call.contract.tags[i]!=0){if((call.contract.tags[i]&128)!=0){resumed[i]=restored.tickets[writer];writer+=1;}else{resumed[i]=call.captures[i].ticket;}}i+=1;
    }
    i=16;while(i>0){i-=1;let slices::Slot slot=pool.slots[i];
        if(slot.live && !slot.exclusive && !same(call.before[i],slices::Ticket{.slot=i,.generation=slot.generation})){
            let usize closed=size(slices::close(ref mut pool,slices::Ticket{.slot=i,.generation=slot.generation},ref mut table,capacity))?;
        }
    }
    let usize cleaned=finish_captures(ref mut stack,ref mut pool,ref mut table,call,ref mut resumed,capacity)?;
    // Every fallible check precedes these plain field copies. No aggregate
    // Runtime temporary, allocation or callback intervenes during publication.
    state.runtime.authority=stack;state.runtime.pool=pool;state.runtime.owners=table;call.active=false;
    return .ok(Resumed{.tickets=resumed,.remaining=fuel-leave_cost()});
}

// Ordinary returns retain no selected view. Close anonymous captures in reverse
// acquisition order, then release requested roots after callee readers are gone.
// This mutates only the caller's unpublished leave_call plan.
fn Result<usize,errors::Error> finish_captures(ref mut authority::State stack,ref mut slices::Pool pool,
    ref mut owners::Table table,ref Call call,ref mut slices::Ticket[] resumed,usize capacity){
    let usize one=1;var usize closed=0;var usize i=call.contract.arity;
    while(i>0){i-=1;let Capture capture=call.captures[i];
        if((capture.drop && !capture.close) || (call.contract.tags[i]==0 &&
            (capture.close || capture.drop || !same(capture.ticket,none())))){return .err(errors::make(5,0));}
        if(call.contract.tags[i]!=0 && capture.close){
            let slices::Ticket current=resumed[i];
            if(current.slot>=16){return .err(errors::make(5,0));}
            var bool pending=false;var usize at=0;
            if((call.contract.tags[i]&128)!=0){
                while(at<stack.depth){if(stack.kinds[at]==2 && stack.children[at].issued.slot==current.slot){pending=true;}at+=1;}
            }
            if(pending){
                if(capture.drop || stack.depth==0 || stack.kinds[stack.depth-1]!=2 || stack.frames[stack.depth-1]!=call.frame ||
                    stack.children[stack.depth-1].issued.slot!=current.slot){return .err(errors::make(5,0));}
                resumed[i]=ticket(authority::leave_child(stack,pool,current,table,capacity,call.frame))?;
            }else{
                if((closed&(one<<current.slot))==0){let usize ended=size(slices::close(pool,current,table,capacity))?;closed|=one<<current.slot;}
                resumed[i]=none();
            }
        }
    }
    var usize dropped=0;i=call.contract.arity;
    while(i>0){i-=1;if(call.contract.tags[i]!=0 && call.captures[i].drop){
        let owners::Token token=call.views[i].root;
        if((dropped&(one<<token.slot))==0){let usize released=size(owners::release(table,token,capacity))?;dropped|=one<<token.slot;}
    }}return .ok(0);
}
