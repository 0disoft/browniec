module tests::m2::record_places;

import record_places as places;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as layouts;

fn layouts::Catalog pair() {
    var layouts::Catalog c=layouts::empty(); c.count=2;
    c.fields[0]=2; c.kinds[0]=1; c.types[0]=1; c.kinds[1]=1; c.types[1]=1;
    c.fields[1]=2; c.types[16]=9; c.types[17]=2; return c;
}
fn owners::Token token(Result<owners::Token,owners::Error> result) {
    return switch(result) { case .ok(t): { t } case .err(_): { assert(false); owners::Token{.slot=0,.generation=0} } };
}
fn places::Place selected(ref layouts::Catalog c,ref owners::Table table,
    owners::Token root,usize ordinal,usize capacity) {
    return switch(places::select(c,table,root,ordinal,capacity)) {
        case .ok(p): { p } case .err(_): { assert(false); places::Place{.root=root,.record=0,
            .length=0,.alignment=0,.mark=0,.base=0,.end=0,.ordinal=0,.element=0,.offset=0} }
    };
}
fn i64 value(Result<i64,owners::Error> result) {
    return switch(result) { case .ok(v): { v } case .err(_): { assert(false); 0 } };
}
fn void unchanged(ref u8[] bytes,ref u8[] before) {
    assert(bytes.len==before.len); var usize i=0;
    while(i<bytes.len) { assert(bytes[i]==before[i]); i+=1; }
}
fn void rejected(ref layouts::Catalog c,ref owners::Table table,ref places::Place p,ref mut u8[] bytes) {
    assert(!places::read(c,table,p,bytes).is_ok);
    assert(!places::store(c,table,p,42,bytes).is_ok);
}

@test fn void original_nominal_root_and_leaf_survive_descriptor_changes_allocations_and_replacement() {
    let layouts::Catalog c=pair(); var u8[96] bytes=[85;96]; var owners::Table table=owners::empty(96);
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token prefix=token(owners::create(ref byte,7,ref mut bytes,ref mut table));
    let i64[4] fields=[20,0,99,1];
    var owners::Token descriptor=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let owners::Token original=descriptor; var usize ordinal=0;
    let places::Place p=selected(ref c,ref table,descriptor,ordinal,bytes.len);
    let i64 old=value(places::read(ref c,ref table,ref p,ref bytes));
    ordinal=2; descriptor=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let i64[4] replacement=[100,1,200,0];
    assert(owners::replace_record(ref c,original,0,ref replacement,ref mut bytes,ref table).is_ok);
    assert(places::store(ref c,ref table,ref p,old+22,ref mut bytes).is_ok);
    let usize[2] first=[0,0]; let usize[2] second=[1,0];
    assert(value(owners::read_record(ref c,ref table,original,ref first,ref bytes))==42);
    assert(value(owners::read_record(ref c,ref table,original,ref second,ref bytes))==200);
    assert(value(owners::read_record(ref c,ref table,descriptor,ref first,ref bytes))==20);
    assert(value(owners::read(ref table,prefix,0,ref bytes))==7);
    assert(ordinal==2 && p.offset==8 && p.mark==1 && p.base==8 && p.end==40);
    assert(table.depth==3 && table.arena.used==72);
}

@test fn void six_scalar_domains_capture_old_values_and_preserve_exact_codec_edges() {
    var layouts::Catalog c=layouts::empty(); c.count=1; c.fields[0]=6;
    let u8[6] tags=[1,2,9,10,11,12]; var usize i=0;
    while(i<6) { c.types[i]=tags[i]; i+=1; }
    let i64[6] fields=[20,0,20,20,20,20]; var u8[64] bytes=[85;64]; var owners::Table table=owners::empty(64);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    i=0; while(i<6) {
        let places::Place p=selected(ref c,ref table,root,i,bytes.len);
        let i64 old=value(places::read(ref c,ref table,ref p,ref bytes));
        let usize[1] path=[i]; let i64 changed=if(tags[i]==2){1}else{99};
        assert(owners::write_record(ref c,ref table,root,ref path,changed,ref mut bytes).is_ok);
        let i64 result=if(tags[i]==2){1}else{old+22};
        assert(places::store(ref c,ref table,ref p,result,ref mut bytes).is_ok);
        assert(value(places::read(ref c,ref table,ref p,ref bytes))==result); i+=1;
    }
    let places::Place signed=selected(ref c,ref table,root,2,bytes.len);
    assert(places::store(ref c,ref table,ref signed,-9223372036854775808,ref mut bytes).is_ok);
    assert(value(places::read(ref c,ref table,ref signed,ref bytes)) == -9223372036854775808);
    assert(places::store(ref c,ref table,ref signed,9223372036854775807,ref mut bytes).is_ok);
    assert(value(places::read(ref c,ref table,ref signed,ref bytes)) == 9223372036854775807);
    let places::Place unsigned=selected(ref c,ref table,root,5,bytes.len);
    assert(places::store(ref c,ref table,ref unsigned,-1,ref mut bytes).is_ok);
    assert(value(places::read(ref c,ref table,ref unsigned,ref bytes)) == -1);
    assert(table.depth==1 && table.arena.used==32);
}

@test fn void selection_does_not_read_bool_payload_and_failed_encoding_is_atomic() {
    let layouts::Catalog c=pair(); let i64[4] fields=[20,0,99,1];
    var u8[64] bytes=[85;64]; var owners::Table table=owners::empty(64);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    bytes[8]=7;
    let places::Place p=selected(ref c,ref table,root,1,bytes.len);
    let u8[64] before=bytes;
    assert(!places::read(ref c,ref table,ref p,ref bytes).is_ok);
    assert(!places::store(ref c,ref table,ref p,2,ref mut bytes).is_ok);
    unchanged(ref bytes,ref before);
    assert(places::store(ref c,ref table,ref p,1,ref mut bytes).is_ok);
    assert(bytes[8]==1 && bytes[7]==0 && bytes[9]==0 && bytes[24]==1);
    assert(table.depth==1 && table.arena.used==32);
}

@test fn void stale_released_reused_and_cleared_owners_cannot_resurrect_a_record_place() {
    let layouts::Catalog c=pair(); let i64[4] fields=[20,0,99,1];
    var u8[64] bytes=[85;64]; var owners::Table table=owners::empty(64);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(ref c,ref table,root,0,bytes.len);
    let owners::Token later=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    assert(owners::release(ref mut table,root,bytes.len).is_ok);
    rejected(ref c,ref table,ref p,ref mut bytes);
    assert(owners::release(ref mut table,later,bytes.len).is_ok);
    let owners::Token replacement=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    assert(replacement.slot==root.slot && replacement.generation!=root.generation);
    let u8[64] before=bytes; rejected(ref c,ref table,ref p,ref mut bytes); unchanged(ref bytes,ref before);
    let places::Place fresh=selected(ref c,ref table,replacement,0,bytes.len);
    assert(owners::clear(ref mut table,bytes.len).is_ok);
    rejected(ref c,ref table,ref fresh,ref mut bytes); unchanged(ref bytes,ref before);
}

@test fn void malformed_snapshots_and_changed_scalar_locations_never_publish_bytes() {
    let layouts::Catalog c=pair(); let i64[4] fields=[20,0,99,1];
    var u8[64] bytes=[85;64]; var owners::Table table=owners::empty(64);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(ref c,ref table,root,0,bytes.len); let u8[64] before=bytes;
    var usize i=0; while(i<12) {
        var places::Place bad=p;
        if(i==0){bad.root.slot=16;}else if(i==1){bad.root.generation+=1;}else if(i==2){bad.record=1;}
        else if(i==3){bad.length+=1;}else if(i==4){bad.alignment=4;}else if(i==5){bad.mark+=1;}
        else if(i==6){bad.base+=1;}else if(i==7){bad.end+=1;}else if(i==8){bad.ordinal=128;}
        else if(i==9){bad.offset+=1;}else if(i==10){bad.element=2;}else{bad.ordinal=2;}
        rejected(ref c,ref table,ref bad,ref mut bytes); unchanged(ref bytes,ref before); i+=1;
    }
    var layouts::Catalog changed=c; changed.types[16]=12;
    rejected(ref changed,ref table,ref p,ref mut bytes); unchanged(ref bytes,ref before);
    assert(table.depth==1 && table.arena.used==32);
}

@test fn void full_ledger_catalog_and_capacity_authentication_reject_malformed_inputs() {
    let layouts::Catalog c=pair(); let i64[4] fields=[20,0,99,1];
    var u8[64] bytes=[85;64]; var owners::Table table=owners::empty(64);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let owners::Token other=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(ref c,ref table,root,0,bytes.len); let u8[64] before=bytes;
    var usize i=0; while(i<12) {
        var owners::Table bad=table;
        if(i==0){bad.depth=17;}else if(i==1){bad.order[0]=16;}else if(i==2){let usize first=bad.order[0];bad.order[1]=first;}
        else if(i==3){bad.arena.limit=65;}else if(i==4){bad.arena.used=65;}else if(i==5){bad.slots[root.slot].reading=true;}
        else if(i==6){bad.slots[root.slot].writing=true;}else if(i==7){bad.slots[root.slot].base+=8;}
        else if(i==8){bad.slots[root.slot].end+=8;}else if(i==9){bad.slots[root.slot].length+=8;}
        else if(i==10){bad.slots[root.slot].alignment=4;}else{bad.slots[other.slot].generation=0;}
        rejected(ref c,ref bad,ref p,ref mut bytes); unchanged(ref bytes,ref before); i+=1;
    }
    assert(!places::select(ref c,ref table,root,0,63).is_ok);
    assert(!places::select(ref c,ref table,root,4,64).is_ok);
    assert(!places::select(ref c,ref table,root,18446744073709551615,64).is_ok);
    var layouts::Catalog cycle=c; cycle.types[0]=0;
    assert(!places::select(ref cycle,ref table,root,0,64).is_ok);
    unchanged(ref bytes,ref before);
    var u8[1] raw=[0]; var owners::Table arrays_table=owners::empty(1);
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token a=token(owners::create(ref byte,0,ref mut raw,ref mut arrays_table));
    assert(!places::select(ref c,ref arrays_table,a,0,1).is_ok);
}

@test fn void maximum_nested_depth_and_last_of_128_scalar_leaves_are_selectable() {
    var layouts::Catalog deep=layouts::empty(); deep.count=16; var usize i=0; var u8 child=1;
    while(i<16){deep.fields[i]=1;if(i<15){deep.kinds[i*16]=1;deep.types[i*16]=child;child+=1;}else{deep.types[i*16]=9;}i+=1;}
    let i64[1] first=[20]; var u8[128] bytes=[85;128]; var owners::Table table=owners::empty(128);
    let owners::Token root=token(owners::create_record(ref deep,0,ref first,ref mut bytes,ref mut table));
    let places::Place p=selected(ref deep,ref table,root,0,128);
    assert(places::store(ref deep,ref table,ref p,42,ref mut bytes).is_ok);
    assert(value(places::read(ref deep,ref table,ref p,ref bytes))==42);
    var layouts::Catalog too_deep=deep; too_deep.count=17; too_deep.kinds[240]=1;
    too_deep.types[240]=16; too_deep.fields[16]=1; too_deep.types[256]=9;
    assert(!places::select(ref too_deep,ref table,root,0,128).is_ok);
    assert(owners::clear(ref mut table,bytes.len).is_ok);
    var layouts::Catalog wide=layouts::empty(); wide.count=2; wide.fields[0]=16; wide.fields[1]=8;
    i=0;while(i<16){wide.kinds[i]=1;wide.types[i]=1;i+=1;}i=0;while(i<8){wide.types[16+i]=10;i+=1;}
    let i64[128] fields=[20;128];
    let owners::Token all=token(owners::create_record(ref wide,0,ref fields,ref mut bytes,ref mut table));
    let places::Place last=selected(ref wide,ref table,all,127,128);
    assert(last.offset==127 && last.length==128 && table.arena.used==128);
    assert(places::store(ref wide,ref table,ref last,255,ref mut bytes).is_ok);
    assert(bytes[126]==20 && bytes[127]==255);
    assert(!places::select(ref wide,ref table,all,128,128).is_ok);
}

@test fn void full_sixteen_owner_and_backing_capacity_needs_no_extra_reservation() {
    let layouts::Catalog c=pair(); let i64[4] fields=[20,0,99,1];
    var u8[47] bytes=[85;47]; var owners::Table table=owners::empty(47);
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    var usize i=0;while(i<15){let owners::Token extra=token(owners::create(ref byte,7,ref mut bytes,ref mut table));i+=1;}
    assert(table.depth==16 && table.arena.used==47);
    let places::Place p=selected(ref c,ref table,root,2,47);
    assert(value(places::read(ref c,ref table,ref p,ref bytes))==99);
    assert(places::store(ref c,ref table,ref p,42,ref mut bytes).is_ok);
    assert(value(places::read(ref c,ref table,ref p,ref bytes))==42);
    assert(table.depth==16 && table.arena.used==47 && bytes[46]==7);
}
