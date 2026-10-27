module tests::m2::struct_replace_values;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_nested_storage as store;
import array_storage as arenas;

fn records::Catalog catalog() {
    var records::Catalog c = records::empty(); c.count = 2;
    c.fields[0] = 1; c.kinds[0] = 1; c.types[0] = 1;
    c.fields[1] = 2; c.types[16] = 9; c.types[17] = 2;
    return c;
}
fn arrays::Array byte_array() {
    return arrays::Array { .element = 10, .length = 1, .stride = 1, .alignment = 1, .bytes = 1 };
}
fn owners::Token token(Result<owners::Token, owners::Error> result) {
    return switch (result) { case .ok(t): { t } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } } };
}
fn usize size(Result<usize, owners::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn i64 value(Result<i64, owners::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn u8 code(owners::Error error) {
    return switch (error) { case .Token: { 1 } case .Owners: { 2 } case .State: { 3 }
        case .Type: { 4 } case .Length: { 5 } case .Metadata: { 6 } case .Overflow: { 7 }
        case .Quota: { 8 } case .Bounds: { 9 } case .Alignment: { 10 } case .Value: { 11 } };
}
fn bool failed_token(Result<owners::Token, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn bool failed_read(Result<i64, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn bool failed(Result<usize, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn void same(ref owners::Table a, ref owners::Table b, ref u8[] bytes, ref u8[] before) {
    assert(a.depth == b.depth && a.arena.used == b.arena.used && a.arena.limit == b.arena.limit);
    var usize i = 0;
    while (i < 16) {
        assert(a.order[i] == b.order[i]);
        assert(a.slots[i].generation == b.slots[i].generation && a.slots[i].live == b.slots[i].live);
        assert(a.slots[i].occupied == b.slots[i].occupied && a.slots[i].mark == b.slots[i].mark);
        assert(a.slots[i].base == b.slots[i].base && a.slots[i].end == b.slots[i].end);
        assert(a.slots[i].element == b.slots[i].element && a.slots[i].length == b.slots[i].length);
        assert(a.slots[i].record == b.slots[i].record && a.slots[i].alignment == b.slots[i].alignment);
        i += 1;
    }
    assert(bytes.len == before.len); i = 0;
    while (i < bytes.len) { assert(bytes[i] == before[i]); i += 1; }
}

@test
fn void mixed_values_replace_nested_root_and_normalize_only_its_padding() {
 var records::Catalog c=records::empty();c.count=2;c.fields[0]=3;
 c.types[0]=10;c.kinds[1]=1;c.types[1]=1;c.types[2]=9;c.fields[1]=6;
 c.types[16]=2;c.types[17]=10;c.types[18]=1;c.types[19]=9;c.types[20]=11;c.types[21]=12;
 var u8[112] bytes=[85;112];var owners::Table t=owners::empty(112);
 let arrays::Array a=byte_array();
 let owners::Token head=token(owners::create(ref a,17,ref mut bytes,ref mut t));
 let i64[8] initial=[0;8];
 let owners::Token dst=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut t));
 let owners::Token tail=token(owners::create(ref a,19,ref mut bytes,ref mut t));
 let usize base=t.slots[dst.slot].base;let usize end=t.slots[dst.slot].end;
 var usize i=base;while(i<end){bytes[i]=85;i+=1;}
 let owners::Table before=t;let u8[112] saved=bytes;
 let i64[8] fields=[255,1,255,-2147483648,-9223372036854775808,4294967295,-1,42];
 assert(size(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t))==48);
 same(ref t,ref before,ref bytes[..0],ref saved[..0]);
 i=0;while(i<bytes.len){if(i<base || i>=end){assert(bytes[i]==saved[i]);}i+=1;}
 i=0;while(i<6){let usize[2] path=[1,i];assert(value(owners::read_record(ref c,ref t,dst,ref path,ref bytes))==fields[i+1]);i+=1;}
 i=1;while(i<8){assert(bytes[base+i]==0);i+=1;}
 assert(bytes[base+10]==0 && bytes[base+11]==0);
 i=28;while(i<32){assert(bytes[base+i]==0);i+=1;}
 assert(value(owners::read(ref t,head,0,ref bytes))==17 && value(owners::read(ref t,tail,0,ref bytes))==19);
}
@test
fn void invalid_values_and_field_counts_preserve_every_byte_and_owner() {
 var records::Catalog c=records::empty();c.count=1;c.fields[0]=6;
 c.types[0]=10;c.types[1]=1;c.types[2]=11;c.types[3]=9;c.types[4]=12;c.types[5]=2;
 var u8[64] bytes=[85;64];var owners::Table t=owners::empty(64);
 let i64[6] initial=[0;6];let owners::Token dst=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut t));
 let owners::Table before=t;let u8[64] saved=bytes;
 var i64[6] fields=[42,42,42,42,-1,1];
 fields[0]=256;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),11));fields[0]=42;
 fields[1]=2147483648;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),11));fields[1]=42;
 fields[2]=4294967296;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),11));fields[2]=42;
 fields[5]=2;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),11));
 fields[5]=-1;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),11));fields[5]=1;
 assert(failed(owners::replace_record(ref c,dst,0,ref fields[..5],ref mut bytes,ref t),5));
 assert(failed(owners::replace_record(ref c,dst,0,ref fields[..0],ref mut bytes,ref t),5));
 let i64[7] extra=[0;7];let i64[129] huge=[0;129];
 assert(failed(owners::replace_record(ref c,dst,0,ref extra,ref mut bytes,ref t),5));
 assert(failed(owners::replace_record(ref c,dst,0,ref huge,ref mut bytes,ref t),5));
 same(ref t,ref before,ref bytes,ref saved);
}
@test
fn void full_owner_table_and_full_arena_replace_all_128_leaves_in_place() {
 var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;
 var usize i=0;while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}
 var u8[2048] bytes=[85;2048];var owners::Table t=owners::empty(2048);
 let i64[128] zero=[0;128];let i64[128] fields=[1;128];
 var owners::Token[16] tokens=[owners::Token{.slot=0,.generation=0};16];
 i=0;while(i<16){tokens[i]=token(owners::create_record(ref c,0,ref zero,ref mut bytes,ref mut t));i+=1;}
 let owners::Table before=t;let u8[2048] saved=bytes;
 assert(size(owners::replace_record(ref c,tokens[7],0,ref fields,ref mut bytes,ref t))==128);
 same(ref t,ref before,ref bytes[..0],ref saved[..0]);
 i=0;while(i<2048){assert(bytes[i]==if(i>=896 && i<1024){1}else{0});i+=1;}
 assert(t.depth==16 && t.arena.used==t.arena.limit);
}
@test
fn void nominal_array_stale_and_forged_metadata_fail_without_writes() {
 var records::Catalog c=catalog();let i64[2] fields=[42,1];let arrays::Array a=byte_array();
 var u8[64] bytes=[85;64];var owners::Table t=owners::empty(64);
 let owners::Token dst=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut t));
 let owners::Token arr=token(owners::create(ref a,17,ref mut bytes,ref mut t));
 let owners::Table before=t;let u8[64] saved=bytes;
 assert(failed(owners::replace_record(ref c,dst,1,ref fields,ref mut bytes,ref t),4));
 assert(failed(owners::replace_record(ref c,dst,32,ref fields,ref mut bytes,ref t),4));
 assert(failed(owners::replace_record(ref c,arr,0,ref fields,ref mut bytes,ref t),4));
 let owners::Token stale=owners::Token{.slot=dst.slot,.generation=dst.generation+1};
 assert(failed(owners::replace_record(ref c,stale,0,ref fields,ref mut bytes,ref t),1));
 t.slots[dst.slot].record=1;assert(!owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t).is_ok);t=before;
 t.slots[dst.slot].alignment=1;assert(!owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t).is_ok);t=before;
 t.slots[dst.slot].base=1;assert(!owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t).is_ok);t=before;
 t.slots[dst.slot].length=15;assert(!owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t).is_ok);t=before;
 t.arena.used=65;assert(!owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t).is_ok);t=before;
 c.types[511]=2;assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),6));
 same(ref t,ref before,ref bytes,ref saved);
}
@test
fn void storage_checks_layout_extents_alignment_state_and_exact_field_count() {
 var records::Catalog c=catalog();let i64[2] fields=[42,1];let i64[3] extra=[42,1,9];
 var u8[64] bytes=[85;64];var arenas::Arena arena=arenas::empty(64);
 assert(store::initialize(ref c,0,ref fields,ref mut bytes,ref mut arena).is_ok);
 let u8[64] saved=bytes;let usize used=arena.used;
 assert(!store::replace_values(ref c,0,1,ref fields,ref mut bytes,ref arena).is_ok);
 assert(!store::replace_values(ref c,0,8,ref fields,ref mut bytes,ref arena).is_ok);
 assert(!store::replace_values(ref c,32,0,ref fields,ref mut bytes,ref arena).is_ok);
 assert(!store::replace_values(ref c,0,0,ref extra,ref mut bytes,ref arena).is_ok);
 assert(!store::replace_values(ref c,0,0,ref fields,ref mut bytes[..8],ref arena).is_ok);
 c.kinds[16]=1;c.types[16]=0;assert(!store::replace_values(ref c,0,0,ref fields,ref mut bytes,ref arena).is_ok);
 var usize i=0;while(i<64){assert(bytes[i]==saved[i]);i+=1;}assert(arena.used==used && arena.limit==64);
}
@test
fn void depth_sixteen_replacement_and_stale_generation_after_release_are_bounded() {
 var records::Catalog c=records::empty();c.count=16;var usize i=0;var u8 child=1;
 while(i<16){c.fields[i]=1;if(i<15){c.kinds[i*16]=1;c.types[i*16]=child;}else{c.types[i*16]=9;}i+=1;child+=1;}
 var u8[8] bytes=[0;8];var owners::Table t=owners::empty(8);let i64[1] initial=[0];let i64[1] fields=[-9223372036854775808];
 let owners::Token dst=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut t));
 assert(size(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t))==8);
 let usize[16] path=[0;16];assert(value(owners::read_record(ref c,ref t,dst,ref path,ref bytes))==-9223372036854775808);
 assert(owners::release(ref mut t,dst,bytes.len).is_ok);
 let owners::Token fresh=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut t));
 let owners::Table before=t;let u8[8] saved=bytes;
 assert(fresh.slot==dst.slot && fresh.generation!=dst.generation);
 assert(failed(owners::replace_record(ref c,dst,0,ref fields,ref mut bytes,ref t),1));
 same(ref t,ref before,ref bytes,ref saved);
}
