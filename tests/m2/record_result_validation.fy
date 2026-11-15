module tests::m2::record_result_validation;
import array_owners as owners;
import array_layout as arrays;
import array_storage as arenas;
import struct_layout as records;
import struct_nested_storage as storage;

fn owners::Error mapped(storage::Error e){return switch(e){
    case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}case .State:{.State}
    case .Alignment:{.Alignment}case .Quota:{.Quota}case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}};
}
// ab423bb result validation: two plans and a normalized snapshot discarded by RET.
fn Result<usize,owners::Error> original(ref records::Catalog c,ref owners::Table t,
    owners::Token root,usize nominal,ref u8[] data){
    let owners::Owner o=owners::resolve_record(c,t,root,data.len)?;
    if(o.record!=nominal){return .err(.Type);}
    var u8[128] scratch=[0;128];
    return switch(storage::snapshot_into(c,nominal,o.base,data,ref t.arena,ref mut scratch[..o.length])){
        case .ok(n):{.ok(n)}case .err(e):{.err(mapped(e))}};
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn u8 checked(Result<usize,storage::Error> r){return switch(r){case .ok(_):{0}case .err(e):{code(mapped(e))}};}
fn u8 compare(ref records::Catalog c,ref owners::Table t,owners::Token root,usize nominal,ref u8[] data,usize capacity){
    assert(data.len==128);var u8[128] saved=[0;128];var usize i=0;while(i<128){saved[i]=data[i];i+=1;}
    let Result<usize,owners::Error> a=original(c,t,root,nominal,data[..capacity]);
    let Result<usize,owners::Error> b=owners::validate_record_result(c,t,root,nominal,data[..capacity]);
    assert(switch(a){case .ok(n):{switch(b){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
    i=0;while(i<128){assert(data[i]==saved[i]);i+=1;}
    return switch(b){case .ok(_):{0}case .err(e):{code(e)}};
}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn records::Catalog catalog(){
    var records::Catalog c=records::empty();c.count=3;c.fields[0]=1;c.kinds[0]=1;c.types[0]=1;
    c.fields[1]=6;let u8[6] tags=[1,9,10,11,12,2];var usize i=0;while(i<6){c.types[16+i]=tags[i];i+=1;}
    c.fields[2]=1;c.types[32]=10;return c;
}
fn owners::Token create(ref records::Catalog c,ref mut owners::Table t,ref mut u8[] data){
    let i64[6] values=[-2147483648,-9223372036854775808,255,4294967295,-1,1];
    return token(owners::create_record(c,0,ref values,data,t));
}
@test fn void validation_only_result_matches_snapshot_catalog_owner_and_error_order(){
    let records::Catalog clean=catalog();var owners::Table table=owners::empty(128);var u8[128] data=[85;128];
    let owners::Token root=create(ref clean,ref mut table,ref mut data);let owners::Token bad=owners::Token{.slot=16,.generation=1};
    var usize count=0;var usize slot=0;while(slot<512){var records::Catalog c=clean;c.kinds[slot]=2;
        assert(compare(ref c,ref table,root,0,ref data,128)==6);
        c=clean;c.types[slot]=255;assert(compare(ref c,ref table,root,0,ref data,128)==6);slot+=1;count+=2;}
    var usize row=0;while(row<32){var records::Catalog c=clean;c.fields[row]=17;
        assert(compare(ref c,ref table,root,0,ref data,128)==6);row+=1;count+=1;}
    var usize mode=0;while(mode<12){var records::Catalog c=clean;
        if(mode==0){c.count=33;}else if(mode==1){c.count=0;}
        else if(mode==2){c.kinds[32]=1;c.types[32]=2;}else if(mode==3){c.fields[1]=5;c.types[21]=0;}
        else if(mode==4){c.types[16]=10;}else if(mode==5){c.types[21]=10;}
        else if(mode==6){c.kinds[0]=0;c.types[0]=10;}else if(mode==7){c.types[16]=12;}
        else if(mode==8){c.types[0]=2;}else if(mode==9){c.count=2;c.fields[2]=0;c.types[32]=0;}
        else if(mode==10){c.types[17]=1;}else{c.fields[0]=0;}
        let u8 a=compare(ref c,ref table,root,0,ref data,128);let u8 b=compare(ref c,ref table,root,1,ref data,128);
        assert(compare(ref c,ref table,bad,0,ref data,128)==1);mode+=1;count+=3;
    }
    var usize index=0;while(index<16){mode=0;while(mode<12){var owners::Table t=table;let owners::Owner prior=t.slots[index];
        if(mode==0){t.slots[index].generation=0;}else if(mode==1){t.slots[index].generation+=1;}
        else if(mode==2){t.slots[index].occupied=!prior.occupied;}else if(mode==3){t.slots[index].live=!prior.live;}
        else if(mode==4){t.slots[index].reading=true;}else if(mode==5){t.slots[index].writing=true;}
        else if(mode==6){t.slots[index].base=127;}else if(mode==7){t.slots[index].end=127;}
        else if(mode==8){t.slots[index].element=10;}else if(mode==9){t.slots[index].record=31;}
        else if(mode==10){t.slots[index].length=1;}else{t.slots[index].alignment=4;}
        let u8 checked=compare(ref clean,ref t,root,0,ref data,128);mode+=1;count+=1;}index+=1;}
    let usize[4] nominals=[0,1,31,18446744073709551615];index=0;while(index<4){
        let u8 checked=compare(ref clean,ref table,root,nominals[index],ref data,128);index+=1;count+=1;}
    let owners::Token[3] invalid=[bad,owners::Token{.slot=root.slot,.generation=0},owners::Token{.slot=root.slot,.generation=root.generation+1}];
    index=0;while(index<3){assert(compare(ref clean,ref table,invalid[index],0,ref data,128)==1);index+=1;count+=1;}
    let u8[4] bools=[0,1,2,255];index=0;while(index<4){data[32]=bools[index];
        assert(compare(ref clean,ref table,root,0,ref data,128)==if(index<2){0}else{11});index+=1;count+=1;}
    let usize[4] capacities=[0,39,127,128];index=0;while(index<4){
        let u8 checked=compare(ref clean,ref table,root,0,ref data,capacities[index]);index+=1;count+=1;}
    assert(compare(ref clean,ref table,root,1,ref data,128)==4);
    var records::Catalog corrupt=clean;corrupt.types[511]=2;
    assert(compare(ref corrupt,ref table,bad,0,ref data,128)==1);
    assert(compare(ref corrupt,ref table,root,1,ref data,128)==6);
    var owners::Table invalid_table=table;invalid_table.order[0]=16;
    assert(compare(ref corrupt,ref invalid_table,root,1,ref data,128)==3);
    var owners::Table scalar_table=owners::empty(128);var u8[128] scalar_data=[85;128];
    let arrays::Array shape=arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};
    let owners::Token scalar=token(owners::create(ref shape,42,ref mut scalar_data,ref mut scalar_table));
    assert(compare(ref corrupt,ref scalar_table,scalar,0,ref scalar_data,128)==4);count+=5;assert(count==1304);
}
@test fn void integer_patterns_nested_bools_and_forged_bindings_keep_snapshot_semantics(){
    let u8[5] tags=[1,9,10,11,12];var usize tag=0;var usize count=0;
    while(tag<5){var records::Catalog c=records::empty();c.count=1;c.fields[0]=16;var usize i=0;
        while(i<16){c.types[i]=tags[tag];i+=1;}var u8[128] data=[85;128];var owners::Table t=owners::empty(128);
        let i64[16] zeros=[0;16];let owners::Token root=token(owners::create_record(ref c,0,ref zeros,ref mut data,ref mut t));
        var usize pattern=0;var u8 value=0;while(pattern<256){i=0;while(i<t.arena.used){data[i]=value;i+=1;}
            assert(compare(ref c,ref t,root,0,ref data,128)==0);pattern+=1;count+=1;if(pattern<256){value+=1;}}tag+=1;
    }
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;var usize i=0;
    while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}
    var u8[128] data=[85;128];var owners::Table t=owners::empty(128);let i64[128] values=[1;128];
    var owners::Token root=token(owners::create_record(ref c,0,ref values,ref mut data,ref mut t));
    assert(compare(ref c,ref t,root,0,ref data,128)==0);count+=1;i=0;
    while(i<128){data[i]=2;assert(compare(ref c,ref t,root,0,ref data,128)==11);
        data[i]=255;assert(compare(ref c,ref t,root,0,ref data,128)==11);data[i]=1;i+=1;count+=2;}
    data=[0;128];assert(compare(ref c,ref t,root,0,ref data,128)==0);count+=1;
    c=records::empty();c.count=16;i=0;var u8 child=1;
    while(i<16){c.fields[i]=1;if(i<15){c.kinds[i*16]=1;c.types[i*16]=child;}i+=1;child+=1;}c.types[240]=2;
    data=[85;128];t=owners::empty(128);let i64[1] one=[1];root=token(owners::create_record(ref c,0,ref one,ref mut data,ref mut t));
    assert(compare(ref c,ref t,root,0,ref data,128)==0);data[0]=2;assert(compare(ref c,ref t,root,0,ref data,128)==11);count+=2;
    c=records::empty();c.count=17;i=0;child=1;
    while(i<17){c.fields[i]=1;if(i<16){c.kinds[i*16]=1;c.types[i*16]=child;}i+=1;child+=1;}c.types[256]=2;
    assert(compare(ref c,ref t,root,0,ref data,128)==6);count+=1;assert(count==1541);
    c=catalog();t=owners::empty(128);data=[85;128];root=create(ref c,ref mut t,ref mut data);
    let storage::Binding good=storage::Binding{.bytes=40,.alignment=8};let u8[128] saved=data;
    assert(checked(storage::validate_result(ref c,0,0,good,0,ref data,ref t.arena))==0);
    var usize mode=0;while(mode<5){var storage::Binding bad=good;
        if(mode==0){bad.bytes=0;}else if(mode==1){bad.bytes=39;}else if(mode==2){bad.bytes=18446744073709551615;}
        else if(mode==3){bad.alignment=0;}else{bad.alignment=4;}
        assert(checked(storage::validate_result(ref c,0,0,bad,1,ref data,ref t.arena))==6);mode+=1;
    }
    assert(checked(storage::validate_result(ref c,32,0,good,0,ref data,ref t.arena))==6);
    assert(checked(storage::validate_result(ref c,0,1,good,0,ref data,ref t.arena))==10);
    assert(checked(storage::validate_result(ref c,0,128,good,0,ref data,ref t.arena))==9);
    var arenas::Arena arena=t.arena;arena.used=0;
    assert(checked(storage::validate_result(ref c,0,0,good,1,ref data,ref arena))==4);
    assert(checked(storage::validate_result(ref c,0,0,good,0,ref data,ref arena))==9);
    arena=t.arena;arena.limit=129;assert(checked(storage::validate_result(ref c,0,0,good,0,ref data,ref arena))==3);
    i=0;while(i<128){assert(data[i]==saved[i]);i+=1;}
}
