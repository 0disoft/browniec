module tests::m2::subrecord_replace_plan;
import array_owners as owners;
import array_layout as arrays;
import array_storage as arenas;
import struct_layout as records;
import struct_range as ranges;
import struct_nested_storage as storage;

fn owners::Error mapped(storage::Error e){return switch(e){
    case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}case .State:{.State}
    case .Alignment:{.Alignment}case .Quota:{.Quota}case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}};
}
// Frozen 05a0a02 wrapper: owner, range and raw storage each plan the catalog.
fn Result<usize,owners::Error> original(ref records::Catalog c,ref owners::Table t,
    owners::Token destination,usize nominal,usize ordinal,ref i64[] fields,ref mut u8[] data){
    let owners::Owner target=owners::resolve_record(c,t,destination,data.len)?;
    let usize selected=switch(ranges::offset(c,target.record,nominal,ordinal)){
        case .ok(n):{n}case .err(_):{return .err(.Type);}};
    if(selected>target.length){return .err(.Bounds);}
    return switch(storage::replace_values(c,nominal,target.base+selected,fields,data,ref t.arena)){
        case .ok(n):{.ok(n)}case .err(e):{.err(mapped(e))}};
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn u8 compare(ref records::Catalog c,ref owners::Table t,owners::Token root,usize nominal,usize ordinal,
    ref i64[] fields,ref u8[] data,usize capacity){
    assert(data.len==256);var u8[256] before=[0;256];var u8[256] after=[0;256];var usize i=0;
    while(i<256){before[i]=data[i];after[i]=data[i];i+=1;}
    let Result<usize,owners::Error> a=original(c,t,root,nominal,ordinal,fields,ref mut before[..capacity]);
    let Result<usize,owners::Error> b=owners::replace_subrecord(c,root,nominal,ordinal,fields,ref mut after[..capacity],t);
    assert(switch(a){case .ok(n):{switch(b){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
    i=0;while(i<256){assert(before[i]==after[i]);if(!b.is_ok){assert(after[i]==data[i]);}i+=1;}
    return switch(b){case .ok(_):{0}case .err(e):{code(e)}};
}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn records::Catalog catalog(){
    var records::Catalog c=records::empty();c.count=4;
    c.fields[0]=3;c.types[0]=10;c.kinds[1]=1;c.types[1]=1;c.kinds[2]=1;c.types[2]=1;
    c.fields[1]=2;c.types[16]=9;c.types[17]=2;c.fields[2]=2;c.types[32]=9;c.types[33]=2;
    c.fields[3]=1;c.types[48]=10;return c;
}
@test fn void one_plan_matches_original_catalog_owner_range_and_failure_precedence(){
    let records::Catalog clean=catalog();var owners::Table t=owners::empty(256);var u8[256] data=[85;256];
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token prefix=token(owners::create(ref byte,7,ref mut data,ref mut t));
    let i64[5] initial=[17,42,1,99,0];let i64[2] values=[-9223372036854775808,1];
    let owners::Token root=token(owners::create_record(ref clean,0,ref initial,ref mut data,ref mut t));
    let owners::Token invalid=owners::Token{.slot=16,.generation=1};var usize count=0;var usize slot=0;
    while(slot<512){var records::Catalog c=clean;c.kinds[slot]=2;
        assert(compare(ref c,ref t,root,1,1,ref values,ref data,256)==6);
        c=clean;c.types[slot]=255;assert(compare(ref c,ref t,root,1,1,ref values,ref data,256)==6);slot+=1;count+=2;}
    var usize row=0;while(row<32){var records::Catalog c=clean;c.fields[row]=17;
        assert(compare(ref c,ref t,root,1,1,ref values,ref data,256)==6);row+=1;count+=1;}
    var usize mode=0;while(mode<12){var records::Catalog c=clean;
        if(mode==0){c.count=33;}else if(mode==1){c.count=0;}else if(mode==2){c.kinds[48]=1;c.types[48]=3;}
        else if(mode==3){c.types[1]=31;}else if(mode==4){c.fields[1]=1;c.types[17]=0;}else if(mode==5){c.types[16]=10;}
        else if(mode==6){c.types[17]=10;}else if(mode==7){c.fields[0]=0;}else if(mode==8){c.types[16]=12;}
        else if(mode==9){c.types[1]=2;}else if(mode==10){c.count=3;c.fields[3]=0;c.types[48]=0;}else{c.types[16]=1;}
        let u8 a=compare(ref c,ref t,root,1,1,ref values,ref data,256);
        assert(compare(ref c,ref t,invalid,1,1,ref values,ref data,256)==1);
        let u8 b=compare(ref c,ref t,root,32,128,ref values[..0],ref data,256);mode+=1;count+=3;
    }
    slot=0;while(slot<16){mode=0;while(mode<12){var owners::Table bad=t;let owners::Owner old=t.slots[slot];
        if(mode==0){bad.slots[slot].generation=0;}else if(mode==1){bad.slots[slot].generation+=1;}
        else if(mode==2){bad.slots[slot].occupied=!old.occupied;}else if(mode==3){bad.slots[slot].live=!old.live;}
        else if(mode==4){bad.slots[slot].reading=true;}else if(mode==5){bad.slots[slot].writing=true;}
        else if(mode==6){bad.slots[slot].base=127;}else if(mode==7){bad.slots[slot].end=127;}
        else if(mode==8){bad.slots[slot].element=10;}else if(mode==9){bad.slots[slot].record=31;}
        else if(mode==10){bad.slots[slot].length=1;}else{bad.slots[slot].alignment=4;}
        let u8 a=compare(ref clean,ref bad,root,1,1,ref values,ref data,256);mode+=1;count+=1;}slot+=1;}
    let owners::Token[4] tokens=[invalid,owners::Token{.slot=root.slot,.generation=0},
        owners::Token{.slot=root.slot,.generation=root.generation+1},prefix];slot=0;
    while(slot<4){let u8 a=compare(ref clean,ref t,tokens[slot],1,1,ref values,ref data,256);slot+=1;count+=1;}
    let usize[7] nominals=[0,1,2,3,4,32,18446744073709551615];
    let usize[7] ordinals=[0,1,2,3,4,128,18446744073709551615];slot=0;
    while(slot<7){var usize j=0;while(j<7){let u8 a=compare(ref clean,ref t,root,nominals[slot],ordinals[j],ref values,ref data,256);j+=1;count+=1;}slot+=1;}
    var i64[129] fields=[1;129];fields[0]=-9223372036854775808;let usize[6] lengths=[0,1,2,3,128,129];slot=0;
    while(slot<6){let u8 a=compare(ref clean,ref t,root,1,1,ref fields[..lengths[slot]],ref data,256);slot+=1;count+=1;}
    let usize[4] capacities=[0,47,255,256];slot=0;while(slot<4){
        let u8 a=compare(ref clean,ref t,root,1,1,ref values,ref data,capacities[slot]);slot+=1;count+=1;}
    let u8[4] bools=[0,1,2,255];slot=0;while(slot<4){data[24]=bools[slot];
        assert(compare(ref clean,ref t,root,1,1,ref values,ref data,256)==0);slot+=1;count+=1;}
    var records::Catalog corrupt=clean;corrupt.types[511]=255;
    assert(compare(ref corrupt,ref t,root,32,128,ref values[..0],ref data,256)==6);
    assert(compare(ref clean,ref t,root,32,128,ref values[..0],ref data,256)==4);
    assert(compare(ref clean,ref t,root,1,1,ref values[..0],ref data,256)==5);count+=3;
    var owners::Table bad=t;bad.slots[root.slot].length=32;bad.slots[root.slot].end=40;bad.arena.used=40;
    assert(compare(ref clean,ref bad,root,32,128,ref values[..0],ref data,256)==6);
    bad=t;bad.slots[root.slot].record=2;assert(compare(ref clean,ref bad,root,32,128,ref values[..0],ref data,256)==6);count+=2;
    assert(count==1356);
}
fn u8 direct(ref records::Catalog c,usize root,usize base,storage::Binding binding,usize nominal,usize ordinal,
    ref i64[] fields,ref u8[] data,ref arenas::Arena arena,usize capacity){
    assert(data.len==256);var u8[256] actual=[0;256];var usize i=0;while(i<256){actual[i]=data[i];i+=1;}
    let Result<usize,storage::Error> r=storage::replace_subrecord_bound(c,root,base,binding,nominal,ordinal,fields,ref mut actual[..capacity],arena);
    if(!r.is_ok){i=0;while(i<256){assert(actual[i]==data[i]);i+=1;}}
    return switch(r){case .ok(_):{0}case .err(e):{code(mapped(e))}};
}
@test fn void checked_storage_rejects_forged_bindings_partial_roots_and_overflowing_offsets(){
    let records::Catalog c=catalog();var owners::Table t=owners::empty(256);var u8[256] data=[85;256];
    let arrays::Array byte=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token prefix=token(owners::create(ref byte,7,ref mut data,ref mut t));
    let i64[5] initial=[17,42,1,99,0];let i64[2] values=[-9223372036854775808,1];
    let owners::Token root=token(owners::create_record(ref c,0,ref initial,ref mut data,ref mut t));
    let storage::Binding good=storage::Binding{.bytes=40,.alignment=8};
    assert(direct(ref c,0,8,good,1,1,ref values,ref data,ref t.arena,256)==0);
    var usize mode=0;while(mode<5){var storage::Binding bad=good;
        if(mode==0){bad.bytes=0;}else if(mode==1){bad.bytes=39;}else if(mode==2){bad.bytes=18446744073709551615;}
        else if(mode==3){bad.alignment=0;}else{bad.alignment=4;}
        assert(direct(ref c,0,18446744073709551608,bad,32,128,ref values[..0],ref data,ref t.arena,0)==6);mode+=1;}
    assert(direct(ref c,32,8,good,1,1,ref values,ref data,ref t.arena,256)==6);
    var records::Catalog corrupt=c;corrupt.types[511]=255;
    assert(direct(ref corrupt,0,8,good,32,128,ref values[..0],ref data,ref t.arena,256)==6);
    assert(direct(ref c,0,8,good,32,1,ref values,ref data,ref t.arena,256)==4);
    assert(direct(ref c,0,8,good,1,128,ref values,ref data,ref t.arena,256)==4);
    assert(direct(ref c,0,1,good,1,1,ref values,ref data,ref t.arena,256)==10);
    assert(direct(ref c,0,18446744073709551608,good,1,1,ref values,ref data,ref t.arena,256)==9);
    var arenas::Arena partial=t.arena;partial.used=32;
    assert(direct(ref c,0,8,good,1,1,ref values,ref data,ref partial,256)==9);
    assert(direct(ref c,0,8,good,1,1,ref values,ref data,ref t.arena,255)==3);
    assert(direct(ref c,0,8,good,1,1,ref values[..0],ref data,ref t.arena,256)==5);
    let i64[2] invalid=[42,2];assert(direct(ref c,0,8,good,1,1,ref invalid,ref data,ref t.arena,256)==11);
    var records::Catalog large=c;large.fields[0]=16;var usize i=0;while(i<16){large.kinds[i]=1;large.types[i]=1;i+=1;}
    let storage::Binding huge=storage::Binding{.bytes=256,.alignment=8};
    assert(direct(ref large,0,0,huge,1,0,ref values,ref data,ref t.arena,256)==4);
    assert(direct(ref c,0,8,good,2,1,ref values,ref data,ref t.arena,256)==4);
}
@test fn void scalar_edges_maximum_leaves_and_depth_preserve_staged_replacement(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=1;c.kinds[0]=1;c.types[0]=1;c.fields[1]=6;
    let u8[6] tags=[1,9,10,11,12,2];var usize i=0;while(i<6){c.types[16+i]=tags[i];i+=1;}
    var owners::Table t=owners::empty(256);var u8[256] data=[85;256];let i64[6] initial=[20,99,255,4294967295,-1,1];
    let owners::Token root=token(owners::create_record(ref c,0,ref initial,ref mut data,ref mut t));
    let i64[8] edge=[0,1,2,-1,255,4294967296,-9223372036854775808,9223372036854775807];var usize count=0;
    var usize field=0;while(field<6){i=0;while(i<8){var i64[6] values=initial;values[field]=edge[i];
        let u8 a=compare(ref c,ref t,root,1,0,ref values,ref data,256);i+=1;count+=1;}field+=1;}
    assert(owners::clear(ref mut t,256).is_ok);
    var records::Catalog wide=records::empty();wide.count=2;wide.fields[0]=8;wide.fields[1]=16;i=0;
    while(i<16){wide.types[16+i]=2;if(i<8){wide.kinds[i]=1;wide.types[i]=1;}i+=1;}
    let i64[128] all=[1;128];let owners::Token full=token(owners::create_record(ref wide,0,ref all,ref mut data,ref mut t));
    var usize group=0;while(group<8){let i64[16] good=[1;16];
        assert(compare(ref wide,ref t,full,1,group*16,ref good,ref data,256)==0);count+=1;field=0;
        while(field<16){var i64[16] bad=good;bad[field]=2;
            assert(compare(ref wide,ref t,full,1,group*16,ref bad,ref data,256)==11);field+=1;count+=1;}group+=1;}
    assert(compare(ref wide,ref t,full,0,0,ref all,ref data,256)==0);count+=1;field=0;
    while(field<128){var i64[128] bad=all;bad[field]=2;
        assert(compare(ref wide,ref t,full,0,0,ref bad,ref data,256)==11);field+=1;count+=1;}
    assert(owners::clear(ref mut t,256).is_ok);
    var records::Catalog deep=records::empty();deep.count=16;i=0;var u8 child=1;
    while(i<16){deep.fields[i]=1;if(i<15){deep.kinds[i*16]=1;deep.types[i*16]=child;child+=1;}else{deep.types[i*16]=9;}i+=1;}
    let i64[1] value=[-9223372036854775808];let owners::Token nested=token(owners::create_record(ref deep,0,ref value,ref mut data,ref mut t));
    assert(compare(ref deep,ref t,nested,15,0,ref value,ref data,256)==0);count+=1;
    deep.count=17;deep.kinds[240]=1;deep.types[240]=16;deep.fields[16]=1;deep.types[256]=9;
    assert(compare(ref deep,ref t,nested,15,0,ref value,ref data,256)==6);count+=1;assert(count==315);
}
