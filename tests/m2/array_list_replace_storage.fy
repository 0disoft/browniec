module tests::m2::array_list_replace_storage;
import array_layout as layouts;
import array_storage as storage;
import array_owners as owners;
import struct_layout as records;
import std::bytes as bytes;

fn layouts::Array shape(u8 tag,usize length){return switch(layouts::scalar(tag,length)){
    case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
};}
fn i64 read(ref owners::Table table,owners::Token t,usize i,ref u8[] data){return switch(owners::read(table,t,i,data)){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn usize code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}case .Metadata:{6}
    case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}
};}
fn bool failed(Result<usize,owners::Error> r,usize expected){return switch(r){
    case .ok(_):{false}case .err(e):{code(e)==expected}
};}
fn usize storage_code(storage::Error e){return switch(e){
        case .State:{3}case .Type:{4}case .Length:{5}case .Metadata:{6}case .Overflow:{7}
        case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}
};}
fn bool storage_failed(Result<usize,storage::Error> r,usize expected){return switch(r){
    case .ok(_):{false}case .err(e):{storage_code(e)==expected}
};}
fn void size(Result<usize,owners::Error> r,usize expected){switch(r){
    case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}
};}
fn void same_bytes(ref u8[] a,ref u8[] b){assert(a.len==b.len);var usize i=0;
    while(i<a.len){assert(a[i]==b[i]);i+=1;}}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}
fn bytes::Buffer backing(usize size){var bytes::Buffer b=switch(bytes::with_capacity(size)){
    case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
};assert(bytes::resize_zeroed(ref mut b,size).is_ok);return b;}

@test fn void replacements_preserve_six_domains_owner_identity_padding_and_neighbors(){
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[18] cells=[-2147483648,0,2147483647,0,1,0,-9223372036854775808,0,9223372036854775807,
        0,42,255,0,42,4294967295,0,42,-1];var usize t=0;
    while(t<6){var owners::Table table=owners::empty(48);var u8[48] data=[85;48];var u8[24] scratch=[77;24];
        let layouts::Array byte=shape(10,1);let layouts::Array layout=shape(tags[t],3);
        let owners::Token prefix=token(owners::create(ref byte,7,ref mut data,ref mut table));
        let owners::Token target=token(owners::create(ref layout,0,ref mut data,ref mut table));
        let owners::Token tail=token(owners::create(ref byte,9,ref mut data,ref mut table));
        let owners::Table before=table;let u8[48] old=data;
        size(owners::replace_values(ref layout,target,ref cells[t*3..t*3+3],ref mut scratch[..layout.bytes],ref mut data,ref table),layout.bytes);
        same_table(ref table,ref before);let owners::Owner span=before.slots[target.slot];var usize i=0;
        while(i<3){assert(read(ref table,target,i,ref data)==cells[t*3+i]);i+=1;}
        i=0;while(i<data.len){if(i<span.base || i>=span.end){assert(data[i]==old[i]);}i+=1;}
        assert(read(ref table,prefix,0,ref data)==7 && read(ref table,tail,0,ref data)==9);
        scratch[0]=77;assert(read(ref table,target,0,ref data)==cells[t*3]);t+=1;
    }
}
@test fn void replacement_succeeds_at_full_quota_and_all_sixteen_owner_slots_without_reallocation(){
    var owners::Table table=owners::empty(23);var u8[23] data=[85;23];var u8[8] scratch=[0;8];
    let layouts::Array pair=shape(1,2);let layouts::Array byte=shape(10,1);
    let owners::Token target=token(owners::create(ref pair,7,ref mut data,ref mut table));var usize i=0;
    while(i<15){let owners::Token other=token(owners::create(ref byte,9,ref mut data,ref mut table));i+=1;}
    assert(table.depth==16 && table.arena.used==23 && table.arena.limit==23);
    let owners::Table before=table;let u8[23] old=data;let i64[2] values=[20,22];
    i=0;while(i<64){size(owners::replace_values(ref pair,target,ref values,ref mut scratch,ref mut data,ref table),8);i+=1;}
    same_table(ref table,ref before);assert(read(ref table,target,0,ref data)==20 && read(ref table,target,1,ref data)==22);
    i=8;while(i<data.len){assert(data[i]==old[i]);i+=1;}
    switch(owners::create(ref byte,0,ref mut data,ref mut table)){case .ok(_):{assert(false);}case .err(e):{assert(code(e)==2);}};
    same_table(ref table,ref before);
}
@test fn void late_bad_cells_arity_scratch_and_shape_errors_preserve_every_published_byte_and_field(){
    let u8[4] tags=[1,2,10,11];let i64[4] bad=[2147483648,2,256,4294967296];var usize t=0;
    while(t<4){var owners::Table table=owners::empty(32);var u8[32] data=[85;32];var u8[24] scratch=[77;24];
        let layouts::Array layout=shape(tags[t],3);let owners::Token target=token(owners::create(ref layout,0,ref mut data,ref mut table));
        let owners::Table before=table;let u8[32] old=data;let i64[3] values=[0,1,bad[t]];
        assert(failed(owners::replace_values(ref layout,target,ref values,ref mut scratch[..layout.bytes],ref mut data,ref table),11));
        same_table(ref table,ref before);same_bytes(ref data,ref old);t+=1;
    }
    var owners::Table table=owners::empty(32);var u8[32] data=[85;32];var u8[9] scratch=[77;9];
    let layouts::Array pair=shape(1,2);let owners::Token target=token(owners::create(ref pair,7,ref mut data,ref mut table));
    let owners::Table before=table;let u8[32] old=data;let i64[3] values=[20,22,0];
    assert(failed(owners::replace_values(ref pair,target,ref values[..0],ref mut scratch[..8],ref mut data,ref table),5));
    assert(failed(owners::replace_values(ref pair,target,ref values[..1],ref mut scratch[..8],ref mut data,ref table),5));
    assert(failed(owners::replace_values(ref pair,target,ref values,ref mut scratch[..8],ref mut data,ref table),5));
    assert(failed(owners::replace_values(ref pair,target,ref values[..2],ref mut scratch[..7],ref mut data,ref table),5));
    assert(failed(owners::replace_values(ref pair,target,ref values[..2],ref mut scratch,ref mut data,ref table),5));
    var layouts::Array malformed=pair;malformed.stride=0;
    assert(failed(owners::replace_values(ref malformed,target,ref values[..2],ref mut scratch[..8],ref mut data,ref table),6));
    let layouts::Array octets=shape(10,2);let layouts::Array wrong_length=shape(1,1);
    assert(failed(owners::replace_values(ref octets,target,ref values[..2],ref mut scratch[..2],ref mut data,ref table),4));
    assert(failed(owners::replace_values(ref wrong_length,target,ref values[..1],ref mut scratch[..4],ref mut data,ref table),5));
    same_table(ref table,ref before);same_bytes(ref data,ref old);
    // Replacement, like fill, need not read obsolete destination scalar bytes.
    var owners::Table booleans=owners::empty(2);var u8[2] bools=[0;2];var u8[2] stage=[0;2];let layouts::Array b=shape(2,2);
    let owners::Token boolean=token(owners::create(ref b,0,ref mut bools,ref mut booleans));bools[1]=255;let i64[2] canonical=[1,0];
    size(owners::replace_values(ref b,boolean,ref canonical,ref mut stage,ref mut bools,ref booleans),2);
    assert(read(ref booleans,boolean,0,ref bools)==1 && read(ref booleans,boolean,1,ref bools)==0);
}
@test fn void storage_replacement_revalidates_full_extent_alignment_layout_and_arena(){
    var u8[32] data=[85;32];var u8[8] scratch=[77;8];var storage::Arena arena=storage::empty(32);arena.used=12;
    let layouts::Array pair=shape(1,2);let i64[2] values=[20,22];let u8[32] before=data;
    assert(storage_failed(storage::replace_values(ref pair,8,ref values,ref mut scratch,ref mut data,ref arena),9));
    assert(storage_failed(storage::replace_values(ref pair,1,ref values,ref mut scratch,ref mut data,ref arena),10));
    assert(storage_failed(storage::replace_values(ref pair,18446744073709551612,ref values,ref mut scratch,ref mut data,ref arena),9));
    var layouts::Array bad=pair;bad.alignment=0;
    assert(storage_failed(storage::replace_values(ref bad,4,ref values,ref mut scratch,ref mut data,ref arena),6));
    var storage::Arena corrupt=arena;corrupt.used=33;
    assert(storage_failed(storage::replace_values(ref pair,4,ref values,ref mut scratch,ref mut data,ref corrupt),3));
    corrupt=arena;corrupt.limit=33;
    assert(storage_failed(storage::replace_values(ref pair,4,ref values,ref mut scratch,ref mut data,ref corrupt),3));
    assert(arena.used==12 && arena.limit==32);same_bytes(ref data,ref before);
    assert(storage::replace_values(ref pair,4,ref values,ref mut scratch,ref mut data,ref arena).is_ok);
    assert(arena.used==12 && arena.limit==32 && data[4]==20 && data[8]==22);
    var usize i=0;while(i<data.len){if(i<4 || i>=12){assert(data[i]==85);}i+=1;}
}
@test fn void stale_record_locked_and_corrupt_owners_are_rejected_before_staging(){
    var owners::Table table=owners::empty(32);var u8[32] data=[85;32];var u8[8] scratch=[77;8];
    let layouts::Array pair=shape(1,2);let i64[2] values=[20,22];let owners::Token target=token(owners::create(ref pair,7,ref mut data,ref mut table));
    let owners::ReadLease reader=switch(owners::begin_read(ref mut table,target,data.len)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    {let owners::Table before=table;let u8[32] old=data;
        assert(failed(owners::replace_values(ref pair,target,ref values,ref mut scratch,ref mut data,ref table),3));
        same_table(ref table,ref before);same_bytes(ref data,ref old);assert(scratch[0]==77);
    }
    assert(owners::end_read(ref mut table,reader,data.len).is_ok);
    let owners::WriteLease writer=switch(owners::begin_write(ref mut table,target,0,2,data.len)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    {let owners::Table before=table;let u8[32] old=data;
        assert(failed(owners::replace_values(ref pair,target,ref values,ref mut scratch,ref mut data,ref table),3));
        same_table(ref table,ref before);same_bytes(ref data,ref old);assert(scratch[0]==77);
    }
    assert(owners::end_write(ref mut table,ref writer,data.len).is_ok);
    var owners::Table corrupt=table;corrupt.arena.used+=1;let owners::Table bad_before=corrupt;let u8[32] old=data;
    assert(failed(owners::replace_values(ref pair,target,ref values,ref mut scratch,ref mut data,ref corrupt),3));
    same_table(ref corrupt,ref bad_before);same_bytes(ref data,ref old);
    assert(owners::release(ref mut table,target,data.len).is_ok);
    let owners::Token fresh=token(owners::create(ref pair,9,ref mut data,ref mut table));assert(fresh.generation!=target.generation);
    {let owners::Table before=table;let u8[32] prior=data;
        assert(failed(owners::replace_values(ref pair,target,ref values,ref mut scratch,ref mut data,ref table),1));
        assert(failed(owners::replace_values(ref pair,owners::Token{.slot=16,.generation=1},ref values,ref mut scratch,ref mut data,ref table),1));
        assert(failed(owners::replace_values(ref pair,owners::Token{.slot=0,.generation=0},ref values,ref mut scratch,ref mut data,ref table),1));
        same_table(ref table,ref before);same_bytes(ref data,ref prior);
    }
    var records::Catalog c=records::empty();c.count=1;c.fields[0]=2;c.types[0]=1;c.types[1]=1;
    let owners::Token record=token(owners::create_record(ref c,0,ref values,ref mut data,ref mut table));
    {let owners::Table before=table;let u8[32] prior=data;
        assert(failed(owners::replace_values(ref pair,record,ref values,ref mut scratch,ref mut data,ref table),4));
        same_table(ref table,ref before);same_bytes(ref data,ref prior);
    }
}
@test fn void full_4096_cell_replacement_uses_the_existing_32768_byte_extent_and_guards(){
    var i64[4096] values=[0;4096];var i64 cell=-2048;var usize i=0;
    while(i<4096){values[i]=cell;cell+=1;i+=1;}values[0]=-9223372036854775808;values[4095]=9223372036854775807;
    var bytes::Buffer staged=backing(32768);var bytes::Buffer guarded=backing(32770);
    var owners::Table table=owners::empty(32768);let layouts::Array layout=shape(9,4096);
    {let ref mut u8[] stage=bytes::view_mut(ref mut staged);let ref mut u8[] all=bytes::view_mut(ref mut guarded);
        all[0]=85;all[32769]=85;let owners::Token target=token(owners::create(ref layout,7,all[1..32769],ref mut table));
        let owners::Table before=table;
        size(owners::replace_values(ref layout,target,ref values,stage,all[1..32769],ref table),32768);
        same_table(ref table,ref before);assert(table.arena.used==32768 && table.arena.limit==32768 && table.depth==1);
        i=0;while(i<4096){assert(read(ref table,target,i,all[1..32769])==values[i]);i+=1;}
    }
    let ref u8[] all=bytes::view(ref guarded);assert(all[0]==85 && all[32769]==85);
}
