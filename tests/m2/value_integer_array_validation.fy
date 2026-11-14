module tests::m2::value_integer_array_validation;
import value_codec as codec;
import value_properties as properties;
import scalar_codec as scalar;
import std::bytes as bytes;
import std::num as num;

fn codec::Layout layout(u8 tag,usize length){
    var properties::Catalog c=properties::empty();c.count=1;
    c.nodes[0]=properties::Node{.kind=2,.first=tag,.second=0,.extent=length};
    return switch(codec::retain(ref c)){case .ok(v):{v}case .err(_):{assert(false);layout(tag,length)}};
}
// Original 1dc64da array branch: exact shape, then decode every scalar cell.
fn Result<codec::Active,codec::Error> original(ref codec::Layout l,ref u8[] data){
    let properties::Property p=codec::shape(l,0)?;
    if(data.len!=p.bytes){return .err(.Bounds);}
    let properties::Node n=codec::node(l,0)?;let usize stride=scalar::width(n.first);var usize at=0;
    while(at<p.bytes){if(!scalar::decode(n.first,data[at..at+stride]).is_ok){return .err(.Value);}at+=stride;}
    return .ok(codec::Active{.present=false,.offset=0,.serial=0});
}
fn u8 code(codec::Error e){return switch(e){case .Layout:{1}case .Type:{2}case .Bounds:{3}case .Value:{4}case .Overlap:{5}};}
fn void same(ref codec::Layout l,ref u8[] data){
    let Result<codec::Active,codec::Error> a=original(l,data);let Result<codec::Active,codec::Error> b=codec::inspect(l,0,data);
    assert(switch(a){case .ok(x):{switch(b){case .ok(y):{x.present==y.present && x.offset==y.offset && x.serial==y.serial}case .err(_):{false}}}
        case .err(x):{switch(b){case .ok(_):{false}case .err(y):{code(x)==code(y)}}}});
}
fn u8 octet(usize value){let i64 v=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(v)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void fill(ref mut u8[] data,usize stride,usize pattern){var usize i=0;while(i<data.len){
    var usize value=0;
    if(pattern==1){value=255;}
    else if(pattern==2){value=if(i%stride==stride-1){128}else{0};}
    else if(pattern==3){value=if(i%stride==stride-1){127}else{255};}
    else if(pattern==4){value=(i*73+19)%256;}
    else if(pattern==5){value=(i*29+239)%256;}
    data[i]=octet(value);i+=1;
}}
fn void integer_case(u8 tag,usize length){
    let codec::Layout l=layout(tag,length);let usize size=scalar::width(tag)*length;
    var bytes::Buffer backing=switch(bytes::with_capacity(size+1)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut backing,size+1).is_ok);var usize pattern=0;
    while(pattern<6){fill(bytes::view_mut(ref mut backing),scalar::width(tag),pattern);
        let ref u8[] data=bytes::view(ref backing);same(ref l,data[..size]);pattern+=1;}
    let ref u8[] data=bytes::view(ref backing);same(ref l,data[..size-1]);same(ref l,data);
}
fn void inactive_array_and_wrapper_padding_stay_canonical(){
    var properties::Catalog c=properties::empty();c.count=2;
    c.nodes[0]=properties::Node{.kind=2,.first=12,.second=0,.extent=4096};
    c.nodes[1]=properties::Node{.kind=5,.first=0,.second=0,.extent=0};
    let codec::Layout l=switch(codec::retain(ref c)){case .ok(v):{v}case .err(_):{
        assert(false);inactive_array_and_wrapper_padding_stay_canonical();return;}};
    // Mutating original analysis metadata must not change the retained type.
    c.nodes[0].first=2;
    var bytes::Buffer backing=switch(bytes::with_capacity(32776)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut backing,32776).is_ok);
    assert(codec::inspect(ref l,1,bytes::view(ref backing)).is_ok);
    {let ref mut u8[] data=bytes::view_mut(ref mut backing);data[32775]=255;}
    assert(!codec::inspect(ref l,1,bytes::view(ref backing)).is_ok); // None still requires zero payload.
    {let ref mut u8[] data=bytes::view_mut(ref mut backing);data[0]=1;}
    assert(codec::inspect(ref l,1,bytes::view(ref backing)).is_ok); // Some allows every integer bit pattern.
    {let ref mut u8[] data=bytes::view_mut(ref mut backing);data[1]=1;}
    assert(!codec::inspect(ref l,1,bytes::view(ref backing)).is_ok); // Active tag padding is still zero.
    {let ref mut u8[] data=bytes::view_mut(ref mut backing);data[1]=0;data[0]=2;}
    assert(!codec::inspect(ref l,1,bytes::view(ref backing)).is_ok);
}
@test fn void all_integer_tags_extremes_maximum_arrays_and_exact_lengths_match_original(){
    let u8[5] tags=[1,9,10,11,12];var usize i=0;while(i<5){
        integer_case(tags[i],1);integer_case(tags[i],17);integer_case(tags[i],4096);i+=1;}
    let codec::Layout l=layout(10,1);var u8[1] data=[0];var usize value=0;
    while(value<256){data[0]=octet(value);same(ref l,ref data);value+=1;}
    var properties::Catalog bad=properties::empty();bad.count=1;
    bad.nodes[0]=properties::Node{.kind=2,.first=13,.second=0,.extent=4096};assert(!codec::retain(ref bad).is_ok);
    bad.nodes[0]=properties::Node{.kind=2,.first=9,.second=0,.extent=0};assert(!codec::retain(ref bad).is_ok);
    bad.nodes[0]=properties::Node{.kind=2,.first=9,.second=0,.extent=4097};assert(!codec::retain(ref bad).is_ok);
    inactive_array_and_wrapper_padding_stay_canonical();
}
@test fn void bool_bytes_and_late_invalid_elements_still_reject_before_copy_publication(){
    let codec::Layout small=layout(2,8);var u8[16] data=[0;16];var usize value=0;
    while(value<256){var usize i=0;while(i<8){data[i]=0;data[8+i]=85;i+=1;}
        data[value%8]=octet(value);same(ref small,ref data[..8]);
        let Result<usize,codec::Error> result=codec::copy_at(ref small,0,0,8,ref mut data);
        if(value>1){assert(switch(result){case .ok(_):{false}case .err(e):{code(e)==4}});
            i=8;while(i<16){assert(data[i]==85);i+=1;}}
        else{assert(result.is_ok && bytes::equal(ref data[..8],ref data[8..16]));}value+=1;
    }
    let codec::Layout maximum=layout(2,4096);var bytes::Buffer backing=switch(bytes::with_capacity(4096)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut backing,4096).is_ok);same(ref maximum,bytes::view(ref backing));
    {let ref mut u8[] all=bytes::view_mut(ref mut backing);var usize i=0;while(i<4096){all[i]=1;i+=1;}}
    same(ref maximum,bytes::view(ref backing));let usize[3] positions=[0,2048,4095];var usize j=0;
    while(j<3){{let ref mut u8[] all=bytes::view_mut(ref mut backing);all[positions[j]]=2;}
        same(ref maximum,bytes::view(ref backing));
        assert(!codec::inspect(ref maximum,0,bytes::view(ref backing)).is_ok);
        {let ref mut u8[] all=bytes::view_mut(ref mut backing);all[positions[j]]=1;}j+=1;}
}
