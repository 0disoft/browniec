module host_wire;

import scalar_codec as scalar;
import std::num as num;

// Catalog wire tags differ from VM tags. No native pointers or owner tokens.
pub enum Error { Type; Count; Header; Length; Value; Limit; Reply; }
pub struct Field { u8 tag; i64 scalar; usize start; usize length; }
pub struct Request { Field[32] fields; usize count; }

pub fn usize payload_limit() { return 1048576; }
pub fn Field empty_field() { return Field{.tag=0,.scalar=0,.start=0,.length=0}; }
pub fn u8 scalar_tag(u8 tag) {
    if(tag==1){return 2;} if(tag==2){return 10;} if(tag==3){return 1;}
    if(tag==4){return 9;} if(tag==5){return 11;} if(tag==6){return 12;}
    return 0;
}
// Private VM register tag for immutable byte ranges. It has no scalar encoding.
pub fn u8 register_tag(u8 tag){return if(tag==7){14}else{scalar_tag(tag)};}
fn bool valid(u8 tag) { return tag>=1 && tag<=7; }
pub fn usize read_u32(ref u8[] input) {
    return input[0] as usize + input[1] as usize*256 +
        input[2] as usize*65536 + input[3] as usize*16777216;
}
pub fn void write_le(usize value,ref mut u8[] output) {
    var usize remaining=value; var usize i=0;
    while(i<output.len){
        let i64 digit=switch(num::i64_from_usize(remaining%256)){
            case .ok(n):{n}case .err(_):{assert(false);0}
        };
        output[i]=switch(num::u8_from_i64(digit)){
            case .ok(n):{n}case .err(_):{assert(false);0}
        };
        remaining/=256;i+=1;
    }
}
fn Result<usize,Error> bounded(usize length,usize limit) {
    if(limit>payload_limit() || length>limit){return .err(.Limit);}
    return .ok(length);
}
fn Result<usize,Error> field_length(ref u8[] input,usize offset,u8 expected){
    if(!valid(expected)){return .err(.Type);}
    if(offset>input.len || input.len-offset<8){return .err(.Header);}
    if(input[offset]!=expected){return .err(.Type);}
    if(input[offset+1]!=0 || input[offset+2]!=0 || input[offset+3]!=0){return .err(.Header);}
    return .ok(read_u32(input[offset+4..offset+8]));
}
// Nonempty replies start with the whole TLV header. Validate the declared
// envelope and fixed scalar width before reserving any snapshot storage.
pub fn Result<usize,Error> reply_prefix(u8 kind,u8 result_tag,ref u8[] prefix,usize total){
    let usize bounded_total=bounded(total,payload_limit())?;
    if(kind>1){return .err(.Reply);}
    let u8 tag=if(kind==1){5}else{result_tag};
    let usize size=field_length(prefix,0,tag)?;
    if(prefix.len>bounded_total || size!=bounded_total-8){return .err(.Length);}
    if(tag!=7 && size!=scalar::width(scalar_tag(tag))){return .err(.Length);}
    return .ok(bounded_total);
}
fn Result<Field,Error> parse_field(ref u8[] input,usize offset,u8 expected) {
    let usize size=field_length(input,offset,expected)?;
    let u8 tag=expected;
    let usize start=offset+8;
    if(size>input.len-start){return .err(.Length);}
    var i64 cell=0;
    if(tag!=7){
        if(size!=scalar::width(scalar_tag(tag))){return .err(.Length);}
        cell=switch(scalar::decode(scalar_tag(tag),input[start..start+size])){
            case .ok(n):{n}case .err(_):{return .err(.Value);}
        };
    }
    return .ok(Field{.tag=tag,.scalar=cell,.start=start,.length=size});
}

// Validate the entire envelope before returning descriptors into caller storage.
// Descriptors are offsets, not lifetime authority; keep input immutable while used.
pub fn Result<Request,Error> decode_request(ref u8[] input,ref u8[] expected,usize limit) {
    let usize total=bounded(input.len,limit)?;
    if(expected.len>32){return .err(.Count);}
    if(total<2){return .err(.Header);}
    let usize count=input[0] as usize+input[1] as usize*256;
    if(count>32 || count!=expected.len){return .err(.Count);}
    var Request result=Request{.fields=[empty_field();32],.count=count};
    var usize i=0;var usize offset=2;
    while(i<count){
        let Field field=parse_field(input,offset,expected[i])?;
        result.fields[i]=field;offset=field.start+field.length;i+=1;
    }
    if(offset!=total){return .err(.Length);}
    return .ok(result);
}
pub fn Result<Field,Error> decode_reply(u8 kind,u8 result_tag,ref u8[] input,usize limit) {
    let usize total=bounded(input.len,limit)?;
    if(kind>2){return .err(.Reply);}
    if(!valid(result_tag)){return .err(.Type);}
    if(kind==2){if(total!=0){return .err(.Length);}return .ok(empty_field());}
    let Field field=parse_field(input,0,if(kind==1){5}else{result_tag})?;
    if(field.start+field.length!=total){return .err(.Length);}
    return .ok(field);
}

// Scalars use their exact packed VM cell; only bytes fields use blob offsets.
fn Result<usize,Error> field_size(Field field,ref u8[] blob) {
    if(!valid(field.tag)){return .err(.Type);}
    if(field.tag==7){
        if(field.start>blob.len || field.length>blob.len-field.start){return .err(.Length);}
        return .ok(field.length);
    }
    let u8 tag=scalar_tag(field.tag);
    if(!scalar::fits(tag,field.scalar)){return .err(.Value);}
    return .ok(scalar::width(tag));
}
fn Result<usize,Error> add_field(usize total,usize size,usize limit) {
    if(total>limit || limit-total<8 || size>limit-total-8){return .err(.Limit);}
    return .ok(total+8+size);
}
// Called only after whole-message preflight. No allocation or fallible growth.
fn void emit(Field field,ref u8[] blob,usize size,ref mut u8[] output) {
    output[0]=field.tag;output[1]=0;output[2]=0;output[3]=0;
    write_le(size,output[4..8]);
    if(field.tag==7){
        var usize i=0;
        while(i<size){output[8+i]=blob[field.start+i];i+=1;}
    }else{
        let Result<usize,scalar::Error> encoded=scalar::encode(scalar_tag(field.tag),field.scalar,output[8..]);
        assert(encoded.is_ok);
    }
}
pub fn Result<usize,Error> request_size(ref Field[] fields,ref u8[] blob,usize limit){
    let usize checked=bounded(2,limit)?;
    if(fields.len>32){return .err(.Count);}
    var usize total=2;var usize i=0;
    while(i<fields.len){total=add_field(total,field_size(fields[i],blob)?,limit)?;i+=1;}
    return .ok(total);
}
pub fn Result<usize,Error> encode_request(ref Field[] fields,ref u8[] blob,
    ref mut u8[] output,usize limit) {
    let usize total=request_size(fields,blob,limit)?;
    if(output.len!=total){return .err(.Length);}
    write_le(fields.len,output[..2]);
    var usize i=0;var usize offset=2;
    while(i<fields.len){
        let Field field=fields[i];
        let usize size=if(field.tag==7){field.length}else{scalar::width(scalar_tag(field.tag))};
        emit(field,blob,size,output[offset..offset+8+size]);offset+=8+size;i+=1;
    }
    return .ok(total);
}
pub fn Result<usize,Error> encode_reply(u8 kind,u8 result_tag,Field field,ref u8[] blob,
    ref mut u8[] output,usize limit) {
    let usize capacity=bounded(output.len,limit)?;
    if(kind>2){return .err(.Reply);}
    if(!valid(result_tag)){return .err(.Type);}
    if(kind==2){if(capacity!=0){return .err(.Length);}return .ok(0);}
    if(field.tag!=if(kind==1){5}else{result_tag}){return .err(.Type);}
    let usize size=field_size(field,blob)?;
    let usize total=add_field(0,size,limit)?;
    if(capacity!=total){return .err(.Length);}
    emit(field,blob,size,output);
    return .ok(total);
}
