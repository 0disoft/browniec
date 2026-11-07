module tests::m2::host_wire;
import host_wire as wire;
import std::bytes as bytes;
import std::num as num;

fn wire::Field field(u8 tag,i64 scalar,usize start,usize length){
    return wire::Field{.tag=tag,.scalar=scalar,.start=start,.length=length};
}
fn void unchanged(ref u8[] output){var usize i=0;while(i<output.len){assert(output[i]==85);i+=1;}}
fn wire::Request request(ref u8[] input,ref u8[] tags,usize limit){
    return switch(wire::decode_request(input,tags,limit)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };
}
fn wire::Field reply(u8 kind,u8 tag,ref u8[] input){
    return switch(wire::decode_reply(kind,tag,input,1048576)){
        case .ok(v):{v}case .err(_):{assert(false);wire::empty_field()}
    };
}
fn void vector(u8 tag,i64 cell,ref u8[] expected){
    var u8[18] out=[85;18];
    let Result<usize,wire::Error> encoded=wire::encode_reply(0,tag,field(tag,cell,0,0),b"",ref mut out[1..1+expected.len],1048576);
    assert(encoded.is_ok && out[0]==85 && out[1+expected.len]==85);
    assert(bytes::equal(ref out[1..1+expected.len],expected));
    assert(reply(0,tag,expected).scalar==cell);
}

@test fn void reference_vectors_and_all_scalar_extremes_match_exact_bytes(){
    let ref u8[] input=b"\x02\x00\x03\x00\x00\x00\x04\x00\x00\x00\xf9\xff\xff\xff\x07\x00\x00\x00\x03\x00\x00\x00a\x00b";
    let wire::Request decoded=request(input,b"\x03\x07",25);
    assert(decoded.count==2 && decoded.fields[0].scalar==-7);
    assert(decoded.fields[1].start==22 && decoded.fields[1].length==3);
    let wire::Field[2] fields=[field(3,-7,0,0),field(7,0,0,3)];
    var u8[25] out=[0;25];
    let Result<usize,wire::Error> encoded=wire::encode_request(ref fields,b"a\x00b",ref mut out,25);
    assert(encoded.is_ok && bytes::equal(ref out,input));
    vector(1,0,b"\x01\x00\x00\x00\x01\x00\x00\x00\x00");
    vector(1,1,b"\x01\x00\x00\x00\x01\x00\x00\x00\x01");
    vector(2,255,b"\x02\x00\x00\x00\x01\x00\x00\x00\xff");
    vector(3,-2147483648,b"\x03\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x80");
    vector(3,2147483647,b"\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\x7f");
    vector(4,-9223372036854775808,b"\x04\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80");
    vector(4,9223372036854775807,b"\x04\x00\x00\x00\x08\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\x7f");
    vector(5,4294967295,b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff");
    vector(6,-1,b"\x06\x00\x00\x00\x08\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff");
    vector(6,-9223372036854775808,b"\x06\x00\x00\x00\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80");
}

@test fn void malformed_envelopes_and_every_truncated_prefix_reject(){
    let ref u8[] good=b"\x01\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01";
    var usize i=0;
    while(i<good.len){assert(!wire::decode_request(good[..i],b"\x01",1048576).is_ok);i+=1;}
    let ref u8[] value=good[2..];i=0;
    while(i<value.len){assert(!wire::decode_reply(0,1,value[..i],1048576).is_ok);i+=1;}
    var u8[12] altered=[0;12];i=0;while(i<good.len){altered[i]=good[i];i+=1;}
    assert(!wire::decode_request(ref altered,b"\x01",1048576).is_ok);
    i=0;
    while(i<256){
        // All nonzero reserved values and all noncanonical bool values reject.
        if(i>0){altered[3]=std_byte(i);
            assert(!wire::decode_request(ref altered[..11],b"\x01",1048576).is_ok);}
        i+=1;
    }
    altered[3]=0;altered[10]=2;
    assert(!wire::decode_request(ref altered[..11],b"\x01",1048576).is_ok);
    altered[10]=1;altered[2]=255;
    assert(!wire::decode_request(ref altered[..11],b"\x01",1048576).is_ok);
    altered[2]=1;altered[6]=255;altered[7]=255;altered[8]=255;altered[9]=255;
    assert(!wire::decode_request(ref altered[..11],b"\x01",1048576).is_ok);
    assert(!wire::decode_request(good,b"\x02",1048576).is_ok);
    assert(!wire::decode_request(good,b"",1048576).is_ok);
    assert(!wire::decode_request(b"\x21\x00",b"",1048576).is_ok);
}

fn u8 std_byte(usize value){
    let i64 n=switch(num::i64_from_usize(value)){case .ok(n):{n}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(n)){case .ok(n):{n}case .err(_):{assert(false);0}};
}

@test fn void reply_kind_contracts_empty_bytes_and_fatal_are_exact(){
    let ref u8[] err=b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff";
    assert(reply(1,7,err).scalar==4294967295);
    assert(!wire::decode_reply(0,7,err,1048576).is_ok);
    assert(!wire::decode_reply(1,5,b"\x02\x00\x00\x00\x01\x00\x00\x00\x01",1048576).is_ok);
    assert(wire::decode_reply(2,7,b"",0).is_ok);
    assert(!wire::decode_reply(2,7,b"\x00",1048576).is_ok);
    assert(!wire::decode_reply(3,7,b"",1048576).is_ok);
    let wire::Field empty=reply(0,7,b"\x07\x00\x00\x00\x00\x00\x00\x00");
    assert(empty.start==8 && empty.length==0);
    var u8[12] output=[85;12];
    let Result<usize,wire::Error> encoded=wire::encode_reply(1,7,field(5,4294967295,0,0),b"",ref mut output,12);
    assert(encoded.is_ok && bytes::equal(ref output,err));
    let Result<usize,wire::Error> fatal=wire::encode_reply(2,7,wire::empty_field(),b"",ref mut output[..0],0);
    assert(fatal.is_ok);
    assert(!wire::encode_reply(2,7,wire::empty_field(),b"",ref mut output,12).is_ok);
    assert(bytes::equal(ref output,err));
}

@test fn void encoder_rejects_late_errors_without_writing_any_byte(){
    var u8[32] output=[85;32];
    var wire::Field[2] fields=[field(3,42,0,0),field(1,2,0,0)];
    assert(!wire::encode_request(ref fields,b"",ref mut output[..23],32).is_ok);unchanged(ref output);
    fields[1]=field(7,0,18446744073709551615,1);
    assert(!wire::encode_request(ref fields,b"",ref mut output,32).is_ok);unchanged(ref output);
    fields[1]=field(7,0,0,18446744073709551615);
    assert(!wire::encode_request(ref fields,b"a",ref mut output,32).is_ok);unchanged(ref output);
    fields[1]=field(7,0,0,1);
    assert(!wire::encode_request(ref fields,b"a",ref mut output[..22],22).is_ok);unchanged(ref output);
    assert(!wire::encode_request(ref fields,b"a",ref mut output,32).is_ok);unchanged(ref output);
    assert(!wire::encode_request(ref fields,b"a",ref mut output,1048577).is_ok);unchanged(ref output);
    assert(!wire::encode_reply(0,3,field(5,42,0,0),b"",ref mut output[..12],12).is_ok);unchanged(ref output);
    assert(!wire::encode_reply(0,3,field(3,2147483648,0,0),b"",ref mut output[..12],12).is_ok);unchanged(ref output);
    assert(!wire::encode_reply(0,0,field(3,0,0,0),b"",ref mut output[..12],12).is_ok);unchanged(ref output);
}

@test fn void count_and_header_inclusive_limits_are_enforced(){
    let wire::Field[33] fields=[field(2,42,0,0);33];let u8[33] tags=[2;33];
    var u8[290] output=[85;290];
    assert(!wire::encode_request(ref fields,b"",ref mut output,290).is_ok);unchanged(ref output);
    assert(!wire::decode_request(b"\x20\x00",ref tags,290).is_ok);
    let Result<usize,wire::Error> encoded=wire::encode_request(ref fields[..32],b"",ref mut output,290);
    assert(encoded.is_ok && request(ref output,ref tags[..32],290).count==32);
    assert(!wire::decode_request(ref output,ref tags[..32],289).is_ok);
    var u8[2] empty=[85;2];
    assert(!wire::encode_request(ref fields[..0],b"",ref mut empty,1).is_ok);unchanged(ref empty);
    let Result<usize,wire::Error> zero=wire::encode_request(ref fields[..0],b"",ref mut empty,2);
    assert(zero.is_ok && request(ref empty,b"",2).count==0);
    assert(!wire::decode_request(ref empty,b"",1048577).is_ok);
}

@test fn void maximum_payload_accounts_for_all_headers_without_stack_arrays(){
    var bytes::Buffer blob=bytes::empty();var bytes::Buffer output=bytes::empty();
    let a=bytes::resize_zeroed(ref mut blob,1048568);
    let b=bytes::resize_zeroed(ref mut output,1048576);
    assert(a.is_ok);assert(b.is_ok);
    let wire::Field value=field(7,0,0,1048568);
    let Result<usize,wire::Error> encoded=wire::encode_reply(0,7,value,bytes::view(ref blob),bytes::view_mut(ref mut output),1048576);
    assert(encoded.is_ok && reply(0,7,bytes::view(ref output)).length==1048568);
    let wire::Field[1] fields=[value];
    assert(!wire::encode_request(ref fields,bytes::view(ref blob),bytes::view_mut(ref mut output),1048576).is_ok);
    let wire::Field[1] small=[field(7,0,0,1048566)];
    let Result<usize,wire::Error> request_encoded=wire::encode_request(ref small,bytes::view(ref blob),bytes::view_mut(ref mut output),1048576);
    assert(request_encoded.is_ok && request(bytes::view(ref output),b"\x07",1048576).fields[0].length==1048566);
}
