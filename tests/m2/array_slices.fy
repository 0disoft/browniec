module tests::m2::array_slices;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_layout as records;

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

@test
fn void independent_handles_keep_the_root_locked_until_the_last_close() {
    var u8[12] data=[0;12]; var owners::Table table=owners::empty(12); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,4,65,ref mut data); let owners::Token other=create(ref mut table,10,2,66,ref mut data);
    let slices::Ticket parent=ticket(slices::open(ref mut pool,ref mut table,root,0,4,12));
    let slices::Ticket child=ticket(slices::subslice(ref mut pool,parent,ref table,1,3,12));
    let slices::Ticket peer=ticket(slices::open(ref mut pool,ref mut table,root,3,4,12));
    let slices::Ticket alias=parent;
    assert(size(slices::close(ref mut pool,parent,ref mut table,12))==parent.slot);
    assert(!slices::close(ref mut pool,alias,ref mut table,12).is_ok && table.slots[root.slot].reading);
    assert(size(slices::length(ref pool,child,ref table,12))==2 && value(slices::read(ref pool,child,ref table,1,ref data))==65);
    let owners::Table before=table; let u8[12] saved=data;
    assert(!owners::write(ref table,root,0,255,ref mut data).is_ok && !owners::fill(ref table,root,255,ref mut data).is_ok);
    assert(!owners::assign(root,other,ref mut data,ref table).is_ok && !owners::validate_result(ref table,root,10,4,ref data).is_ok);
    assert(!owners::release(ref mut table,root,12).is_ok && !owners::clear(ref mut table,12).is_ok);
    same_owners(ref table,ref before,ref data,ref saved);
    let owners::Token copied=token(owners::copy(root,ref mut data,ref mut table)); assert(!table.slots[copied.slot].reading);
    assert(slices::close(ref mut pool,peer,ref mut table,12).is_ok && table.slots[root.slot].reading);
    assert(slices::close(ref mut pool,child,ref mut table,12).is_ok && !table.slots[root.slot].reading);
    assert(owners::write(ref table,root,0,255,ref mut data).is_ok && owners::clear(ref mut table,12).is_ok);
}

@test
fn void nested_empty_and_utf8_ranges_retain_root_relative_bounds() {
    var u8[8] data=[0;8]; var owners::Table table=owners::empty(8); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,6,255,ref mut data);
    assert(owners::write(ref table,root,1,226,ref mut data).is_ok && owners::write(ref table,root,2,130,ref mut data).is_ok && owners::write(ref table,root,3,172,ref mut data).is_ok);
    let slices::Ticket all=ticket(slices::open(ref mut pool,ref mut table,root,0,6,8));
    let slices::Ticket euro=ticket(slices::subslice(ref mut pool,all,ref table,1,4,8));
    let slices::Ticket tail=ticket(slices::subslice(ref mut pool,euro,ref table,1,3,8));
    let slices::Ticket empty=ticket(slices::subslice(ref mut pool,euro,ref table,3,3,8));
    assert(!utf8(slices::utf8(ref pool,all,ref table,ref data)) && utf8(slices::utf8(ref pool,euro,ref table,ref data)));
    assert(!utf8(slices::utf8(ref pool,tail,ref table,ref data)) && utf8(slices::utf8(ref pool,empty,ref table,ref data)));
    assert(size(slices::length(ref pool,empty,ref table,8))==0 && !slices::read(ref pool,empty,ref table,0,ref data).is_ok);
    assert(value(slices::read(ref pool,tail,ref table,0,ref data))==130);
    assert(!slices::subslice(ref mut pool,euro,ref table,0,4,8).is_ok && !slices::subslice(ref mut pool,euro,ref table,3,2,8).is_ok);
    assert(!slices::subslice(ref mut pool,euro,ref table,0,18446744073709551615,8).is_ok);
    assert(size(slices::clear(ref mut pool,ref mut table,8))==4 && !table.slots[root.slot].reading);
    assert(!slices::utf8(ref pool,empty,ref table,ref data).is_ok && owners::clear(ref mut table,8).is_ok);
}

@test
fn void scalar_tags_and_maximum_length_use_no_payload_copy() {
    let u8[6] tags=[2,10,1,9,11,12]; let i64[6] cells=[1,255,-2147483648,-9223372036854775808,4294967295,-1];
    var usize i=0; while(i<6) {
        var u8[64] data=[85;64]; var owners::Table table=owners::empty(64); var slices::Pool pool=slices::empty();
        let owners::Token prefix=create(ref mut table,10,1,0,ref mut data);
        let owners::Token root=create(ref mut table,tags[i],3,cells[i],ref mut data); let u8[64] saved=data; let usize used=table.arena.used;
        let slices::Ticket part=ticket(slices::open(ref mut pool,ref mut table,root,1,3,64));
        assert(value(slices::read(ref pool,part,ref table,1,ref data))==cells[i]);
        assert(!slices::read(ref pool,part,ref table,2,ref data).is_ok && !slices::read(ref pool,part,ref table,18446744073709551615,ref data).is_ok);
        if(tags[i]!=10) { assert(!slices::utf8(ref pool,part,ref table,ref data).is_ok); }
        assert(table.depth==2 && table.arena.used==used); var usize j=0; while(j<64) { assert(data[j]==saved[j]); j+=1; }
        assert(slices::clear(ref mut pool,ref mut table,64).is_ok && owners::clear(ref mut table,64).is_ok); i+=1;
    }
    var u8[4096] data=[0;4096]; var owners::Table table=owners::empty(4096); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,4096,65,ref mut data);
    let slices::Ticket all=ticket(slices::open(ref mut pool,ref mut table,root,0,4096,4096));
    assert(utf8(slices::utf8(ref pool,all,ref table,ref data)) && value(slices::read(ref pool,all,ref table,4095,ref data))==65);
    assert(slices::clear(ref mut pool,ref mut table,4096).is_ok);
}

@test
fn void failed_creation_and_capacity_limits_preserve_both_tables() {
    var u8[32] data=[0;32]; var owners::Table table=owners::empty(32); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,2,65,ref mut data); let owners::Token other=create(ref mut table,10,1,66,ref mut data);
    let owners::Table before=table; let slices::Pool empty=pool; let u8[32] saved=data;
    assert(!slices::open(ref mut pool,ref mut table,root,2,1,32).is_ok && !slices::open(ref mut pool,ref mut table,root,0,3,32).is_ok);
    assert(!slices::open(ref mut pool,ref mut table,root,0,1,0).is_ok);
    same_pool(ref pool,ref empty); same_owners(ref table,ref before,ref data,ref saved);
    var usize i=0; while(i<16) { let slices::Ticket t=ticket(slices::open(ref mut pool,ref mut table,root,0,2,32)); assert(t.slot==i); i+=1; }
    let slices::Pool full=pool; let owners::Table locked=table;
    assert(!slices::open(ref mut pool,ref mut table,other,0,1,32).is_ok && !table.slots[other.slot].reading);
    let slices::Ticket first=slices::Ticket { .slot=0,.generation=1 };
    assert(!slices::subslice(ref mut pool,first,ref table,0,1,32).is_ok);
    same_pool(ref pool,ref full); same_owners(ref table,ref locked,ref data,ref saved);
    assert(size(slices::clear(ref mut pool,ref mut table,32))==16);
    let owners::ReadLease external=switch(owners::begin_read(ref mut table,root,32)) { case .ok(v): { v } case .err(_): { assert(false); owners::ReadLease{.root=root,.generation=0} } };
    let slices::Pool vacant=pool; let owners::Table leased=table;
    assert(!slices::open(ref mut pool,ref mut table,root,0,2,32).is_ok); same_pool(ref pool,ref vacant); same_owners(ref table,ref leased,ref data,ref saved);
    assert(owners::end_read(ref mut table,external,32).is_ok);
    var records::Catalog catalog=records::empty(); catalog.count=1; catalog.fields[0]=1; catalog.types[0]=10; let i64[1] fields=[42];
    let owners::Token record=token(owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table));
    assert(!slices::open(ref mut pool,ref mut table,record,0,1,32).is_ok);
    assert(!slices::open(ref mut pool,ref mut table,owners::Token{.slot=16,.generation=1},0,1,32).is_ok);
    assert(owners::clear(ref mut table,32).is_ok);
}

@test
fn void stale_handles_and_exhausted_generations_never_unlock_later_sessions() {
    var u8[4] data=[0;4]; var owners::Table table=owners::empty(4); var slices::Pool pool=slices::empty();
    let owners::Token root=create(ref mut table,10,1,65,ref mut data);
    let slices::Ticket old=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4));
    assert(slices::close(ref mut pool,old,ref mut table,4).is_ok);
    let slices::Ticket fresh=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4)); assert(fresh.generation!=old.generation);
    assert(!slices::close(ref mut pool,old,ref mut table,4).is_ok && !slices::length(ref pool,old,ref table,4).is_ok && table.slots[root.slot].reading);
    assert(slices::close(ref mut pool,fresh,ref mut table,4).is_ok);
    var slices::Slot exhausted=pool.slots[0]; exhausted.generation=18446744073709551615; pool.slots[0]=exhausted;
    let slices::Ticket last=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4)); assert(last.generation==18446744073709551615);
    assert(slices::close(ref mut pool,last,ref mut table,4).is_ok && pool.slots[0].generation==0);
    let slices::Ticket next=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4)); assert(next.slot==1);
    assert(!slices::close(ref mut pool,last,ref mut table,4).is_ok && slices::close(ref mut pool,next,ref mut table,4).is_ok);
    table.slots[root.slot].read_generation=18446744073709551615;
    let slices::Ticket final=ticket(slices::open(ref mut pool,ref mut table,root,0,1,4));
    let slices::Ticket child=ticket(slices::subslice(ref mut pool,final,ref table,0,0,4));
    assert(slices::close(ref mut pool,final,ref mut table,4).is_ok && slices::close(ref mut pool,child,ref mut table,4).is_ok);
    assert(table.slots[root.slot].read_generation==0 && !slices::open(ref mut pool,ref mut table,root,0,1,4).is_ok);
    assert(owners::release(ref mut table,root,4).is_ok); let owners::Token reused=create(ref mut table,10,1,66,ref mut data);
    let slices::Ticket live=ticket(slices::open(ref mut pool,ref mut table,reused,0,1,4));
    assert(!slices::read(ref pool,child,ref table,0,ref data).is_ok && value(slices::read(ref pool,live,ref table,0,ref data))==66);
    assert(slices::clear(ref mut pool,ref mut table,4).is_ok);
}

@test
fn void bad_metadata_and_short_backing_fail_without_partial_cleanup() {
    var u8[8] data=[0;8]; var owners::Table table=owners::empty(8); var slices::Pool pool=slices::empty();
    let owners::Token a=create(ref mut table,10,2,65,ref mut data); let owners::Token b=create(ref mut table,10,2,66,ref mut data);
    let slices::Ticket first=ticket(slices::open(ref mut pool,ref mut table,a,0,2,8)); let slices::Ticket second=ticket(slices::open(ref mut pool,ref mut table,b,0,2,8));
    let slices::Pool before=pool; let owners::Table locked=table; let u8[8] saved=data;
    assert(!slices::clear(ref mut pool,ref mut table,0).is_ok && !slices::close(ref mut pool,first,ref mut table,0).is_ok);
    let u8[3] short=[65;3];
    assert(!slices::read(ref pool,second,ref table,0,ref short).is_ok); same_pool(ref pool,ref before); same_owners(ref table,ref locked,ref data,ref saved);
    var usize i=0; while(i<7) {
        var slices::Slot bad=before.slots[second.slot];
        if(i==0) { bad.view.end=3; } else if(i==1) { bad.view.element=1; } else if(i==2) { bad.view.length=3; }
        else if(i==3) { bad.lease.generation=0; } else if(i==4) { bad.view.root=a; }
        else if(i==5) { bad.generation=0; } else { bad.view.start=18446744073709551615; }
        pool.slots[second.slot]=bad; let slices::Pool corrupt=pool;
        assert(!slices::clear(ref mut pool,ref mut table,8).is_ok && !slices::close(ref mut pool,first,ref mut table,8).is_ok);
        same_pool(ref pool,ref corrupt); same_owners(ref table,ref locked,ref data,ref saved); pool.slots=before.slots; i+=1;
    }
    let owners::ReadLease old=pool.slots[first.slot].lease; assert(owners::end_read(ref mut table,old,8).is_ok);
    let owners::ReadLease fresh=switch(owners::begin_read(ref mut table,a,8)) { case .ok(v): { v } case .err(_): { assert(false); old } };
    assert(!slices::clear(ref mut pool,ref mut table,8).is_ok && table.slots[a.slot].reading && table.slots[b.slot].reading);
    // Native caller fault injection is explicitly repaired; stale pool cannot end fresh.
    assert(owners::end_read(ref mut table,fresh,8).is_ok); table.slots[a.slot].read_generation=old.generation; table.slots[a.slot].reading=true;
    assert(size(slices::clear(ref mut pool,ref mut table,8))==2 && owners::clear(ref mut table,8).is_ok);
}

@test
fn void full_owner_table_and_external_sessions_remain_independent() {
    var u8[16] data=[0;16]; var owners::Table table=owners::empty(16); var slices::Pool pool=slices::empty();
    var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16]; var usize i=0;
    while(i<16) { roots[i]=create(ref mut table,10,1,65,ref mut data); i+=1; }
    let owners::Table before=table; let u8[16] saved=data;
    i=0; while(i<16) { let slices::Ticket t=ticket(slices::open(ref mut pool,ref mut table,roots[i],0,1,16)); assert(value(slices::read(ref pool,t,ref table,0,ref data))==65); i+=1; }
    assert(table.depth==16 && table.arena.used==16 && size(slices::clear(ref mut pool,ref mut table,16))==16);
    i=0; while(i<16) { assert(!table.slots[i].reading && table.slots[i].read_generation==before.slots[i].read_generation+1); i+=1; }
    let owners::ReadLease external=switch(owners::begin_read(ref mut table,roots[0],16)) { case .ok(v): { v } case .err(_): { assert(false); owners::ReadLease{.root=roots[0],.generation=0} } };
    let slices::Ticket own=ticket(slices::open(ref mut pool,ref mut table,roots[1],0,1,16));
    assert(size(slices::clear(ref mut pool,ref mut table,16))==1 && table.slots[0].reading && !table.slots[1].reading);
    assert(size(slices::clear(ref mut pool,ref mut table,16))==0 && table.slots[0].reading);
    assert(owners::end_read(ref mut table,external,16).is_ok); i=0; while(i<16) { assert(data[i]==saved[i]); i+=1; }
    assert(owners::clear(ref mut table,16).is_ok);
}
