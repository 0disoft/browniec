module tests::m2::array_assign_storage;
import array_owners as owners;
import array_layout as layouts;

fn layouts::Array layout(u8 tag, usize length) {
    return switch(layouts::scalar(tag,length)) {case .ok(a): {a} case .err(_): {assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
}
fn owners::Token created(ref layouts::Array a, i64 value, ref mut u8[] data, ref mut owners::Table table) {
    return switch(owners::create(a,value,data,table)) {case .ok(t): {t} case .err(_): {assert(false);owners::Token{.slot=0,.generation=0}}};
}
fn i64 read(ref owners::Table table, owners::Token t, usize index, ref u8[] data) {
    return switch(owners::read(table,t,index,data)) {case .ok(n): {n} case .err(_): {assert(false);0}};
}
fn void unchanged(ref u8[] data, ref u8[] before) {
    var usize i=0; while(i<data.len) {assert(data[i]==before[i]);i+=1;}
}
@test
fn void assignment_reuses_full_storage_and_preserves_independent_owners() {
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;
    while(i<6) {
        var u8[64] data=[85;64]; let layouts::Array a=layout(tags[i],3);
        var owners::Table table=owners::empty(a.bytes*2);
        let owners::Token source=created(ref a,values[i],ref mut data,ref mut table);
        let owners::Token target=created(ref a,0,ref mut data,ref mut table);
        assert(owners::assign(target,source,ref mut data,ref table).is_ok);
        assert(read(ref table,target,2,ref data)==values[i] && table.arena.used==a.bytes*2 && table.depth==2);
        assert(owners::write(ref table,source,0,0,ref mut data).is_ok);
        assert(read(ref table,target,0,ref data)==values[i]);
        assert(owners::assign(target,target,ref mut data,ref table).is_ok);
        assert(read(ref table,target,0,ref data)==values[i] && data[a.bytes*2]==85);
        assert(table.slots[target.slot].generation==target.generation);
        i+=1;
    }
    var u8[16] data=[0;16]; var owners::Table table=owners::empty(16);
    let layouts::Array a=layout(10,1);
    let owners::Token source=created(ref a,42,ref mut data,ref mut table);
    var owners::Token target=source; i=1;
    while(i<16) {target=created(ref a,0,ref mut data,ref mut table);i+=1;}
    assert(owners::assign(target,source,ref mut data,ref table).is_ok);
    assert(read(ref table,target,0,ref data)==42 && table.depth==16 && table.arena.used==16);
}
@test
fn void invalid_sources_leave_the_entire_destination_unchanged() {
    var u8[64] data=[85;64]; var owners::Table table=owners::empty(64);
    let layouts::Array a=layout(2,3); let layouts::Array shorter=layout(2,2); let layouts::Array byte=layout(10,3);
    let owners::Token source=created(ref a,1,ref mut data,ref mut table);
    let owners::Token target=created(ref a,0,ref mut data,ref mut table);
    let owners::Token short=created(ref shorter,0,ref mut data,ref mut table);
    let owners::Token other=created(ref byte,42,ref mut data,ref mut table);
    data[2]=2; let u8[64] corrupt=data;
    assert(!owners::assign(target,source,ref mut data,ref table).is_ok); unchanged(ref data,ref corrupt);
    assert(!owners::assign(source,source,ref mut data,ref table).is_ok); unchanged(ref data,ref corrupt);
    data[2]=1; let u8[64] before=data;
    assert(!owners::assign(target,short,ref mut data,ref table).is_ok); unchanged(ref data,ref before);
    assert(!owners::assign(target,other,ref mut data,ref table).is_ok); unchanged(ref data,ref before);
    assert(owners::release(ref mut table,source,data.len).is_ok);
    assert(!owners::assign(target,source,ref mut data,ref table).is_ok); unchanged(ref data,ref before);
    assert(!owners::assign(source,target,ref mut data,ref table).is_ok); unchanged(ref data,ref before);
    assert(read(ref table,target,2,ref data)==0 && table.depth==4 && table.arena.used==11);
}

@test fn void self_assignment_cannot_bypass_read_write_stale_or_overlapping_ledger_guards(){
    var u8[32] data=[85;32];var owners::Table table=owners::empty(32);let layouts::Array a=layout(1,2);
    let owners::Token token=created(ref a,42,ref mut data,ref mut table);let u8[32] before=data;
    let owners::ReadLease reader=switch(owners::begin_read(ref mut table,token,32)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(!owners::assign(token,token,ref mut data,ref table).is_ok);unchanged(ref data,ref before);
    assert(owners::end_read(ref mut table,reader,32).is_ok);
    let owners::WriteLease writer=switch(owners::begin_write(ref mut table,token,0,2,32)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(!owners::assign(token,token,ref mut data,ref table).is_ok);unchanged(ref data,ref before);
    assert(owners::end_write(ref mut table,ref writer,32).is_ok);
    var owners::Table forged=table;let owners::Owner duplicate=table.slots[0];
    forged.slots[1]=duplicate;forged.order[1]=1;forged.depth=2;
    assert(!owners::assign(token,token,ref mut data,ref forged).is_ok);unchanged(ref data,ref before);
    assert(owners::release(ref mut table,token,32).is_ok);
    assert(!owners::assign(token,token,ref mut data,ref table).is_ok);unchanged(ref data,ref before);
}
