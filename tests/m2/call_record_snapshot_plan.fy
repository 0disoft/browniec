module tests::m2::call_record_snapshot_plan;
import struct_layout as records;
import struct_nested_storage as storage;
import array_storage as arenas;

fn u8 code(storage::Error e){return switch(e){
    case .Layout:{1}case .Bounds:{2}case .Fields:{3}case .State:{4}case .Alignment:{5}
    case .Quota:{6}case .Overflow:{7}case .Value:{8}case .Type:{9}};}
fn void rejected(ref records::Catalog c,usize record,usize base,storage::Binding binding,
    ref u8[] data,ref arenas::Arena arena,usize size,storage::Error expected){
    var u8[128] encoded=[77;128];
    let Result<usize,storage::Error> r=storage::snapshot_into_bound(c,record,base,binding,data,arena,ref mut encoded[..size]);
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==code(expected)}});
    var usize i=0;while(i<128){assert(encoded[i]==77);i+=1;}
}
fn void compare(ref records::Catalog c,usize record,usize base,storage::Binding binding,
    ref u8[] data,ref arenas::Arena arena){
    var u8[128] before=[77;128];var u8[128] after=[77;128];
    let Result<usize,storage::Error> a=storage::snapshot_into(c,record,base,data,arena,ref mut before[..binding.bytes]);
    let Result<usize,storage::Error> b=storage::snapshot_into_bound(c,record,base,binding,data,arena,ref mut after[..binding.bytes]);
    assert(switch(a){case .ok(n):{switch(b){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
    var usize i=0;while(i<128){assert(before[i]==after[i]);i+=1;}
}
@test fn void bound_snapshots_reject_catalog_binding_and_extent_faults_before_scratch(){
    var records::Catalog clean=records::empty();clean.count=2;clean.fields[0]=2;clean.types[0]=9;clean.types[1]=2;
    clean.fields[1]=1;clean.types[16]=10;var u8[64] data=[85;64];data[16]=1;
    var arenas::Arena arena=arenas::empty(64);arena.used=24;
    let storage::Binding good=storage::Binding{.bytes=16,.alignment=8};var usize count=0;var usize slot=0;
    while(slot<512){var records::Catalog c=clean;c.kinds[slot]=2;
        rejected(ref c,0,8,good,ref data,ref arena,16,.Layout);
        c=clean;c.types[slot]=255;rejected(ref c,0,8,good,ref data,ref arena,16,.Layout);slot+=1;count+=2;}
    slot=0;while(slot<32){var records::Catalog c=clean;c.fields[slot]=17;
        rejected(ref c,0,8,good,ref data,ref arena,16,.Layout);slot+=1;count+=1;}
    var usize mode=0;while(mode<5){var storage::Binding bad=good;
        if(mode==0){bad.bytes=0;}else if(mode==1){bad.bytes=15;}else if(mode==2){bad.bytes=18446744073709551615;}
        else if(mode==3){bad.alignment=0;}else{bad.alignment=4;}
        rejected(ref clean,0,1,bad,ref data,ref arena,0,.Layout);mode+=1;count+=1;}
    rejected(ref clean,32,8,good,ref data,ref arena,16,.Layout);
    rejected(ref clean,18446744073709551615,8,good,ref data,ref arena,16,.Layout);count+=2;
    rejected(ref clean,0,1,good,ref data,ref arena,16,.Alignment);
    rejected(ref clean,0,18446744073709551608,good,ref data,ref arena,16,.Bounds);count+=2;
    var arenas::Arena partial=arena;partial.used=23;
    rejected(ref clean,0,8,good,ref data,ref partial,16,.Bounds);
    rejected(ref clean,0,8,good,ref data[..63],ref arena,16,.State);
    rejected(ref clean,0,8,good,ref data,ref arena,15,.Bounds);count+=3;
    var records::Catalog large=records::empty();large.count=2;large.fields[0]=16;large.fields[1]=2;
    large.types[16]=9;large.types[17]=9;slot=0;
    while(slot<16){large.kinds[slot]=1;large.types[slot]=1;slot+=1;}
    let storage::Binding huge=storage::Binding{.bytes=256,.alignment=8};
    rejected(ref large,0,0,huge,ref data,ref arena,0,.Quota);count+=1;assert(count==1069);
    compare(ref clean,0,8,good,ref data,ref arena);
}
@test fn void bound_and_raw_snapshots_match_all_bool_positions_scalar_bits_and_nominal_depths(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;var usize i=0;
    while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}
    var u8[256] data=[85;256];i=0;while(i<128){data[i]=1;i+=1;}
    var arenas::Arena arena=arenas::empty(256);arena.used=128;
    let storage::Binding wide=storage::Binding{.bytes=128,.alignment=1};
    compare(ref c,0,0,wide,ref data,ref arena);var usize count=1;
    i=0;while(i<128){data[i]=2;compare(ref c,0,0,wide,ref data,ref arena);data[i]=1;i+=1;count+=1;}
    c=records::empty();c.count=16;i=0;var u8 child=1;
    while(i<16){c.fields[i]=1;if(i<15){c.kinds[i*16]=1;c.types[i*16]=child;}else{c.types[i*16]=2;}i+=1;child+=1;}
    let storage::Binding one=storage::Binding{.bytes=1,.alignment=1};i=0;
    while(i<16){compare(ref c,i,0,one,ref data,ref arena);i+=1;count+=1;}
    c.count=17;c.kinds[240]=1;c.types[240]=16;c.fields[16]=1;c.types[256]=2;
    compare(ref c,0,0,one,ref data,ref arena);count+=1;
    c=records::empty();c.count=1;c.fields[0]=6;let u8[6] tags=[1,9,10,11,12,2];i=0;
    while(i<6){c.types[i]=tags[i];i+=1;}data=[255;256];data[32]=1;
    let storage::Binding mixed=storage::Binding{.bytes=40,.alignment=8};
    compare(ref c,0,0,mixed,ref data,ref arena);data[32]=2;
    compare(ref c,0,0,mixed,ref data,ref arena);count+=2;assert(count==148);
}
