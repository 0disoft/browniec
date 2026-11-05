module tests::m2::array_list_storage;
import array_layout as layouts;
import array_storage as storage;
import array_owners as owners;
import std::bytes as bytes;

fn layouts::Array shape(u8 tag,usize length){return switch(layouts::scalar(tag,length)){
    case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
};}
fn owners::Token made(ref layouts::Array layout,ref i64[] values,ref mut u8[] scratch,
    ref mut u8[] data,ref mut owners::Table table){return switch(owners::create_values(layout,values,scratch,data,table)){
    case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
};}
fn i64 read(ref owners::Table table,owners::Token token,usize at,ref u8[] data){return switch(owners::read(table,token,at,data)){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn usize error(Result<owners::Token,owners::Error> result){return switch(result){
    case .ok(_):{0}case .err(e):{switch(e){
        case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}case .Metadata:{6}
        case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}
    }}
};}
fn void same_bytes(ref u8[] a,ref u8[] b){assert(a.len==b.len);var usize i=0;while(i<a.len){assert(a[i]==b[i]);i+=1;}}
fn bytes::Buffer backing(usize size){
    var bytes::Buffer result=switch(bytes::with_capacity(size)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    assert(bytes::resize_zeroed(ref mut result,size).is_ok);return result;
}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}
@test fn void exact_lists_preserve_six_scalar_domains_and_independent_values(){
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[18] cells=[-2147483648,0,2147483647,0,1,0,-9223372036854775808,0,9223372036854775807,
        0,42,255,0,42,4294967295,0,42,-1];
    var usize t=0;while(t<6){
        var owners::Table table=owners::empty(32);var u8[32] data=[85;32];var u8[24] scratch=[77;24];
        let layouts::Array layout=shape(tags[t],3);
        let owners::Token token=made(ref layout,ref cells[t*3..t*3+3],ref mut scratch[..layout.bytes],ref mut data,ref mut table);
        assert(table.depth==1 && table.arena.used==layout.bytes);
        var usize i=0;while(i<3){assert(read(ref table,token,i,ref data)==cells[t*3+i]);i+=1;}
        scratch[0]=77;
        assert(read(ref table,token,0,ref data)==cells[t*3]);
        assert(owners::write(ref table,token,1,0,ref mut data).is_ok);
        assert(read(ref table,token,1,ref data)==0 && read(ref table,token,2,ref data)==cells[t*3+2]);
        i=layout.bytes;while(i<data.len){assert(data[i]==85);i+=1;}
        assert(owners::release(ref mut table,token,data.len).is_ok && table.depth==0 && table.arena.used==0);t+=1;
    }
    var owners::Table pairs=owners::empty(16);let i64[2] input=[20,22];var u8[8] stage=[0;8];var u8[16] pair_data=[0;16];
    let layouts::Array pair=shape(1,2);
    let owners::Token first=made(ref pair,ref input,ref mut stage,ref mut pair_data,ref mut pairs);
    let owners::Token second=made(ref pair,ref input,ref mut stage,ref mut pair_data,ref mut pairs);
    assert(first.slot!=second.slot && pairs.depth==2 && pairs.arena.used==16);
    assert(owners::write(ref pairs,first,0,0,ref mut pair_data).is_ok);
    assert(read(ref pairs,second,0,ref pair_data)==20 && read(ref pairs,second,1,ref pair_data)==22 && input[0]==20);
}
@test fn void full_4096_values_fit_exact_backing_and_preserve_both_guards(){
    var i64[4096] values=[0;4096];var i64 cell=0;var usize i=0;
    while(i<4096){values[i]=cell;cell+=1;i+=1;}
    // Fairy's native fixed-array limit is 4096 elements; byte backing is supplied
    // by two host Buffers, as in the existing full-capacity storage regression.
    var bytes::Buffer staged=backing(32768);var bytes::Buffer guarded=backing(32770);
    var owners::Table table=owners::empty(32768);
    let layouts::Array layout=shape(9,4096);
    {
        let ref mut u8[] stage=bytes::view_mut(ref mut staged);
        let ref mut u8[] all=bytes::view_mut(ref mut guarded);all[0]=85;all[32769]=85;
        let owners::Token token=made(ref layout,ref values,stage,all[1..32769],ref mut table);
        assert(table.arena.used==32768 && table.depth==1);
        i=0;cell=0;while(i<4096){assert(read(ref table,token,i,all[1..32769])==cell);i+=1;cell+=1;}
    }
    let ref u8[] after=bytes::view(ref guarded);assert(after[0]==85 && after[32769]==85);
}
@test fn void failed_lists_leave_every_backing_byte_and_owner_field_unchanged(){
    var owners::Table table=owners::empty(12);var u8[32] data=[85;32];var u8[9] scratch=[77;9];
    let layouts::Array prefix=shape(10,1);let owners::Token prior=switch(owners::create(ref prefix,7,ref mut data,ref mut table)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let owners::Table before=table;let u8[32] bytes=data;let layouts::Array pair=shape(1,2);
    let i64[2] values=[20,22];let i64[2] invalid=[20,2147483648];
    assert(error(owners::create_values(ref pair,ref values[..1],ref mut scratch[..8],ref mut data,ref mut table))==5);
    assert(error(owners::create_values(ref pair,ref values[..0],ref mut scratch[..8],ref mut data,ref mut table))==5);
    assert(error(owners::create_values(ref pair,ref values,ref mut scratch[..7],ref mut data,ref mut table))==5);
    assert(error(owners::create_values(ref pair,ref values,ref mut scratch,ref mut data,ref mut table))==5);
    assert(error(owners::create_values(ref pair,ref invalid,ref mut scratch[..8],ref mut data,ref mut table))==11);
    var layouts::Array malformed=pair;malformed.stride=0;
    assert(error(owners::create_values(ref malformed,ref values,ref mut scratch[..8],ref mut data,ref mut table))==6);
    same_table(ref table,ref before);same_bytes(ref data,ref bytes);assert(read(ref table,prior,0,ref data)==7);
    var owners::Table quota=table;quota.arena.limit=11;let owners::Table quota_before=quota;
    assert(error(owners::create_values(ref pair,ref values,ref mut scratch[..8],ref mut data,ref mut quota))==8);
    same_table(ref quota,ref quota_before);same_bytes(ref data,ref bytes);
    var owners::Table corrupt=table;corrupt.arena.used=2;let owners::Table corrupt_before=corrupt;
    assert(error(owners::create_values(ref pair,ref values,ref mut scratch[..8],ref mut data,ref mut corrupt))==3);
    same_table(ref corrupt,ref corrupt_before);same_bytes(ref data,ref bytes);
    let layouts::Array boolean=shape(2,2);let i64[2] bad_bool=[1,2];
    assert(error(owners::create_values(ref boolean,ref bad_bool,ref mut scratch[..2],ref mut data,ref mut table))==11);
    let layouts::Array octets=shape(10,2);let i64[2] bad_u8=[20,256];
    assert(error(owners::create_values(ref octets,ref bad_u8,ref mut scratch[..2],ref mut data,ref mut table))==11);
    same_table(ref table,ref before);same_bytes(ref data,ref bytes);
    let owners::Token next=made(ref pair,ref values,ref mut scratch[..8],ref mut data,ref mut table);
    assert(table.depth==2 && table.arena.used==12 && read(ref table,next,0,ref data)==20 && read(ref table,next,1,ref data)==22);
    assert(data[0]==7 && data[1]==0 && data[2]==0 && data[3]==0 && data[12]==85);
    var owners::Table pressure=owners::empty(32);var u8[32] occupied=[85;32];var usize i=0;
    while(i<16){let owners::Token one=switch(owners::create(ref prefix,7,ref mut occupied,ref mut pressure)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };i+=1;}
    let owners::Table full_before=pressure;let u8[32] full_bytes=occupied;
    assert(error(owners::create_values(ref pair,ref values,ref mut scratch[..8],ref mut occupied,ref mut pressure))==2);
    same_table(ref pressure,ref full_before);same_bytes(ref occupied,ref full_bytes);
    var storage::Arena arena=storage::empty(32);arena.used=33;
    assert(!storage::initialize_values(ref pair,ref values,ref mut scratch[..8],ref mut occupied,ref mut arena).is_ok);
    assert(arena.used==33 && arena.limit==32);same_bytes(ref occupied,ref full_bytes);
}
