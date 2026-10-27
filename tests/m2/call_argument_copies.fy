module tests::m2::call_argument_copies;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_nested_storage as storage;
import std::bytes as buffers;

fn records::Catalog catalog() {
    var records::Catalog c=records::empty(); c.count=4;
    c.fields[0]=2; c.types[0]=10; c.kinds[1]=1; c.types[1]=1;
    c.fields[1]=5; c.types[16]=9; c.types[17]=2; c.types[18]=11; c.types[19]=12; c.types[20]=1;
    c.fields[2]=2; c.types[32]=10; c.kinds[33]=1; c.types[33]=1;
    c.fields[3]=1; c.types[48]=10;
    return c;
}
fn arrays::Array layout(u8 tag,usize length) {
    return switch(arrays::scalar(tag,length)) {
        case .ok(a):{a}case .err(_):{assert(false);arrays::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
    };
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
    return switch(r){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};
}
fn owners::CallArgument record(owners::Token t,usize id) {
    return owners::CallArgument{.source=t,.element=0,.length=0,.record=id};
}
fn owners::CallArgument array(owners::Token t,u8 tag,usize length) {
    return owners::CallArgument{.source=t,.element=tag,.length=length,.record=0};
}
fn owners::Copies copy(ref records::Catalog c,ref owners::CallArgument[] args,
    ref mut u8[] data,ref mut owners::Table table) {
    return switch(owners::copy_call_arguments(c,args,data,table)) {
        case .ok(r):{r}case .err(_):{assert(false);owners::Copies{.tokens=[owners::Token{.slot=0,.generation=0};8],.count=0}}
    };
}
fn u8 code(owners::Error e) {
    return switch(e){case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}
        case .Length:{5}case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn bool failed(Result<owners::Copies,owners::Error> r,u8 expected) {
    return switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}};
}
fn i64 value(Result<i64,owners::Error> r) {
    return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn void same(ref owners::Table a,ref owners::Table b,ref u8[] data,ref u8[] before) {
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;
    while(i<16) {
        let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element);
        assert(x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;
    }
    assert(data.len==before.len);i=0;while(i<data.len){assert(data[i]==before[i]);i+=1;}
}

@test
fn void mixed_nested_records_normalize_padding_and_keep_copies_independent() {
    let records::Catalog c=catalog();var u8[192] data=[85;192];var owners::Table table=owners::empty(192);
    let i64[6] fields=[255,-9223372036854775808,1,4294967295,-1,-2147483648];
    let owners::Token r=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    let arrays::Array a=layout(10,3);let owners::Token t=token(owners::create(ref a,42,ref mut data,ref mut table));
    data[1]=201;data[17]=202;data[39]=203;
    let owners::CallArgument[3] args=[record(r,0),array(t,10,3),record(r,0)];
    let owners::Copies copies=copy(ref c,ref args,ref mut data,ref mut table);
    assert(copies.count==3 && table.depth==5 && table.arena.used==136 && data[136]==85);
    let usize first=table.slots[copies.tokens[0].slot].base;let usize last=table.slots[copies.tokens[2].slot].base;
    assert(first==48 && last==96 && data[first+1]==0 && data[first+17]==0 && data[first+39]==0);
    assert(data[1]==201 && data[17]==202 && data[39]==203);
    let usize[2] signed=[1,0];let usize[2] boolean=[1,1];let usize[2] wide=[1,2];let usize[2] unsigned=[1,3];let usize[2] small=[1,4];
    assert(value(owners::read_record(ref c,ref table,copies.tokens[0],ref signed,ref data))==-9223372036854775808);
    assert(value(owners::read_record(ref c,ref table,copies.tokens[0],ref boolean,ref data))==1);
    assert(value(owners::read_record(ref c,ref table,copies.tokens[0],ref wide,ref data))==4294967295);
    assert(value(owners::read_record(ref c,ref table,copies.tokens[0],ref unsigned,ref data))==-1);
    assert(value(owners::read_record(ref c,ref table,copies.tokens[0],ref small,ref data))==-2147483648);
    assert(owners::write_record(ref c,ref table,r,ref signed,0,ref mut data).is_ok);
    assert(owners::write_record(ref c,ref table,copies.tokens[0],ref signed,42,ref mut data).is_ok);
    assert(value(owners::read_record(ref c,ref table,copies.tokens[2],ref signed,ref data))==-9223372036854775808);
    assert(owners::write(ref table,t,0,0,ref mut data).is_ok);
    assert(value(owners::read(ref table,copies.tokens[1],0,ref data))==42);
    var usize i=3;while(i>0){i-=1;assert(owners::release(ref mut table,copies.tokens[i],data.len).is_ok);}
    assert(table.depth==2 && table.arena.used==43);
}

@test
fn void late_record_and_array_bool_errors_never_publish_a_prefix() {
    let records::Catalog c=catalog();var u8[192] data=[85;192];var owners::Table table=owners::empty(192);
    let arrays::Array a=layout(2,2);let owners::Token t=token(owners::create(ref a,1,ref mut data,ref mut table));
    let i64[6] fields=[7,42,1,0,0,0];let owners::Token r=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    let usize bool_at=table.slots[r.slot].base+16;data[bool_at]=2;
    let owners::CallArgument[2] args=[array(t,2,2),record(r,0)];let owners::Table before=table;let u8[192] bad_record=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),11));
    same(ref table,ref before,ref data,ref bad_record);
    data[bool_at]=1;data[1]=2;let u8[192] bad_array=data;
    let owners::CallArgument[2] reverse=[record(r,0),array(t,2,2)];
    assert(failed(owners::copy_call_arguments(ref c,ref reverse,ref mut data,ref mut table),11));
    same(ref table,ref before,ref data,ref bad_array);
}

@test
fn void late_identity_token_descriptor_catalog_and_shape_errors_are_atomic() {
    var records::Catalog c=catalog();var u8[128] data=[85;128];var owners::Table table=owners::empty(128);
    let i64[1] field=[42];let owners::Token r=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    let i64[6] fields=[0,0,1,0,0,0];let owners::Token nested=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    var owners::CallArgument[2] args=[record(r,3),record(nested,2)];let owners::Table before=table;let u8[128] old=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),4));same(ref table,ref before,ref data,ref old);
    args[1]=record(owners::Token{.slot=nested.slot,.generation=nested.generation+1},0);
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),1));same(ref table,ref before,ref data,ref old);
    args[1]=array(nested,10,40);
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),4));same(ref table,ref before,ref data,ref old);
    args[1]=record(nested,0);args[1].length=1;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref before,ref data,ref old);
    args[1]=record(nested,0);c.types[19]=10;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref before,ref data,ref old);
    c=catalog();c.kinds[16]=1;c.types[16]=0;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref before,ref data,ref old);
    c=catalog();table.slots[nested.slot].record=31;let owners::Table bad=table;
    args[1]=record(nested,31);
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref bad,ref data,ref old);
}

@test
fn void combined_quota_alignment_and_array_shape_failures_leave_bytes_untouched() {
    let records::Catalog c=catalog();var u8[128] data=[85;128];var owners::Table table=owners::empty(95);
    let i64[6] fields=[0,42,1,0,0,0];let owners::Token r=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    let arrays::Array a=layout(10,3);let owners::Token t=token(owners::create(ref a,42,ref mut data,ref mut table));
    var owners::CallArgument[2] args=[array(t,10,3),record(r,0)];let owners::Table before=table;let u8[128] old=data;
    // Original prefix 43, array copy ends 46, aligned record copy ends 88.
    table.arena.limit=87;let owners::Table low=table;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),8));same(ref table,ref low,ref data,ref old);
    table=before;args[0].length=2;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),5));same(ref table,ref before,ref data,ref old);
    args[0].length=3;args[0].record=1;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref before,ref data,ref old);
    args[0].record=0;table.arena.limit=88;let owners::Copies copies=copy(ref c,ref args,ref mut data,ref mut table);
    assert(table.arena.used==88 && data[46]==0 && data[47]==0 && data[88]==85);
    assert(table.slots[copies.tokens[1].slot].base==48);
}

@test
fn void owner_pressure_retirement_and_deferred_holes_are_preflighted() {
    let records::Catalog c=catalog();var u8[64] data=[85;64];var owners::Table table=owners::empty(64);let i64[1] field=[42];
    let owners::Token r=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    var usize i=1;while(i<15){let owners::Token t=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));i+=1;}
    let owners::CallArgument[2] args=[record(r,3),record(r,3)];let owners::Table before=table;let u8[64] old=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),2));same(ref table,ref before,ref data,ref old);
    table=owners::empty(64);table.slots[15].generation=0;
    i=0;while(i<14){let owners::Token t=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));i+=1;}
    let owners::Table retired=table;let u8[64] retired_data=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),2));same(ref table,ref retired,ref data,ref retired_data);
    table=owners::empty(4);let owners::Token first=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    let owners::Token middle=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    let owners::Token last=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    assert(owners::release(ref mut table,middle,data.len).is_ok);let owners::Table hole=table;let u8[64] hole_data=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),8));same(ref table,ref hole,ref data,ref hole_data);
    assert(owners::release(ref mut table,last,data.len).is_ok);let owners::Copies copies=copy(ref c,ref args,ref mut data,ref mut table);
    assert(table.depth==3 && copies.count==2 && table.arena.used==3 && first.slot==r.slot);
}

@test
fn void provisional_tokens_and_released_generations_cannot_become_sources() {
    let records::Catalog c=catalog();var u8[64] data=[85;64];var owners::Table table=owners::empty(64);let i64[1] field=[42];
    let owners::Token r=token(owners::create_record(ref c,3,ref field,ref mut data,ref mut table));
    var owners::CallArgument[2] args=[record(r,3),record(owners::Token{.slot=1,.generation=1},3)];
    let owners::Table before=table;let u8[64] old=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),1));same(ref table,ref before,ref data,ref old);
    args[1]=record(r,3);let owners::Copies first=copy(ref c,ref args,ref mut data,ref mut table);
    assert(owners::release(ref mut table,first.tokens[1],data.len).is_ok);assert(owners::release(ref mut table,first.tokens[0],data.len).is_ok);
    let owners::Copies second=copy(ref c,ref args,ref mut data,ref mut table);
    assert(first.tokens[0].slot==second.tokens[0].slot && first.tokens[0].generation!=second.tokens[0].generation);
    args[1]=record(first.tokens[0],3);let owners::Table live=table;let u8[64] live_data=data;
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),1));same(ref table,ref live,ref data,ref live_data);
}

@test
fn void zero_eight_nine_arguments_and_full_128_byte_roots_are_bounded() {
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=16;c.fields[1]=8;
    var usize i=0;while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}
    i=16;while(i<24){c.types[i]=10;i+=1;}
    var u8[2049] data=[85;2049];var owners::Table table=owners::empty(2048);let i64[128] fields=[255;128];
    let owners::Token r=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    let owners::CallArgument[9] args=[record(r,0);9];let owners::Table before=table;let u8[2049] old=data;
    let owners::Copies empty=copy(ref c,ref args[..0],ref mut data,ref mut table);
    assert(empty.count==0 && empty.tokens[0].generation==0);same(ref table,ref before,ref data,ref old);
    assert(failed(owners::copy_call_arguments(ref c,ref args,ref mut data,ref mut table),6));same(ref table,ref before,ref data,ref old);
    table.arena.used=129;let owners::Table corrupt=table;
    assert(failed(owners::copy_call_arguments(ref c,ref args[..1],ref mut data,ref mut table),3));same(ref table,ref corrupt,ref data,ref old);table=before;
    assert(failed(owners::copy_call_arguments(ref c,ref args[..1],ref mut data[..0],ref mut table),3));same(ref table,ref before,ref data,ref old);
    i=1;while(i<8){let owners::Token t=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));i+=1;}
    let owners::Copies copies=copy(ref c,ref args[..8],ref mut data,ref mut table);
    assert(copies.count==8 && table.depth==16 && table.arena.used==2048 && data[2048]==85);
    assert(copies.tokens[7].slot==15 && data[2047]==255 && data[1024]==255);
}

@test
fn void every_scalar_array_tag_and_the_full_payload_peak_remain_supported() {
    let records::Catalog c=catalog();let u8[6] tags=[2,10,1,9,11,12];let i64[6] values=[1,255,-2147483648,-9223372036854775808,4294967295,-1];
    var usize i=0;while(i<6) {
        var u8[96] data=[85;96];var owners::Table table=owners::empty(96);let arrays::Array shape=layout(tags[i],3);
        let owners::Token source=token(owners::create(ref shape,values[i],ref mut data,ref mut table));
        let owners::CallArgument[2] args=[array(source,tags[i],3),array(source,tags[i],3)];let owners::Copies copies=copy(ref c,ref args,ref mut data,ref mut table);
        assert(value(owners::read(ref table,copies.tokens[1],2,ref data))==values[i]);i+=1;
    }
    var buffers::Buffer buffer=switch(buffers::with_capacity(65536)){case .ok(b):{b}case .err(_):{assert(false);buffers::empty()}};
    assert(buffers::resize_zeroed(ref mut buffer,65536).is_ok);let ref mut u8[] data=buffers::view_mut(ref mut buffer);
    var owners::Table table=owners::empty(65536);let arrays::Array large=layout(9,4096);
    let owners::Token source=token(owners::create(ref large,-9223372036854775808,data,ref mut table));
    let owners::CallArgument[2] args=[array(source,9,4096),array(source,9,4096)];let owners::Table before=table;
    assert(failed(owners::copy_call_arguments(ref c,ref args,data,ref mut table),8));same(ref table,ref before,data,data);
    i=0;while(i<65536){assert(data[i]==if(i<32768 && i%8==7){128}else{0});i+=1;}
    let owners::Copies copies=copy(ref c,ref args[..1],data,ref mut table);
    assert(table.arena.used==65536 && value(owners::read(ref table,copies.tokens[0],4095,data))==-9223372036854775808);
}

@test
fn void snapshots_recheck_extent_scratch_size_and_maximum_nested_depth() {
    var records::Catalog c=records::empty();c.count=16;var usize i=0;var u8 child=1;
    while(i<15){c.fields[i]=1;c.kinds[i*16]=1;c.types[i*16]=child;i+=1;child+=1;}
    c.fields[15]=1;c.types[240]=2;var u8[32] data=[85;32];var owners::Table table=owners::empty(32);let i64[1] fields=[1];
    let owners::Token r=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut table));
    let owners::CallArgument[1] args=[record(r,0)];let owners::Copies copies=copy(ref c,ref args,ref mut data,ref mut table);
    assert(table.arena.used==2 && data[1]==1 && copies.count==1);
    var u8[2] scratch=[77;2];
    assert(!storage::snapshot_into(ref c,0,0,ref data,ref table.arena,ref mut scratch).is_ok && scratch[0]==77);
    assert(!storage::snapshot_into(ref c,0,2,ref data,ref table.arena,ref mut scratch[..1]).is_ok && scratch[0]==77);
    c.types[240]=99;assert(!storage::snapshot_into(ref c,0,0,ref data,ref table.arena,ref mut scratch[..1]).is_ok);
}
