module tests::m2::slice_exclusive_pool;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import slice_vm as loans;
import slice_frame_vm as frames;
import slice_call_vm as calls;
import compiler as compiler;
import ir as ir;
import errors as errors;
import std::bytes as bytes;

fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool valid(Result<bool,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);false}};}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize n,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){
    var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];
        assert(x.live==y.live && x.exclusive==y.exclusive && x.generation==y.generation);
        assert(x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation);
        assert(x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end);
        assert(x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);i+=1;}
}
fn void same_owners(ref owners::Table a,ref owners::Table b,ref u8[] data,ref u8[] saved){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
    assert(data.len==saved.len);i=0;while(i<data.len){assert(data[i]==saved[i]);i+=1;}
}

@test
fn void all_scalar_ranges_read_and_write_actual_bytes_without_new_owners_or_extents(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];
    var usize i=0;while(i<6){
        var u8[32] data=[0;32];var owners::Table table=owners::empty(32);var slices::Pool pool=slices::empty();
        let owners::Token root=create(ref mut table,tags[i],3,ref mut data);let usize used=table.arena.used;
        let slices::Ticket w=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,2,32));
        assert(pool.slots[w.slot].exclusive && size(slices::length(ref pool,w,ref table,32))==1);
        assert(size(slices::write(ref pool,w,ref table,0,values[i],ref mut data))>0);
        assert(cell(slices::read(ref pool,w,ref table,0,ref data))==values[i]);
        assert(!owners::read(ref table,root,1,ref data).is_ok && table.arena.used==used && table.depth==1);
        assert(slices::close(ref mut pool,w,ref mut table,32).is_ok);
        assert(cell(owners::read(ref table,root,0,ref data))==0 && cell(owners::read(ref table,root,1,ref data))==values[i]);
        assert(cell(owners::read(ref table,root,2,ref data))==0 && !table.slots[root.slot].writing);i+=1;
    }
}

@test
fn void shared_exclusive_conflicts_and_borrow_batches_preserve_both_modes_atomically(){
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);var slices::Pool pool=slices::empty();
    let owners::Token a=create(ref mut table,10,2,ref mut data);let owners::Token b=create(ref mut table,10,2,ref mut data);
    let slices::Ticket r=ticket(slices::open(ref mut pool,ref mut table,a,0,2,16));
    let slices::Ticket w=ticket(slices::open_exclusive(ref mut pool,ref mut table,b,0,2,16));
    let slices::Pool before=pool;let owners::Table saved_table=table;let u8[16] saved=data;
    assert(!slices::open_exclusive(ref mut pool,ref mut table,a,0,0,16).is_ok);
    assert(!slices::open(ref mut pool,ref mut table,b,0,0,16).is_ok);
    assert(!slices::open_exclusive(ref mut pool,ref mut table,b,1,2,16).is_ok);
    assert(!slices::write(ref pool,r,ref table,0,42,ref mut data).is_ok);
    assert(!slices::subslice(ref mut pool,w,ref table,0,1,16).is_ok);
    let slices::Ticket[2] input=[r,w];assert(!slices::borrow_arguments(ref mut pool,ref input,ref table,16).is_ok);
    var slices::Arguments forged=slices::empty_arguments();forged.count=2;forged.tickets[0]=r;forged.tickets[1]=w;
    assert(!slices::close_arguments(ref mut pool,ref mut forged,ref mut table,16).is_ok && forged.count==2);
    same_pool(ref pool,ref before);same_owners(ref table,ref saved_table,ref data,ref saved);
    let slices::Ticket[1] readonly=[r];var slices::Arguments retained=switch(slices::borrow_arguments(ref mut pool,ref readonly,ref table,16)){case .ok(v):{v}case .err(_):{assert(false);slices::empty_arguments()}};
    assert(size(slices::close_arguments(ref mut pool,ref mut retained,ref mut table,16))==1 && table.slots[b.slot].writing);
    assert(size(slices::clear(ref mut pool,ref mut table,16))==2 && !table.slots[a.slot].reading && !table.slots[b.slot].writing);
}

@test
fn void stale_tickets_wrong_modes_duplicate_writers_and_wrong_root_metadata_fail_closed(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,2,ref mut data);let owners::Token other=create(ref mut table,10,1,ref mut data);
    let slices::Ticket old=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,2,8));
    assert(slices::close(ref mut pool,old,ref mut table,8).is_ok);
    let slices::Ticket now=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,2,8));
    assert(now.generation!=old.generation && !slices::write(ref pool,old,ref table,0,42,ref mut data).is_ok);
    assert(!slices::close(ref mut pool,old,ref mut table,8).is_ok);
    let slices::Pool before=pool;
    pool.slots[now.slot].exclusive=false;assert(!slices::length(ref pool,now,ref table,8).is_ok);pool.slots=before.slots;
    pool.slots[now.slot].lease.root=other;assert(!slices::length(ref pool,now,ref table,8).is_ok);pool.slots=before.slots;
    let slices::Slot duplicate=pool.slots[now.slot];pool.slots[15]=duplicate;assert(!slices::clear(ref mut pool,ref mut table,8).is_ok);pool.slots=before.slots;
    pool.slots[15].exclusive=true;assert(!slices::read(ref pool,now,ref table,0,ref data).is_ok);pool.slots=before.slots;
    assert(table.slots[root.slot].writing && size(slices::clear(ref mut pool,ref mut table,8))==1);
}

@test
fn void invalid_values_bounds_backing_and_non_u8_scans_leave_state_unchanged(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,2,2,ref mut data);
    let slices::Ticket w=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,2,8));
    let slices::Pool before=pool;let owners::Table saved_table=table;let u8[8] saved=data;
    assert(!slices::write(ref pool,w,ref table,0,2,ref mut data).is_ok);
    assert(!slices::write(ref pool,w,ref table,2,1,ref mut data).is_ok);
    assert(!slices::write(ref pool,w,ref table,0,1,ref mut data[..1]).is_ok);
    assert(!slices::utf8(ref pool,w,ref table,ref data).is_ok && !slices::close(ref mut pool,w,ref mut table,1).is_ok);
    same_pool(ref pool,ref before);same_owners(ref table,ref saved_table,ref data,ref saved);
    assert(slices::close(ref mut pool,w,ref mut table,8).is_ok);
    let owners::Token bytes_root=create(ref mut table,10,3,ref mut data);
    assert(owners::write(ref table,bytes_root,0,255,ref mut data).is_ok);
    let slices::Ticket text=ticket(slices::open_exclusive(ref mut pool,ref mut table,bytes_root,1,2,8));
    assert(valid(slices::utf8(ref pool,text,ref table,ref data)));
    assert(slices::write(ref pool,text,ref table,0,255,ref mut data).is_ok && !valid(slices::utf8(ref pool,text,ref table,ref data)));
    assert(slices::close(ref mut pool,text,ref mut table,8).is_ok);
    let slices::Ticket empty=ticket(slices::open_exclusive(ref mut pool,ref mut table,bytes_root,3,3,8));
    assert(size(slices::length(ref pool,empty,ref table,8))==0 && valid(slices::utf8(ref pool,empty,ref table,ref data)));
    assert(!slices::write(ref pool,empty,ref table,0,1,ref mut data).is_ok);
    assert(slices::clear(ref mut pool,ref mut table,8).is_ok);
}

@test
fn void both_modes_share_sixteen_slots_and_pool_and_owner_epochs_never_wrap(){
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);var slices::Pool pool=slices::empty();
    var owners::Token first=owners::Token{.slot=16,.generation=0};var usize i=0;
    while(i<16){let owners::Token root=create(ref mut table,10,1,ref mut data);if(i==0){first=root;}
        let slices::Ticket t=if(i%2==0){ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,16))}else{ticket(slices::open(ref mut pool,ref mut table,root,0,1,16))};i+=1;}
    let slices::Pool before=pool;let owners::Table saved_table=table;let u8[16] saved=data;
    assert(!slices::open_exclusive(ref mut pool,ref mut table,first,0,0,16).is_ok);
    same_pool(ref pool,ref before);same_owners(ref table,ref saved_table,ref data,ref saved);
    assert(size(slices::clear(ref mut pool,ref mut table,16))==16);
    pool.slots[0].generation=18446744073709551615;
    table.slots[first.slot].read_generation=18446744073709551615;
    let slices::Ticket last=ticket(slices::open_exclusive(ref mut pool,ref mut table,first,0,0,16));
    assert(last.slot==0 && slices::close(ref mut pool,last,ref mut table,16).is_ok);
    assert(pool.slots[0].generation==0 && table.slots[first.slot].read_generation==0);
    assert(!slices::open_exclusive(ref mut pool,ref mut table,first,0,0,16).is_ok);
    assert(!slices::read(ref pool,last,ref table,0,ref data).is_ok);
}

@test
fn void vm_drain_preserves_outcomes_or_retains_failed_cleanup_and_readonly_adapters_reject_writers(){
    var bytes::Buffer buffer=switch(arrays::prepare(8)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    var arrays::State state=arrays::empty(8);var loans::State loan=loans::empty();
    var owners::Token a=owners::Token{.slot=16,.generation=0};var owners::Token b=a;
    {let ref mut u8[] data=bytes::view_mut(ref mut buffer);a=create(ref mut state.owners,10,1,data);b=create(ref mut state.owners,10,1,data);}
    state.tokens[0]=a;state.tokens[1]=b;
    let slices::Ticket w=ticket(slices::open_exclusive(ref mut loan.pool,ref mut state.owners,a,0,1,8));
    let slices::Ticket r=ticket(slices::open(ref mut loan.pool,ref mut state.owners,b,0,1,8));loan.tickets[0]=w;loan.tickets[1]=r;
    {let ref mut u8[] data=bytes::view_mut(ref mut buffer);assert(slices::write(ref loan.pool,w,ref state.owners,0,42,data).is_ok);}
    let ir::Program p=switch(compiler::compile(b"module main;fn i32 main(){var u8[1] a=[0;1];let ref u8[] p=ref a;let usize n=p.len;return 42;}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    var usize pc=0;while(p.code[pc*8]!=57){pc+=1;}var i64[128] registers=[999;128];let calls::Frames origin=calls::empty();
    assert(switch(loans::step(ref p,pc,0,ref mut loan,ref mut state,ref buffer,ref mut registers,4097)){case .ok(_):{false}case .err(e):{e.kind==5}});
    assert(switch(frames::step(ref p,0,pc,0,ref origin,ref mut loan,ref mut state,ref buffer,ref mut registers,4097)){case .ok(_):{false}case .err(e):{e.kind==5}});
    let usize epoch=state.owners.slots[b.slot].read_generation;state.owners.slots[b.slot].read_generation=epoch+1;
    let slices::Pool before=loan.pool;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref buffer,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==5}});
    same_pool(ref loan.pool,ref before);assert(state.owners.slots[a.slot].writing && state.owners.slots[b.slot].reading && loan.tickets[0].generation==w.generation);
    state.owners.slots[b.slot].read_generation=epoch;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref buffer,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
    assert(!state.owners.slots[a.slot].writing && !state.owners.slots[b.slot].reading && loan.tickets[0].generation==0 && loan.tickets[1].generation==0);
    assert(cell(owners::read(ref state.owners,a,0,bytes::view(ref buffer)))==42);
    let slices::Ticket again=ticket(slices::open_exclusive(ref mut loan.pool,ref mut state.owners,a,0,1,8));loan.tickets[0]=again;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref buffer,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});
    assert(!state.owners.slots[a.slot].writing && loan.tickets[0].generation==0);
}
