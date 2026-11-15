module tests::m2::record_access_plan;
import array_owners as owners;
import struct_layout as records;
import struct_nested_storage as storage;
import array_storage as arenas;

// b992a2d owner access: resolve_record plans first, raw storage plans again.
fn owners::Error mapped(storage::Error e){return switch(e){
    case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}case .State:{.State}
    case .Alignment:{.Alignment}case .Quota:{.Quota}case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}};
}
fn Result<i64,owners::Error> original_read(ref records::Catalog c,ref owners::Table t,owners::Token token,ref usize[] path,ref u8[] data){
    let owners::Owner o=owners::resolve_record(c,t,token,data.len)?;
    return switch(storage::read(c,o.record,o.base,path,data,ref t.arena)){
        case .ok(v):{.ok(v)}case .err(e):{.err(mapped(e))}};
}
fn Result<usize,owners::Error> original_write(ref records::Catalog c,ref owners::Table t,owners::Token token,ref usize[] path,i64 value,ref mut u8[] data){
    let owners::Owner o=owners::resolve_record(c,t,token,data.len)?;
    return switch(storage::write(c,o.record,o.base,path,value,data,ref t.arena)){
        case .ok(v):{.ok(v)}case .err(e):{.err(mapped(e))}};
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void compare(ref records::Catalog c,ref owners::Table t,owners::Token token,ref usize[] path,i64 value,ref u8[] data,usize capacity){
    let Result<i64,owners::Error> a=original_read(c,t,token,path,data[..capacity]);
    let Result<i64,owners::Error> b=owners::read_record(c,t,token,path,data[..capacity]);
    assert(switch(a){case .ok(v):{switch(b){case .ok(w):{v==w}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
    assert(data.len==128);var u8[128] before=[0;128];var u8[128] after=[0;128];var usize i=0;
    while(i<128){before[i]=data[i];after[i]=data[i];i+=1;}
    let Result<usize,owners::Error> x=original_write(c,t,token,path,value,ref mut before[..capacity]);
    let Result<usize,owners::Error> y=owners::write_record(c,t,token,path,value,ref mut after[..capacity]);
    assert(switch(x){case .ok(v):{switch(y){case .ok(w):{v==w}case .err(_):{false}}}
        case .err(e):{switch(y){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
    i=0;while(i<128){assert(before[i]==after[i]);if(!y.is_ok){assert(after[i]==data[i]);}i+=1;}
}
fn records::Catalog catalog(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=1;c.kinds[0]=1;c.types[0]=1;
    c.fields[1]=6;let u8[6] tags=[1,9,10,11,12,2];var usize i=0;
    while(i<6){c.types[16+i]=tags[i];i+=1;}return c;
}
fn owners::Token create(ref records::Catalog c,ref mut owners::Table t,ref mut u8[] data){
    let i64[6] values=[-2147483648,-9223372036854775808,255,4294967295,-1,1];
    return switch(owners::create_record(c,0,ref values,data,t)){
        case .ok(token):{token}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
@test fn void owner_bound_reads_and_writes_match_original_for_all_catalog_slots_and_error_order(){
    let records::Catalog clean=catalog();var owners::Table table=owners::empty(128);var u8[128] data=[85;128];
    let owners::Token root=create(ref clean,ref mut table,ref mut data);let usize[2] path=[0,5];
    // Every field metadata slot, including inactive tails, remains authenticated.
    var usize slot=0;while(slot<512){var records::Catalog c=clean;c.kinds[slot]=2;
        compare(ref c,ref table,root,ref path,2,ref data,128);
        c=clean;c.types[slot]=255;compare(ref c,ref table,root,ref path,2,ref data,128);slot+=1;}
    var usize row=0;while(row<32){var records::Catalog c=clean;c.fields[row]=17;
        compare(ref c,ref table,root,ref path,2,ref data,128);row+=1;}
    var usize mode=0;while(mode<12){var records::Catalog c=clean;
        if(mode==0){c.count=33;}else if(mode==1){c.count=0;c.fields=[0;32];c.kinds=[0;512];c.types=[0;512];}
        else if(mode==2){c.count=1;c.fields[0]=1;c.kinds[0]=0;c.types[0]=10;c.fields[1]=0;c.types[16]=0;c.types[17]=0;c.types[18]=0;c.types[19]=0;c.types[20]=0;c.types[21]=0;}
        else if(mode==3){c.types[0]=0;}else if(mode==4){c.fields[1]=5;c.types[21]=0;}
        else if(mode==5){c.types[16]=10;}else if(mode==6){c.types[21]=10;}
        else if(mode==7){c.types[16]=12;}else if(mode==8){c.fields[0]=0;}
        else if(mode==9){c.count=3;c.fields[2]=1;c.kinds[32]=1;c.types[32]=2;}
        else if(mode==10){c.count=3;c.fields[2]=1;c.types[32]=10;}else{c.types[17]=1;}
        compare(ref c,ref table,root,ref path,2,ref data,128);
        compare(ref c,ref table,root,ref path[..0],2,ref data,128);
        compare(ref c,ref table,owners::Token{.slot=16,.generation=1},ref path,2,ref data,128);mode+=1;
    }
    var usize index=0;while(index<16){mode=0;while(mode<8){var owners::Table t=table;
        if(mode==0){t.slots[index].generation=0;}else if(mode==1){t.slots[index].generation+=1;}
        else if(mode==2){t.slots[index].occupied=true;}else if(mode==3){t.slots[index].reading=true;}
        else if(mode==4){t.slots[index].writing=true;}else if(mode==5){t.slots[index].base=127;}
        else if(mode==6){t.slots[index].element=10;}else{t.slots[index].record=31;}
        compare(ref clean,ref t,root,ref path,2,ref data,128);mode+=1;}index+=1;}
    let usize[3] beyond=[0,5,0];let usize[2] outside=[0,6];
    compare(ref clean,ref table,root,ref beyond,2,ref data,128);
    compare(ref clean,ref table,root,ref outside,2,ref data,128);
    compare(ref clean,ref table,root,ref path[..0],2,ref data,128);
    compare(ref clean,ref table,root,ref path[..1],2,ref data,128);
    compare(ref clean,ref table,root,ref path,2,ref data,0);
    compare(ref clean,ref table,root,ref path,2,ref data,39);
    let i64[5] candidates=[0,1,2,-1,4294967296];var usize field=0;
    while(field<6){var usize[2] chosen=[0,field];index=0;while(index<5){
        compare(ref clean,ref table,root,ref chosen,candidates[index],ref data,128);index+=1;}field+=1;}
    data[32]=2;compare(ref clean,ref table,root,ref path,0,ref data,128);
}
@test fn void checked_storage_binding_rejects_forged_shape_before_path_or_payload_access(){
    let records::Catalog c=catalog();var owners::Table table=owners::empty(128);var u8[128] data=[85;128];
    let owners::Token root=create(ref c,ref mut table,ref mut data);let usize[2] path=[0,5];let u8[128] saved=data;
    let storage::Binding good=storage::Binding{.bytes=40,.alignment=8};
    assert(storage::read_bound(ref c,0,0,good,ref path,ref data,ref table.arena).is_ok);
    var usize mode=0;while(mode<5){var storage::Binding bad=good;
        if(mode==0){bad.bytes=0;}else if(mode==1){bad.bytes=39;}else if(mode==2){bad.bytes=18446744073709551615;}
        else if(mode==3){bad.alignment=0;}else{bad.alignment=4;}
        assert(switch(storage::read_bound(ref c,0,0,bad,ref path,ref data,ref table.arena)){
            case .ok(_):{false}case .err(e):{switch(e){case .Layout:{true}case .Bounds:{false}case .Fields:{false}case .State:{false}case .Alignment:{false}case .Quota:{false}case .Overflow:{false}case .Value:{false}case .Type:{false}}}});
        assert(switch(storage::write_bound(ref c,0,0,bad,ref path[..0],2,ref mut data,ref table.arena)){
            case .ok(_):{false}case .err(e):{switch(e){case .Layout:{true}case .Bounds:{false}case .Fields:{false}case .State:{false}case .Alignment:{false}case .Quota:{false}case .Overflow:{false}case .Value:{false}case .Type:{false}}}});mode+=1;
    }
    assert(!storage::read_bound(ref c,32,0,good,ref path,ref data,ref table.arena).is_ok);
    var arenas::Arena invalid=table.arena;invalid.used=0;
    assert(!storage::write_bound(ref c,0,0,good,ref path,1,ref mut data,ref invalid).is_ok);
    var usize i=0;while(i<128){assert(data[i]==saved[i]);i+=1;}
}
