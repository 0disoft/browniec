module tests::m2::subrecord_assign_plan;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_range as ranges;
import struct_nested_storage as storage;

fn owners::Error mapped(storage::Error e){return switch(e){
    case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}case .State:{.State}
    case .Alignment:{.Alignment}case .Quota:{.Quota}case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}};
}
// ef0a258 algorithm: two owner plans, two range plans, one raw storage plan.
fn Result<usize,owners::Error> original(ref records::Catalog c,ref owners::Table t,
    owners::Token destination,owners::Token source,usize nominal,usize target_leaf,usize source_leaf,ref mut u8[] data){
    let owners::Owner target=owners::resolve_record(c,t,destination,data.len)?;
    let owners::Owner origin=owners::resolve_record(c,t,source,data.len)?;
    let usize to=switch(ranges::offset(c,target.record,nominal,target_leaf)){
        case .ok(n):{n}case .err(_):{return .err(.Type);}};
    let usize from=switch(ranges::offset(c,origin.record,nominal,source_leaf)){
        case .ok(n):{n}case .err(_):{return .err(.Type);}};
    if(to>target.length || from>origin.length){return .err(.Bounds);}
    return switch(storage::assign(c,nominal,target.base+to,origin.base+from,data,ref t.arena)){
        case .ok(n):{.ok(n)}case .err(e):{.err(mapped(e))}};
}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn u8 compare(ref records::Catalog c,ref owners::Table t,owners::Token target,owners::Token source,
    usize nominal,usize to,usize from,ref u8[] data,usize capacity){
    assert(data.len==256);var u8[256] before=[0;256];var u8[256] after=[0;256];var usize i=0;
    while(i<256){before[i]=data[i];after[i]=data[i];i+=1;}
    let Result<usize,owners::Error> a=original(c,t,target,source,nominal,to,from,ref mut before[..capacity]);
    let Result<usize,owners::Error> b=owners::assign_subrecord(c,target,source,nominal,to,from,ref mut after[..capacity],t);
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
    c.fields[1]=2;c.types[16]=9;c.types[17]=2;
    c.fields[2]=2;c.types[32]=9;c.types[33]=2;c.fields[3]=1;c.types[48]=10;return c;
}
@test fn void shared_plan_matches_original_catalog_owner_faults_and_diagnostic_precedence(){
    let records::Catalog clean=catalog();var owners::Table table=owners::empty(256);var u8[256] data=[85;256];
    let i64[5] a=[17,42,1,0,0];let i64[5] b=[9,-9223372036854775808,0,9223372036854775807,1];
    let owners::Token p=token(owners::create_record(ref clean,0,ref a,ref mut data,ref mut table));
    let owners::Token q=token(owners::create_record(ref clean,0,ref b,ref mut data,ref mut table));
    let arrays::Array shape=switch(arrays::scalar(10,1)){case .ok(s):{s}case .err(_):{assert(false);arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    let owners::Token scalar=token(owners::create(ref shape,42,ref mut data,ref mut table));
    let owners::Token bad=owners::Token{.slot=16,.generation=1};var usize comparisons=0;
    var usize slot=0;while(slot<512){var records::Catalog c=clean;c.kinds[slot]=2;
        assert(compare(ref c,ref table,p,q,1,1,3,ref data,256)==6);
        c=clean;c.types[slot]=255;assert(compare(ref c,ref table,p,q,1,1,3,ref data,256)==6);slot+=1;comparisons+=2;}
    var usize row=0;while(row<32){var records::Catalog c=clean;c.fields[row]=17;
        assert(compare(ref c,ref table,p,q,1,1,3,ref data,256)==6);row+=1;comparisons+=1;}
    var usize mode=0;while(mode<12){var records::Catalog c=clean;
        if(mode==0){c.count=33;}else if(mode==1){c.count=0;}
        else if(mode==2){c.kinds[48]=1;c.types[48]=3;}else if(mode==3){c.types[1]=31;}
        else if(mode==4){c.fields[1]=1;c.types[17]=0;}else if(mode==5){c.types[16]=10;}
        else if(mode==6){c.types[17]=10;}else if(mode==7){c.fields[0]=0;}
        else if(mode==8){c.types[16]=12;}else if(mode==9){c.types[1]=2;}
        else if(mode==10){c.count=3;c.fields[3]=0;c.types[48]=0;}else{c.types[16]=1;}
        let u8 checked=compare(ref c,ref table,p,q,1,1,3,ref data,256);
        assert(compare(ref c,ref table,bad,q,1,1,3,ref data,256)==1);
        let u8 source_checked=compare(ref c,ref table,p,bad,1,1,3,ref data,256);mode+=1;comparisons+=3;
    }
    var usize index=0;while(index<16){mode=0;while(mode<12){var owners::Table t=table;let owners::Owner prior=t.slots[index];
        if(mode==0){t.slots[index].generation=0;}else if(mode==1){t.slots[index].generation+=1;}
        else if(mode==2){t.slots[index].occupied=!prior.occupied;}else if(mode==3){t.slots[index].live=!prior.live;}
        else if(mode==4){t.slots[index].reading=true;}else if(mode==5){t.slots[index].writing=true;}
        else if(mode==6){t.slots[index].base=127;}else if(mode==7){t.slots[index].end=127;}
        else if(mode==8){t.slots[index].element=10;}else if(mode==9){t.slots[index].record=31;}
        else if(mode==10){t.slots[index].length=1;}else{t.slots[index].alignment=4;}
        let u8 checked=compare(ref clean,ref t,p,q,1,1,3,ref data,256);mode+=1;comparisons+=1;}index+=1;}
    assert(comparisons==1284);
    let owners::Token[4] invalid=[bad,owners::Token{.slot=q.slot,.generation=0},owners::Token{.slot=q.slot,.generation=q.generation+1},scalar];
    index=0;while(index<4){let u8 x=compare(ref clean,ref table,invalid[index],q,1,1,3,ref data,256);
        let u8 y=compare(ref clean,ref table,p,invalid[index],1,1,3,ref data,256);index+=1;}
    var records::Catalog corrupt=clean;corrupt.types[511]=2;
    assert(compare(ref corrupt,ref table,scalar,bad,1,128,128,ref data,256)==4);
    assert(compare(ref corrupt,ref table,p,bad,1,128,128,ref data,256)==6);
    assert(compare(ref clean,ref table,p,bad,1,128,128,ref data,256)==1);
    assert(compare(ref clean,ref table,p,q,1,1,3,ref data,255)==3);
    assert(compare(ref clean,ref table,p,q,2,1,3,ref data,256)==4);
    data[table.slots[q.slot].base+32]=2;
    assert(compare(ref clean,ref table,p,q,1,1,3,ref data,256)==11);
    assert(compare(ref clean,ref table,p,q,1,128,3,ref data,256)==4);
}
@test fn void shared_plan_preserves_maximum_leaves_depth_and_different_root_scalar_layouts(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;var usize i=0;
    while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}
    var u8[256] data=[85;256];var owners::Table t=owners::empty(256);let i64[128] fields=[1;128];
    var owners::Token p=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    var owners::Token q=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    assert(compare(ref c,ref t,p,q,0,0,0,ref data,256)==0);
    assert(compare(ref c,ref t,p,q,1,112,0,ref data,256)==0);
    assert(compare(ref c,ref t,p,p,0,0,0,ref data,256)==0);
    assert(compare(ref c,ref t,p,q,1,128,0,ref data,256)==4);
    assert(compare(ref c,ref t,p,q,1,0,128,ref data,256)==4);
    data[255]=2;assert(compare(ref c,ref t,p,q,0,0,0,ref data,256)==11);
    assert(compare(ref c,ref t,q,q,0,0,0,ref data,256)==11);
    assert(compare(ref c,ref t,p,q,1,112,0,ref data,256)==0);
    c=records::empty();c.count=16;i=0;var u8 child=1;
    while(i<16){c.fields[i]=1;if(i<15){c.kinds[i*16]=1;c.types[i*16]=child;}i+=1;child+=1;}c.types[240]=2;
    t=owners::empty(256);data=[85;256];let i64[1] one=[1];
    p=token(owners::create_record(ref c,0,ref one,ref mut data,ref mut t));
    q=token(owners::create_record(ref c,0,ref one,ref mut data,ref mut t));
    i=0;while(i<16){assert(compare(ref c,ref t,p,q,i,0,0,ref data,256)==0);i+=1;}
    c=records::empty();c.count=3;c.fields[0]=2;c.types[0]=10;c.kinds[1]=1;c.types[1]=1;
    c.fields[1]=6;let u8[6] tags=[1,9,10,11,12,2];i=0;while(i<6){c.types[16+i]=tags[i];i+=1;}
    c.fields[2]=2;c.kinds[32]=1;c.types[32]=1;c.types[33]=12;
    t=owners::empty(256);data=[85;256];let i64[7] a=[17,0,0,0,0,0,0];
    let i64[7] b=[-2147483648,-9223372036854775808,255,4294967295,-1,1,99];
    p=token(owners::create_record(ref c,0,ref a,ref mut data,ref mut t));
    q=token(owners::create_record(ref c,2,ref b,ref mut data,ref mut t));
    assert(compare(ref c,ref t,p,q,1,1,0,ref data,256)==0);
    assert(compare(ref c,ref t,q,p,1,0,1,ref data,256)==0);
}
