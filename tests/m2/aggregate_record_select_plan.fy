module tests::m2::aggregate_record_select_plan;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_range as ranges;
import aggregate_places as places;

// Frozen d944ec5 aggregate boundaries: owner resolution and selection each plan.
fn Result<places::Place,owners::Error> original_select(ref records::Catalog catalog,
    ref owners::Table table,owners::Token root,usize nominal,usize ordinal,usize capacity){
    let owners::Owner owner=owners::resolve_record(catalog,table,root,capacity)?;
    let records::Plan plan=switch(records::plan(catalog,18446744073709551615)){
        case .ok(v):{v}case .err(_):{return .err(.Metadata);}
    };
    let usize offset=switch(ranges::offset_prepared(catalog,ref plan,owner.record,nominal,ordinal)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    let usize size=plan.bytes[nominal];
    if(offset>owner.length || size>owner.length-offset){return .err(.Bounds);}
    return .ok(places::Place{.root=root,.element=0,.length=owner.length,.record=owner.record,
        .nominal=nominal,.ordinal=ordinal,.alignment=owner.alignment,.mark=owner.mark,
        .base=owner.base,.end=owner.end,.offset=offset,.size=size});
}
fn Result<usize,owners::Error> original_unchanged(ref places::Place old,ref places::Place now){
    if(old.element!=now.element || old.record!=now.record || old.nominal!=now.nominal){return .err(.Type);}
    if(old.length!=now.length || old.size!=now.size){return .err(.Length);}
    if(old.ordinal!=now.ordinal || old.alignment!=now.alignment || old.mark!=now.mark ||
        old.base!=now.base || old.end!=now.end || old.offset!=now.offset){return .err(.State);}
    return .ok(now.size);
}
fn Result<usize,owners::Error> original_validate(ref records::Catalog catalog,
    ref owners::Table table,ref places::Place place,usize capacity){
    if(place.element!=0){return .err(.Type);}
    let places::Place now=original_select(catalog,table,place.root,place.nominal,place.ordinal,capacity)?;
    return original_unchanged(place,ref now);
}
fn Result<usize,owners::Error> original_store(ref records::Catalog catalog,
    ref owners::Table table,ref places::Place place,owners::Token source,usize source_ordinal,ref mut u8[] bytes){
    let usize checked=original_validate(catalog,table,place,bytes.len)?;
    return owners::assign_subrecord(catalog,place.root,source,place.nominal,place.ordinal,source_ordinal,bytes,table);
}
fn Result<usize,owners::Error> original_replace(ref records::Catalog catalog,
    ref owners::Table table,ref places::Place place,ref i64[] fields,ref mut u8[] bytes){
    let usize checked=original_validate(catalog,table,place,bytes.len)?;
    return owners::replace_subrecord(catalog,place.root,place.nominal,place.ordinal,fields,bytes,table);
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void same_place(ref places::Place a,ref places::Place b){
    assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element);
    assert(a.length==b.length && a.record==b.record && a.nominal==b.nominal && a.ordinal==b.ordinal);
    assert(a.alignment==b.alignment && a.mark==b.mark && a.base==b.base && a.end==b.end);
    assert(a.offset==b.offset && a.size==b.size);
}
fn u8 same_size(Result<usize,owners::Error> a,Result<usize,owners::Error> b){
    return switch(a){case .ok(n):{assert(switch(b){case .ok(m):{n==m}case .err(_):{false}});0}
        case .err(e):{assert(switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}});code(e)}};
}
fn u8 compare_snapshot(ref records::Catalog c,ref owners::Table t,ref places::Place p,
    ref i64[] fields,ref u8[] data,usize capacity){
    assert(data.len==256 && capacity<=256);
    let Result<places::Place,owners::Error> a=original_select(c,t,p.root,p.nominal,p.ordinal,capacity);
    let Result<places::Place,owners::Error> b=places::select_record(c,t,p.root,p.nominal,p.ordinal,capacity);
    let u8 picked=switch(a){case .ok(v):{switch(b){case .ok(w):{same_place(ref v,ref w);}case .err(_):{assert(false);}};0}
        case .err(e):{assert(switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}});code(e)}};
    let u8 checked=same_size(original_validate(c,t,p,capacity),places::validate_record(c,t,p,capacity));
    var u8[256] expected=[0;256];var u8[256] actual=[0;256];var usize i=0;
    while(i<256){expected[i]=data[i];actual[i]=data[i];i+=1;}
    let u8 copied=same_size(original_store(c,t,p,p.root,p.ordinal,ref mut expected[..capacity]),
        places::store_record(c,t,p,p.root,p.ordinal,ref mut actual[..capacity]));
    i=0;while(i<256){assert(expected[i]==actual[i]);if(copied!=0){assert(actual[i]==data[i]);}i+=1;}
    i=0;while(i<256){expected[i]=data[i];actual[i]=data[i];i+=1;}
    let u8 replaced=same_size(original_replace(c,t,p,fields,ref mut expected[..capacity]),
        places::replace_record(c,t,p,fields,ref mut actual[..capacity]));
    i=0;while(i<256){assert(expected[i]==actual[i]);if(replaced!=0){assert(actual[i]==data[i]);}i+=1;}
    return picked;
}
fn u8 compare(ref records::Catalog c,ref owners::Table t,owners::Token root,usize nominal,usize ordinal,
    ref i64[] fields,ref u8[] data,usize capacity){
    let places::Place p=places::Place{.root=root,.element=0,.length=40,.record=0,.nominal=nominal,.ordinal=ordinal,
        .alignment=8,.mark=1,.base=8,.end=48,.offset=8,.size=16};
    return compare_snapshot(c,t,ref p,fields,data,capacity);
}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn places::Place picked(Result<places::Place,owners::Error> r){return switch(r){
    case .ok(p):{p}case .err(_):{assert(false);places::Place{.root=owners::Token{.slot=16,.generation=0},
        .element=0,.length=0,.record=0,.nominal=0,.ordinal=0,.alignment=0,.mark=0,.base=0,.end=0,.offset=0,.size=0}}};
}
fn records::Catalog catalog(){
    var records::Catalog c=records::empty();c.count=4;
    c.fields[0]=3;c.types[0]=10;c.kinds[1]=1;c.types[1]=1;c.kinds[2]=1;c.types[2]=1;
    c.fields[1]=2;c.types[16]=9;c.types[17]=2;c.fields[2]=2;c.types[32]=9;c.types[33]=2;
    c.fields[3]=1;c.types[48]=10;return c;
}

@test fn void one_plan_matches_original_selection_revalidation_and_atomic_stores(){
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
    assert(compare(ref clean,ref t,root,1,1,ref values[..0],ref data,256)==0);count+=3;
    var owners::Table bad=t;bad.slots[root.slot].length=32;bad.slots[root.slot].end=40;bad.arena.used=40;
    assert(compare(ref clean,ref bad,root,32,128,ref values[..0],ref data,256)==6);
    bad=t;bad.slots[root.slot].record=2;assert(compare(ref clean,ref bad,root,32,128,ref values[..0],ref data,256)==6);count+=2;
    let places::Place snapshot=picked(original_select(ref clean,ref t,root,1,1,256));mode=0;
    while(mode<13){var places::Place p=snapshot;
        if(mode==0){p.element=10;}else if(mode==1){p.length+=1;}else if(mode==2){p.record=2;}
        else if(mode==3){p.nominal=2;}else if(mode==4){p.ordinal+=1;}else if(mode==5){p.alignment=1;}
        else if(mode==6){p.mark+=1;}else if(mode==7){p.base+=1;}else if(mode==8){p.end+=1;}
        else if(mode==9){p.offset+=1;}else if(mode==10){p.size+=1;}
        else if(mode==11){p.root.slot=16;}else{p.root.generation+=1;}
        let u8 a=compare_snapshot(ref clean,ref t,ref p,ref values,ref data,256);mode+=1;count+=1;
    }
    assert(count==1369);
}

@test fn void wide_bool_payloads_and_depth_limits_keep_metadata_selection_independent_of_payload(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;var usize i=0;
    while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}
    var u8[256] data=[85;256];var owners::Table t=owners::empty(256);let i64[128] all=[1;128];
    let owners::Token root=token(owners::create_record(ref c,0,ref all,ref mut data,ref mut t));
    let places::Place whole=picked(original_select(ref c,ref t,root,0,0,256));
    assert(compare_snapshot(ref c,ref t,ref whole,ref all,ref data,256)==0);var usize count=1;
    let i64[16] child=[1;16];var usize group=0;
    while(group<8){let places::Place p=picked(original_select(ref c,ref t,root,1,group*16,256));
        assert(compare_snapshot(ref c,ref t,ref p,ref child,ref data,256)==0);group+=1;count+=1;}
    i=0;while(i<128){data[i]=2;
        assert(compare_snapshot(ref c,ref t,ref whole,ref all,ref data,256)==0);
        let places::Place p=picked(original_select(ref c,ref t,root,1,(i/16)*16,256));
        assert(compare_snapshot(ref c,ref t,ref p,ref child,ref data,256)==0);data[i]=1;i+=1;count+=2;}
    assert(owners::clear(ref mut t,256).is_ok);
    var records::Catalog deep=records::empty();deep.count=16;i=0;var u8 next=1;
    while(i<16){deep.fields[i]=1;if(i<15){deep.kinds[i*16]=1;deep.types[i*16]=next;next+=1;}else{deep.types[i*16]=9;}i+=1;}
    let i64[1] field=[-9223372036854775808];
    let owners::Token nested=token(owners::create_record(ref deep,0,ref field,ref mut data,ref mut t));i=0;
    while(i<16){let places::Place p=picked(original_select(ref deep,ref t,nested,i,0,256));
        assert(compare_snapshot(ref deep,ref t,ref p,ref field,ref data,256)==0);i+=1;count+=1;}
    let places::Place leaf=picked(original_select(ref deep,ref t,nested,15,0,256));
    deep.count=17;deep.kinds[240]=1;deep.types[240]=16;deep.fields[16]=1;deep.types[256]=9;
    assert(compare_snapshot(ref deep,ref t,ref leaf,ref field,ref data,256)==6);count+=1;assert(count==282);
}
