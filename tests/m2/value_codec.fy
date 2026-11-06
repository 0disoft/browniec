module tests::m2::value_codec;
import value_codec as codec;
import value_properties as values;
import struct_layout as records;
import scalar_codec as scalars;
import std::bytes as bytes;

fn values::Node node(u8 kind,u8 first,u8 second,usize extent){return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};}
fn values::Catalog catalog(){
    var values::Catalog c=values::empty();c.count=21;
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){c.nodes[i]=node(1,tags[i],0,0);i+=1;}
    c.nodes[6]=node(4,0,0,0);c.nodes[7]=node(5,6,0,0);c.nodes[8]=node(6,0,6,0);c.nodes[9]=node(5,0,0,0);
    c.nodes[10]=node(2,9,0,4096);c.nodes[11]=node(6,10,4,0);c.nodes[12]=node(5,7,0,0);
    c.nodes[13]=node(5,12,0,0);c.nodes[14]=node(5,13,0,0);c.nodes[15]=node(3,0,0,0);c.nodes[16]=node(3,1,0,0);
    c.nodes[17]=node(4,0,0,0);c.nodes[18]=node(5,17,0,0);c.nodes[19]=node(2,10,0,8);c.nodes[20]=node(5,1,0,0);
    c.records.count=2;c.records.fields[0]=3;c.records.types[0]=10;c.records.types[1]=9;c.records.types[2]=2;
    c.records.fields[1]=2;c.records.kinds[16]=1;c.records.types[16]=0;c.records.types[17]=11;return c;
}
fn codec::Layout retained(ref values::Catalog c){return switch(codec::retain(c)){
    case .ok(v):{v}case .err(_):{assert(false);retained(c)}
};}
fn usize ok(Result<usize,codec::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn values::Property shape(ref codec::Layout l,usize id){return switch(codec::shape(l,id)){
    case .ok(v):{v}case .err(_):{assert(false);values::Property{.bytes=0,.alignment=0,.payload_offset=0,.wrapper_depth=0,.copyable=false,.contains_buffer=false}}
};}
fn codec::Active active(ref codec::Layout l,usize id,ref u8[] data){return switch(codec::inspect(l,id,data)){
    case .ok(v):{v}case .err(_):{assert(false);codec::Active{.present=false,.offset=0,.serial=0}}
};}
fn codec::Selection selected(ref codec::Layout l,usize id,u8 variant,ref u8[] data){return switch(codec::select(l,id,variant,data)){
    case .ok(v):{v}case .err(_):{assert(false);codec::Selection{.matched=false,.payload=false,.type_id=0,.offset=0,.bytes=0}}
};}
@test fn void retained_layout_and_six_scalar_domains_preserve_exact_cells_and_canonical_bool(){
    var values::Catalog c=catalog();let codec::Layout l=retained(ref c);c.count=0;c.nodes[6].kind=0;
    assert(codec::count(ref l)==21 && shape(ref l,6).bytes==8 && !shape(ref l,7).copyable);
    assert(switch(codec::same(ref l,7,18)){case .ok(v):{v}case .err(_):{false}});
    assert(switch(codec::same(ref l,15,16)){case .ok(v):{!v}case .err(_):{false}});
    let i64[6] cells=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;while(i<6){var u8[8] data=[88;8];let usize width=shape(ref l,i).bytes;
        assert(ok(codec::write_scalar(ref l,i,cells[i],ref mut data[..width]))==width);
        assert(switch(codec::read_scalar(ref l,i,ref data[..width])){case .ok(v):{v==cells[i]}case .err(_):{false}});
        assert(!active(ref l,i,ref data[..width]).present);i+=1;}
    var u8[1] bad=[99];assert(!codec::write_scalar(ref l,1,2,ref mut bad).is_ok && bad[0]==99);
    assert(!codec::inspect(ref l,1,ref bad).is_ok && !codec::shape(ref l,64).is_ok);
}
@test fn void tag_layout_uses_design_bytes_and_locates_only_the_single_active_buffer(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);var u8[160] data=[0;160];
    assert(ok(codec::write_scalar(ref l,5,-1,ref mut data[..8]))==8);
    assert(ok(codec::wrap_at(ref l,7,1,0,16,ref mut data))==16 && data[16]==1);
    let codec::Active first=active(ref l,7,ref data[16..32]);assert(first.present && first.offset==8 && first.serial==18446744073709551615);
    assert(ok(codec::wrap_at(ref l,12,1,16,40,ref mut data))==24);
    assert(ok(codec::wrap_at(ref l,13,1,40,72,ref mut data))==32);
    assert(ok(codec::wrap_at(ref l,14,1,72,112,ref mut data))==40);
    let codec::Active nested=active(ref l,14,ref data[112..152]);assert(nested.present && nested.offset==32 && nested.serial==first.serial);
    assert(ok(codec::wrap_at(ref l,7,0,0,16,ref mut data))==16 && !active(ref l,7,ref data[16..32]).present);
    assert(ok(codec::write_scalar(ref l,0,42,ref mut data[..4]))==4);
    assert(ok(codec::wrap_at(ref l,8,1,0,40,ref mut data))==16 && data[40]==0); // IR ok1 -> stored ok0
    assert(!active(ref l,8,ref data[40..56]).present && !shape(ref l,8).copyable);
    let codec::Selection yes=selected(ref l,8,1,ref data[40..56]);assert(yes.matched && yes.payload && yes.type_id==0 && yes.offset==8 && yes.bytes==4);
    assert(!selected(ref l,8,0,ref data[40..56]).matched);
    assert(shape(ref l,11).bytes==32776 && shape(ref l,11).payload_offset==8);
}
@test fn void records_validate_nested_scalars_and_all_padding_before_any_publication(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);var u8[96] data=[0;96];
    data[0]=255;data[16]=1;
    assert(scalars::encode(9,-9223372036854775808,ref mut data[8..16]).is_ok);
    assert(scalars::encode(11,4294967295,ref mut data[24..28]).is_ok);
    assert(!active(ref l,16,ref data[..32]).present && shape(ref l,16).bytes==32);
    assert(ok(codec::copy_at(ref l,16,0,64,ref mut data))==32 && bytes::equal(ref data[..32],ref data[64..96]));
    var usize i=64;while(i<96){data[i]=77;i+=1;}data[16]=2; // late invalid bool
    assert(!codec::copy_at(ref l,16,0,64,ref mut data).is_ok);i=64;while(i<96){assert(data[i]==77);i+=1;}
    data[16]=1;data[1]=1;assert(!codec::inspect(ref l,16,ref data[..32]).is_ok);
    data[1]=0;data[31]=1;assert(!codec::inspect(ref l,16,ref data[..32]).is_ok);
    data[31]=0;data[23]=1;assert(!codec::inspect(ref l,16,ref data[..32]).is_ok);
}
@test fn void one_backing_copies_support_both_alias_directions_and_reject_unsafe_tag_overlap_atomically(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);
    var u8[24] data=[0;24];var usize i=0;var u8 value=1;while(i<16){data[i]=value;value+=1;i+=1;}
    assert(ok(codec::copy_at(ref l,19,0,4,ref mut data))==8);
    i=0;value=1;while(i<8){assert(data[4+i]==value);i+=1;value+=1;}
    assert(ok(codec::copy_at(ref l,19,4,0,ref mut data))==8);i=0;value=1;
    while(i<8){assert(data[i]==value);i+=1;value+=1;}
    let u8[24] before=data;
    assert(!codec::copy_at(ref l,19,18446744073709551615,0,ref mut data).is_ok && bytes::equal(ref data,ref before));
    assert(!codec::wrap_at(ref l,9,1,0,0,ref mut data).is_ok && bytes::equal(ref data,ref before));
    assert(!codec::wrap_at(ref l,9,1,0,20,ref mut data).is_ok && bytes::equal(ref data,ref before));
    data[0]=2;let u8[24] malformed=data;
    assert(!codec::wrap_at(ref l,20,1,0,16,ref mut data).is_ok && bytes::equal(ref data,ref malformed));
}
@test fn void active_tags_inactive_bytes_and_opaque_words_are_checked_without_owner_authority(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);var u8[32] data=[0;32];
    assert(!codec::inspect(ref l,6,ref data[..8]).is_ok); // zero is no owner serial
    assert(ok(codec::write_scalar(ref l,5,7,ref mut data[..8]))==8);
    assert(ok(codec::wrap_at(ref l,8,0,0,16,ref mut data))==16 && data[16]==1); // err Buffer
    let codec::Active owner=active(ref l,8,ref data[16..32]);assert(owner.present && owner.serial==7 && owner.offset==8);
    data[16]=2;assert(!codec::inspect(ref l,8,ref data[16..32]).is_ok);data[16]=1;
    data[17]=1;assert(!codec::inspect(ref l,8,ref data[16..32]).is_ok);data[17]=0;
    assert(ok(codec::wrap_at(ref l,7,0,0,16,ref mut data))==16);
    data[24]=255;assert(!codec::inspect(ref l,7,ref data[16..32]).is_ok); // check bytes, never resolve inactive token
    data[24]=0;let codec::Selection none=selected(ref l,7,0,ref data[16..32]);assert(none.matched && !none.payload && none.bytes==0);
    assert(!codec::select(ref l,7,2,ref data[16..32]).is_ok);
}
fn bytes::Buffer backing(usize size){var bytes::Buffer b=switch(bytes::with_capacity(size)){
    case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
};assert(bytes::resize_zeroed(ref mut b,size).is_ok);return b;}
@test fn void maximum_arrays_records_and_independent_depth_are_bounded_and_layout_snapshots_are_immutable(){
    var values::Catalog c=catalog();let codec::Layout l=retained(ref c);var bytes::Buffer a=backing(32776);
    assert(!active(ref l,11,bytes::view(ref a)).present); // ok0, i64[4096] payload, all zero
    let ref mut u8[] all=bytes::view_mut(ref mut a);all[32775]=128;
    assert(!active(ref l,11,bytes::view(ref a)).present); // final i64 sign byte
    c.records=records::empty();c.records.count=16;let u8[16] next=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,2];
    var usize i=0;while(i<16){c.records.fields[i]=1;c.records.kinds[i*16]=if(i<15){1}else{0};c.records.types[i*16]=next[i];i+=1;}
    c.nodes[15]=node(3,0,0,0);c.nodes[16]=node(3,0,0,0);let codec::Layout deep=retained(ref c);let u8[1] yes=[1];
    assert(!active(ref deep,15,ref yes).present);
    c.records.kinds[15*16]=1;c.records.types[15*16]=0;assert(!codec::retain(ref c).is_ok);
    assert(!active(ref deep,15,ref yes).present);
    c=catalog();c.records=records::empty();c.records.count=3;c.records.fields[0]=16;c.records.fields[1]=16;c.records.fields[2]=2;
    i=0;while(i<16){c.records.types[i]=9;c.records.kinds[16+i]=1;c.records.types[16+i]=0;i+=1;}
    c.records.kinds[32]=1;c.records.types[32]=1;c.records.kinds[33]=1;c.records.types[33]=1;c.nodes[15]=node(3,2,0,0);
    let codec::Layout maximum=retained(ref c);var bytes::Buffer record=backing(4096);
    assert(shape(ref maximum,15).bytes==4096 && !active(ref maximum,15,bytes::view(ref record)).present);
    c.records.count=4;c.records.fields[3]=3;i=48;while(i<51){c.records.kinds[i]=1;c.records.types[i]=1;i+=1;}
    assert(!codec::retain(ref c).is_ok);c.count=65;assert(!codec::retain(ref c).is_ok);
}
