module json_tokens;
import std::text as text;
import std::num as num;

// Bounded UTF-8 JSON tokens, not a DOM or schema/duplicate-key validator.
// Consumers must accept complete object/array grammar and exactly one root.
pub struct Error { u8 kind; usize offset; }
pub struct State { u8 kind; usize begin; usize end; usize cursor; }
struct String { usize end; usize length; }
pub fn usize byte_limit(){return 65536;}
fn Error invalid(usize at){return Error{.kind=1,.offset=at};}
fn Error limit(usize at){return Error{.kind=2,.offset=at};}
pub fn State empty(){return State{.kind=0,.begin=0,.end=0,.cursor=0};}
fn bool whitespace(u8 v){return v==32 || v==9 || v==10 || v==13;}
fn bool digit(u8 v){return v>=48 && v<=57;}
fn bool delimiter(u8 v){return whitespace(v) || v==123 || v==125 || v==91 || v==93 || v==44 || v==58;}
fn Result<usize,Error> hex(u8 v,usize at){
    if(digit(v)){return .ok((v-48) as usize);}
    if(v>=65 && v<=70){return .ok((v-65) as usize+10);}
    if(v>=97 && v<=102){return .ok((v-97) as usize+10);}
    return .err(invalid(at));
}
fn Result<usize,Error> unit(ref u8[] source,usize at){
    if(at>source.len || source.len-at<4){return .err(invalid(at));}
    var usize point=0;var usize i=0;
    while(i<4){point=point*16+hex(source[at+i],at+i)?;i+=1;}
    return .ok(point);
}
fn Result<u8,Error> octet(usize v,usize at){
    let i64 n=switch(num::i64_from_usize(v)){case .ok(n):{n}case .err(_):{return .err(invalid(at));}};
    return switch(num::u8_from_i64(n)){case .ok(n):{.ok(n)}case .err(_):{.err(invalid(at))}};
}
fn Result<usize,Error> append(ref mut u8[] out,usize used,u8 v,bool write,usize at){
    if(used>=byte_limit() || (write && used>=out.len)){return .err(limit(at));}
    if(write){out[used]=v;}return .ok(used+1);
}
fn Result<usize,Error> scalar(ref mut u8[] out,usize used,usize point,bool write,usize at){
    if(point<=127){return append(out,used,octet(point,at)?,write,at);}
    var usize n=used;
    if(point<=2047){
        n=append(out,n,octet(192+point/64,at)?,write,at)?;
    }else if(point<=65535){
        n=append(out,n,octet(224+point/4096,at)?,write,at)?;
        n=append(out,n,octet(128+(point/64)%64,at)?,write,at)?;
    }else{
        n=append(out,n,octet(240+point/262144,at)?,write,at)?;
        n=append(out,n,octet(128+(point/4096)%64,at)?,write,at)?;
        n=append(out,n,octet(128+(point/64)%64,at)?,write,at)?;
    }
    return append(out,n,octet(128+point%64,at)?,write,at);
}
// Validate UTF-16 escapes, including paired surrogates, before accepting a token.
// Raw input UTF-8 is checked once by start; decode also checks its selected span.
fn Result<String,Error> string(ref u8[] source,usize begin,ref mut u8[] out,bool write){
    if(begin>=source.len || source[begin]!=34){return .err(invalid(begin));}
    var usize at=begin+1;var usize used=0;
    while(at<source.len){
        let u8 v=source[at];
        if(v==34){return .ok(String{.end=at+1,.length=used});}
        if(v<32){return .err(invalid(at));}
        if(v!=92){used=append(out,used,v,write,at)?;at+=1;continue;}
        let usize escaped=at;
        if(source.len-at<2){return .err(invalid(at));}
        let u8 code=source[at+1];at+=2;
        if(code==117){
            var usize point=unit(source,at)?;at+=4;
            if(point>=55296 && point<=56319){
                if(source.len-at<6 || source[at]!=92 || source[at+1]!=117){return .err(invalid(escaped));}
                let usize low=unit(source,at+2)?;
                if(low<56320 || low>57343){return .err(invalid(at));}
                point=65536+(point-55296)*1024+(low-56320);at+=6;
            }else if(point>=56320 && point<=57343){return .err(invalid(escaped));}
            used=scalar(out,used,point,write,escaped)?;continue;
        }
        var u8 decoded=code;
        if(code==98){decoded=8;}else if(code==102){decoded=12;}
        else if(code==110){decoded=10;}else if(code==114){decoded=13;}else if(code==116){decoded=9;}
        else if(code!=34 && code!=92 && code!=47){return .err(invalid(escaped));}
        used=append(out,used,decoded,write,escaped)?;
    }
    return .err(invalid(at));
}
fn Result<usize,Error> number(ref u8[] source,usize begin){
    var usize at=begin;
    if(source[at]==45){at+=1;}
    if(at==source.len || !digit(source[at])){return .err(invalid(at));}
    if(source[at]==48){at+=1;}else{while(at<source.len && digit(source[at])){at+=1;}}
    if(at<source.len && source[at]==46){
        at+=1;let usize first=at;while(at<source.len && digit(source[at])){at+=1;}
        if(at==first){return .err(invalid(at));}
    }
    if(at<source.len && (source[at]==101 || source[at]==69)){
        at+=1;if(at<source.len && (source[at]==43 || source[at]==45)){at+=1;}
        let usize first=at;while(at<source.len && digit(source[at])){at+=1;}
        if(at==first){return .err(invalid(at));}
    }
    if(at<source.len && !delimiter(source[at])){return .err(invalid(at));}
    return .ok(at);
}
// kind: punctuation byte, 34 string, 2 number, 3 true, 4 false, 5 null, 0 EOF.
// Success publishes State once; malformed tokens leave the old State intact.
pub fn Result<usize,Error> next(ref u8[] source,ref mut State s){
    if(source.len>byte_limit()){return .err(limit(byte_limit()));}
    if(s.cursor>source.len){return .err(Error{.kind=4,.offset=source.len});}
    var usize at=s.cursor;
    while(at<source.len && whitespace(source[at])){at+=1;}
    let usize begin=at;var u8 kind=0;
    if(at<source.len){
        let u8 v=source[at];kind=v;
        if(v==34){
            var u8[1] scratch=[0;1];
            let String checked=string(source,at,ref mut scratch,false)?;at=checked.end;
        }else if(v==45 || digit(v)){kind=2;at=number(source,at)?;}
        else if(v==116 || v==102 || v==110){
            let ref u8[] expected=if(v==116){b"true"}else if(v==102){b"false"}else{b"null"};
            if(expected.len>source.len-at){return .err(invalid(at));}
            var usize i=0;while(i<expected.len){if(source[at+i]!=expected[i]){return .err(invalid(at+i));}i+=1;}
            at+=expected.len;if(at<source.len && !delimiter(source[at])){return .err(invalid(at));}
            kind=if(v==116){3}else if(v==102){4}else{5};
        }else if(v==123 || v==125 || v==91 || v==93 || v==44 || v==58){at+=1;}
        else{return .err(invalid(at));}
    }
    s.kind=kind;s.begin=begin;s.end=at;s.cursor=at;return .ok(at);
}
pub fn Result<State,Error> start(ref u8[] source){
    if(source.len>byte_limit()){return .err(limit(byte_limit()));}
    if(!text::validate_utf8(source).is_ok){return .err(Error{.kind=3,.offset=0});}
    var State s=empty();let usize first=next(source,ref mut s)?;return .ok(s);
}
// No view escapes caller scratch. Failure may leave partial scratch bytes.
pub fn Result<usize,Error> decode(ref u8[] source,State s,ref mut u8[] out){
    if(source.len>byte_limit()){return .err(limit(byte_limit()));}
    if(s.kind!=34 || s.begin>=s.end || s.end>source.len){return .err(Error{.kind=4,.offset=0});}
    let ref u8[] token=source[s.begin..s.end];
    if(!text::validate_utf8(token).is_ok){return .err(Error{.kind=3,.offset=s.begin});}
    let String parsed=string(source[..s.end],s.begin,out,true)?;
    if(parsed.end!=s.end){return .err(invalid(s.begin));}return .ok(parsed.length);
}
