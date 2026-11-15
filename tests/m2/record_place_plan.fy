module tests::m2::record_place_plan;
import record_places as places;
import array_layout as arrays;
import array_storage as arenas;

import array_owners as owners;
import struct_layout as layouts;
import struct_nested_storage as storage;
import scalar_codec as codec;

// Frozen 06d6683 scalar place implementation; its two checked plans remain.
fn owners::Error original_failure(storage::Error error) {
    return switch(error) {
        case .Layout: { .Metadata } case .Bounds: { .Bounds } case .Fields: { .Length }
        case .State: { .State } case .Alignment: { .Alignment } case .Quota: { .Quota }
        case .Overflow: { .Overflow } case .Value: { .Value } case .Type: { .Type }
    };
}
fn owners::Error original_codec_error(codec::Error error) {
    return switch(error) { case .Type: { .Type } case .Width: { .Metadata } case .Value: { .Value } };
}

// Authentication and scalar selection precede any RHS/payload read. Plain bool
// stores can replace a noncanonical old byte; compound reads must reject it.
pub fn Result<places::Place,owners::Error> original_select(ref layouts::Catalog catalog,
    ref owners::Table table,owners::Token root,usize ordinal,usize capacity) {
    let owners::Owner owner=owners::resolve_record(catalog,table,root,capacity)?;
    let storage::Leaf leaf=switch(storage::scalar_location(catalog,owner.record,owner.base,
        ordinal,capacity,ref table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(original_failure(error)); }
    };
    return .ok(places::Place { .root=root,.record=owner.record,.length=owner.length,.alignment=owner.alignment,
        .mark=owner.mark,.base=owner.base,.end=owner.end,.ordinal=ordinal,.element=leaf.tag,.offset=leaf.offset });
}
// The caller's current descriptor/ordinal never redirects the selected target.
// In-place replacement may alter payload, but not nominal type or reservation.
fn Result<usize,owners::Error> original_validate(ref layouts::Catalog catalog,
    ref owners::Table table,ref places::Place place,usize capacity) {
    let places::Place now=original_select(catalog,table,place.root,place.ordinal,capacity)?;
    if(now.record!=place.record || now.element!=place.element){return .err(.Type);}
    if(now.length!=place.length){return .err(.Length);}
    if(now.alignment!=place.alignment || now.mark!=place.mark || now.base!=place.base ||
        now.end!=place.end || now.offset!=place.offset){return .err(.State);}
    return .ok(codec::width(now.element));
}
pub fn Result<i64,owners::Error> original_read(ref layouts::Catalog catalog,
    ref owners::Table table,ref places::Place place,ref u8[] bytes) {
    let usize width=original_validate(catalog,table,place,bytes.len)?;
    return switch(codec::decode(place.element,bytes[place.offset..place.offset+width])) {
        case .ok(value): { .ok(value) } case .err(error): { .err(original_codec_error(error)) }
    };
}
// The scalar codec stages <=8 bytes. Revalidation/encoding original_failure leaves both
// payload and owner metadata unchanged; no reservation, owner or heap allocation.
pub fn Result<usize,owners::Error> original_store(ref layouts::Catalog catalog,
    ref owners::Table table,ref places::Place place,i64 value,ref mut u8[] bytes) {
    let usize width=original_validate(catalog,table,place,bytes.len)?;
    return switch(codec::encode(place.element,value,bytes[place.offset..place.offset+width])) {
        case .ok(size): { .ok(size) } case .err(error): { .err(original_codec_error(error)) }
    };
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void same_place(ref places::Place a,ref places::Place b){
    assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.record==b.record);
    assert(a.length==b.length && a.alignment==b.alignment && a.mark==b.mark && a.base==b.base && a.end==b.end);
    assert(a.ordinal==b.ordinal && a.element==b.element && a.offset==b.offset);
}
fn void same_read(Result<i64,owners::Error> a,Result<i64,owners::Error> b){
    assert(switch(a){case .ok(v):{switch(b){case .ok(w):{v==w}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
}
fn void same_write(Result<usize,owners::Error> a,Result<usize,owners::Error> b){
    assert(switch(a){case .ok(v):{switch(b){case .ok(w):{v==w}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
}
fn places::Place selected(ref layouts::Catalog c,ref owners::Table t,owners::Token root,usize ordinal){
    return switch(original_select(c,t,root,ordinal,128)){case .ok(p):{p}case .err(_):{
        assert(false);places::Place{.root=root,.record=0,.length=0,.alignment=0,.mark=0,.base=0,.end=0,
            .ordinal=0,.element=0,.offset=0}}};
}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void compare(ref layouts::Catalog c,ref owners::Table t,owners::Token root,usize ordinal,
    ref places::Place p,ref u8[] data,usize capacity,i64 cell){
    let Result<places::Place,owners::Error> a=original_select(c,t,root,ordinal,capacity);
    let Result<places::Place,owners::Error> b=places::select(c,t,root,ordinal,capacity);
    switch(a){case .ok(v):{switch(b){case .ok(w):{same_place(ref v,ref w);}case .err(_):{assert(false);}};}
        case .err(e):{switch(b){case .ok(_):{assert(false);}case .err(f):{assert(code(e)==code(f));}};}};
    same_read(original_read(c,t,p,data[..capacity]),places::read(c,t,p,data[..capacity]));
    assert(data.len==128);var u8[128] before=[0;128];var u8[128] after=[0;128];var usize i=0;
    while(i<128){before[i]=data[i];after[i]=data[i];i+=1;}
    let Result<usize,owners::Error> x=original_store(c,t,p,cell,ref mut before[..capacity]);
    let Result<usize,owners::Error> y=places::store(c,t,p,cell,ref mut after[..capacity]);
    same_write(x,y);i=0;while(i<128){assert(before[i]==after[i]);if(!y.is_ok){assert(after[i]==data[i]);}i+=1;}
}
fn layouts::Catalog catalog(){
    var layouts::Catalog c=layouts::empty();c.count=2;c.fields[0]=1;c.kinds[0]=1;c.types[0]=1;c.fields[1]=6;
    let u8[6] tags=[1,9,10,11,12,2];var usize i=0;while(i<6){c.types[16+i]=tags[i];i+=1;}return c;
}
@test fn void selected_scalar_access_matches_original_for_catalog_owner_and_snapshot_faults(){
    let layouts::Catalog clean=catalog();var owners::Table t=owners::empty(128);var u8[128] data=[85;128];
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token prefix=token(owners::create(ref byte,7,ref mut data,ref mut t));
    let i64[6] fields=[20,99,255,4294967295,-1,1];
    let owners::Token root=token(owners::create_record(ref clean,0,ref fields,ref mut data,ref mut t));
    let places::Place p=selected(ref clean,ref t,root,5);var usize count=0;
    var usize slot=0;while(slot<512){var layouts::Catalog c=clean;c.kinds[slot]=2;
        compare(ref c,ref t,root,5,ref p,ref data,128,2);
        c=clean;c.types[slot]=255;compare(ref c,ref t,root,5,ref p,ref data,128,2);count+=2;slot+=1;}
    var usize row=0;while(row<32){var layouts::Catalog c=clean;c.fields[row]=17;
        compare(ref c,ref t,root,5,ref p,ref data,128,2);count+=1;row+=1;}
    var usize mode=0;while(mode<8){var layouts::Catalog c=clean;
        if(mode==0){c.count=33;}else if(mode==1){c.types[0]=0;}else if(mode==2){c.fields[1]=5;c.types[21]=0;}
        else if(mode==3){c.types[16]=10;}else if(mode==4){c.count=3;c.fields[2]=1;c.kinds[32]=1;c.types[32]=2;}
        else if(mode==5){c.count=1;c.fields[1]=0;var usize i=0;while(i<6){c.types[16+i]=0;i+=1;}c.types[0]=0;c.kinds[0]=0;}
        else if(mode==6){c.fields[0]=0;}else{c.types[21]=10;}
        let usize[3] ordinals=[5,128,18446744073709551615];var usize j=0;
        while(j<3){var places::Place bad=p;bad.ordinal=ordinals[j];
            compare(ref c,ref t,root,ordinals[j],ref bad,ref data,128,2);count+=1;j+=1;}
        var places::Place bad=p;bad.root.slot=16;
        compare(ref c,ref t,bad.root,128,ref bad,ref data,0,2);count+=1;mode+=1;
    }
    slot=0;while(slot<16){mode=0;while(mode<12){var owners::Table bad=t;
        if(mode==0){bad.slots[slot].generation=0;}else if(mode==1){bad.slots[slot].generation+=1;}
        else if(mode==2){bad.slots[slot].occupied=true;}else if(mode==3){bad.slots[slot].reading=true;}
        else if(mode==4){bad.slots[slot].writing=true;}else if(mode==5){bad.slots[slot].base=127;}
        else if(mode==6){bad.slots[slot].element=10;}else if(mode==7){bad.slots[slot].record=31;}
        else if(mode==8){bad.slots[slot].length+=1;}else if(mode==9){bad.slots[slot].alignment=1;}
        else if(mode==10){bad.slots[slot].live=false;}else{bad.slots[slot].end+=1;}
        compare(ref clean,ref bad,root,5,ref p,ref data,128,2);count+=1;mode+=1;}slot+=1;}
    mode=0;while(mode<13){var places::Place bad=p;
        if(mode==0){bad.root.slot=16;}else if(mode==1){bad.root.generation=0;}else if(mode==2){bad.root.generation+=1;}
        else if(mode==3){bad.record=1;}else if(mode==4){bad.length+=1;}else if(mode==5){bad.alignment=4;}
        else if(mode==6){bad.mark+=1;}else if(mode==7){bad.base+=1;}else if(mode==8){bad.end+=1;}
        else if(mode==9){bad.ordinal=128;}else if(mode==10){bad.element=10;}else if(mode==11){bad.offset+=1;}else{bad.ordinal=0;}
        compare(ref clean,ref t,bad.root,bad.ordinal,ref bad,ref data,128,2);count+=1;mode+=1;}
    let usize[4] capacities=[0,47,127,128];mode=0;while(mode<4){
        compare(ref clean,ref t,root,5,ref p,ref data,capacities[mode],1);count+=1;mode+=1;}
    let places::Place array=p;var places::Place wrong=array;wrong.root=prefix;
    compare(ref clean,ref t,prefix,128,ref wrong,ref data,128,2);count+=1;
    assert(count==1298);
}
fn u8 raw_code(Result<storage::Leaf,storage::Error> r){return switch(r){case .ok(_):{0}case .err(e):{code(original_failure(e))}};}
@test fn void ordinal_bound_storage_preserves_raw_precedence_and_rejects_forged_bindings(){
    let layouts::Catalog c=catalog();var owners::Table t=owners::empty(128);var u8[128] data=[85;128];
    let i64[6] fields=[20,99,255,4294967295,-1,1];
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    let storage::Binding good=storage::Binding{.bytes=40,.alignment=8};
    assert(raw_code(storage::scalar_location_bound(ref c,0,0,good,5,128,ref t.arena))==0);
    var usize mode=0;while(mode<5){var storage::Binding bad=good;
        if(mode==0){bad.bytes=0;}else if(mode==1){bad.bytes=39;}else if(mode==2){bad.bytes=18446744073709551615;}
        else if(mode==3){bad.alignment=0;}else{bad.alignment=4;}
        assert(raw_code(storage::scalar_location_bound(ref c,0,127,bad,128,0,ref t.arena))==6);mode+=1;}
    assert(raw_code(storage::scalar_location_bound(ref c,32,0,good,128,128,ref t.arena))==6);
    var layouts::Catalog bad=c;bad.types[511]=255;
    assert(raw_code(storage::scalar_location(ref bad,0,0,128,128,ref t.arena))==9);
    assert(raw_code(storage::scalar_location_bound(ref bad,0,0,good,128,128,ref t.arena))==6);
    assert(raw_code(storage::scalar_location_bound(ref c,0,0,good,128,128,ref t.arena))==9);
    assert(raw_code(storage::scalar_location_bound(ref c,0,1,good,0,128,ref t.arena))==10);
    var arenas::Arena short=t.arena;short.used=39;
    assert(raw_code(storage::scalar_location_bound(ref c,0,0,good,0,128,ref short))==9);
    assert(raw_code(storage::scalar_location_bound(ref c,0,0,good,0,127,ref t.arena))==3);
}
@test fn void all_scalar_domains_and_last_leaf_match_original_at_depth_and_capacity_limits(){
    let layouts::Catalog c=catalog();var owners::Table t=owners::empty(128);var u8[128] data=[85;128];
    let i64[6] fields=[20,99,255,4294967295,-1,1];
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    let i64[8] values=[0,1,2,-1,255,4294967296,-9223372036854775808,9223372036854775807];
    var usize leaf=0;while(leaf<6){let places::Place p=selected(ref c,ref t,root,leaf);var usize v=0;
        while(v<8){compare(ref c,ref t,root,leaf,ref p,ref data,128,values[v]);v+=1;}leaf+=1;}
    let places::Place bool_place=selected(ref c,ref t,root,5);let u8[4] bools=[0,1,2,255];var usize i=0;
    while(i<4){data[32]=bools[i];compare(ref c,ref t,root,5,ref bool_place,ref data,128,1);i+=1;}
    assert(owners::clear(ref mut t,128).is_ok);
    var layouts::Catalog deep=layouts::empty();deep.count=16;i=0;var u8 child=1;
    while(i<16){deep.fields[i]=1;if(i<15){deep.kinds[i*16]=1;deep.types[i*16]=child;child+=1;}else{deep.types[i*16]=9;}i+=1;}
    let i64[1] first=[20];let owners::Token nested=token(owners::create_record(ref deep,0,ref first,ref mut data,ref mut t));
    let places::Place d=selected(ref deep,ref t,nested,0);compare(ref deep,ref t,nested,0,ref d,ref data,128,42);
    deep.count=17;deep.kinds[240]=1;deep.types[240]=16;deep.fields[16]=1;deep.types[256]=9;
    compare(ref deep,ref t,nested,128,ref d,ref data,128,42);
    assert(owners::clear(ref mut t,128).is_ok);
    var layouts::Catalog wide=layouts::empty();wide.count=2;wide.fields[0]=16;wide.fields[1]=8;
    i=0;while(i<16){wide.kinds[i]=1;wide.types[i]=1;i+=1;}i=0;while(i<8){wide.types[16+i]=10;i+=1;}
    let i64[128] all=[20;128];let owners::Token full=token(owners::create_record(ref wide,0,ref all,ref mut data,ref mut t));
    leaf=0;while(leaf<128){let places::Place p=selected(ref wide,ref t,full,leaf);
        compare(ref wide,ref t,full,leaf,ref p,ref data,128,255);leaf+=1;}
}
