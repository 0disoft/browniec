module literal_source;
import errors as errors;
import std::text as utf8;
import std::num as num;
import static_image as images;
import literal_source_work as staged;

// Compiler-owned scratch only. Raw spans include the prefix and both quotes;
// only data[..length] is payload. No view into this temporary may escape.
pub struct Decoded { u8[4096] data; usize begin; usize end; usize length; bool text; }
struct Token { usize end; usize length; bool text; }
fn errors::Error invalid(usize at){return errors::make(1,at);}
fn errors::Error limit(usize at){return errors::make(4,at);}
pub fn u8 kind(ref u8[] source,usize begin){
    if(begin>=source.len){return 0;}
    if(source[begin]==34){return 4;}
    if(source[begin]==98 && begin+1<source.len && source[begin+1]==34){return 3;}
    return 0;
}
fn Result<usize,errors::Error> hex(u8 value,usize at){
    if(value>=48 && value<=57){return .ok((value-48) as usize);}
    if(value>=65 && value<=70){return .ok((value-65) as usize+10);}
    if(value>=97 && value<=102){return .ok((value-97) as usize+10);}
    return .err(invalid(at));
}
fn Result<u8,errors::Error> octet(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(invalid(at))}};
}
fn Result<usize,errors::Error> append(ref mut u8[] data,usize used,u8 value,usize at){
    if(used>=data.len){return .err(limit(at));}data[used]=value;return .ok(used+1);
}
fn Result<usize,errors::Error> scalar(ref mut u8[] data,usize used,usize value,usize at){
    if(value>1114111 || (value>=55296 && value<=57343)){return .err(invalid(at));}
    let usize count=if(value<=127){1}else if(value<=2047){2}else if(value<=65535){3}else{4};
    if(used>data.len || count>data.len-used){return .err(limit(at));}
    var u8[4] encoded=[0;4];
    if(count==1){encoded[0]=octet(value,at)?;}
    else if(count==2){
        encoded[0]=octet(192+value/64,at)?;encoded[1]=octet(128+value%64,at)?;
    }else if(count==3){
        encoded[0]=octet(224+value/4096,at)?;encoded[1]=octet(128+(value/64)%64,at)?;
        encoded[2]=octet(128+value%64,at)?;
    }else{
        encoded[0]=octet(240+value/262144,at)?;encoded[1]=octet(128+(value/4096)%64,at)?;
        encoded[2]=octet(128+(value/64)%64,at)?;encoded[3]=octet(128+value%64,at)?;
    }
    var usize i=0;while(i<count){data[used+i]=encoded[i];i+=1;}return .ok(used+count);
}
// Private staging may contain partial bytes on error. Callers publish nothing
// until this returns successfully, including complete source/cooked UTF-8 checks.
fn Result<Token,errors::Error> read(ref u8[] source,usize begin,ref mut u8[] data){
    if(source.len>4096){return .err(limit(4096));}
    let u8 tag=kind(source,begin);if(tag==0){return .err(invalid(begin));}
    let bool text=tag==4;var usize at=begin+if(text){1}else{2};var usize used=0;
    while(at<source.len){
        let u8 value=source[at];
        if(value==34){
            let usize end=at+1;
            if(!utf8::validate_utf8(source[begin..end]).is_ok ||
                (text && !utf8::validate_utf8(data[..used]).is_ok)){return .err(invalid(begin));}
            return .ok(Token{.end=end,.length=used,.text=text});
        }
        if(value==0 || value==10 || value==13 ||
            (value==239 && source.len-at>=3 && source[at+1]==187 && source[at+2]==191)){
            return .err(invalid(at));
        }
        if(value!=92){used=append(data,used,value,at)?;at+=1;continue;}
        let usize escaped=at;
        if(source.len-at<2){return .err(invalid(escaped));}
        let u8 code=source[at+1];var u8 decoded=0;
        if(code==117){
            if(!text || source.len-at<3 || source[at+2]!=123){return .err(invalid(escaped));}
            at+=3;var usize digits=0;var usize point=0;
            while(at<source.len && source[at]!=125){
                if(digits==6){return .err(invalid(escaped));}
                point=point*16+hex(source[at],escaped)?;digits+=1;at+=1;
            }
            if(digits==0 || at==source.len){return .err(invalid(escaped));}
            used=scalar(data,used,point,escaped)?;at+=1;continue;
        }
        if(code==120){
            if(source.len-at<4){return .err(invalid(escaped));}
            let usize high=hex(source[at+2],escaped)?;let usize low=hex(source[at+3],escaped)?;
            decoded=octet(high*16+low,escaped)?;at+=4;
        }else{
            if(code==92 || code==34){decoded=code;}
            else if(code==110){decoded=10;}else if(code==114){decoded=13;}
            else if(code==116){decoded=9;}else if(code==48){decoded=0;}
            else{return .err(invalid(escaped));}
            at+=2;
        }
        used=append(data,used,decoded,escaped)?;
    }
    return .err(invalid(begin));
}
// Lexing needs only the raw end. Keep decoded scratch out of lexer::State.
pub fn Result<usize,errors::Error> scan(ref u8[] source,usize begin){
    var u8[4096] data=[0;4096];let Token token=read(source,begin,ref mut data)?;
    return .ok(token.end);
}
pub fn Result<Decoded,errors::Error> decode_raw(ref u8[] source,usize begin){
    var Decoded decoded=Decoded{.data=[0;4096],.begin=begin,.end=begin,.length=0,.text=false};
    let Token token=read(source,begin,ref mut decoded.data)?;
    decoded.end=token.end;decoded.length=token.length;decoded.text=token.text;
    return .ok(decoded);
}
// Keep read/scan/decode_raw as independent comparisons for staged interning.
pub fn Result<Decoded,errors::Error> decode(ref u8[] source,usize begin){return staged::decode(source,begin);}
pub enum Failure { Source; Image; }
pub struct Error { Failure kind; errors::Error source; images::Error image; }
pub struct Interned { usize literal; usize begin; usize end; usize length; bool text; }
// Decode completely before interning. Source and image failures are distinct;
// both leave the existing builder unchanged. Returned IDs are builder-local.
pub fn Result<Interned,Error> intern(ref mut images::Builder builder,ref u8[] source,usize begin){
    let Decoded value=switch(decode(source,begin)){
        case .ok(v):{v}
        case .err(e):{return .err(Error{.kind=.Source,.source=e,.image=.State});}
    };
    let ref u8[] data=ref value.data;
    let Result<usize,images::Error> added=if(value.text){images::intern_text(builder,data[..value.length])}
        else{images::intern_bytes(builder,data[..value.length])};
    let usize id=switch(added){
        case .ok(v):{v}
        case .err(e):{return .err(Error{.kind=.Image,.source=errors::make(0,0),.image=e});}
    };
    return .ok(Interned{.literal=id,.begin=begin,.end=value.end,.length=value.length,.text=value.text});
}
