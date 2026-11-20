module tests::m2::runtime_cleanup_work;
import runtime_cleanup_work as work;
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

fn void same(ref runtime::State a,ref runtime::State b){same_pool(ref a.runtime.pool,ref b.runtime.pool);same_owners(ref a.runtime.owners,ref b.runtime.owners);same_authority(ref a.runtime.authority,ref b.runtime.authority);}
fn Result<usize,errors::Error> drive(ref mut runtime::State live,ref runtime::State before){
    var runtime::State scratch=runtime::empty(0);var work::State w=work::empty();var budget::State allowance=budget::empty();
    let usize started=work::begin(ref mut w,64)?;var usize n=0;
    while(n<96){let usize reset=budget::reset(ref mut allowance,0)?;let usize total=allowance.total;
        let bool used=budget::admit(ref mut allowance,1,0)?;assert(used);let usize index=w.index;let u8 phase=w.phase;
        let bool partial=work::advance(ref mut w,ref mut scratch.runtime,live,ref mut allowance)?;
        assert(!partial && index==w.index && phase==w.phase && allowance.last==1 && allowance.total==total+1);same(live,before);
        let usize fresh=budget::reset(ref mut allowance,0)?;
        let bool done=work::advance(ref mut w,ref mut scratch.runtime,live,ref mut allowance)?;same(live,before);
        if(phase==5){
            let ref owners::Table table=ref scratch.runtime.owners;
            assert(w.index==index+1 && !table.slots[index].occupied && !table.slots[index].live);
            if(!done){
                assert(table.arena.used==before.runtime.owners.arena.used);
                assert(table.slots[w.index].live==before.runtime.owners.slots[w.index].live);
            }
        }
        assert(allowance.last==4096);n+=1;if(done){let usize again=budget::reset(ref mut allowance,0)?;
            assert(budget::admit(ref mut allowance,4096,0).is_ok);work::publish(ref w,ref scratch.runtime,live);return .ok(n);}
    }assert(false);return .err(errors::make(5,0));
}
fn Result<usize,errors::Error> parity(bool mixed,bool corrupt){
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];
    var usize i=0;while(i<16){let owners::Token root=create(ref mut state,ref mut data)?;
        if(mixed && i<15){let slices::Ticket held=open(ref mut state,root,i%2!=0)?;
            if(i==0){let slices::Ticket extra=open(ref mut state,root,false)?;}}
        i+=1;
    }
    if(corrupt){state.runtime.authority.depth=99;state.runtime.authority.kinds[30]=9;}
    let runtime::State before=state;var runtime::State raw=state;
    let usize aborted=runtime::abort(ref mut raw,64,0)?;assert(aborted==0);
    let usize stages=drive(ref mut state,ref before)?;assert(stages==82);same(ref state,ref raw);return .ok(0);
}
@test fn void saturated_mixed_sessions_and_owners_match_raw_zero_fuel_cleanup(){assert(parity(true,false).is_ok);}
@test fn void corrupt_authority_receipts_do_not_block_authenticated_cleanup(){assert(parity(true,true).is_ok);}
@test fn void owner_only_cleanup_keeps_generation_and_arena_parity(){assert(parity(false,false).is_ok);}
fn Result<usize,errors::Error> stale_lease(){
    var runtime::State live=runtime::empty(64);var u8[64] data=[0;64];
    let owners::Token root=create(ref mut live,ref mut data)?;
    let slices::Ticket first=open(ref mut live,root,false)?;
    let slices::Ticket second=open(ref mut live,root,false)?;
    live.runtime.pool.slots[second.slot].lease.generation+=1;
    let runtime::State before=live;
    var runtime::State raw=live;
    assert(!runtime::abort(ref mut raw,64,0).is_ok);same(ref raw,ref before);
    assert(!drive(ref mut live,ref before).is_ok);same(ref live,ref before);
    return .ok(first.slot);
}
@test fn void stale_shared_lease_rejects_before_any_publication(){assert(stale_lease().is_ok);}
fn Result<usize,errors::Error> owner_generations(){
    var runtime::State live=runtime::empty(64);var u8[64] data=[0;64];
    let owners::Token dead=create(ref mut live,ref mut data)?;
    let owners::Token retiring=create(ref mut live,ref mut data)?;
    let usize held=size(owners::release(ref mut live.runtime.owners,dead,64))?;
    assert(held==0);
    live.runtime.owners.slots[retiring.slot].generation=18446744073709551615;
    let runtime::State before=live;
    var runtime::State raw=live;
    let usize aborted=runtime::abort(ref mut raw,64,0)?;
    let usize stages=drive(ref mut live,ref before)?;
    assert(aborted==0 && stages==82 && live.runtime.owners.arena.used==0);
    same(ref raw,ref live);
    assert(live.runtime.owners.slots[dead.slot].generation==dead.generation+1);
    assert(live.runtime.owners.slots[retiring.slot].generation==0);
    assert(!owners::read(ref live.runtime.owners,dead,0,ref data).is_ok);
    return .ok(0);
}
@test fn void dead_extents_and_exhausted_generation_survive_root_cleanup(){assert(owner_generations().is_ok);}

fn Result<usize,errors::Error> orphaned_lease(){
    var runtime::State live=runtime::empty(64);var u8[64] data=[0;64];var usize i=0;
    while(i<16){let owners::Token root=create(ref mut live,ref mut data)?;i+=1;}
    live.runtime.owners.slots[15].reading=true;
    let runtime::State before=live;
    var runtime::State raw=live;
    assert(!runtime::abort(ref mut raw,64,0).is_ok);same(ref raw,ref before);
    assert(!drive(ref mut live,ref before).is_ok);same(ref live,ref before);
    return .ok(0);
}
@test fn void late_orphaned_lease_discards_private_root_progress(){assert(orphaned_lease().is_ok);}

@test fn void invalid_pool_rejects_without_publishing_or_touching_live_state(){
    var runtime::State live=runtime::empty(64);live.runtime.pool.slots[15].exclusive=true;let runtime::State before=live;
    var runtime::State raw=live;assert(!runtime::abort(ref mut raw,64,0).is_ok);same(ref raw,ref before);
    assert(!drive(ref mut live,ref before).is_ok);same(ref live,ref before);
}
