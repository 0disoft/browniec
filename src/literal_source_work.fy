module literal_source_work;
import errors as errors;
import std::text as utf8;
import std::num as num;
import literal_source as raw;
import source_utf8_work as utf8_work;
import metadata_budget as budget;

// Compiler-owned scratch only. Raw spans include the prefix and both quotes;
// only data[..length] is payload. No view into this temporary may escape.
pub struct Decoded { u8[4096] data; usize begin; usize end; usize length; bool text; }

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
// Invocation-private decoded scratch; never publish it until done. No raw
// decode/scan call is hidden behind an admitted stage. At most sixteen cooked
// scalar/escape steps run; raw-token and cooked-text UTF-8 checks follow in
// separate <=259-byte chunks, preserving raw diagnostic precedence.
pub struct State { raw::Decoded result; usize cursor; usize checked; usize visits; u8 phase; bool done; }
pub fn State empty(usize begin){return State{.result=raw::Decoded{.data=[0;4096],.begin=begin,.end=begin,.length=0,.text=false},
    .cursor=begin,.checked=0,.visits=0,.phase=0,.done=false};}
fn Result<bool,errors::Error> step(ref u8[] source,ref mut State w){
    var usize at=w.cursor;let usize begin=w.result.begin;let usize used=w.result.length;let bool text=w.result.text;
    if(at>=source.len){return .err(invalid(begin));}let u8 value=source[at];w.visits+=1;
    if(value==34){w.result.end=at+1;w.checked=0;w.phase=2;return .ok(false);}
    if(value==0 || value==10 || value==13 ||
        (value==239 && source.len-at>=3 && source[at+1]==187 && source[at+2]==191)){return .err(invalid(at));}
    if(value!=92){let usize length=append(ref mut w.result.data[..],used,value,at)?;w.result.length=length;w.cursor=at+1;return .ok(false);}
    let usize escaped=at;if(source.len-at<2){return .err(invalid(escaped));}
    let u8 code=source[at+1];var u8 decoded=0;
    if(code==117){
        if(!text || source.len-at<3 || source[at+2]!=123){return .err(invalid(escaped));}
        at+=3;var usize digits=0;var usize point=0;
        while(at<source.len && source[at]!=125){if(digits==6){return .err(invalid(escaped));}
            point=point*16+hex(source[at],escaped)?;digits+=1;at+=1;}
        if(digits==0 || at==source.len){return .err(invalid(escaped));}
        let usize length=scalar(ref mut w.result.data[..],used,point,escaped)?;
        w.result.length=length;w.cursor=at+1;return .ok(false);
    }
    if(code==120){if(source.len-at<4){return .err(invalid(escaped));}
        let usize high=hex(source[at+2],escaped)?;let usize low=hex(source[at+3],escaped)?;
        decoded=octet(high*16+low,escaped)?;at+=4;
    }else{if(code==92 || code==34){decoded=code;}else if(code==110){decoded=10;}
        else if(code==114){decoded=13;}else if(code==116){decoded=9;}else if(code==48){decoded=0;}
        else{return .err(invalid(escaped));}at+=2;}
    let usize length=append(ref mut w.result.data[..],used,decoded,escaped)?;
    w.result.length=length;w.cursor=at;return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.result.begin)?){return .ok(false);}
    if(w.phase==0){
        if(source.len>4096){return .err(limit(4096));}
        let usize begin=w.result.begin;let u8 tag=kind(source,begin);if(tag==0){return .err(invalid(begin));}
        w.result.text=tag==4;w.cursor=begin+if(tag==4){1}else{2};w.phase=1;return .ok(false);
    }
    if(w.phase==1){var usize steps=0;while(steps<16 && w.phase==1){let bool next=step(source,w)?;steps+=1;}return .ok(false);}
    if(w.phase==2){let usize begin=w.result.begin;let usize end=w.result.end;
        let usize cursor=switch(utf8_work::chunk(source[begin..end],w.checked)){
            case .ok(v):{v}case .err(_):{return .err(invalid(begin));}};
        w.checked=cursor;if(cursor==end-begin){w.checked=0;if(w.result.text){w.phase=3;}else{w.done=true;}}return .ok(w.done);
    }
    if(w.phase==3){let usize begin=w.result.begin;let usize length=w.result.length;let usize checked=w.checked;
        let ref u8[] data=ref w.result.data;
        let usize cursor=switch(utf8_work::chunk(data[..length],checked)){
            case .ok(v):{v}case .err(_):{return .err(invalid(begin));}};
        w.checked=cursor;if(cursor==length){w.done=true;}return .ok(w.done);
    }
    return .err(errors::make(5,w.result.begin));
}
pub fn Result<raw::Decoded,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.result.begin));}return .ok(w.result);}
