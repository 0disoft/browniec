module runtime_policy_json;
import json_tokens as json;
import std::bytes as bytes;
import project_names as names;
import host_catalog_names as catalog_names;

pub enum Failure { Json; Limit; Unknown; Duplicate; Missing; Value; Relation; Authority; Allocation; Bounds; }
pub struct Error { Failure kind; usize offset; }
pub struct Cursor { json::State token; usize tokens; }
pub struct Span { usize begin; usize end; }
struct Table { Span[65] items; usize count; }
pub resource Capabilities { bytes::Buffer strings; Table table; cleanup { } }
pub fn Error error(Failure kind,usize at){return Error{.kind=kind,.offset=at};}
fn Error lexical(json::Error e){return error(if(e.kind==2){.Limit}else{.Json},e.offset);}
pub fn usize byte_limit(){return json::byte_limit();}
pub fn usize token_limit(){return 8192;}
pub fn usize capability_limit(){return 65;}
pub fn Result<Cursor,Error> start(ref u8[] source){
    let json::State token=switch(json::start(source)){case .ok(v):{v}case .err(e):{return .err(lexical(e));}};
    return .ok(Cursor{.token=token,.tokens=1});
}
pub fn Result<usize,Error> next(ref u8[] source,ref mut Cursor c){
    if(c.tokens>=token_limit()){return .err(error(.Limit,c.token.begin));}
    let usize n=switch(json::next(source,ref mut c.token)){case .ok(n):{n}case .err(e):{return .err(lexical(e));}};
    c.tokens+=1;return .ok(n);
}
pub fn Result<usize,Error> take(ref u8[] source,ref mut Cursor c,u8 kind){
    if(c.token.kind!=kind){return .err(error(.Json,c.token.begin));}return next(source,c);
}
pub fn Result<usize,Error> decoded(ref u8[] source,ref Cursor c,ref mut u8[] out){
    if(c.token.kind!=34){return .err(error(.Value,c.token.begin));}
    return switch(json::decode(source,c.token,out)){case .ok(n):{.ok(n)}case .err(e):{.err(lexical(e))}};
}
// Delimited trusted field vocabulary, matched only after JSON escape decoding.
pub fn Result<usize,Error> field(ref u8[] source,ref mut Cursor c,ref u8[] vocabulary){
    var u8[32] scratch=[0;32];let usize n=decoded(source,c,ref mut scratch)?;
    let ref u8[] all=ref scratch;var usize begin=0;var usize at=0;var usize index=0;
    while(at<=vocabulary.len){
        if(at==vocabulary.len || vocabulary[at]==124){
            if(bytes::equal(all[..n],vocabulary[begin..at])){
                let usize key=next(source,c)?;let usize colon=take(source,c,58)?;return .ok(index);
            }begin=at+1;index+=1;
        }at+=1;
    }return .err(error(.Unknown,c.token.begin));
}
pub fn Result<usize,Error> mark(ref mut bool[] seen,usize field,usize at){
    if(field>=seen.len){return .err(error(.Bounds,at));}
    if(seen[field]){return .err(error(.Duplicate,at));}seen[field]=true;return .ok(field);
}
pub fn Result<usize,Error> complete(ref bool[] seen,usize at){
    var usize i=0;while(i<seen.len){if(!seen[i]){return .err(error(.Missing,at));}i+=1;}return .ok(i);
}
pub fn Result<usize,Error> constant(ref u8[] source,ref mut Cursor c,ref u8[] value){
    var u8[32] scratch=[0;32];let usize n=decoded(source,c,ref mut scratch)?;let ref u8[] all=ref scratch;
    if(!bytes::equal(all[..n],value)){return .err(error(.Value,c.token.begin));}return next(source,c);
}
// No float conversion, signed cast or unchecked multiply. Reject fraction,
// exponent, minus (including -0), and numbers above their schema ceiling.
pub fn Result<usize,Error> integer(ref u8[] source,ref mut Cursor c,usize minimum,usize maximum){
    let usize begin=c.token.begin;let usize end=c.token.end;
    if(c.token.kind!=2 || end<=begin || end-begin>20){return .err(error(.Value,begin));}
    var usize value=0;var usize at=begin;
    while(at<end){
        let u8 ch=source[at];if(ch<48 || ch>57){return .err(error(.Value,begin));}
        let usize digit=(ch-48) as usize;
        if(digit>maximum || value>(maximum-digit)/10){return .err(error(.Value,begin));}
        value=value*10+digit;at+=1;
    }
    if(value<minimum){return .err(error(.Value,begin));}
    let usize advanced=next(source,c)?;return .ok(value);
}
pub fn Result<usize,Error> append(ref mut bytes::Buffer pool,ref u8[] value){
    let usize used=bytes::len(pool);
    if(used>byte_limit() || value.len>byte_limit()-used){return .err(error(.Limit,0));}
    return switch(bytes::append(pool,value)){case .ok(n):{.ok(n)}case .err(_):{.err(error(.Allocation,0))}};
}
pub fn ref u8[] view(ref bytes::Buffer pool,Span s){let ref u8[] all=bytes::view(pool);return all[s.begin..s.end];}
pub fn Result<Capabilities,Error> capabilities(ref u8[] source,ref mut Cursor c){
    var bytes::Buffer strings=bytes::empty();let Span no=Span{.begin=0,.end=0};
    var Span[65] items=[no;65];var usize count=0;let usize open=take(source,c,91)?;
    if(c.token.kind!=93){while(true){
        if(count>=capability_limit()){return .err(error(.Limit,c.token.begin));}
        var u8[128] scratch=[0;128];let usize n=decoded(source,c,ref mut scratch)?;let ref u8[] all=ref scratch;
        let ref u8[] name=all[..n];if(!names::capability(name)){return .err(error(.Value,c.token.begin));}
        var usize i=0;while(i<count){
            if(bytes::equal(view(ref strings,items[i]),name)){return .err(error(.Duplicate,c.token.begin));}i+=1;
        }
        let usize begin=bytes::len(ref strings);let usize added=append(ref mut strings,name)?;
        items[count]=Span{.begin=begin,.end=begin+n};count+=1;let usize advanced=next(source,c)?;
        if(c.token.kind==93){break;}let usize comma=take(source,c,44)?;
    }}
    let usize close=take(source,c,93)?;
    return .ok(Capabilities{.strings=strings,.table=Table{.items=items,.count=count}});
}
pub fn usize heap_bytes(ref Capabilities caps){return bytes::capacity(ref caps.strings);}
pub fn usize count(ref Capabilities caps){return caps.table.count;}
pub fn Result<ref u8[],Error> capability(ref Capabilities caps,usize i){
    if(i>=caps.table.count){return .err(error(.Bounds,0));}return .ok(view(ref caps.strings,caps.table.items[i]));
}
pub fn bool contains(ref Capabilities caps,ref u8[] name){
    var usize i=0;while(i<caps.table.count){if(bytes::equal(view(ref caps.strings,caps.table.items[i]),name)){return true;}i+=1;}return false;
}
pub fn bool subset(ref Capabilities small,ref Capabilities large){
    var usize i=0;while(i<small.table.count){if(!contains(large,view(ref small.strings,small.table.items[i]))){return false;}i+=1;}return true;
}
// Entry uses the schema's spelling grammar, including keywords and std/brownie
// roots. project_names::module_name additionally applies source language rules.
pub fn bool module_name(ref u8[] name){
    if(name.len==0 || name.len>128){return false;}
    var usize begin=0;var usize at=0;
    while(at<name.len){
        if(name[at]==58){
            if(at+1>=name.len || name[at+1]!=58 || !identifier(name[begin..at])){return false;}
            at+=2;begin=at;
        }else{at+=1;}
    }
    // A scope segment may exceed the 64-byte function-name ceiling.
    return identifier(name[begin..name.len]);
}
fn bool identifier(ref u8[] name){
    if(name.len==0){return false;}
    var usize at=0;while(at<name.len){
        let u8 ch=name[at];let bool alpha=(ch>=65 && ch<=90) || (ch>=97 && ch<=122) || ch==95;
        if(!alpha && (at==0 || ch<48 || ch>57)){return false;}at+=1;
    }return true;
}
pub fn Result<Span,Error> entry_name(ref u8[] source,ref mut Cursor c,ref mut bytes::Buffer pool,bool scope){
    var u8[128] scratch=[0;128];let usize n=decoded(source,c,ref mut scratch)?;let ref u8[] all=ref scratch;let ref u8[] name=all[..n];
    if(!(if(scope){module_name(name)}else{catalog_names::symbol(name)})){return .err(error(.Value,c.token.begin));}
    let usize begin=bytes::len(pool);let usize added=append(pool,name)?;let usize advanced=next(source,c)?;
    return .ok(Span{.begin=begin,.end=begin+n});
}

pub fn Capabilities empty_capabilities(){
    let Span no=Span{.begin=0,.end=0};
    return Capabilities{.strings=bytes::empty(),.table=Table{.items=[no;65],.count=0}};
}
