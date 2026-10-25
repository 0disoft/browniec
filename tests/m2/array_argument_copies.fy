module tests::m2::array_argument_copies;

import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

fn layouts::Array layout(u8 tag, usize length) {
    return switch (layouts::scalar(tag, length)) {
        case .ok(a): { a } case .err(_): { assert(false); layouts::Array { .element=0,.length=0,.stride=0,.alignment=0,.bytes=0 } }
    };
}
fn owners::Token created(ref layouts::Array a, i64 value, ref mut u8[] data, ref mut owners::Table table) {
    return switch (owners::create(a,value,data,table)) {
        case .ok(t): { t } case .err(_): { assert(false); owners::Token { .slot=0,.generation=0 } }
    };
}
fn owners::Copies copied(ref owners::Token[] sources, ref layouts::Array[] shapes, ref mut u8[] data, ref mut owners::Table table) {
    return switch (owners::copy_arguments(sources,shapes,data,table)) {
        case .ok(c): { c } case .err(_): { assert(false); owners::Copies { .tokens=[owners::Token{.slot=0,.generation=0};8],.count=0 } }
    };
}
fn i64 read(ref owners::Table table, owners::Token t, usize index, ref u8[] data) {
    return switch (owners::read(table,t,index,data)) {
        case .ok(n): { n } case .err(_): { assert(false); 0 }
    };
}
fn void identical(ref owners::Table table, ref owners::Table before, ref u8[] data, ref u8[] bytes) {
    assert(table.depth==before.depth && table.arena.used==before.arena.used && table.arena.limit==before.arena.limit);
    var usize i=0;
    while (i<16) {
        assert(table.order[i]==before.order[i]);
        let owners::Owner a=table.slots[i]; let owners::Owner b=before.slots[i];
        assert(a.generation==b.generation && a.occupied==b.occupied && a.live==b.live);
        assert(a.mark==b.mark && a.base==b.base && a.end==b.end && a.element==b.element && a.length==b.length);
        i+=1;
    }
    assert(data.len==bytes.len); i=0;
    while (i<data.len) { assert(data[i]==bytes[i]); i+=1; }
}

@test
fn void all_elements_and_repeated_sources_produce_independent_copies() {
    let u8[6] tags=[2,10,1,9,11,12];
    let i64[6] values=[1,255,-2147483648,-9223372036854775808,4294967295,-1];
    var usize i=0;
    while (i<6) {
        var u8[80] data=[85;80]; var owners::Table table=owners::empty(80);
        let layouts::Array a=layout(tags[i],3);
        let owners::Token source=created(ref a,values[i],ref mut data,ref mut table);
        let owners::Token[2] sources=[source,source]; let layouts::Array[2] shapes=[a,a];
        let owners::Copies copies=copied(ref sources,ref shapes,ref mut data,ref mut table);
        assert(copies.count==2 && table.depth==3 && table.arena.used==a.bytes*3);
        assert(copies.tokens[0].slot!=source.slot && copies.tokens[1].slot!=copies.tokens[0].slot);
        assert(owners::write(ref table,source,0,0,ref mut data).is_ok);
        assert(read(ref table,copies.tokens[0],0,ref data)==values[i]);
        assert(owners::write(ref table,copies.tokens[0],1,0,ref mut data).is_ok);
        assert(read(ref table,copies.tokens[1],1,ref data)==values[i]);
        assert(data[a.bytes*3]==85 && copies.tokens[2].generation==0);
        assert(owners::release(ref mut table,copies.tokens[1],data.len).is_ok);
        assert(owners::release(ref mut table,copies.tokens[0],data.len).is_ok);
        assert(table.depth==1 && table.arena.used==a.bytes && read(ref table,source,2,ref data)==values[i]);
        i+=1;
    }
}

@test
fn void combined_peak_includes_existing_extents_and_alignment() {
    var u8[48] data=[85;48]; var owners::Table table=owners::empty(31);
    let layouts::Array small=layout(10,3); let layouts::Array wide=layout(9,1);
    let owners::Token a=created(ref small,42,ref mut data,ref mut table);
    let owners::Token b=created(ref wide,99,ref mut data,ref mut table);
    let owners::Token[2] sources=[a,b]; let layouts::Array[2] shapes=[small,wide];
    let owners::Table before=table; let u8[48] bytes=data;
    // Source prefix 16, byte copy ends at 19, aligned wide copy ends at 32.
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    table.arena.limit=32;
    let owners::Copies copies=copied(ref sources,ref shapes,ref mut data,ref mut table);
    assert(table.arena.used==32 && table.depth==4);
    assert(table.slots[copies.tokens[0].slot].base==16 && table.slots[copies.tokens[1].slot].base==24);
    var usize i=19; while(i<24) {assert(data[i]==0);i+=1;}
    assert(data[32]==85 && read(ref table,copies.tokens[1],0,ref data)==99);
}

@test
fn void late_shape_token_and_bool_errors_leave_all_state_untouched() {
    var u8[64] data=[85;64]; var owners::Table table=owners::empty(64);
    let layouts::Array byte=layout(10,2); let layouts::Array boolean=layout(2,2);
    let owners::Token a=created(ref byte,42,ref mut data,ref mut table);
    let owners::Token b=created(ref boolean,1,ref mut data,ref mut table);
    var owners::Token[2] sources=[a,b]; var layouts::Array[2] shapes=[byte,boolean];
    let owners::Table before=table; let u8[64] bytes=data;
    shapes[1]=byte;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    shapes[1]=layout(2,1);
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    shapes[1]=boolean; shapes[1].bytes=1;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    shapes[1]=boolean; sources[1]=owners::Token{.slot=b.slot,.generation=b.generation+1};
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    sources[1]=b; data[3]=2; let u8[64] corrupt=data;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref corrupt);
    data[3]=1;
    assert(owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
}

@test
fn void owner_pressure_retirement_and_deferred_holes_are_accounted() {
    var u8[64] data=[85;64]; var owners::Table table=owners::empty(64);
    let layouts::Array a=layout(10,1);
    let owners::Token source=created(ref a,42,ref mut data,ref mut table);
    var usize i=1; while(i<15) {let owners::Token next=created(ref a,0,ref mut data,ref mut table);i+=1;}
    let owners::Token[2] sources=[source,source]; let layouts::Array[2] shapes=[a,a];
    let owners::Table before=table; let u8[64] bytes=data;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    table=owners::empty(64); table.slots[15].generation=0;
    let owners::Token retained=created(ref a,42,ref mut data,ref mut table);
    i=1; while(i<14) {let owners::Token next=created(ref a,0,ref mut data,ref mut table);i+=1;}
    let owners::Table retired=table; let u8[64] retired_bytes=data;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref retired,ref data,ref retired_bytes);
    assert(read(ref table,retained,0,ref data)==42);
    table=owners::empty(4);
    let owners::Token first=created(ref a,42,ref mut data,ref mut table);
    let owners::Token middle=created(ref a,0,ref mut data,ref mut table);
    let owners::Token last=created(ref a,0,ref mut data,ref mut table);
    assert(owners::release(ref mut table,middle,data.len).is_ok);
    let owners::Table hole=table; let u8[64] hole_bytes=data;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref hole,ref data,ref hole_bytes);
    assert(owners::release(ref mut table,last,data.len).is_ok);
    let owners::Copies copies=copied(ref sources,ref shapes,ref mut data,ref mut table);
    assert(table.depth==3 && read(ref table,first,0,ref data)==42 && copies.count==2);
}

@test
fn void provisional_destinations_cannot_become_sources_and_stale_tokens_stay_stale() {
    var u8[32] data=[85;32]; var owners::Table table=owners::empty(32);
    let layouts::Array a=layout(10,1);
    let owners::Token source=created(ref a,42,ref mut data,ref mut table);
    var owners::Token[2] sources=[source,owners::Token{.slot=1,.generation=1}];
    let layouts::Array[2] shapes=[a,a]; let owners::Table before=table; let u8[32] bytes=data;
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    sources[1]=source;
    let owners::Copies first=copied(ref sources,ref shapes,ref mut data,ref mut table);
    assert(owners::release(ref mut table,first.tokens[1],data.len).is_ok);
    assert(owners::release(ref mut table,first.tokens[0],data.len).is_ok);
    let owners::Copies second=copied(ref sources,ref shapes,ref mut data,ref mut table);
    assert(first.tokens[0].slot==second.tokens[0].slot && first.tokens[0].generation!=second.tokens[0].generation);
    assert(!owners::read(ref table,first.tokens[0],0,ref data).is_ok);
    assert(read(ref table,second.tokens[0],0,ref data)==42);
}

@test
fn void empty_eight_and_invalid_batches_and_corrupt_tables_are_bounded() {
    var u8[32] data=[85;32]; var owners::Table table=owners::empty(32);
    let layouts::Array a=layout(10,1);
    let owners::Token source=created(ref a,42,ref mut data,ref mut table);
    let owners::Token[9] sources=[source;9]; let layouts::Array[9] shapes=[a;9];
    let owners::Table before=table; let u8[32] bytes=data;
    let owners::Copies empty=copied(ref sources[..0],ref shapes[..0],ref mut data,ref mut table);
    assert(empty.count==0 && empty.tokens[0].generation==0); identical(ref table,ref before,ref data,ref bytes);
    assert(!owners::copy_arguments(ref sources,ref shapes,ref mut data,ref mut table).is_ok);
    assert(!owners::copy_arguments(ref sources[..1],ref shapes[..0],ref mut data,ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    table.arena.used=2; let owners::Table corrupt=table;
    assert(!owners::copy_arguments(ref sources[..1],ref shapes[..1],ref mut data,ref mut table).is_ok);
    identical(ref table,ref corrupt,ref data,ref bytes);
    table=before;
    assert(!owners::copy_arguments(ref sources[..1],ref shapes[..1],ref mut data[..0],ref mut table).is_ok);
    identical(ref table,ref before,ref data,ref bytes);
    let owners::Copies eight=copied(ref sources[..8],ref shapes[..8],ref mut data,ref mut table);
    assert(eight.count==8 && table.depth==9 && table.arena.used==9);
    assert(read(ref table,eight.tokens[7],0,ref data)==42 && data[9]==85);
    table=owners::empty(32); var owners::Token[8] unique=[source;8];
    var usize i=0;
    while(i<8) {unique[i]=created(ref a,42,ref mut data,ref mut table);i+=1;}
    let owners::Copies full=copied(ref unique,ref shapes[..8],ref mut data,ref mut table);
    assert(full.count==8 && table.depth==16 && table.arena.used==16);
    assert(full.tokens[7].slot==15 && read(ref table,unique[7],0,ref data)==42);
    assert(read(ref table,full.tokens[7],0,ref data)==42);
}

@test
fn void maximum_payload_reservations_use_old_plus_new_peak() {
    var bytes::Buffer buffer=switch(bytes::with_capacity(65536)) {
        case .ok(b): {b} case .err(_): {assert(false);bytes::empty()}
    };
    assert(bytes::resize_zeroed(ref mut buffer,65536).is_ok);
    let ref mut u8[] data=bytes::view_mut(ref mut buffer);
    var owners::Table table=owners::empty(65536);
    let layouts::Array a=layout(9,4096);
    let owners::Token source=created(ref a,-9223372036854775808,data,ref mut table);
    let owners::Token[2] sources=[source,source]; let layouts::Array[2] shapes=[a,a];
    let owners::Table before=table;
    assert(!owners::copy_arguments(ref sources,ref shapes,data,ref mut table).is_ok);
    identical(ref table,ref before,data,data);
    var usize i=0;
    while(i<data.len) {
        assert(data[i]==if(i<32768 && i%8==7){128}else{0}); i+=1;
    }
    let owners::Copies copies=copied(ref sources[..1],ref shapes[..1],data,ref mut table);
    assert(table.arena.used==65536 && read(ref table,copies.tokens[0],4095,data)==-9223372036854775808);
}
