module tests::m2::runtime_metadata_work;
import runtime_metadata_work as work;
import metadata_budget as budget;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import errors as errors;

fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn Result<usize,errors::Error> size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){
    var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];
        assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);
        same_view(x.view,y.view);i+=1;
    }
}
fn void same_owners(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}
fn void same_authority(ref authority::State a,ref authority::State b){
    assert(a.depth==b.depth && a.frame==b.frame);
    var usize i=0;while(i<31){
        assert(a.counts[i]==b.counts[i] && a.reserves[i]==b.reserves[i] && a.kinds[i]==b.kinds[i] && a.frames[i]==b.frames[i]);
        let x=a.children[i];let y=b.children[i];same_view(x.parent.view,y.parent.view);same_view(x.selected,y.selected);same_ticket(x.issued,y.issued);
        assert(x.parent.generation==y.parent.generation && x.depth==y.depth && x.active==y.active);i+=1;
    }
    i=0;while(i<248){same_ticket(a.tickets[i],b.tickets[i]);same_view(a.leases[i].view,b.leases[i].view);assert(a.leases[i].generation==b.leases[i].generation);i+=1;}
}
fn void same_metadata(ref runtime::Runtime a,ref runtime::Runtime b){
    same_authority(ref a.authority,ref b.authority);same_pool(ref a.pool,ref b.pool);same_owners(ref a.owners,ref b.owners);
}
fn void copy_metadata(ref runtime::Runtime from,ref mut runtime::Runtime to){
    let ref authority::State stack=ref from.authority;let ref slices::Pool pool=ref from.pool;let ref owners::Table table=ref from.owners;
    to.authority=*stack;to.pool=*pool;to.owners=*table;
}
fn void same_call(ref runtime::Call a,ref runtime::Call b){
    assert(a.contract.arity==b.contract.arity && a.contract.selected==b.contract.selected && a.depth==b.depth && a.frame==b.frame && a.remaining==b.remaining && a.active==b.active);
    var usize i=0;while(i<8){let runtime::Capture x=a.captures[i];let runtime::Capture y=b.captures[i];same_ticket(x.ticket,y.ticket);
        assert(x.close==y.close && x.drop==y.drop && x.ends==y.ends && a.contract.tags[i]==b.contract.tags[i]);same_view(a.views[i],b.views[i]);same_ticket(a.issued[i],b.issued[i]);i+=1;
    }
    i=0;while(i<16){same_ticket(a.before[i],b.before[i]);i+=1;}
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
fn Result<slices::Ticket,errors::Error> open(ref mut runtime::State state,owners::Token root,bool exclusive){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let slices::Ticket result=ticket(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,64)}
        else{slices::open(ref mut pool,ref mut table,root,0,4,64)})?;
    state.runtime.pool=pool;state.runtime.owners=table;return .ok(result);
}
fn Result<slices::Ticket,errors::Error> child(ref mut runtime::State state,slices::Ticket parent,usize lo,usize hi){
    let ref authority::State original_stack=ref state.runtime.authority;var authority::State stack=*original_stack;
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let usize frame=stack.frame;let ref owners::Table table=ref state.runtime.owners;
    let slices::Ticket result=ticket(authority::enter_child(ref mut stack,ref mut pool,parent,table,lo,hi,64,frame))?;
    state.runtime.authority=stack;state.runtime.pool=pool;return .ok(result);
}
fn Result<usize,errors::Error> close_ticket(ref mut runtime::State state,slices::Ticket current){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let usize result=size(slices::close(ref mut pool,current,ref mut table,64))?;
    state.runtime.pool=pool;state.runtime.owners=table;return .ok(result);
}
fn Result<slices::Ticket,errors::Error> sub(ref mut runtime::State state,slices::Ticket parent,usize lo,usize hi){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table table=ref state.runtime.owners;
    let slices::Ticket result=ticket(slices::subslice(ref mut pool,parent,table,lo,hi,64))?;
    state.runtime.pool=pool;return .ok(result);
}
fn runtime::Contract eight(){return runtime::Contract{.tags=[138;8],.arity=8,.selected=0};}
fn runtime::Contract borrowed(){return runtime::Contract{.tags=[138,0,0,0,0,0,0,0],.arity=1,.selected=1};}
fn Result<usize,errors::Error> writers(ref mut runtime::State live,ref mut u8[] data,ref mut runtime::Capture[] args){
    var usize i=0;while(i<8){let owners::Token root=create(live,data)?;let slices::Ticket parent=open(live,root,true)?;args[i]=runtime::capture(parent,false,false);i+=1;}return .ok(8);
}

// The snapshot lives in this helper frame, not alongside another Work or an
// oracle Runtime in a test frame. Compare every metadata field at every yield,
// at completion, and on errors. A nonzero phase requests cancellation there.
fn Result<usize,errors::Error> drive(ref mut work::State w,ref runtime::State live,u8 stop_phase){
    var runtime::State before=runtime::empty(64);copy_metadata(ref live.runtime,ref mut before.runtime);
    var budget::State allowance=budget::empty();var usize dispatches=0;
    while(dispatches<1024){
        let usize reset=budget::reset(ref mut allowance,0)?;
        assert(reset==4096 && allowance.last==0);
        let Result<bool,errors::Error> progressed=work::advance(w,ref mut allowance);
        assert(allowance.last<=4096);same_metadata(ref live.runtime,ref before.runtime);dispatches+=1;
        let bool done=switch(progressed){case .ok(v):{v}case .err(e):{assert(!w.active && !w.done);return .err(e);}};
        assert(allowance.stages==dispatches && allowance.last==4096);
        if(done){assert(w.done && !w.active && dispatches>1);return .ok(dispatches);}
        assert(w.active && !w.done);
        if(stop_phase!=0 && w.phase==stop_phase){return .ok(dispatches);}
    }
    assert(false);return .err(errors::make(5,0));
}
// Independent synchronous oracle; no second Work is allocated.
fn Result<usize,errors::Error> entry_oracle(ref runtime::State live,runtime::Contract binding,ref runtime::Capture[] args,ref work::State w){
    let ref authority::State original=ref live.runtime.authority;var authority::State stack=*original;
    let ref slices::Pool original_pool=ref live.runtime.pool;var slices::Pool pool=*original_pool;
    let runtime::Call expected=runtime::prepare_entry(live,binding,args,64,runtime::cost()+17,ref mut stack,ref mut pool)?;
    same_call(ref expected,ref w.call);same_authority(ref stack,ref w.planned.authority);same_pool(ref pool,ref w.planned.pool);same_owners(ref live.runtime.owners,ref w.planned.owners);return .ok(0);
}
fn Result<usize,errors::Error> return_oracle(ref runtime::State live,ref runtime::Call call,slices::Ticket selected,ref owners::Token[] roots,bool is_borrowed,ref work::State w){
    var runtime::State expected=runtime::empty(64);copy_metadata(ref live.runtime,ref mut expected.runtime);var runtime::Call receipt=*call;
    if(is_borrowed){let runtime::Returned result=runtime::handoff_roots(ref mut expected,ref mut receipt,selected,roots,64,runtime::handoff_cost()+19)?;same_returned(ref result,ref w.returned);}
    else{let runtime::Resumed result=runtime::leave_call(ref mut expected,ref mut receipt,64,runtime::leave_cost()+19)?;
        assert(result.remaining==w.returned.remaining && !w.returned.held.active);var usize i=0;while(i<8){same_ticket(result.tickets[i],w.returned.resumed[i]);i+=1;}
    }
    assert(!receipt.active && call.active);same_metadata(ref expected.runtime,ref w.planned);return .ok(0);
}

@test
fn void eight_exclusive_writers_enter_and_ordinary_return_match_synchronous_metadata(){
    assert(eight_checked().is_ok);
}
fn Result<usize,errors::Error> eight_checked(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);var runtime::Capture[8] args=[runtime::capture(none(),false,false);8];
    let i64[8] values=[1,2,3,4,5,6,7,8];
    let usize setup=writers(ref mut live,ref mut data,ref mut args)?;var work::State w=work::empty();
    let usize started=work::start_enter(ref mut w,ref live,eight(),ref args,64,runtime::cost()+17)?;
    let usize entered=drive(ref mut w,ref live,0)?;let usize checked=entry_oracle(ref live,eight(),ref args,ref w)?;
    work::publish(ref w,ref mut live);var runtime::Call call=w.call;assert(call.remaining==17);
    same_metadata(ref live.runtime,ref w.planned);
    var usize i=0;while(i<8){assert(call.issued[i].generation==args[i].ticket.generation+1);
        assert(!slices::length(ref live.runtime.pool,args[i].ticket,ref live.runtime.owners,64).is_ok);
        let usize written=size(slices::write(ref live.runtime.pool,call.issued[i],ref live.runtime.owners,0,values[i],ref mut data))?;i+=1;
    }
    let owners::Token[1] roots=[owners::Token{.slot=0,.generation=0}];let runtime::Call receipt=call;
    let usize returning=work::start_return(ref mut w,ref live,ref call,none(),ref roots[..0],64,runtime::leave_cost()+19,false)?;
    let usize left=drive(ref mut w,ref live,0)?;same_call(ref call,ref receipt);
    let usize verified=return_oracle(ref live,ref call,none(),ref roots[..0],false,ref w)?;
    work::publish(ref w,ref mut live);call.active=false;same_metadata(ref live.runtime,ref w.planned);
    assert(w.returned.remaining==19 && live.runtime.authority.depth==0 && live.runtime.authority.frame==0);
    i=0;while(i<8){let slices::Ticket resumed=w.returned.resumed[i];assert(resumed.generation==args[i].ticket.generation+2);
        assert(!slices::length(ref live.runtime.pool,receipt.issued[i],ref live.runtime.owners,64).is_ok);
        switch(slices::read(ref live.runtime.pool,resumed,ref live.runtime.owners,0,ref data)){case .ok(v):{assert(v==values[i]);}case .err(e):{return .err(arrays::failure(e,0));}};
        let owners::Token root=live.runtime.pool.slots[resumed.slot].view.root;
        let usize closed=close_ticket(ref mut live,resumed)?;
        let usize released=size(owners::release(ref mut live.runtime.owners,root,64))?;i+=1;
    }
    assert(live.runtime.owners.depth==0 && live.runtime.owners.arena.used==0);return .ok(entered+left);
}

@test
fn void exclusive_borrowed_nested_children_and_local_root_cleanup_match_handoff_roots(){assert(borrowed_checked().is_ok);}
fn Result<usize,errors::Error> borrowed_checked(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);let owners::Token root=create(ref mut live,ref mut data)?;
    let slices::Ticket parent=open(ref mut live,root,true)?;let runtime::Capture[1] args=[runtime::capture(parent,false,false)];
    var work::State w=work::empty();let usize started=work::start_enter(ref mut w,ref live,borrowed(),ref args,64,runtime::cost()+17)?;
    let usize entered=drive(ref mut w,ref live,0)?;let usize checked=entry_oracle(ref live,borrowed(),ref args,ref w)?;
    work::publish(ref w,ref mut live);var runtime::Call call=w.call;
    let slices::Ticket first=child(ref mut live,call.issued[0],1,4)?;let slices::Ticket leaf=child(ref mut live,first,0,2)?;
    let usize written=size(slices::write(ref live.runtime.pool,leaf,ref live.runtime.owners,0,42,ref mut data))?;
    let owners::Token local=create(ref mut live,ref mut data)?;let slices::Ticket local_reader=open(ref mut live,local,false)?;
    let slices::Ticket extra=sub(ref mut live,local_reader,1,3)?;
    let owners::Token[1] roots=[local];let runtime::Call receipt=call;
    let usize returning=work::start_return(ref mut w,ref live,ref call,leaf,ref roots,64,runtime::handoff_cost()+19,true)?;
    let usize left=drive(ref mut w,ref live,0)?;same_call(ref call,ref receipt);
    let usize verified=return_oracle(ref live,ref call,leaf,ref roots,true,ref w)?;
    work::publish(ref w,ref mut live);call.active=false;same_metadata(ref live.runtime,ref w.planned);
    var runtime::Returned result=w.returned;assert(result.remaining==19 && result.held.active && result.held.exclusive && !result.held.drop);
    assert(result.held.issued.generation==parent.generation+7 && result.held.view.start==1 && result.held.view.end==3);
    assert(live.runtime.authority.depth==1 && live.runtime.authority.frame==0 && !owners::view(ref live.runtime.owners,local,0,0,64).is_ok);
    assert(!slices::length(ref live.runtime.pool,leaf,ref live.runtime.owners,64).is_ok && !slices::length(ref live.runtime.pool,extra,ref live.runtime.owners,64).is_ok);
    switch(slices::read(ref live.runtime.pool,result.held.issued,ref live.runtime.owners,0,ref data)){case .ok(v):{assert(v==42);}case .err(e):{return .err(arrays::failure(e,0));}};
    let slices::Ticket selected=result.held.issued;let runtime::Closed closed=runtime::close(ref mut live,ref mut result.held,selected,64,0)?;
    assert(!result.held.active && closed.remaining==0 && closed.parent.slot==parent.slot && closed.parent.generation>selected.generation);
    let usize ended=close_ticket(ref mut live,closed.parent)?;
    let usize released=size(owners::release(ref mut live.runtime.owners,root,64))?;
    assert(live.runtime.authority.depth==0 && live.runtime.owners.depth==0 && live.runtime.owners.arena.used==0);return .ok(left);
}

fn errors::Error entry_failure_oracle(ref runtime::State live,ref runtime::Capture[] args,usize fuel){
    let ref authority::State original=ref live.runtime.authority;var authority::State stack=*original;
    let ref slices::Pool original_pool=ref live.runtime.pool;var slices::Pool pool=*original_pool;
    return switch(runtime::prepare_entry(live,eight(),args,64,fuel,ref mut stack,ref mut pool)){case .ok(_):{assert(false);errors::make(5,0)}case .err(e):{e}};
}
fn Result<usize,errors::Error> enter_failure(usize mode){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);var runtime::Capture[8] args=[runtime::capture(none(),false,false);8];
    let usize setup=writers(ref mut live,ref mut data,ref mut args)?;
    if(mode==0){args[7].ticket.generation+=1;}
    if(mode==1){let usize slot=args[7].ticket.slot;live.runtime.pool.slots[slot].generation=18446744073709551614;args[7].ticket.generation=18446744073709551614;}
    let usize fuel=if(mode==2){runtime::cost()-1}else{runtime::cost()+17};let errors::Error expected=entry_failure_oracle(ref live,ref args,fuel);
    var work::State w=work::empty();let Result<usize,errors::Error> started=work::start_enter(ref mut w,ref live,eight(),ref args,64,fuel);
    if(mode==2){switch(started){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8 && e.kind==expected.kind && e.offset==expected.offset);}};assert(!w.active && !w.done);}
    else{let usize begun=started?;switch(drive(ref mut w,ref live,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==expected.kind && e.offset==expected.offset);}};assert(!w.active && !w.done);}
    // Dropping the failed unpublished Work must leave every original writer usable.
    var usize i=0;while(i<8){let usize slot=args[i].ticket.slot;let slices::Ticket original=slices::Ticket{.slot=slot,.generation=live.runtime.pool.slots[slot].generation};
        let usize written=size(slices::write(ref live.runtime.pool,original,ref live.runtime.owners,0,7,ref mut data))?;i+=1;
    }return .ok(0);
}
fn Result<usize,errors::Error> cancel_plan(ref runtime::State live,ref runtime::Capture[] args){
    var work::State w=work::empty();let usize started=work::start_enter(ref mut w,live,eight(),args,64,runtime::cost()+17)?;
    let usize pending=drive(ref mut w,live,3)?;assert(w.active && !w.done);
    assert(w.planned.pool.slots[args[0].ticket.slot].generation==args[0].ticket.generation+1);
    return .ok(pending); // Scope exit discards a genuinely rotated private plan.
}
fn Result<usize,errors::Error> cancellation(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);var runtime::Capture[8] args=[runtime::capture(none(),false,false);8];
    let usize setup=writers(ref mut live,ref mut data,ref mut args)?;let usize cancelled=cancel_plan(ref live,ref args)?;
    var usize i=0;while(i<8){assert(live.runtime.pool.slots[args[i].ticket.slot].generation==args[i].ticket.generation);
        let usize written=size(slices::write(ref live.runtime.pool,args[i].ticket,ref live.runtime.owners,0,23,ref mut data))?;i+=1;
    }return .ok(cancelled);
}
fn errors::Error late_failure_oracle(ref runtime::State live,ref runtime::Call call,slices::Ticket selected){
    var runtime::State expected=runtime::empty(64);copy_metadata(ref live.runtime,ref mut expected.runtime);var runtime::Call receipt=*call;
    let owners::Token[1] roots=[owners::Token{.slot=0,.generation=0}];
    return switch(runtime::handoff_roots(ref mut expected,ref mut receipt,selected,ref roots[..0],64,runtime::handoff_cost()+19)){case .ok(_):{assert(false);errors::make(5,0)}case .err(e):{assert(receipt.active);e}};
}
fn Result<usize,errors::Error> late_failure(){
    var u8[64] data=[0;64];var runtime::State live=runtime::empty(64);let owners::Token root=create(ref mut live,ref mut data)?;let owners::Token other=create(ref mut live,ref mut data)?;
    let slices::Ticket writer=open(ref mut live,root,true)?;let slices::Ticket reader=open(ref mut live,other,false)?;let slices::Ticket alias=open(ref mut live,other,false)?;
    let runtime::Capture[2] args=[runtime::capture(writer,false,false),runtime::capture(reader,true,true)];
    let runtime::Contract binding=runtime::Contract{.tags=[138,10,0,0,0,0,0,0],.arity=2,.selected=1};
    var runtime::Call call=runtime::enter_call(ref mut live,binding,ref args,64,runtime::cost()+17)?;let runtime::Call receipt=call;let slices::Ticket selected=call.issued[0];
    let usize written=size(slices::write(ref live.runtime.pool,selected,ref live.runtime.owners,0,42,ref mut data))?;
    let errors::Error expected=late_failure_oracle(ref live,ref call,selected);let owners::Token[1] roots=[owners::Token{.slot=0,.generation=0}];
    var work::State w=work::empty();let usize started=work::start_return(ref mut w,ref live,ref call,selected,ref roots[..0],64,runtime::handoff_cost()+19,true)?;
    switch(drive(ref mut w,ref live,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==expected.kind && e.offset==expected.offset);}};
    assert(w.phase==9 && !w.active && !w.done);same_call(ref call,ref receipt);
    assert(w.planned.pool.slots[selected.slot].generation!=selected.generation);
    switch(slices::read(ref live.runtime.pool,selected,ref live.runtime.owners,0,ref data)){case .ok(v):{assert(v==42);}case .err(e):{return .err(arrays::failure(e,0));}};
    let usize closed=close_ticket(ref mut live,alias)?;
    let runtime::Returned retry=runtime::handoff_roots(ref mut live,ref mut call,selected,ref roots[..0],64,runtime::handoff_cost()+19)?;
    assert(!call.active && retry.held.active && retry.remaining==19);return .ok(0);
}

@test
fn void stale_generation_low_fuel_late_failure_and_cancel_preserve_original_authority(){
    assert(enter_failure(0).is_ok);assert(enter_failure(1).is_ok);assert(enter_failure(2).is_ok);
    assert(cancellation().is_ok);assert(late_failure().is_ok);
}
