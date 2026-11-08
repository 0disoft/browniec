module runtime_metadata_work;
import slice_result_runtime as runtime;
import slice_authority as authority;
import slice_handoff as handoff;
import slice_handoff_work as writers;
import slice_reborrow as reborrow;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import metadata_budget as budget;
import errors as errors;

// Invocation-local unpublished transaction. The owning caller pins the exact
// original Runtime and runs no guest operation/callback until publish or abort.
// There are no payload bytes, guest pointers or authenticated Program caches.
pub struct State {
    runtime::Runtime planned; runtime::Call call; writers::State writer;
    slices::Arguments moved; slices::Ticket[8] resumed; slices::Ticket[8] inputs;
    bool[8] restored; owners::Token[16] roots; usize roots_count; bool roots_invalid;
    owners::View selected_view; slices::Ticket selected; slices::Ticket issued;
    usize capacity; usize fuel; usize result_depth; usize index; usize count;
    usize ended; usize closed; usize dropped; usize root_index; usize slot;
    bool root_checked; bool drop; bool exclusive; bool active; bool done;
    u8 mode; u8 phase; runtime::Returned returned;
}
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn owners::View blank(){return owners::View{.root=owners::Token{.slot=16,.generation=0},.element=0,.length=0,.start=0,.end=0};}
fn runtime::Call empty_call(){return runtime::Call{.captures=[runtime::capture(none(),false,false);8],.views=[blank();8],
    .issued=[none();8],.before=[none();16],.contract=runtime::Contract{.tags=[0;8],.arity=0,.selected=0},.depth=0,.frame=0,.remaining=0,.active=false};}
pub fn State empty(){return State{.planned=runtime::Runtime{.authority=authority::empty(),.pool=slices::empty(),.owners=owners::empty(0)},
    .call=empty_call(),.writer=writers::empty(),.moved=slices::empty_arguments(),.resumed=[none();8],.inputs=[none();8],
    .restored=[false;8],.roots=[owners::Token{.slot=0,.generation=0};16],.roots_count=0,.roots_invalid=false,
    .selected_view=blank(),.selected=none(),.issued=none(),.capacity=0,.fuel=0,.result_depth=0,.index=0,.count=0,
    .ended=0,.closed=0,.dropped=0,.root_index=0,.slot=0,.root_checked=false,.drop=false,.exclusive=false,.active=false,.done=false,
    .mode=0,.phase=0,.returned=runtime::Returned{.held=runtime::Held{.issued=none(),.view=blank(),.exclusive=false,
        .close_parent=false,.drop=false,.depth=0,.frame=0,.active=false},.resumed=[none();8],.remaining=0}};}
fn errors::Error invalid(){return errors::make(5,0);}
fn Result<usize,errors::Error> size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(runtime_error(e))}};}
fn errors::Error runtime_error(owners::Error e){return arrays::failure(e,0);}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(runtime_error(e))}};}
fn bool same(slices::Ticket a,slices::Ticket b){return a.slot==b.slot && a.generation==b.generation;}
fn bool root(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
fn bool view(owners::View a,owners::View b){return root(a.root,b.root) && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end;}
fn void snapshot(ref mut State w,ref runtime::State original){
    let ref authority::State a=ref original.runtime.authority;let ref slices::Pool p=ref original.runtime.pool;
    let ref owners::Table o=ref original.runtime.owners;
    w.planned.authority=*a;w.planned.pool=*p;w.planned.owners=*o;
}
// Charge the snapshot stage before calling either start API. Even failed start
// never touches the original runtime or the caller's linear Call receipt.
pub fn Result<usize,errors::Error> start_enter(ref mut State w,ref runtime::State original,runtime::Contract binding,
    ref runtime::Capture[] captures,usize capacity,usize fuel){
    if(fuel<runtime::cost()){return .err(errors::make(8,0));}
    if(binding.arity>8 || captures.len!=binding.arity || binding.selected>binding.arity ||
        (binding.selected!=0 && binding.tags[binding.selected-1]==0)){return .err(invalid());}
    if(w.active){return .err(invalid());}
    w.active=true;w.done=false;w.mode=1;w.phase=0;w.index=0;w.count=0;w.capacity=capacity;w.fuel=fuel;
    snapshot(w,original);w.call=empty_call();w.call.contract=binding;
    var usize i=0;while(i<captures.len){w.call.captures[i]=captures[i];i+=1;}
    return .ok(0);
}
pub fn Result<usize,errors::Error> start_return(ref mut State w,ref runtime::State original,ref runtime::Call call,
    slices::Ticket selected,ref owners::Token[] roots,usize capacity,usize fuel,bool borrowed){
    if(fuel<if(borrowed){runtime::handoff_cost()}else{runtime::leave_cost()}){return .err(errors::make(8,0));}
    if(w.active){return .err(invalid());}
    w.active=true;w.done=false;w.mode=if(borrowed){3}else{2};w.phase=0;w.index=0;w.count=0;
    w.capacity=capacity;w.fuel=fuel;w.call=*call;w.selected=selected;w.issued=selected;
    w.closed=0;w.dropped=0;w.drop=false;w.ended=0;w.root_index=0;w.root_checked=false;
    w.roots_invalid=roots.len>16;w.roots_count=if(roots.len>16){16}else{roots.len};
    let usize roots_count=w.roots_count;var usize i=0;while(i<16){w.roots[i]=if(i<roots_count){roots[i]}else{owners::Token{.slot=0,.generation=0}};i+=1;}
    i=0;while(i<8){w.resumed[i]=none();w.restored[i]=false;i+=1;}
    snapshot(w,original);return .ok(0);
}
fn Result<usize,errors::Error> start_writers(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table,bool entering){
    var writers::State next=writers::empty();let usize count=w.count;
    let slices::Ticket[8] inputs=w.inputs;let usize frame=w.call.frame;let usize depth=w.call.depth;
    if(entering){let usize begun=size(writers::start_enter(ref mut next,pool,ref inputs[..count],depth))?;}
    else{let handoff::Batch batch=switch(authority::prepare_leave_call(stack,frame+1)){
        case .ok(v):{v}case .err(e):{return .err(runtime_error(e));}
    };let usize begun=size(writers::start_restore(ref mut next,pool,ref batch,ref inputs[..count]))?;}
    w.writer=next;return .ok(0);
}
fn Result<bool,errors::Error> step_writers(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    var writers::State next=w.writer;
    let bool done=switch(writers::advance(ref mut next,pool,table,w.capacity,1)){
        case .ok(v):{v}case .err(e):{return .err(runtime_error(e));}
    };
    w.writer=next;
    if(done){
        pool.slots=next.planned.slots;
        if(w.mode==1){let authority::Entry entry=authority::Entry{.call=next.batch,.child=reborrow::empty(),.kind=1,.frame=w.call.frame};
            w.moved=authority::publish_call(stack,entry);
        }else{w.moved=next.returned;authority::publish_leave_call(stack);}
    }return .ok(done);
}
fn Result<usize,errors::Error> enter_stage(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    let usize arity=w.call.contract.arity;
    if(w.phase==0){
        let usize depth=size(authority::inspect(stack))?;w.call.depth=depth;w.call.frame=stack.frame;
        let owners::View empty=pool.slots[0].view;
        var usize i=0;while(i<8){w.call.views[i]=empty;w.call.issued[i]=none();i+=1;}
        i=0;while(i<16){w.call.before[i]=if(pool.slots[i].live){slices::Ticket{.slot=i,.generation=pool.slots[i].generation}}else{none()};i+=1;}
        w.phase=1;w.index=0;return .ok(0);
    }
    if(w.phase==1){
        if(w.index<arity){let usize i=w.index;let runtime::Capture c=w.call.captures[i];let u8 tag=w.call.contract.tags[i];
            if(c.ends>16 || c.close!=(c.ends!=0) || (c.ends>1 && (c.drop || w.call.contract.selected==0))){return .err(invalid());}
            if(tag==0){if(!same(c.ticket,none()) || c.close || c.drop){return .err(invalid());}}
            else{let usize n=size(slices::length(pool,c.ticket,table,w.capacity))?;
                let slices::Slot entry=pool.slots[c.ticket.slot];let u8 actual=entry.view.element | if(entry.exclusive){128}else{0};
                if(actual!=tag || (c.drop && !c.close) || (c.ends>1 && !entry.exclusive)){return .err(invalid());}
                var usize prior=0;while(prior<i){if(same(c.ticket,w.call.captures[prior].ticket) && c.close!=w.call.captures[prior].close){return .err(invalid());}prior+=1;}
                w.call.views[i]=entry.view;if(entry.exclusive){let usize count=w.count;w.inputs[count]=c.ticket;w.count+=1;}
            }w.index+=1;return .ok(0);
        }
        let usize begun=start_writers(w,stack,pool,table,true)?;w.phase=2;return .ok(0);
    }
    if(w.phase==2){if(step_writers(w,stack,pool,table)?){w.phase=3;w.index=0;w.count=0;}return .ok(0);}
    if(w.phase==3){
        if(w.index<arity){let usize i=w.index;let u8 tag=w.call.contract.tags[i];
            if(tag!=0){if((tag&128)!=0){let slices::Ticket moved=w.moved.tickets[w.count];w.call.issued[i]=moved;w.count+=1;}
                else{let slices::Ticket parent=w.call.captures[i].ticket;let usize length=w.call.views[i].end-w.call.views[i].start;
                    let slices::Ticket issued=ticket(slices::subslice(pool,parent,table,0,length,w.capacity))?;w.call.issued[i]=issued;}
            }w.index+=1;return .ok(0);
        }
        w.call.remaining=w.fuel-runtime::cost();w.call.active=true;w.done=true;w.active=false;return .ok(0);
    }
    return .err(invalid());
}
fn Result<usize,errors::Error> return_header(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    let usize depth=size(authority::inspect(stack))?;
    let runtime::Call call=w.call;let usize arity=call.contract.arity;
    if(!call.active || arity>8 || call.depth>=31 || call.frame>=31 || depth<=call.depth ||
        stack.frame!=call.frame+1 || stack.kinds[call.depth]!=1 ||
        stack.frames[call.depth]!=call.frame){return .err(invalid());}
    if(w.mode==2){if(call.contract.selected!=0){return .err(invalid());}}
    else{
        if(call.contract.selected==0 || call.contract.selected>arity){return .err(invalid());}
        let usize n=size(slices::length(pool,w.selected,table,w.capacity))?;
        let slices::Slot entry=pool.slots[w.selected.slot];let owners::View expected=call.views[call.contract.selected-1];
        if(!root(entry.view.root,expected.root) || entry.view.element!=expected.element || entry.view.length!=expected.length ||
            entry.view.start<expected.start || entry.view.end>expected.end || entry.exclusive!=((call.contract.tags[call.contract.selected-1]&128)!=0) ||
            (!entry.exclusive && same(call.before[w.selected.slot],w.selected))){return .err(invalid());}
        if(entry.exclusive && w.selected.slot!=call.issued[call.contract.selected-1].slot){return .err(invalid());}
        w.selected_view=entry.view;w.exclusive=entry.exclusive;
    }
    w.phase=1;return .ok(0);
}
fn Result<usize,errors::Error> restore_child(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    let usize depth=stack.depth;
    if(depth<=w.call.depth+1){w.phase=2;w.index=0;w.count=0;return .ok(0);}
    let usize top=depth-1;
    if(stack.kinds[top]!=2 || stack.frames[top]!=w.call.frame+1){return .err(invalid());}
    let usize slot=stack.children[top].issued.slot;if(slot>=16){return .err(invalid());}
    let slices::Ticket current=slices::Ticket{.slot=slot,.generation=pool.slots[slot].generation};let usize frame=w.call.frame+1;
    let slices::Ticket restored=ticket(authority::leave_child(stack,pool,current,table,w.capacity,frame))?;
    return .ok(0);
}
fn Result<usize,errors::Error> restore_argument(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    if(w.index==w.call.contract.arity){let usize begun=start_writers(w,stack,pool,table,false)?;w.phase=3;return .ok(0);}
    let usize i=w.index;let u8 tag=w.call.contract.tags[i];
    if(tag!=0){let slices::Ticket issued=w.call.issued[i];if(issued.slot>=16){return .err(invalid());}
        if((tag&128)!=0){
            if(!same(stack.tickets[w.call.depth*8+w.count],issued)){return .err(invalid());}
            let slices::Ticket current=slices::Ticket{.slot=issued.slot,.generation=pool.slots[issued.slot].generation};
            let usize n=size(slices::length(pool,current,table,w.capacity))?;
            if(!view(pool.slots[issued.slot].view,w.call.views[i])){return .err(invalid());}
            let usize count=w.count;w.inputs[count]=current;w.count+=1;
        }else{let usize n=size(slices::length(pool,issued,table,w.capacity))?;}
    }w.index+=1;return .ok(0);
}
fn Result<usize,errors::Error> readers(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table,bool borrowed){
    if(w.index==0){w.phase=if(borrowed){9}else{6};w.index=w.call.contract.arity;return .ok(0);}
    w.index-=1;let usize i=w.index;let slices::Slot entry=pool.slots[i];
    if(entry.live && !entry.exclusive && (!borrowed || i!=w.issued.slot) &&
        !same(w.call.before[i],slices::Ticket{.slot=i,.generation=entry.generation})){
        let slices::Ticket current=slices::Ticket{.slot=i,.generation=entry.generation};
        let usize closed=size(slices::close(pool,current,table,w.capacity))?;
    }return .ok(0);
}
fn Result<usize,errors::Error> captures(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    if(w.index==0){w.phase=if(w.mode==3){7}else{9};w.index=w.call.contract.arity;return .ok(0);}
    let usize i=w.index-1;let runtime::Capture c=w.call.captures[i];let u8 tag=w.call.contract.tags[i];
    if(w.mode==2 && ((c.drop && !c.close) || (tag==0 && (c.close || c.drop || !same(c.ticket,none()))))){return .err(invalid());}
    if(w.mode==3 && c.drop && tag!=0 && root(w.call.views[i].root,w.selected_view.root)){w.drop=true;}
    if(tag!=0 && c.close){
        let slices::Ticket current=w.resumed[i];if(current.slot>=16){return .err(invalid());}
        var bool pending=false;var usize at=0;
        if((tag&128)!=0){while(at<stack.depth){
            if(stack.kinds[at]==2 && stack.children[at].issued.slot==current.slot){pending=true;}at+=1;
        }}
        if(pending){let usize depth=stack.depth;
            if(c.drop || depth==0 || stack.kinds[depth-1]!=2 || stack.frames[depth-1]!=w.call.frame ||
                stack.children[depth-1].issued.slot!=current.slot){return .err(invalid());}
            let usize frame=w.call.frame;
            let slices::Ticket resumed=ticket(authority::leave_child(stack,pool,current,
                table,w.capacity,frame))?;w.resumed[i]=resumed;
            if(w.mode==3){w.ended+=1;if(w.ended<c.ends){return .ok(0);}w.restored[i]=true;}
        }else{
            if(w.mode==3 && (tag&128)!=0 && c.ends>1){return .err(invalid());}
            if(!(w.mode==3 && (tag&128)!=0 && w.exclusive && i==w.call.contract.selected-1)){
                let usize one=1;
                if((w.closed&(one<<current.slot))==0){let usize closed=size(slices::close(pool,current,table,w.capacity))?;w.closed|=one<<current.slot;}
                w.resumed[i]=none();
            }
        }
    }
    w.ended=0;w.index-=1;return .ok(0);
}
fn Result<usize,errors::Error> install(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    let usize chosen=w.call.contract.selected-1;w.result_depth=stack.depth;
    if(w.exclusive){let slices::Ticket current=w.resumed[chosen];if(current.slot>=16){return .err(invalid());}
        let owners::View parent=pool.slots[current.slot].view;
        if(!root(parent.root,w.selected_view.root) || w.selected_view.start<parent.start || w.selected_view.end>parent.end){return .err(invalid());}
        let usize start=w.selected_view.start-parent.start;let usize end=w.selected_view.end-parent.start;let usize frame=w.call.frame;
        let slices::Ticket issued=ticket(authority::enter_child(stack,pool,current,table,start,end,w.capacity,frame))?;
        w.issued=issued;w.resumed[chosen]=none();
    }else{
        if(w.selected.generation==18446744073709551615){return .err(invalid());}
        w.issued=slices::Ticket{.slot=w.selected.slot,.generation=w.selected.generation+1};
        pool.slots[w.selected.slot].generation=w.issued.generation;
    }
    w.phase=8;w.index=16;return .ok(0);
}
fn Result<usize,errors::Error> drop_capture(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    if(w.index==0){w.phase=if(w.mode==3){10}else{11};return .ok(0);}
    w.index-=1;let usize i=w.index;
    if(w.call.captures[i].drop && w.call.contract.tags[i]!=0 && (w.mode==2 || !root(w.call.views[i].root,w.selected_view.root))){
        let owners::Token token=w.call.views[i].root;let usize one=1;
        if(token.slot>=16){return .err(invalid());}
        if((w.dropped&(one<<token.slot))==0){let usize released=size(owners::release(table,token,w.capacity))?;w.dropped|=one<<token.slot;}
    }return .ok(0);
}
fn Result<usize,errors::Error> drop_root(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    if(w.roots_invalid){return .err(invalid());}
    if(w.root_index==w.roots_count){w.phase=11;return .ok(0);}
    let owners::Token token=w.roots[w.root_index];
    if(token.generation==0){w.root_index+=1;return .ok(0);}
    if(!w.root_checked){
        var usize a=0;while(a<w.call.contract.arity){if(w.call.contract.tags[a]!=0 && root(token,w.call.views[a].root)){return .err(invalid());}a+=1;}
        var usize prior=0;while(prior<w.root_index){if(root(token,w.roots[prior])){return .err(invalid());}prior+=1;}
        w.root_checked=true;w.slot=16;return .ok(0);
    }
    if(w.slot!=0){w.slot-=1;let usize slot=w.slot;
        if(pool.slots[slot].live && root(pool.slots[slot].view.root,token)){
            let slices::Ticket current=slices::Ticket{.slot=slot,.generation=pool.slots[slot].generation};
            let usize closed=size(slices::close(pool,current,table,w.capacity))?;
        }return .ok(0);
    }
    let usize released=size(owners::release(table,token,w.capacity))?;
    w.root_index+=1;w.root_checked=false;return .ok(0);
}
fn Result<usize,errors::Error> return_stage(ref mut State w,ref mut authority::State stack,ref mut slices::Pool pool,ref mut owners::Table table){
    if(w.phase==0){return return_header(w,stack,pool,table);}
    if(w.phase==1){return restore_child(w,stack,pool,table);}
    if(w.phase==2){return restore_argument(w,stack,pool,table);}
    if(w.phase==3){
        if(step_writers(w,stack,pool,table)?){var usize i=0;var usize writer=0;
            while(i<w.call.contract.arity){if(w.call.contract.tags[i]!=0){
                if((w.call.contract.tags[i]&128)!=0){let slices::Ticket moved=w.moved.tickets[writer];w.resumed[i]=moved;writer+=1;}
                else{let slices::Ticket saved=w.call.captures[i].ticket;w.resumed[i]=saved;}
            }i+=1;}
            w.phase=if(w.mode==3){6}else{5};w.index=if(w.mode==3){w.call.contract.arity}else{16};
        }return .ok(0);
    }
    if(w.phase==5){return readers(w,stack,pool,table,false);}
    if(w.phase==6){return captures(w,stack,pool,table);}
    if(w.phase==7){return install(w,stack,pool,table);}
    if(w.phase==8){return readers(w,stack,pool,table,true);}
    if(w.phase==9){return drop_capture(w,stack,pool,table);}
    if(w.phase==10){return drop_root(w,stack,pool,table);}
    if(w.phase==11){
        let usize price=if(w.mode==3){runtime::handoff_cost()}else{runtime::leave_cost()};
        let slices::Ticket[8] resumed=w.resumed;let usize remaining=w.fuel-price;w.returned.resumed=resumed;w.returned.remaining=remaining;
        if(w.mode==2){w.returned.held.active=false;}
        if(w.mode==3){let usize chosen=w.call.contract.selected-1;
            w.returned.held=runtime::Held{.issued=w.issued,.view=w.selected_view,.exclusive=w.exclusive,
                .close_parent=w.call.captures[chosen].close && !w.restored[chosen],.drop=w.drop,.depth=w.result_depth,.frame=w.call.frame,.active=true};
        }
        w.done=true;w.active=false;return .ok(0);
    }return .err(invalid());
}
// One stage performs at most one canonical pool mutation/check, except a
// bounded writer substep. The bound includes all copied authority banks, not
// only the visible outer loop. No credits are carried to the next dispatch.
pub fn usize next_bound(ref State w){return 4096;}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref mut budget::State allowance){
    if(!w.active || w.done || w.mode<1 || w.mode>3){return .err(invalid());}
    while(!w.done){
        let usize bound=next_bound(w);if(!budget::admit(allowance,bound,0)?){return .ok(false);}
        let ref authority::State original_stack=ref w.planned.authority;
        let ref slices::Pool original_pool=ref w.planned.pool;
        let ref owners::Table original_table=ref w.planned.owners;
        var authority::State stack=*original_stack;var slices::Pool pool=*original_pool;var owners::Table table=*original_table;
        let Result<usize,errors::Error> progressed=if(w.mode==1){enter_stage(w,ref mut stack,ref mut pool,ref mut table)}
            else{return_stage(w,ref mut stack,ref mut pool,ref mut table)};
        switch(progressed){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
        w.planned.authority=stack;w.planned.pool=pool;w.planned.owners=table;
    }return .ok(true);
}
// All failure/cancellation paths discard the unpublished Work. The parent must
// reserve a final publication stage before calling this infallible private API.
pub fn void publish(ref State w,ref mut runtime::State live){
    if(w.mode!=1){live.runtime.owners=w.planned.owners;}
    live.runtime.pool=w.planned.pool;live.runtime.authority=w.planned.authority;
}
