module tests::m2::array_write_leases;
import array_owners as owners;
import array_layout as layouts;
import array_slices as slices;
import struct_layout as records;

fn layouts::Array shape(u8 tag, usize count) {
    return switch (layouts::scalar(tag,count)) {
        case .ok(v): { v } case .err(_): { assert(false); layouts::Array{.element=10,.length=0,.stride=1,.alignment=1,.bytes=0} }
    };
}
fn owners::Token create(ref mut owners::Table table, u8 tag, usize count, ref mut u8[] data) {
    let layouts::Array a=shape(tag,count);
    return switch (owners::create(ref a,0,data,table)) {
        case .ok(v): { v } case .err(_): { assert(false); owners::Token{.slot=16,.generation=0} }
    };
}
fn owners::WriteLease begin(ref mut owners::Table table, owners::Token root, usize start, usize end, usize capacity) {
    return switch (owners::begin_write(table,root,start,end,capacity)) {
        case .ok(v): { v } case .err(_): { assert(false); owners::WriteLease{.view=owners::View{.root=root,.element=10,.length=0,.start=0,.end=0},.generation=0} }
    };
}
fn i64 cell(Result<i64,owners::Error> r) { return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}}; }
fn void same(ref owners::Table a, ref owners::Table b, ref u8[] data, ref u8[] saved) {
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;
    while(i<16){
        let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.live==y.live && x.occupied==y.occupied);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;
    }
    assert(data.len==saved.len);i=0;while(i<data.len){assert(data[i]==saved[i]);i+=1;}
}

@test
fn void all_six_scalar_tags_write_selected_ranges_without_new_storage() {
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];
    var usize i=0;
    while(i<6){
        var u8[32] data=[0;32];var owners::Table table=owners::empty(32);
        let owners::Token root=create(ref mut table,tags[i],3,ref mut data);
        let usize used=table.arena.used;
        let owners::WriteLease lease=begin(ref mut table,root,1,2,32);
        assert(owners::exclusive_length(ref table,ref lease,32).is_ok);
        assert(owners::exclusive_write(ref table,ref lease,0,values[i],ref mut data).is_ok);
        assert(cell(owners::exclusive_read(ref table,ref lease,0,ref data))==values[i]);
        assert(!owners::exclusive_read(ref table,ref lease,1,ref data).is_ok);
        assert(table.arena.used==used && table.depth==1);
        assert(owners::end_write(ref mut table,ref lease,32).is_ok);
        assert(cell(owners::read(ref table,root,0,ref data))==0);
        assert(cell(owners::read(ref table,root,1,ref data))==values[i]);
        assert(cell(owners::read(ref table,root,2,ref data))==0);i+=1;
    }
}

@test
fn void exclusive_session_blocks_direct_access_copy_batches_and_cleanup_atomically() {
    var u8[32] data=[0;32];var owners::Table table=owners::empty(32);
    let owners::Token root=create(ref mut table,10,2,ref mut data);
    let owners::Token other=create(ref mut table,10,2,ref mut data);
    let owners::View v=switch(owners::view(ref table,root,0,2,32)){case .ok(v):{v}case .err(_):{assert(false);owners::View{.root=root,.element=10,.length=2,.start=0,.end=2}}};
    let owners::WriteLease lease=begin(ref mut table,root,0,2,32);
    let owners::Table before=table;let u8[32] saved=data;
    assert(!owners::read(ref table,root,0,ref data).is_ok);
    assert(!owners::view_read(ref table,ref v,0,ref data).is_ok);
    assert(!owners::view_length(ref table,ref v,32).is_ok);
    assert(!owners::subview(ref table,ref v,0,1,32).is_ok);
    assert(!owners::utf8_valid(ref table,root,2,ref data).is_ok);
    assert(!owners::view_utf8(ref table,ref v,ref data).is_ok);
    assert(!owners::view(ref table,root,0,1,32).is_ok);
    assert(!owners::begin_read(ref mut table,root,32).is_ok);
    assert(!owners::begin_write(ref mut table,root,0,0,32).is_ok);
    assert(!owners::write(ref table,root,0,42,ref mut data).is_ok);
    assert(!owners::fill(ref table,root,42,ref mut data).is_ok);
    assert(!owners::copy(root,ref mut data,ref mut table).is_ok);
    assert(!owners::assign(root,other,ref mut data,ref table).is_ok);
    assert(!owners::assign(other,root,ref mut data,ref table).is_ok);
    assert(!owners::validate_result(ref table,root,10,2,ref data).is_ok);
    assert(!owners::release(ref mut table,root,32).is_ok);
    assert(!owners::clear(ref mut table,32).is_ok);
    let owners::Token[2] sources=[other,root];let layouts::Array[2] shapes=[shape(10,2);2];
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    let records::Catalog catalog=records::empty();
    let owners::CallArgument[2] args=[owners::CallArgument{.source=other,.element=10,.length=2,.record=0},owners::CallArgument{.source=root,.element=10,.length=2,.record=0}];
    assert(!owners::copy_call_arguments(ref catalog,ref args,ref mut data,ref mut table).is_ok);
    var slices::Pool pool=slices::empty();
    assert(!slices::open(ref mut pool,ref mut table,root,0,1,32).is_ok);
    same(ref table,ref before,ref data,ref saved);
    assert(owners::write(ref table,other,0,42,ref mut data).is_ok);
    assert(owners::end_write(ref mut table,ref lease,32).is_ok);
    assert(owners::clear(ref mut table,32).is_ok);
}

@test
fn void old_tickets_cannot_access_or_close_new_read_or_write_sessions() {
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);
    let owners::Token root=create(ref mut table,10,2,ref mut data);
    let owners::WriteLease old=begin(ref mut table,root,0,2,8);let owners::WriteLease copied=old;
    assert(owners::end_write(ref mut table,ref old,8).is_ok);
    let owners::ReadLease reader=switch(owners::begin_read(ref mut table,root,8)){case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=root,.generation=0}}};
    assert(!owners::end_write(ref mut table,ref copied,8).is_ok);
    assert(!owners::begin_write(ref mut table,root,0,2,8).is_ok);
    assert(owners::end_read(ref mut table,reader,8).is_ok);
    let owners::WriteLease current=begin(ref mut table,root,0,2,8);
    let owners::Table before=table;let u8[8] saved=data;
    assert(!owners::exclusive_write(ref table,ref old,0,42,ref mut data).is_ok);
    assert(!owners::exclusive_read(ref table,ref old,0,ref data).is_ok);
    assert(!owners::end_write(ref mut table,ref old,8).is_ok);
    assert(!owners::end_read(ref mut table,reader,8).is_ok);
    same(ref table,ref before,ref data,ref saved);
    assert(owners::end_write(ref mut table,ref current,8).is_ok);
    assert(owners::release(ref mut table,root,8).is_ok);
    let owners::Token replacement=create(ref mut table,10,2,ref mut data);
    let owners::WriteLease fresh=begin(ref mut table,replacement,0,2,8);
    assert(!owners::end_write(ref mut table,ref current,8).is_ok);
    assert(owners::end_write(ref mut table,ref fresh,8).is_ok);
}

@test
fn void invalid_values_bounds_shapes_and_backing_preserve_bytes_and_session() {
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);
    let owners::Token root=create(ref mut table,2,2,ref mut data);
    let owners::WriteLease lease=begin(ref mut table,root,0,2,8);
    let owners::Table before=table;let u8[8] saved=data;
    assert(!owners::exclusive_write(ref table,ref lease,0,2,ref mut data).is_ok);
    assert(!owners::exclusive_write(ref table,ref lease,2,1,ref mut data).is_ok);
    assert(!owners::exclusive_write(ref table,ref lease,0,1,ref mut data[..1]).is_ok);
    assert(!owners::end_write(ref mut table,ref lease,1).is_ok);
    var owners::WriteLease bad=lease;bad.view.element=10;
    assert(!owners::exclusive_length(ref table,ref bad,8).is_ok);
    bad=lease;bad.view.length=3;assert(!owners::exclusive_read(ref table,ref bad,0,ref data).is_ok);
    bad=lease;bad.view.end=3;assert(!owners::end_write(ref mut table,ref bad,8).is_ok);
    bad=lease;bad.view.start=18446744073709551615;
    assert(!owners::exclusive_write(ref table,ref bad,0,1,ref mut data).is_ok);
    same(ref table,ref before,ref data,ref saved);
    data[0]=2;assert(!owners::exclusive_read(ref table,ref lease,0,ref data).is_ok);
    assert(owners::exclusive_write(ref table,ref lease,0,1,ref mut data).is_ok);
    assert(owners::end_write(ref mut table,ref lease,8).is_ok);
}

@test
fn void empty_ranges_lock_roots_and_epoch_exhaustion_never_wraps() {
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);
    let owners::Token root=create(ref mut table,10,1,ref mut data);
    let owners::Table before=table;let u8[8] saved=data;
    assert(!owners::begin_write(ref mut table,root,2,1,8).is_ok);
    assert(!owners::begin_write(ref mut table,root,1,2,8).is_ok);
    same(ref table,ref before,ref data,ref saved);
    table.slots[root.slot].read_generation=18446744073709551615;
    let owners::WriteLease last=begin(ref mut table,root,1,1,8);
    assert(!owners::read(ref table,root,0,ref data).is_ok);
    assert(!owners::exclusive_write(ref table,ref last,0,1,ref mut data).is_ok);
    assert(!owners::clear(ref mut table,8).is_ok);
    assert(owners::exclusive_length(ref table,ref last,8).is_ok);
    assert(owners::end_write(ref mut table,ref last,8).is_ok);
    assert(table.slots[root.slot].read_generation==0);
    assert(!owners::begin_write(ref mut table,root,1,1,8).is_ok);
    assert(!owners::begin_read(ref mut table,root,8).is_ok);
    assert(owners::fill(ref table,root,1,ref mut data).is_ok);
    assert(owners::release(ref mut table,root,8).is_ok);
    let owners::Token replacement=create(ref mut table,10,1,ref mut data);
    let owners::WriteLease next=begin(ref mut table,replacement,1,1,8);
    assert(!owners::end_write(ref mut table,ref last,8).is_ok);
    assert(owners::end_write(ref mut table,ref next,8).is_ok);
}

@test
fn void impossible_session_metadata_and_record_roots_are_rejected() {
    var u8[16] data=[0;16];var owners::Table table=owners::empty(16);
    let owners::Token root=create(ref mut table,10,1,ref mut data);
    let owners::WriteLease lease=begin(ref mut table,root,0,1,16);
    table.slots[root.slot].reading=true;
    assert(!owners::exclusive_length(ref table,ref lease,16).is_ok);
    table.slots[root.slot].reading=false;
    table.slots[15].writing=true;
    assert(!owners::end_write(ref mut table,ref lease,16).is_ok);
    table.slots[15].writing=false;
    assert(owners::end_write(ref mut table,ref lease,16).is_ok);
    var records::Catalog catalog=records::empty();catalog.count=1;catalog.fields[0]=1;catalog.types[0]=10;
    let i64[1] fields=[42];
    let owners::Token record=switch(owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table)){case .ok(v):{v}case .err(_):{assert(false);root}};
    let owners::Table before=table;let u8[16] saved=data;
    assert(!owners::begin_write(ref mut table,record,0,1,16).is_ok);
    same(ref table,ref before,ref data,ref saved);
}
