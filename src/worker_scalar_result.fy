module worker_scalar_result;

import errors as errors;
import runtime_policy_json as json;
import std::bytes as bytes;
import std::num as num;

pub enum Status { Checked; Completed; Failed; }
pub struct Outcome { Status status; i64 value; errors::Error error; }
pub struct Expected { bool run; bool output; usize source_bytes; usize instructions; }

pub fn usize byte_limit(){return 256;}

pub fn bool is_completed(Outcome outcome){
    return switch(outcome.status){case .Completed:{true}case .Checked:{false}case .Failed:{false}};
}

pub fn Outcome checked(){
    return Outcome{.status=.Checked,.value=0,.error=errors::absent(0,0)};
}
pub fn Outcome completed(i64 value){
    return Outcome{.status=.Completed,.value=value,.error=errors::absent(0,0)};
}
pub fn Outcome failed(errors::Error error){
    return Outcome{.status=.Failed,.value=0,.error=error};
}

fn bool valid_error(errors::Error error, Expected expected){
    let u8 kind=error.kind;
    if(kind==11 || kind==errors::deadline_kind() || (expected.run && kind==errors::memory_limit_kind())){
        return error.location==errors::absent_location() && error.offset==0;
    }
    if(!(kind>=1 && kind<=8 || kind>=12 && kind<=15 || kind==18 || (expected.run && expected.output && kind==20))){return false;}
    if(!expected.run && !(kind<=5 || kind==15 || kind==18)){return false;}
    if(error.location==0){return error.offset<=expected.source_bytes;}
    if(error.location==errors::instruction_location()){
        return kind==5 && error.offset<expected.instructions;
    }
    return error.location==errors::absent_location() && error.offset==0;
}

fn bool valid(Outcome out,Expected expected){
    return switch(out.status){
        case .Checked:{!expected.run}
        case .Completed:{expected.run && out.value>= -2147483648 && out.value<=2147483647}
        case .Failed:{valid_error(out.error,expected)}
    };
}

fn Result<usize,json::Error> status(ref u8[] source,ref mut json::Cursor cursor){
    var u8[9] scratch=[0;9];
    let usize size=json::decoded(source,cursor,ref mut scratch)?;
    let ref u8[] word=ref scratch;
    let ref u8[] key=word[..size];
    var usize outcome=2;
    if(bytes::equal(key,b"checked")){outcome=0;}
    else if(bytes::equal(key,b"completed")){outcome=1;}
    else if(!bytes::equal(key,b"error")){return .err(json::error(.Value,cursor.token.begin));}
    discard json::next(source,cursor)?;
    return .ok(outcome);
}

fn u8 checked_byte(usize value){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{v}case .err(_):{assert(false);0}};
}

pub fn Result<Outcome,json::Error> parse(ref u8[] source,Expected expected){
    if(source.len>byte_limit()){return .err(json::error(.Limit,byte_limit()));}
    var json::Cursor cursor=json::start(source)?;
    discard json::take(source,ref mut cursor,123)?;
    var bool[6] seen=[false;6];
    var usize tag=0;
    var i64 value=0;
    var errors::Error error=errors::absent(0,0);
    while(cursor.token.kind!=125){
        let usize at=cursor.token.begin;
        let usize field=json::field(source,ref mut cursor,b"schema|status|return_i32|kind|location|offset")?;
        discard json::mark(ref mut seen,field,at)?;
        if(field==0){discard json::constant(source,ref mut cursor,b"browniec.worker-result/v1")?;}
        else if(field==1){tag=status(source,ref mut cursor)?;}
        else if(field==2){
            let usize begin=cursor.token.begin;
            let usize end=cursor.token.end;
            if(cursor.token.kind!=2 || end-begin>11){return .err(json::error(.Value,begin));}
            value=switch(num::parse_i64_decimal(source[begin..end])){
                case .ok(n):{n}case .err(_):{return .err(json::error(.Value,begin));}
            };
            discard json::next(source,ref mut cursor)?;
        }
        else if(field==3){error.kind=checked_byte(json::integer(source,ref mut cursor,1,255)?);}
        else if(field==4){error.location=checked_byte(json::integer(source,ref mut cursor,0,2)?);}
        else{error.offset=json::integer(source,ref mut cursor,0,if(expected.source_bytes>expected.instructions){
            expected.source_bytes
        }else{expected.instructions})?;}
        if(cursor.token.kind==125){break;}
        discard json::take(source,ref mut cursor,44)?;
        if(cursor.token.kind==125){return .err(json::error(.Json,cursor.token.begin));}
    }
    discard json::take(source,ref mut cursor,125)?;
    if(cursor.token.kind!=0){return .err(json::error(.Json,cursor.token.begin));}
    if(!seen[0] || !seen[1]){return .err(json::error(.Missing,0));}
    let Status state=if(tag==0){.Checked}else if(tag==1){.Completed}else{.Failed};
    let bool shape=switch(state){
        case .Checked:{!seen[2] && !seen[3] && !seen[4] && !seen[5]}
        case .Completed:{seen[2] && !seen[3] && !seen[4] && !seen[5]}
        case .Failed:{!seen[2] && seen[3] && seen[4] && seen[5]}
    };
    let Outcome out=Outcome{.status=state,.value=value,.error=error};
    if(!shape || !valid(out,expected)){return .err(json::error(.Relation,0));}
    return .ok(out);
}

pub fn Result<bytes::Buffer,json::Error> encode(Outcome out,Expected expected){
    if(!valid(out,expected)){return .err(json::error(.Relation,0));}
    return switch(encode_bytes(out)){
        case .ok(buffer):{.ok(buffer)}case .err(_):{.err(json::error(.Allocation,0))}
    };
}

fn Result<bytes::Buffer,bytes::BufferError> encode_bytes(Outcome out){
    var bytes::Buffer buffer=bytes::with_capacity(byte_limit())?;
    discard bytes::append(ref mut buffer,b"{\"schema\":\"browniec.worker-result/v1\",\"status\":")?;
    switch(out.status){
        case .Checked:{discard bytes::append(ref mut buffer,b"\"checked\"")?;}
        case .Completed:{
            discard bytes::append(ref mut buffer,b"\"completed\",\"return_i32\":")?;
            discard bytes::append_i64(ref mut buffer,out.value)?;
        }
        case .Failed:{
            discard bytes::append(ref mut buffer,b"\"error\",\"kind\":")?;
            discard bytes::append_usize(ref mut buffer,out.error.kind as usize)?;
            discard bytes::append(ref mut buffer,b",\"location\":")?;
            discard bytes::append_usize(ref mut buffer,out.error.location as usize)?;
            discard bytes::append(ref mut buffer,b",\"offset\":")?;
            discard bytes::append_usize(ref mut buffer,out.error.offset)?;
        }
    };
    discard bytes::append_byte(ref mut buffer,125)?;
    return .ok(buffer);
}
