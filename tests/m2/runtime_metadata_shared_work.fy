module tests::m2::runtime_metadata_shared_work;
import runtime_metadata_work as work;
import metadata_budget as budget;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import errors as errors;

fn Result<usize,errors::Error> size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_metadata(ref runtime::Runtime a,ref runtime::Runtime b){
    let ref slices::Pool ap=ref a.pool;let ref slices::Pool bp=ref b.pool;
    let ref owners::Table ao=ref a.owners;let ref owners::Table bo=ref b.owners;
    assert(ao.depth==bo.depth && ao.arena.used==bo.arena.used && ao.arena.limit==bo.arena.limit);
    var usize i=0;while(i<16){let slices::Slot x=ap.slots[i];let slices::Slot y=bp.slots[i];same_view(x.view,y.view);
        assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);
        let owners::Owner u=ao.slots[i];let owners::Owner v=bo.slots[i];
        assert(ao.order[i]==bo.order[i] && u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.mark==v.mark && u.base==v.base && u.end==v.end && u.element==v.element && u.length==v.length && u.record==v.record && u.alignment==v.alignment);i+=1;
    }
    let ref authority::State aa=ref a.authority;let ref authority::State ba=ref b.authority;
    assert(aa.depth==ba.depth && aa.frame==ba.frame);i=0;
    while(i<31){assert(aa.counts[i]==ba.counts[i] && aa.reserves[i]==ba.reserves[i] && aa.kinds[i]==ba.kinds[i] && aa.frames[i]==ba.frames[i]);
        let x=aa.children[i];let y=ba.children[i];same_view(x.parent.view,y.parent.view);same_view(x.selected,y.selected);same_ticket(x.issued,y.issued);
        assert(x.parent.generation==y.parent.generation && x.depth==y.depth && x.active==y.active);i+=1;
    }
    i=0;while(i<248){same_ticket(aa.tickets[i],ba.tickets[i]);same_view(aa.leases[i].view,ba.leases[i].view);assert(aa.leases[i].generation==ba.leases[i].generation);i+=1;}
}
fn void copy_metadata(ref runtime::Runtime from,ref mut runtime::Runtime to){
    let ref authority::State stack=ref from.authority;let ref slices::Pool pool=ref from.pool;let ref owners::Table table=ref from.owners;
    to.authority=*stack;to.pool=*pool;to.owners=*table;
}
fn void same_returned(ref runtime::Returned a,ref runtime::Returned b){
    let runtime::Held x=a.held;let runtime::Held y=b.held;same_ticket(x.issued,y.issued);same_view(x.view,y.view);
    assert(x.exclusive==y.exclusive && x.close_parent==y.close_parent && x.drop==y.drop && x.depth==y.depth && x.frame==y.frame && x.active==y.active && a.remaining==b.remaining);
    var usize i=0;while(i<8){same_ticket(a.resumed[i],b.resumed[i]);i+=1;}
}
fn Result<owners::Token,errors::Error> create(ref mut runtime::State state,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    return switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};
}
fn Result<slices::Ticket,errors::Error> open(ref mut runtime::State state,owners::Token root){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let slices::Ticket result=ticket(slices::open(ref mut pool,ref mut table,root,0,4,64))?;
    state.runtime.pool=pool;state.runtime.owners=table;return .ok(result);
}
fn Result<slices::Ticket,errors::Error> sub(ref mut runtime::State state,slices::Ticket parent){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table table=ref state.runtime.owners;
    let slices::Ticket result=ticket(slices::subslice(ref mut pool,parent,table,1,3,64))?;
    state.runtime.pool=pool;return .ok(result);
}
fn Result<usize,errors::Error> close_ticket(ref mut runtime::State state,slices::Ticket current){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let usize result=size(slices::close(ref mut pool,current,ref mut table,64))?;
    state.runtime.pool=pool;state.runtime.owners=table;return .ok(result);
}
// Keep this one snapshot in its own frame, separate from the oracle and Work.
// Initial shared room is deliberately insufficient for the first 4096 stage.
fn Result<usize,errors::Error> drive(ref mut work::State w,ref runtime::State live){
    var runtime::State before=runtime::empty(64);copy_metadata(ref live.runtime,ref mut before.runtime);
    var budget::State allowance=budget::empty();let bool admitted=budget::admit(ref mut allowance,512,0)?;assert(admitted);
    let u8 phase=w.phase;let usize index=w.index;let bool active=w.active;let bool done=w.done;
    let bool deferred=work::advance(w,ref mut allowance)?;assert(!deferred);
    assert(w.phase==phase && w.index==index && w.active==active && w.done==done);
    assert(allowance.last==512 && allowance.total==512 && allowance.stages==1);
    same_metadata(ref live.runtime,ref before.runtime);same_metadata(ref w.planned,ref before.runtime);
    var usize dispatches=0;while(dispatches<256){
        let usize reset=budget::reset(ref mut allowance,0)?;assert(reset==4096 && allowance.last==0);
        let Result<bool,errors::Error> result=work::advance(w,ref mut allowance);dispatches+=1;
        assert(allowance.last==4096 && allowance.last<=budget::limit() && allowance.total==512+dispatches*4096 && allowance.stages==1+dispatches);
        same_metadata(ref live.runtime,ref before.runtime);
        let bool finished=switch(result){case .ok(v):{v}case .err(e):{assert(!w.active && !w.done);return .err(e);}};
        if(finished){assert(w.done && !w.active && dispatches>1);return .ok(dispatches);}
        assert(w.active && !w.done);
    }
    assert(false);return .err(errors::make(5,0));
}
fn Result<usize,errors::Error> handoff_oracle(ref runtime::State live,ref runtime::Call call,slices::Ticket selected,ref work::State w){
    var runtime::State expected=runtime::empty(64);copy_metadata(ref live.runtime,ref mut expected.runtime);var runtime::Call receipt=*call;
    let owners::Token[1] roots=[owners::Token{.slot=0,.generation=0}];
    let runtime::Returned result=runtime::handoff_roots(ref mut expected,ref mut receipt,selected,ref roots[..0],64,runtime::handoff_cost()+23)?;
    assert(!receipt.active && call.active);same_returned(ref result,ref w.returned);same_metadata(ref expected.runtime,ref w.planned);return .ok(0);
}
fn Result<usize,errors::Error> shared_return(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);let owners::Token root=create(ref mut live,ref mut data)?;
    let usize written=size(owners::write(ref mut live.runtime.owners,root,1,42,ref mut data))?;let slices::Ticket parent=open(ref mut live,root)?;
    let runtime::Capture[2] args=[runtime::capture(parent,true,true),runtime::capture(parent,true,true)];
    let runtime::Contract binding=runtime::Contract{.tags=[10,10,0,0,0,0,0,0],.arity=2,.selected=1};
    var runtime::Call call=runtime::enter_call(ref mut live,binding,ref args,64,runtime::cost()+7)?;
    assert(call.issued[0].slot!=call.issued[1].slot);let slices::Ticket selected=sub(ref mut live,call.issued[0])?;
    let owners::Token[1] roots=[owners::Token{.slot=0,.generation=0}];var work::State w=work::empty();
    let usize started=work::start_return(ref mut w,ref live,ref call,selected,ref roots[..0],64,runtime::handoff_cost()+23,true)?;
    let usize dispatches=drive(ref mut w,ref live)?;assert(call.active && call.remaining==7);
    let usize compared=handoff_oracle(ref live,ref call,selected,ref w)?;
    work::publish(ref w,ref mut live);call.active=false;same_metadata(ref live.runtime,ref w.planned);
    var runtime::Returned result=w.returned;
    assert(result.remaining==23 && result.held.active && !result.held.exclusive && result.held.close_parent && result.held.drop);
    assert(result.held.view.start==1 && result.held.view.end==3 && result.held.issued.slot==selected.slot && result.held.issued.generation==selected.generation+1);
    var usize i=0;var usize handles=0;while(i<16){if(live.runtime.pool.slots[i].live){handles+=1;}i+=1;}assert(handles==1);
    i=0;while(i<8){assert(result.resumed[i].slot==16 && result.resumed[i].generation==0);i+=1;}
    assert(!slices::length(ref live.runtime.pool,parent,ref live.runtime.owners,64).is_ok && !slices::length(ref live.runtime.pool,selected,ref live.runtime.owners,64).is_ok);
    switch(slices::read(ref live.runtime.pool,result.held.issued,ref live.runtime.owners,0,ref data)){case .ok(v):{assert(v==42);}case .err(e):{return .err(arrays::failure(e,0));}};
    assert(!owners::release(ref mut live.runtime.owners,root,64).is_ok);
    let slices::Ticket issued=result.held.issued;let runtime::Closed closed=runtime::close(ref mut live,ref mut result.held,issued,64,0)?;
    assert(!result.held.active && closed.parent.slot==16 && closed.remaining==0 && live.runtime.owners.depth==0 && live.runtime.owners.arena.used==0);
    assert(!owners::view(ref live.runtime.owners,root,0,0,64).is_ok);i=0;while(i<16){assert(!live.runtime.pool.slots[i].live);i+=1;}return .ok(dispatches);
}

@test
fn void aliased_readonly_close_drop_keeps_only_selected_subrange_until_held_close(){assert(shared_return().is_ok);}

fn errors::Error full_oracle(ref runtime::State live,runtime::Contract binding,ref runtime::Capture[] args){
    let ref authority::State original_stack=ref live.runtime.authority;var authority::State stack=*original_stack;
    let ref slices::Pool original_pool=ref live.runtime.pool;var slices::Pool pool=*original_pool;
    return switch(runtime::prepare_entry(live,binding,args,64,runtime::cost()+7,ref mut stack,ref mut pool)){
        case .ok(_):{assert(false);errors::make(5,0)}
        case .err(e):{assert(stack.depth==1 && stack.frame==1);e}
    };
}
fn Result<usize,errors::Error> full_pool(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);
    var owners::Token[16] roots=[owners::Token{.slot=0,.generation=0};16];var slices::Ticket[16] inputs=[slices::Ticket{.slot=16,.generation=0};16];
    var usize i=0;while(i<16){roots[i]=create(ref mut live,ref mut data)?;inputs[i]=open(ref mut live,roots[i])?;i+=1;}
    assert(live.runtime.owners.depth==16 && live.runtime.owners.arena.used==64);
    let runtime::Contract binding=runtime::Contract{.tags=[10,0,0,0,0,0,0,0],.arity=1,.selected=1};
    let runtime::Capture[1] args=[runtime::capture(inputs[0],false,false)];let errors::Error expected=full_oracle(ref live,binding,ref args);
    var work::State w=work::empty();let usize started=work::start_enter(ref mut w,ref live,binding,ref args,64,runtime::cost()+7)?;
    switch(drive(ref mut w,ref live)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==expected.kind && e.offset==expected.offset);}};
    assert(!w.active && !w.done && w.phase==3 && w.index==0 && w.planned.authority.depth==1 && w.planned.authority.frame==1);
    assert(live.runtime.authority.depth==0 && live.runtime.authority.frame==0);
    i=0;while(i<16){let usize length=size(slices::length(ref live.runtime.pool,inputs[i],ref live.runtime.owners,64))?;assert(length==4);
        assert(!owners::release(ref mut live.runtime.owners,roots[i],64).is_ok);i+=1;
    }
    i=16;while(i>0){i-=1;let usize closed=close_ticket(ref mut live,inputs[i])?;let usize released=size(owners::release(ref mut live.runtime.owners,roots[i],64))?;}
    assert(live.runtime.owners.depth==0 && live.runtime.owners.arena.used==0);return .ok(0);
}

@test
fn void sixteen_owners_and_full_readonly_pool_reject_entry_after_private_call_frame(){assert(full_pool().is_ok);}
