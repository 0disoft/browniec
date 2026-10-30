module tests::m2::slice_arguments;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import compiler as compiler;

fn slices::Ticket ticket(Result<slices::Ticket, owners::Error> r) {
    return switch (r) { case .ok(v): { v } case .err(_): { assert(false); slices::Ticket { .slot = 16, .generation = 0 } } };
}
fn owners::Token token(Result<owners::Token, owners::Error> r) {
    return switch (r) { case .ok(v): { v } case .err(_): { assert(false); owners::Token { .slot = 16, .generation = 0 } } };
}
fn usize size(Result<usize, owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn i64 value(Result<i64, owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn bool utf8(Result<bool, owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); false } }; }
fn owners::Token create(ref mut owners::Table table, u8 tag, usize n, i64 fill, ref mut u8[] data) {
    let layouts::Array shape = switch(layouts::scalar(tag,n)) { case .ok(v): { v } case .err(_): { assert(false); layouts::Array { .element=10,.length=1,.stride=1,.alignment=1,.bytes=1 } } };
    return token(owners::create(ref shape,fill,data,table));
}
fn void same_pool(ref slices::Pool a, ref slices::Pool b) {
    var usize i=0; while(i<16) {
        let slices::Slot x=a.slots[i]; let slices::Slot y=b.slots[i];
        assert(x.live==y.live && x.generation==y.generation);
        assert(x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation);
        assert(x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end);
        assert(x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation); i+=1;
    }
}
fn void same_owners(ref owners::Table a, ref owners::Table b, ref u8[] data, ref u8[] saved) {
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0; while(i<16) {
        let owners::Owner x=a.slots[i]; let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.live==y.live && x.occupied==y.occupied);
        assert(x.reading==y.reading && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment); i+=1;
    }
    assert(data.len==saved.len); i=0; while(i<data.len) { assert(data[i]==saved[i]); i+=1; }
}

fn slices::Arguments arguments(Result<slices::Arguments,owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); slices::empty_arguments() } }; }
fn void same_batch(ref slices::Arguments a,ref slices::Arguments b) {
    assert(a.count==b.count); var usize i=0; while(i<8) { assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation); i+=1; }
}
fn void rejected_close(ref mut slices::Pool pool,ref mut slices::Arguments batch,ref mut owners::Table table,usize capacity) {
    let slices::Pool before=slices::Pool{.slots=pool.slots}; let owners::Table owner_before=owners::Table{.slots=table.slots,.order=table.order,.depth=table.depth,.arena=table.arena}; let slices::Arguments saved=slices::Arguments{.tickets=batch.tickets,.count=batch.count};
    assert(!slices::close_arguments(pool,batch,table,capacity).is_ok);
    same_pool(pool,ref before); let u8[1] data=[0]; same_owners(table,ref owner_before,ref data,ref data); same_batch(batch,ref saved);
}

@test
fn void duplicated_mixed_and_empty_arguments_get_independent_ranges_without_payload_copies() {
    var u8[16] data=[0;16]; var owners::Table table=owners::empty(16); var slices::Pool pool=slices::empty();
    let owners::Token a=create(ref mut table,10,6,65,ref mut data); let owners::Token b=create(ref mut table,10,2,255,ref mut data);
    let slices::Ticket parent=ticket(slices::open(ref mut pool,ref mut table,a,1,4,16));
    let slices::Ticket empty=ticket(slices::open(ref mut pool,ref mut table,b,2,2,16));
    let slices::Ticket[3] source=[parent,parent,empty]; let owners::Table before=table; let u8[16] saved=data;
    var slices::Arguments batch=arguments(slices::borrow_arguments(ref mut pool,ref source,ref table,16));
    assert(batch.count==3 && batch.tickets[0].slot!=batch.tickets[1].slot && batch.tickets[0].slot!=parent.slot);
    assert(size(slices::length(ref pool,batch.tickets[0],ref table,16))==3 && size(slices::length(ref pool,batch.tickets[2],ref table,16))==0);
    assert(value(slices::read(ref pool,batch.tickets[1],ref table,2,ref data))==65 && utf8(slices::utf8(ref pool,batch.tickets[2],ref table,ref data)));
    same_owners(ref table,ref before,ref data,ref saved);
    assert(slices::close(ref mut pool,parent,ref mut table,16).is_ok && table.slots[a.slot].reading);
    assert(value(slices::read(ref pool,batch.tickets[0],ref table,0,ref data))==65);
    assert(size(slices::close_arguments(ref mut pool,ref mut batch,ref mut table,16))==3 && batch.count==0);
    assert(!table.slots[a.slot].reading && table.slots[b.slot].reading && slices::length(ref pool,empty,ref table,16).is_ok);
    assert(slices::close(ref mut pool,empty,ref mut table,16).is_ok && owners::clear(ref mut table,16).is_ok);
}

@test
fn void late_invalid_future_or_excess_arguments_and_partial_capacity_never_publish_children() {
    var u8[4] data=[0;4]; var owners::Table table=owners::empty(4); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,1,42,ref mut data); let slices::Ticket parent=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4));
    let slices::Pool before=pool; let owners::Table locked=table; let u8[4] saved=data;
    // This ticket would become valid if earlier staged children were trusted as inputs.
    let slices::Ticket[2] future=[parent,slices::Ticket{.slot=1,.generation=1}];
    assert(!slices::borrow_arguments(ref mut pool,ref future,ref table,4).is_ok);
    same_pool(ref pool,ref before); same_owners(ref table,ref locked,ref data,ref saved);
    let slices::Ticket[9] too_many=[parent;9]; assert(!slices::borrow_arguments(ref mut pool,ref too_many,ref table,4).is_ok);
    let slices::Ticket[2] source=[parent,parent]; assert(!slices::borrow_arguments(ref mut pool,ref source,ref table,0).is_ok);
    same_pool(ref pool,ref before); same_owners(ref table,ref locked,ref data,ref saved);
    var usize i=1; while(i<14) { let slices::Ticket peer=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4)); i+=1; }
    let slices::Pool nearly_full=pool; let slices::Ticket[3] triple=[parent;3];
    assert(!slices::borrow_arguments(ref mut pool,ref triple,ref table,4).is_ok);
    same_pool(ref pool,ref nearly_full); same_owners(ref table,ref locked,ref data,ref saved);
    let usize ended=size(slices::clear(ref mut pool,ref mut table,4));
    assert(!slices::borrow_arguments(ref mut pool,ref source,ref table,4).is_ok && !table.slots[root.slot].reading);
}

@test
fn void batch_exit_is_atomic_consumes_only_its_handles_and_rejects_stale_or_duplicate_copies() {
    var u8[4] data=[0;4]; var owners::Table table=owners::empty(4); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,1,42,ref mut data); let slices::Ticket parent=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4));
    let slices::Ticket[2] source=[parent;2]; var slices::Arguments batch=arguments(slices::borrow_arguments(ref mut pool,ref source,ref table,4));
    var slices::Arguments bad=batch; bad.tickets[0].generation+=1;
    rejected_close(ref mut pool,ref mut bad,ref mut table,4);
    bad=batch; let slices::Ticket first=bad.tickets[0]; bad.tickets[1]=first; rejected_close(ref mut pool,ref mut bad,ref mut table,4);
    bad=batch; bad.count=9; rejected_close(ref mut pool,ref mut bad,ref mut table,4);
    bad=batch; bad.tickets[7]=parent; rejected_close(ref mut pool,ref mut bad,ref mut table,4);
    rejected_close(ref mut pool,ref mut batch,ref mut table,0);
    var slices::Arguments stale=batch;
    assert(size(slices::close_arguments(ref mut pool,ref mut batch,ref mut table,4))==2 && table.slots[root.slot].reading);
    assert(size(slices::close_arguments(ref mut pool,ref mut batch,ref mut table,4))==0);
    batch=arguments(slices::borrow_arguments(ref mut pool,ref source,ref table,4));
    rejected_close(ref mut pool,ref mut stale,ref mut table,4);
    assert(size(slices::close_arguments(ref mut pool,ref mut batch,ref mut table,4))==2);
    assert(slices::close(ref mut pool,parent,ref mut table,4).is_ok);
    let slices::Ticket newer=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4));
    rejected_close(ref mut pool,ref mut stale,ref mut table,4);
    assert(table.slots[root.slot].reading && slices::close(ref mut pool,newer,ref mut table,4).is_ok);
}

@test
fn void eight_arguments_full_pool_scalar_types_maximum_ranges_and_empty_batches_stay_bounded() {
    var u8[128] data=[0;128]; var owners::Table table=owners::empty(128); var slices::Pool pool=slices::empty();
    let u8[8] tags=[2,10,1,9,11,12,10,10]; let i64[8] values=[1,255,-2147483648,-9223372036854775808,4294967295,-1,42,65];
    var slices::Ticket[8] source=[slices::Ticket{.slot=16,.generation=0};8]; var usize i=0;
    while(i<8) { let owners::Token root=create(ref mut table,tags[i],1,values[i],ref mut data); source[i]=ticket(slices::open(ref mut pool,ref mut table,root,0,1,128)); i+=1; }
    let u8[128] saved=data; let owners::Table before=table;
    var slices::Arguments batch=arguments(slices::borrow_arguments(ref mut pool,ref source,ref table,128)); assert(batch.count==8);
    i=0; while(i<8) { assert(value(slices::read(ref pool,batch.tickets[i],ref table,0,ref data))==values[i]); i+=1; }
    same_owners(ref table,ref before,ref data,ref saved);
    assert(!slices::borrow_arguments(ref mut pool,ref source[..1],ref table,128).is_ok);
    assert(size(slices::close_arguments(ref mut pool,ref mut batch,ref mut table,128))==8);
    var slices::Arguments none=arguments(slices::borrow_arguments(ref mut pool,ref source[..0],ref table,128));
    assert(none.count==0 && size(slices::close_arguments(ref mut pool,ref mut none,ref mut table,128))==0);
    assert(size(slices::clear(ref mut pool,ref mut table,128))==8);
    var u8[4096] large=[0;4096]; var owners::Table big=owners::empty(4096); var slices::Pool ranges=slices::empty();
    let owners::Token root=create(ref mut big,10,4096,65,ref mut large); let slices::Ticket whole=ticket(slices::open(ref mut ranges,ref mut big,root,0,4096,4096));
    let slices::Ticket[1] input=[whole]; var slices::Arguments wide=arguments(slices::borrow_arguments(ref mut ranges,ref input,ref big,4096));
    assert(size(slices::length(ref ranges,wide.tickets[0],ref big,4096))==4096 && value(slices::read(ref ranges,wide.tickets[0],ref big,4095,ref large))==65);
    assert(size(slices::close_arguments(ref mut ranges,ref mut wide,ref mut big,4096))==1 && big.arena.used==4096 && big.depth==1);
    assert(!compiler::compile(b"module main;fn i32 f(ref u8[] p){return p[0] as i32;}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main;fn ref u8[] f(){let u8[1] a=[42;1];return ref a;}fn i32 main(){return 42;}").is_ok);
}
