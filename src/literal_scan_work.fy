module literal_scan_work;
import errors as errors;
import std::text as utf8;
import std::num as num;
import source_utf8_work as utf8_work;
import metadata_budget as budget;

// Compiler-owned scratch only. Raw spans include the prefix and both quotes;
// only data[..length] is payload. No view into this temporary may escape.


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
// Token-only scanner: no decoded 4096-byte bank is allocated per lexer token.
// Semantic escape errors precede deferred raw/cooked UTF-8 failure, as in scan.
pub struct State { usize begin; usize end; usize cursor; usize length; usize checked;
    usize visits; usize continuation; u8 low; u8 high; u8 phase; bool valid; bool text; bool done; }
pub fn State empty(usize begin){return State{.begin=begin,.end=begin,.cursor=begin,.length=0,.checked=0,
    .visits=0,.continuation=0,.low=128,.high=191,.phase=0,.valid=true,.text=false,.done=false};}
fn Result<usize,errors::Error> append(ref mut State w,u8 value,usize at){
    if(w.length>=4096){return .err(limit(at));}w.length+=1;
    if(!w.text || !w.valid){return .ok(w.length);}
    if(w.continuation!=0){if(value<w.low || value>w.high){w.valid=false;}
        else{w.continuation-=1;w.low=128;w.high=191;}return .ok(w.length);}
    if(value<128){return .ok(w.length);}w.low=128;w.high=191;
    if(value>=194 && value<=223){w.continuation=1;}
    else if(value>=224 && value<=239){w.continuation=2;if(value==224){w.low=160;}else if(value==237){w.high=159;}}
    else if(value>=240 && value<=244){w.continuation=3;if(value==240){w.low=144;}else if(value==244){w.high=143;}}
    else{w.valid=false;}return .ok(w.length);
}
fn Result<usize,errors::Error> scalar(ref mut State w,usize value,usize at){
    if(value>1114111 || (value>=55296 && value<=57343)){return .err(invalid(at));}
    let usize count=if(value<=127){1}else if(value<=2047){2}else if(value<=65535){3}else{4};
    if(count>4096-w.length){return .err(limit(at));}
    if(count==1){let usize a=append(w,octet(value,at)?,at)?;}
    else if(count==2){let usize a=append(w,octet(192+value/64,at)?,at)?;let usize b=append(w,octet(128+value%64,at)?,at)?;}
    else if(count==3){let usize a=append(w,octet(224+value/4096,at)?,at)?;let usize b=append(w,octet(128+(value/64)%64,at)?,at)?;
        let usize c=append(w,octet(128+value%64,at)?,at)?;}
    else{let usize a=append(w,octet(240+value/262144,at)?,at)?;let usize b=append(w,octet(128+(value/4096)%64,at)?,at)?;
        let usize c=append(w,octet(128+(value/64)%64,at)?,at)?;let usize d=append(w,octet(128+value%64,at)?,at)?;}
    return .ok(w.length);
}
fn Result<bool,errors::Error> step(ref u8[] source,ref mut State w){
    var usize at=w.cursor;let usize begin=w.begin;
    if(at>=source.len){return .err(invalid(begin));}let u8 value=source[at];w.visits+=1;
    if(value==34){w.end=at+1;w.checked=0;w.phase=2;return .ok(false);}
    if(value==0 || value==10 || value==13 ||
        (value==239 && source.len-at>=3 && source[at+1]==187 && source[at+2]==191)){return .err(invalid(at));}
    if(value!=92){let usize length=append(w,value,at)?;w.cursor=at+1;return .ok(false);}
    let usize escaped=at;if(source.len-at<2){return .err(invalid(escaped));}
    let u8 code=source[at+1];var u8 decoded=0;
    if(code==117){
        if(!w.text || source.len-at<3 || source[at+2]!=123){return .err(invalid(escaped));}
        at+=3;var usize digits=0;var usize point=0;
        while(at<source.len && source[at]!=125){if(digits==6){return .err(invalid(escaped));}
            point=point*16+hex(source[at],escaped)?;digits+=1;at+=1;}
        if(digits==0 || at==source.len){return .err(invalid(escaped));}
        let usize length=scalar(w,point,escaped)?;w.cursor=at+1;return .ok(false);
    }
    if(code==120){if(source.len-at<4){return .err(invalid(escaped));}
        let usize high=hex(source[at+2],escaped)?;let usize low=hex(source[at+3],escaped)?;
        decoded=octet(high*16+low,escaped)?;at+=4;
    }else{if(code==92 || code==34){decoded=code;}else if(code==110){decoded=10;}
        else if(code==114){decoded=13;}else if(code==116){decoded=9;}else if(code==48){decoded=0;}
        else{return .err(invalid(escaped));}at+=2;}
    let usize length=append(w,decoded,escaped)?;w.cursor=at;return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==0){if(source.len>4096){return .err(limit(4096));}
        let u8 tag=kind(source,w.begin);if(tag==0){return .err(invalid(w.begin));}
        w.text=tag==4;w.cursor=w.begin+if(w.text){1}else{2};w.phase=1;return .ok(false);}
    if(w.phase==1){var usize steps=0;while(steps<16 && w.phase==1){let bool next=step(source,w)?;steps+=1;}return .ok(false);}
    if(w.phase==2){let usize cursor=switch(utf8_work::chunk(source[w.begin..w.end],w.checked)){
        case .ok(v):{v}case .err(_):{return .err(invalid(w.begin));}};
        w.checked=cursor;if(cursor==w.end-w.begin){w.phase=3;}return .ok(false);}
    if(w.phase==3){if(w.text && (!w.valid || w.continuation!=0)){return .err(invalid(w.begin));}w.done=true;return .ok(true);}
    return .err(errors::make(5,w.begin));
}
