module tests::m2::array_views;
import array_owners as owners;
import array_layout as layouts;
import struct_layout as records;

fn owners::Token token(Result<owners::Token,owners::Error> result) {
    return switch(result){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn owners::View span(Result<owners::View,owners::Error> result) {
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);owners::View{.root=owners::Token{.slot=16,.generation=0},.element=0,.length=0,.start=0,.end=0}}};
}
fn usize size(Result<usize,owners::Error> result) {
    return switch(result){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn i64 value(Result<i64,owners::Error> result) {
    return switch(result){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn bool valid_utf8(Result<bool,owners::Error> result) {
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);false}};
}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize length,i64 fill,ref mut u8[] bytes) {
    let layouts::Array shape=switch(layouts::scalar(tag,length)) {
        case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}
    };
    return token(owners::create(ref shape,fill,bytes,table));
}
fn void same(ref owners::Table a,ref owners::Table b,ref u8[] bytes,ref u8[] before) {
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){
        assert(a.order[i]==b.order[i]);
        assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].occupied==b.slots[i].occupied && a.slots[i].live==b.slots[i].live);
        assert(a.slots[i].mark==b.slots[i].mark && a.slots[i].base==b.slots[i].base && a.slots[i].end==b.slots[i].end);
        assert(a.slots[i].element==b.slots[i].element && a.slots[i].length==b.slots[i].length);
        assert(a.slots[i].record==b.slots[i].record && a.slots[i].alignment==b.slots[i].alignment);i+=1;
    }
    assert(bytes.len==before.len);i=0;while(i<bytes.len){assert(bytes[i]==before[i]);i+=1;}
}

@test
fn void scalar_views_use_element_indices_and_preserve_aligned_storage() {
    let u8[6] tags=[2,10,1,9,11,12];
    let i64[6] cells=[1,255,-2147483648,-9223372036854775808,4294967295,-1];
    var usize i=0;while(i<6){
        var u8[64] bytes=[85;64];var owners::Table table=owners::empty(64);
        let owners::Token prefix=create(ref mut table,10,1,65,ref mut bytes);
        let owners::Token root=create(ref mut table,tags[i],3,cells[i],ref mut bytes);
        let owners::Table before=table;let u8[64] saved=bytes;
        let owners::View v=span(owners::view(ref table,root,1,3,bytes.len));
        assert(size(owners::view_length(ref table,ref v,bytes.len))==2);
        assert(value(owners::view_read(ref table,ref v,0,ref bytes))==cells[i]);
        assert(value(owners::view_read(ref table,ref v,1,ref bytes))==cells[i]);
        assert(!owners::view_read(ref table,ref v,2,ref bytes).is_ok);
        assert(!owners::view_read(ref table,ref v,18446744073709551615,ref bytes).is_ok);
        let owners::View nested=span(owners::subview(ref table,ref v,1,2,bytes.len));
        assert(nested.start==2 && nested.end==3 && value(owners::view_read(ref table,ref nested,0,ref bytes))==cells[i]);
        same(ref table,ref before,ref bytes,ref saved);i+=1;
    }
}

@test
fn void utf8_scans_only_the_selected_live_bytes_including_empty_ranges() {
    var u8[6] bytes=[0;6];var owners::Table table=owners::empty(6);
    let owners::Token root=create(ref mut table,10,6,0,ref mut bytes);
    bytes[0]=255;bytes[1]=234;bytes[2]=176;bytes[3]=128;bytes[5]=255;
    let owners::Table before=table;let u8[6] saved=bytes;
    let owners::View good=span(owners::view(ref table,root,1,4,6));
    let owners::View parent=span(owners::view(ref table,root,1,5,6));
    let owners::View child=span(owners::subview(ref table,ref parent,0,3,6));
    let owners::View whole=span(owners::view(ref table,root,0,6,6));
    let owners::View truncated=span(owners::view(ref table,root,1,3,6));
    let owners::View continuation=span(owners::view(ref table,root,2,4,6));
    let owners::View empty=span(owners::subview(ref table,ref parent,4,4,6));
    let owners::View tail=span(owners::view(ref table,root,6,6,6));
    assert(valid_utf8(owners::view_utf8(ref table,ref good,ref bytes)) && valid_utf8(owners::view_utf8(ref table,ref child,ref bytes)));
    assert(!valid_utf8(owners::view_utf8(ref table,ref whole,ref bytes)));
    assert(!valid_utf8(owners::view_utf8(ref table,ref truncated,ref bytes)) && !valid_utf8(owners::view_utf8(ref table,ref continuation,ref bytes)));
    assert(size(owners::view_length(ref table,ref empty,6))==0 && valid_utf8(owners::view_utf8(ref table,ref empty,ref bytes)));
    assert(valid_utf8(owners::view_utf8(ref table,ref tail,ref bytes)) && !owners::view_read(ref table,ref empty,0,ref bytes).is_ok);
    same(ref table,ref before,ref bytes,ref saved);
    // This descriptor is not a shared loan: writes remain allowed and visible.
    assert(owners::write(ref table,root,1,255,ref mut bytes).is_ok);
    assert(!valid_utf8(owners::view_utf8(ref table,ref good,ref bytes)));
}

@test
fn void dropped_cleared_and_reused_roots_invalidate_even_empty_views() {
    var u8[4] bytes=[0;4];var owners::Table table=owners::empty(4);
    let owners::Token first=create(ref mut table,10,3,65,ref mut bytes);
    let owners::Token last=create(ref mut table,10,1,0,ref mut bytes);
    let owners::View v=span(owners::view(ref table,first,0,3,4));
    let owners::View empty=span(owners::view(ref table,first,3,3,4));
    assert(size(owners::release(ref mut table,first,4))==0);
    assert(!owners::view_length(ref table,ref v,0).is_ok && !owners::view_read(ref table,ref v,0,b"").is_ok);
    assert(!owners::view_utf8(ref table,ref empty,b"").is_ok && !owners::subview(ref table,ref v,0,0,0).is_ok);
    assert(size(owners::release(ref mut table,last,4))==4);
    let owners::Token reused=create(ref mut table,10,3,0,ref mut bytes);
    assert(reused.slot==first.slot && reused.generation!=first.generation);
    assert(!owners::view_read(ref table,ref v,0,ref bytes).is_ok && !owners::view_utf8(ref table,ref empty,ref bytes).is_ok);
    let owners::View fresh=span(owners::view(ref table,reused,0,0,4));
    assert(owners::clear(ref mut table,4).is_ok && !owners::view_utf8(ref table,ref fresh,b"").is_ok);
}

@test
fn void forged_shape_range_backing_and_record_tokens_are_rejected() {
    var u8[8] bytes=[0;8];var owners::Table table=owners::empty(8);
    let owners::Token root=create(ref mut table,10,4,65,ref mut bytes);
    let owners::View good=span(owners::view(ref table,root,0,4,8));var owners::View bad=good;
    assert(!owners::view(ref table,root,3,2,8).is_ok && !owners::view(ref table,root,0,5,8).is_ok);
    assert(!owners::view(ref table,root,18446744073709551615,18446744073709551615,8).is_ok);
    bad.element=2;assert(!owners::view_utf8(ref table,ref bad,ref bytes).is_ok);bad=good;
    bad.length=18446744073709551615;assert(!owners::view_length(ref table,ref bad,8).is_ok);bad=good;
    bad.start=18446744073709551615;bad.end=18446744073709551615;
    assert(!owners::subview(ref table,ref bad,0,0,8).is_ok && !owners::view_read(ref table,ref bad,0,ref bytes).is_ok);
    assert(!owners::subview(ref table,ref good,0,18446744073709551615,8).is_ok);
    assert(!owners::view_read(ref table,ref good,0,b"").is_ok && !owners::view_utf8(ref table,ref good,b"").is_ok);
    table.arena.used=3;assert(!owners::view_utf8(ref table,ref good,ref bytes).is_ok);table.arena.used=4;
    let owners::Token bits=create(ref mut table,2,1,1,ref mut bytes);
    let owners::View boolean=span(owners::view(ref table,bits,0,1,8));
    assert(!owners::view_utf8(ref table,ref boolean,ref bytes).is_ok);
    bytes[4]=2;assert(!owners::view_read(ref table,ref boolean,0,ref bytes).is_ok);
    var records::Catalog catalog=records::empty();catalog.count=1;catalog.fields[0]=1;catalog.types[0]=10;
    let i64[1] cells=[65];
    let owners::Token record=token(owners::create_record(ref catalog,0,ref cells,ref mut bytes,ref mut table));
    assert(!owners::view(ref table,record,0,1,8).is_ok);
}

@test
fn void descriptors_use_no_owner_slots_and_support_the_maximum_array() {
    var u8[16] bytes=[0;16];var owners::Table table=owners::empty(16);var owners::Token root=owners::Token{.slot=16,.generation=0};
    var usize i=0;while(i<16){root=create(ref mut table,10,1,65,ref mut bytes);i+=1;}
    let owners::Table before=table;let u8[16] saved=bytes;i=0;
    while(i<100){let owners::View v=span(owners::view(ref table,root,0,1,16));assert(value(owners::view_read(ref table,ref v,0,ref bytes))==65);i+=1;}
    same(ref table,ref before,ref bytes,ref saved);
    var u8[4096] large=[0;4096];var owners::Table big=owners::empty(4096);
    let owners::Token token=create(ref mut big,10,4096,65,ref mut large);
    let owners::View full=span(owners::view(ref big,token,0,4096,4096));
    let owners::View end=span(owners::subview(ref big,ref full,4095,4096,4096));
    assert(valid_utf8(owners::view_utf8(ref big,ref full,ref large)) && value(owners::view_read(ref big,ref end,0,ref large))==65);
    assert(big.depth==1 && big.arena.used==4096);
}
