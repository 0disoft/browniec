module tests::m2::slice_reborrow;
import slice_reborrow as reborrow;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;

fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize n,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);same_view(x.view,y.view);i+=1;}}
fn void same_owners(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
}

fn reborrow::Loan loan(Result<reborrow::Loan,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);reborrow::empty()}};}
fn void same_loan(ref reborrow::Loan a,ref reborrow::Loan b){same_view(a.parent.view,b.parent.view);same_view(a.selected,b.selected);assert(a.parent.generation==b.parent.generation && a.issued.slot==b.issued.slot && a.issued.generation==b.issued.generation && a.depth==b.depth && a.active==b.active);}

@test
fn void six_scalar_subranges_write_relative_elements_and_restore_only_fresh_parent_tickets(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;
    while(i<6){var u8[40] data=[0;40];var owners::Table table=owners::empty(40);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,tags[i],5,ref mut data);
        let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,4,40));let owners::Table saved=table;
        var reborrow::Loan receipt=loan(reborrow::begin(ref mut pool,parent,ref table,1,2,40,0));let slices::Ticket child=receipt.issued;
        assert(child.slot==parent.slot && child.generation==parent.generation+1 && size(slices::length(ref pool,child,ref table,40))==1);same_owners(ref table,ref saved);
        assert(!slices::length(ref pool,parent,ref table,40).is_ok && !slices::read(ref pool,parent,ref table,0,ref data).is_ok && !slices::write(ref pool,parent,ref table,0,42,ref mut data).is_ok && !slices::close(ref mut pool,parent,ref mut table,40).is_ok);
        assert(size(slices::write(ref pool,child,ref table,0,values[i],ref mut data))>0 && cell(slices::read(ref pool,child,ref table,0,ref data))==values[i]);assert(!slices::write(ref pool,child,ref table,1,0,ref mut data).is_ok && !owners::read(ref table,root,2,ref data).is_ok);
        let slices::Ticket resumed=ticket(reborrow::restore(ref mut pool,ref mut receipt,child,ref table,40));assert(!receipt.active && resumed.generation==child.generation+1 && size(slices::length(ref pool,resumed,ref table,40))==3);same_owners(ref table,ref saved);
        assert(!slices::read(ref pool,child,ref table,0,ref data).is_ok && !slices::close(ref mut pool,child,ref mut table,40).is_ok && cell(slices::read(ref pool,resumed,ref table,1,ref data))==values[i]);
        assert(slices::close(ref mut pool,resumed,ref mut table,40).is_ok);var usize j=0;while(j<5){assert(cell(owners::read(ref table,root,j,ref data))==if(j==2){values[i]}else{0});j+=1;}i+=1;
    }
}

@test
fn void thirty_one_nested_loans_and_empty_ranges_restore_the_original_authority(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,4,ref mut data);let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,4,8));var slices::Ticket current=parent;var reborrow::Loan[31] stack=[reborrow::empty();31];var usize depth=0;
    while(depth<31){stack[depth]=loan(reborrow::begin(ref mut pool,current,ref table,if(depth==0){1}else{0},if(depth==0){4}else{3},8,depth));current=stack[depth].issued;depth+=1;}
    let slices::Pool saved=pool;assert(!reborrow::begin(ref mut pool,current,ref table,0,1,8,31).is_ok);same_pool(ref pool,ref saved);assert(slices::write(ref pool,current,ref table,0,42,ref mut data).is_ok);
    while(depth>0){depth-=1;current=ticket(reborrow::restore(ref mut pool,ref mut stack[depth],current,ref table,8));assert(!stack[depth].active);}
    assert(current.generation==parent.generation+62 && size(slices::length(ref pool,current,ref table,8))==4 && cell(slices::read(ref pool,current,ref table,1,ref data))==42);
    var reborrow::Loan empty=loan(reborrow::begin(ref mut pool,current,ref table,4,4,8,0));let slices::Ticket child=empty.issued;assert(size(slices::length(ref pool,child,ref table,8))==0 && !slices::write(ref pool,child,ref table,0,42,ref mut data).is_ok && !owners::read(ref table,root,0,ref data).is_ok);
    assert(switch(slices::utf8(ref pool,child,ref table,ref data)){case .ok(v):{v}case .err(_):{false}});current=ticket(reborrow::restore(ref mut pool,ref mut empty,child,ref table,8));assert(slices::close(ref mut pool,current,ref mut table,8).is_ok);
}

@test
fn void invalid_begin_stale_shared_overflow_bounds_and_corrupt_backing_publish_nothing(){
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,4,ref mut data);let owners::Token other=create(ref mut table,10,4,ref mut data);
    let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,3,16));let slices::Ticket reader=ticket(slices::open(ref mut pool,ref mut table,other,0,4,16));let slices::Pool saved=pool;let owners::Table before=table;
    assert(!reborrow::begin(ref mut pool,reader,ref table,0,1,16,0).is_ok);assert(!reborrow::begin(ref mut pool,slices::Ticket{.slot=16,.generation=1},ref table,0,1,16,0).is_ok);
    assert(!reborrow::begin(ref mut pool,slices::Ticket{.slot=parent.slot,.generation=parent.generation+1},ref table,0,1,16,0).is_ok);
    assert(!reborrow::begin(ref mut pool,parent,ref table,2,1,16,0).is_ok && !reborrow::begin(ref mut pool,parent,ref table,0,3,16,0).is_ok && !reborrow::begin(ref mut pool,parent,ref table,0,18446744073709551615,16,0).is_ok);
    assert(!reborrow::begin(ref mut pool,parent,ref table,0,1,3,0).is_ok);same_pool(ref pool,ref saved);same_owners(ref table,ref before);assert(size(slices::clear(ref mut pool,ref mut table,16))==2);
}

@test
fn void restore_authenticates_the_selected_range_session_and_latest_nested_ticket_atomically(){
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,4,ref mut data);let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,4,8));var reborrow::Loan outer=loan(reborrow::begin(ref mut pool,parent,ref table,1,3,8,0));var reborrow::Loan inner=loan(reborrow::begin(ref mut pool,outer.issued,ref table,0,1,8,1));
    let slices::Pool nested=pool;let reborrow::Loan original=outer;assert(!reborrow::restore(ref mut pool,ref mut outer,inner.issued,ref table,8).is_ok);same_pool(ref pool,ref nested);same_loan(ref outer,ref original);
    let slices::Ticket inner_ticket=inner.issued;let slices::Ticket now=ticket(reborrow::restore(ref mut pool,ref mut inner,inner_ticket,ref table,8));let slices::Pool saved=pool;let owners::Table before=table;
    var usize mode=0;while(mode<9){var reborrow::Loan bad=outer;if(mode==0){bad.active=false;}if(mode==1){bad.depth=31;}if(mode==2){bad.issued.slot=16;}if(mode==3){bad.parent.generation+=1;}if(mode==4){bad.selected.start=0;}if(mode==5){bad.parent.view.end=0;}if(mode==6){bad.selected.end=5;}if(mode==7){bad.selected.element=11;}if(mode==8){bad.parent.view.root.generation+=1;}let reborrow::Loan prior=bad;assert(!reborrow::restore(ref mut pool,ref mut bad,now,ref table,8).is_ok);same_pool(ref pool,ref saved);same_loan(ref bad,ref prior);mode+=1;}
    let slices::Ticket stale=outer.issued;assert(!reborrow::restore(ref mut pool,ref mut outer,stale,ref table,8).is_ok && !reborrow::restore(ref mut pool,ref mut outer,now,ref table,3).is_ok);same_pool(ref pool,ref saved);same_owners(ref table,ref before);same_loan(ref outer,ref original);
    let slices::Ticket restored=ticket(reborrow::restore(ref mut pool,ref mut outer,now,ref table,8));assert(!reborrow::restore(ref mut pool,ref mut outer,restored,ref table,8).is_ok && slices::close(ref mut pool,restored,ref mut table,8).is_ok);
}

@test
fn void generation_reserves_never_wrap_and_closed_owner_epochs_cannot_be_resurrected(){
    var usize mode=0;while(mode<2){var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,1,ref mut data);let slices::Ticket initial=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,8));let usize depth=if(mode==0){0}else{30};pool.slots[initial.slot].generation=18446744073709551615-(depth+1);let slices::Ticket exhausted=slices::Ticket{.slot=initial.slot,.generation=pool.slots[initial.slot].generation};let slices::Pool saved=pool;
        assert(!reborrow::begin(ref mut pool,exhausted,ref table,0,1,8,depth).is_ok);same_pool(ref pool,ref saved);pool.slots[initial.slot].generation-=1;let slices::Ticket parent=slices::Ticket{.slot=initial.slot,.generation=pool.slots[initial.slot].generation};var reborrow::Loan receipt=loan(reborrow::begin(ref mut pool,parent,ref table,0,1,8,depth));let slices::Ticket child=receipt.issued;assert(!reborrow::begin(ref mut pool,child,ref table,0,1,8,depth+1).is_ok);
        let slices::Pool allowed=pool;pool.slots[child.slot].generation=18446744073709551615;let slices::Ticket last=slices::Ticket{.slot=child.slot,.generation=18446744073709551615};let slices::Pool terminal=pool;let reborrow::Loan prior=receipt;assert(!reborrow::restore(ref mut pool,ref mut receipt,last,ref table,8).is_ok);same_pool(ref pool,ref terminal);same_loan(ref receipt,ref prior);pool.slots=allowed.slots;
        let slices::Ticket restored=ticket(reborrow::restore(ref mut pool,ref mut receipt,child,ref table,8));assert(restored.generation==18446744073709551615-depth && slices::close(ref mut pool,restored,ref mut table,8).is_ok);if(depth==0){assert(pool.slots[restored.slot].generation==0);}mode+=1;
    }
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();let owners::Token root=create(ref mut table,10,4,ref mut data);let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,0,4,8));var reborrow::Loan receipt=loan(reborrow::begin(ref mut pool,parent,ref table,1,2,8,0));assert(slices::close(ref mut pool,receipt.issued,ref mut table,8).is_ok);let slices::Ticket replacement=ticket(slices::open_exclusive(ref mut pool,ref mut table,root,1,2,8));let slices::Pool before=pool;let reborrow::Loan copy=receipt;assert(!reborrow::restore(ref mut pool,ref mut receipt,replacement,ref table,8).is_ok);same_pool(ref pool,ref before);same_loan(ref receipt,ref copy);assert(slices::clear(ref mut pool,ref mut table,8).is_ok);
}

@test
fn void full_pool_reborrows_need_no_extra_slot_and_abort_drain_is_atomic_and_keeps_writes(){
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);var slices::Pool pool=slices::empty();var reborrow::Loan[16] receipts=[reborrow::empty();16];var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16];var usize i=0;
    while(i<16){roots[i]=create(ref mut table,10,1,ref mut data);let slices::Ticket parent=ticket(slices::open_exclusive(ref mut pool,ref mut table,roots[i],0,1,16));receipts[i]=loan(reborrow::begin(ref mut pool,parent,ref table,0,1,16,0));assert(slices::write(ref pool,receipts[i].issued,ref table,0,42,ref mut data).is_ok);i+=1;}
    let usize used=table.arena.used;let usize depth=table.depth;let slices::Slot entry=pool.slots[15];pool.slots[15].view.end=2;let slices::Pool bad=pool;let owners::Table before=table;let reborrow::Loan first=receipts[0];assert(!reborrow::finish(ref mut pool,ref mut receipts,ref mut table,16).is_ok);same_pool(ref pool,ref bad);same_owners(ref table,ref before);same_loan(ref receipts[0],ref first);pool.slots[15]=entry;
    assert(size(reborrow::finish(ref mut pool,ref mut receipts,ref mut table,16))==16 && table.arena.used==used && table.depth==depth);i=0;while(i<16){assert(!receipts[i].active && !pool.slots[i].live && !table.slots[roots[i].slot].writing && cell(owners::read(ref table,roots[i],0,ref data))==42);i+=1;}
}
