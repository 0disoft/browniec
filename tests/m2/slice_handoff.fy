module tests::m2::slice_handoff;
import slice_handoff as handoff;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import slice_vm as loans;
import errors as errors;
import std::bytes as bytes;

fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn handoff::Batch batch(Result<handoff::Batch,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);handoff::empty()}};}
fn slices::Arguments returned(Result<slices::Arguments,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::empty_arguments()}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize n,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);same_view(x.view,y.view);i+=1;}}
fn void same_batch(ref handoff::Batch a,ref handoff::Batch b){assert(a.count==b.count && a.frame==b.frame);var usize i=0;while(i<8){assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation && a.leases[i].generation==b.leases[i].generation);same_view(a.leases[i].view,b.leases[i].view);i+=1;}}
fn void same_owners(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
}

@test
fn void six_scalar_ranges_transfer_actual_writes_and_return_only_fresh_caller_tickets(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;
    while(i<6){var u8[32] data=[0;32];var owners::Table table=owners::empty(32);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,tags[i],3,ref mut data);
        let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,2,32));let owners::Table saved=table;let slices::Ticket[1] input=[parent];var handoff::Batch call=batch(handoff::begin(ref mut pool,ref input,ref table,32,0));let slices::Ticket child=call.tickets[0];
        assert(child.slot==parent.slot && child.generation==parent.generation+1 && size(slices::length(ref pool,child,ref table,32))==1);same_owners(ref table,ref saved);
        assert(!slices::read(ref pool,parent,ref table,0,ref data).is_ok && !slices::write(ref pool,parent,ref table,0,42,ref mut data).is_ok && !slices::close(ref mut pool,parent,ref mut table,32).is_ok);
        assert(size(slices::write(ref pool,child,ref table,0,values[i],ref mut data))>0 && cell(slices::read(ref pool,child,ref table,0,ref data))==values[i]);assert(!owners::read(ref table,root,1,ref data).is_ok);
        let slices::Ticket[1] current=[child];let slices::Arguments resumed=returned(handoff::restore(ref mut pool,ref mut call,ref current,ref table,32));let slices::Ticket caller=resumed.tickets[0];
        assert(call.count==0 && resumed.count==1 && caller.slot==parent.slot && caller.generation==child.generation+1);same_owners(ref table,ref saved);
        assert(!slices::read(ref pool,child,ref table,0,ref data).is_ok && !slices::close(ref mut pool,child,ref mut table,32).is_ok && cell(slices::read(ref pool,caller,ref table,0,ref data))==values[i]);
        assert(slices::close(ref mut pool,caller,ref mut table,32).is_ok && cell(owners::read(ref table,root,1,ref data))==values[i] && cell(owners::read(ref table,root,0,ref data))==0 && cell(owners::read(ref table,root,2,ref data))==0);i+=1;
    }
}

@test
fn void thirty_one_nested_handoffs_restore_in_order_and_empty_ranges_keep_root_exclusion(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,4,ref mut data);let slices::Ticket original=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,3,8));
    var handoff::Batch[31] stack=[handoff::empty();31];var slices::Ticket current=original;var usize depth=0;
    while(depth<31){let slices::Ticket[1] input=[current];stack[depth]=batch(handoff::begin(ref mut pool,ref input,ref table,8,depth));current=stack[depth].tickets[0];depth+=1;}
    let slices::Ticket[1] too_deep=[current];assert(!handoff::begin(ref mut pool,ref too_deep,ref table,8,31).is_ok);assert(size(slices::write(ref pool,current,ref table,0,42,ref mut data))==1);
    let slices::Ticket[1] stale=[stack[0].tickets[0]];assert(!handoff::restore(ref mut pool,ref mut stack[0],ref stale,ref table,8).is_ok && stack[0].count==1);
    while(depth>0){depth-=1;let slices::Ticket[1] active=[current];let slices::Arguments result=returned(handoff::restore(ref mut pool,ref mut stack[depth],ref active,ref table,8));current=result.tickets[0];}
    assert(current.generation==original.generation+62 && !slices::read(ref pool,original,ref table,0,ref data).is_ok && cell(slices::read(ref pool,current,ref table,0,ref data))==42);
    let slices::Ticket[1] again=[current];var handoff::Batch next=batch(handoff::begin(ref mut pool,ref again,ref table,8,0));let slices::Ticket[1] nested=[next.tickets[0]];let slices::Arguments result=returned(handoff::restore(ref mut pool,ref mut next,ref nested,ref table,8));assert(slices::close(ref mut pool,result.tickets[0],ref mut table,8).is_ok);
    let slices::Ticket empty=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,4,4,8));let slices::Ticket[1] input=[empty];var handoff::Batch zero=batch(handoff::begin(ref mut pool,ref input,ref table,8,0));let slices::Ticket child=zero.tickets[0];
    assert(size(slices::length(ref pool,child,ref table,8))==0 && !slices::write(ref pool,child,ref table,0,42,ref mut data).is_ok && !owners::read(ref table,root,0,ref data).is_ok);
    let slices::Ticket[1] active=[child];let slices::Arguments resumed=returned(handoff::restore(ref mut pool,ref mut zero,ref active,ref table,8));assert(slices::close(ref mut pool,resumed.tickets[0],ref mut table,8).is_ok);
}

@test
fn void stale_fabricated_duplicate_readonly_and_excess_arguments_fail_before_any_rotation(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token a=create(ref mut table,10,1,ref mut data);let owners::Token b=create(ref mut table,10,1,ref mut data);let owners::Token c=create(ref mut table,10,1,ref mut data);
    let slices::Ticket x=ticket(slices::open_exclusive(ref mut pool,ref mut table,a,0,1,8));let slices::Ticket y=ticket(slices::open_exclusive(ref mut pool,ref mut table,b,0,1,8));let slices::Ticket reader=ticket(slices::open(ref mut pool,ref mut table,c,0,1,8));let slices::Pool saved=pool;let owners::Table owners_before=table;
    let slices::Ticket[2] late=[x,slices::Ticket{.slot=y.slot,.generation=y.generation+1}];assert(!handoff::begin(ref mut pool,ref late,ref table,8,0).is_ok);
    let slices::Ticket[2] fabricated=[x,slices::Ticket{.slot=x.slot,.generation=x.generation+1}];assert(!handoff::begin(ref mut pool,ref fabricated,ref table,8,0).is_ok);
    let slices::Ticket[2] duplicate=[x,x];assert(!handoff::begin(ref mut pool,ref duplicate,ref table,8,0).is_ok);let slices::Ticket[2] mixed=[x,reader];assert(!handoff::begin(ref mut pool,ref mixed,ref table,8,0).is_ok);
    let slices::Ticket[9] excess=[x;9];assert(!handoff::begin(ref mut pool,ref excess,ref table,8,0).is_ok);let slices::Ticket[1] one=[x];assert(!handoff::begin(ref mut pool,ref one,ref table,8,31).is_ok);
    assert(!slices::rotate_exclusive(ref mut pool,reader,ref table,8).is_ok);same_pool(ref pool,ref saved);same_owners(ref table,ref owners_before);var usize i=0;while(i<8){assert(data[i]==0);i+=1;}
    var handoff::Batch empty=batch(handoff::begin(ref mut pool,ref one[..0],ref table,8,0));let slices::Arguments none=returned(handoff::restore(ref mut pool,ref mut empty,ref one[..0],ref table,8));assert(none.count==0);same_pool(ref pool,ref saved);assert(size(slices::clear(ref mut pool,ref mut table,8))==3);
}

@test
fn void restore_checks_every_receipt_before_publication_and_accepts_fresh_nested_returns(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token a=create(ref mut table,10,2,ref mut data);let owners::Token b=create(ref mut table,10,2,ref mut data);
    let slices::Ticket x=ticket(slices::open_exclusive(ref mut pool,ref mut table,a,0,2,8));let slices::Ticket y=ticket(slices::open_exclusive(ref mut pool,ref mut table,b,0,2,8));let slices::Ticket[2] sources=[x,y];var handoff::Batch call=batch(handoff::begin(ref mut pool,ref sources,ref table,8,0));
    let slices::Ticket[1] inner=[call.tickets[1]];var handoff::Batch child=batch(handoff::begin(ref mut pool,ref inner,ref table,8,1));let slices::Ticket[1] child_now=[child.tickets[0]];let slices::Arguments child_return=returned(handoff::restore(ref mut pool,ref mut child,ref child_now,ref table,8));
    let slices::Ticket[2] active=[call.tickets[0],child_return.tickets[0]];let slices::Pool saved=pool;let owners::Table owners_before=table;let handoff::Batch receipt=call;
    assert(!handoff::restore(ref mut pool,ref mut call,ref receipt.tickets[..2],ref table,8).is_ok);same_pool(ref pool,ref saved);same_batch(ref call,ref receipt);
    var handoff::Batch bad=call;bad.leases[1].view.start=1;assert(!handoff::restore(ref mut pool,ref mut bad,ref active,ref table,8).is_ok);
    bad=call;bad.leases[1].generation+=1;assert(!handoff::restore(ref mut pool,ref mut bad,ref active,ref table,8).is_ok);
    bad=call;let usize duplicate_slot=bad.tickets[0].slot;bad.tickets[1].slot=duplicate_slot;assert(!handoff::restore(ref mut pool,ref mut bad,ref active,ref table,8).is_ok);
    bad=call;bad.leases[7].view.root.slot=0;assert(!handoff::restore(ref mut pool,ref mut bad,ref active,ref table,8).is_ok);
    bad=call;bad.frame=31;assert(!handoff::restore(ref mut pool,ref mut bad,ref active,ref table,8).is_ok);
    assert(!handoff::restore(ref mut pool,ref mut call,ref active[..1],ref table,8).is_ok);let slices::Ticket[2] swapped=[active[1],active[0]];assert(!handoff::restore(ref mut pool,ref mut call,ref swapped,ref table,8).is_ok);
    same_pool(ref pool,ref saved);same_owners(ref table,ref owners_before);same_batch(ref call,ref receipt);
    let slices::Arguments result=returned(handoff::restore(ref mut pool,ref mut call,ref active,ref table,8));assert(result.count==2 && call.count==0 && result.tickets[0].generation==3 && result.tickets[1].generation==5);assert(size(slices::clear(ref mut pool,ref mut table,8))==2);
}

@test
fn void generation_headroom_and_owner_epochs_never_wrap_or_reopen_an_old_session(){
    var usize mode=0;while(mode<2){var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,1,ref mut data);let slices::Ticket opened=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8));let usize frame=if(mode==0){0}else{30};
        pool.slots[opened.slot].generation=18446744073709551615-(frame+1);let slices::Ticket exhausted=slices::Ticket{.slot=opened.slot,.generation=pool.slots[opened.slot].generation};let slices::Ticket[1] fail=[exhausted];let slices::Pool before=pool;assert(!handoff::begin(ref mut pool,ref fail,ref table,8,frame).is_ok);same_pool(ref pool,ref before);
        pool.slots[opened.slot].generation-=1;let slices::Ticket parent=slices::Ticket{.slot=opened.slot,.generation=pool.slots[opened.slot].generation};let slices::Ticket[1] input=[parent];var handoff::Batch call=batch(handoff::begin(ref mut pool,ref input,ref table,8,frame));let slices::Ticket[1] current=[call.tickets[0]];
        assert(!handoff::begin(ref mut pool,ref current,ref table,8,frame+1).is_ok);let slices::Arguments result=returned(handoff::restore(ref mut pool,ref mut call,ref current,ref table,8));assert(result.tickets[0].generation==18446744073709551615-frame);assert(slices::close(ref mut pool,result.tickets[0],ref mut table,8).is_ok);if(mode==0){assert(pool.slots[opened.slot].generation==0);}mode+=1;
    }
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,1,ref mut data);let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8));let slices::Ticket[1] input=[parent];var handoff::Batch call=batch(handoff::begin(ref mut pool,ref input,ref table,8,0));assert(slices::close(ref mut pool,call.tickets[0],ref mut table,8).is_ok);
    let slices::Ticket replacement=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8));let slices::Ticket[1] wrong_session=[replacement];let slices::Pool saved=pool;assert(!handoff::restore(ref mut pool,ref mut call,ref wrong_session,ref table,8).is_ok && call.count==1);same_pool(ref pool,ref saved);assert(slices::close(ref mut pool,replacement,ref mut table,8).is_ok);
    table.slots[root.slot].read_generation=18446744073709551615;let slices::Ticket last=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8));let slices::Ticket[1] last_input=[last];var handoff::Batch final=batch(handoff::begin(ref mut pool,ref last_input,ref table,8,0));let slices::Ticket[1] child=[final.tickets[0]];let slices::Arguments back=returned(handoff::restore(ref mut pool,ref mut final,ref child,ref table,8));assert(table.slots[root.slot].read_generation==18446744073709551615);assert(slices::close(ref mut pool,back.tickets[0],ref mut table,8).is_ok && table.slots[root.slot].read_generation==0 && !slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8).is_ok);
}

@test
fn void full_pool_uses_no_extra_slots_and_abort_drain_preserves_writes_or_failed_cleanup_metadata(){
    var arrays::State state=arrays::empty(16);var loans::State loan=loans::empty();var bytes::Buffer buffer=switch(arrays::prepare(16)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};var slices::Ticket[8] sources=[slices::Ticket{.slot=16,.generation=0};8];
    var usize i=0;while(i<16){let owners::Token root=create(ref mut state.owners,10,1,bytes::view_mut(ref mut buffer));state.tokens[i]=root;let slices::Ticket opened=if(i<8){ticket(slices::open_exclusive(ref mut loan.pool,ref mut state.owners,root,0,1,16))}else{ticket(slices::open(ref mut loan.pool,ref mut state.owners,root,0,1,16))};loan.tickets[i]=opened;if(i<8){sources[i]=opened;}i+=1;}
    var handoff::Batch call=batch(handoff::begin(ref mut loan.pool,ref sources,ref state.owners,16,0));assert(call.count==8);i=0;while(i<8){assert(call.tickets[i].slot==sources[i].slot);loan.tickets[i]=call.tickets[i];i+=1;}
    assert(size(slices::write(ref loan.pool,call.tickets[0],ref state.owners,0,42,bytes::view_mut(ref mut buffer)))==1);
    let usize epoch=state.owners.slots[7].read_generation;state.owners.slots[7].read_generation+=1;let slices::Pool saved=loan.pool;let owners::Table owners_before=state.owners;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref buffer,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==5}});same_pool(ref loan.pool,ref saved);same_owners(ref state.owners,ref owners_before);assert(loan.tickets[0].generation==call.tickets[0].generation);
    state.owners.slots[7].read_generation=epoch;assert(switch(loans::finish(ref mut loan,ref mut state,ref buffer,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
    assert(cell(owners::read(ref state.owners,state.tokens[0],0,bytes::view(ref buffer)))==42);i=0;while(i<16){assert(!loan.pool.slots[i].live && !state.owners.slots[i].writing && !state.owners.slots[i].reading);i+=1;}i=0;while(i<512){assert(loan.tickets[i].generation==0);i+=1;}
    let slices::Ticket[8] stale=call.tickets;assert(!handoff::restore(ref mut loan.pool,ref mut call,ref stale,ref state.owners,16).is_ok);
}
