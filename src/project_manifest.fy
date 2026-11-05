module project_manifest;
import json_tokens as json;
import project_names as names;
import std::bytes as bytes;

// Typed metadata only, never source-file access, executable admission or grants.
pub enum Failure { Json; Limit; Unknown; Duplicate; Missing; Value; Allocation; Bounds; }
pub struct Error { Failure kind; usize offset; }
struct Span { usize begin; usize end; }
struct Source { Span scope; Span path; }
struct Table {
    Span name; Span scope; Span function;
    Source[32] sources; Span[256] requires; usize count; usize requirements;
}
pub resource Project { bytes::Buffer strings; Table table; cleanup { } }
pub fn usize source_limit(){return 32;}
pub fn usize requirement_limit(){return 256;}
pub fn usize string_limit(){return 44816;}
fn Error error(Failure kind,usize at){return Error{.kind=kind,.offset=at};}
fn Error lexical(json::Error e){return error(if(e.kind==2){.Limit}else{.Json},e.offset);}
fn Span absent(){return Span{.begin=0,.end=0};}
fn Table empty(){
    let Span none=absent();
    return Table{.name=none,.scope=none,.function=none,
        .sources=[Source{.scope=none,.path=none};32],.requires=[none;256],.count=0,.requirements=0};
}
fn ref u8[] view(ref bytes::Buffer pool,Span span){
    let ref u8[] data=bytes::view(pool);return data[span.begin..span.end];
}
fn bool same(ref bytes::Buffer pool,Span left,Span right){return bytes::equal(view(pool,left),view(pool,right));}
fn bool collision(ref bytes::Buffer pool,Span left,Span right){return names::same_path(view(pool,left),view(pool,right));}
fn Result<usize,Error> next(ref u8[] source,ref mut json::State s){
    return switch(json::next(source,s)){case .ok(n):{.ok(n)}case .err(e):{.err(lexical(e))}};
}
fn Result<usize,Error> take(ref u8[] source,ref mut json::State s,u8 expected){
    if(s.kind!=expected){return .err(error(.Json,s.begin));}return next(source,s);
}
fn Result<usize,Error> decoded(ref u8[] source,json::State s,ref mut u8[] out){
    return switch(json::decode(source,s,out)){case .ok(n):{.ok(n)}case .err(e):{.err(lexical(e))}};
}
fn bool valid(ref u8[] value,u8 tag){
    if(tag==1){return bytes::equal(value,b"brownie.project/0.3");}
    if(tag==2){return names::project_name(value);}
    if(tag==3){return names::module_name(value);}
    if(tag==4){return names::function_name(value);}
    if(tag==5){return names::member_path(value);}
    return names::capability(value);
}
fn Result<Span,Error> value(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,u8 tag){
    if(s.kind!=34){return .err(error(.Value,s.begin));}
    var u8[240] data=[0;240];let usize n=decoded(source,*s,ref mut data)?;
    let ref u8[] text=ref data;
    if(!valid(text[..n],tag)){return .err(error(.Value,s.begin));}
    if(tag==1){let usize advanced=next(source,s)?;return .ok(absent());}
    let usize begin=bytes::len(pool);
    if(n>string_limit()-begin){return .err(error(.Limit,s.begin));}
    let usize appended=switch(bytes::append(pool,text[..n])){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,s.begin));}
    };
    let usize advanced=next(source,s)?;return .ok(Span{.begin=begin,.end=begin+n});
}
// Decode before comparing keys: "module" and "\u006dodule" are the same key.
fn Result<u8,Error> key(ref u8[] source,ref mut json::State s,u8 object){
    if(s.kind!=34){return .err(error(.Json,s.begin));}
    var u8[32] data=[0;32];let usize n=decoded(source,*s,ref mut data)?;
    let ref u8[] all=ref data;let ref u8[] text=all[..n];var u8 field=0;
    if(object==0){
        if(bytes::equal(text,b"schema")){field=1;}else if(bytes::equal(text,b"name")){field=2;}
        else if(bytes::equal(text,b"entry")){field=3;}else if(bytes::equal(text,b"sources")){field=4;}
        else if(bytes::equal(text,b"requires")){field=5;}
    }else{
        if(bytes::equal(text,b"module")){field=1;}
        else if(bytes::equal(text,if(object==1){b"function"}else{b"path"})){field=2;}
    }
    if(field==0){return .err(error(.Unknown,s.begin));}
    let usize advanced=next(source,s)?;let usize colon=take(source,s,58)?;return .ok(field);
}
fn Result<Source,Error> pair(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,bool entry){
    let usize open=take(source,s,123)?;
    var bool module_seen=false;var bool second_seen=false;
    var Span scope=absent();var Span second=absent();
    while(true){
        let usize at=s.begin;let u8 field=key(source,s,if(entry){1}else{2})?;
        if(field==1){
            if(module_seen){return .err(error(.Duplicate,at));}module_seen=true;
            scope=value(source,s,pool,3)?;
        }else{
            if(second_seen){return .err(error(.Duplicate,at));}second_seen=true;
            second=value(source,s,pool,if(entry){4}else{5})?;
        }
        if(s.kind==125){break;}let usize comma=take(source,s,44)?;
    }
    if(!module_seen || !second_seen){return .err(error(.Missing,s.begin));}
    let usize close=take(source,s,125)?;return .ok(Source{.scope=scope,.path=second});
}
fn Result<usize,Error> read_sources(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,ref mut Table t){
    let usize open=take(source,s,91)?;
    if(s.kind==93){return .err(error(.Missing,s.begin));}
    while(true){
        let usize at=s.begin;
        if(t.count==source_limit()){return .err(error(.Limit,at));}
        let Source item=pair(source,s,pool,false)?;var usize i=0;
        while(i<t.count){
            if(same(pool,t.sources[i].scope,item.scope) || collision(pool,t.sources[i].path,item.path)){
                return .err(error(.Duplicate,at));
            }i+=1;
        }
        let usize slot=t.count;t.sources[slot]=item;t.count=slot+1;
        if(s.kind==93){break;}let usize comma=take(source,s,44)?;
    }
    return take(source,s,93);
}
fn Result<usize,Error> read_requires(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,ref mut Table t){
    let usize open=take(source,s,91)?;
    if(s.kind==93){return take(source,s,93);}
    while(true){
        let usize at=s.begin;
        if(t.requirements==requirement_limit()){return .err(error(.Limit,at));}
        let Span item=value(source,s,pool,6)?;var usize i=0;
        while(i<t.requirements){
            if(same(pool,t.requires[i],item)){return .err(error(.Duplicate,at));}i+=1;
        }
        let usize slot=t.requirements;t.requires[slot]=item;t.requirements=slot+1;
        if(s.kind==93){break;}let usize comma=take(source,s,44)?;
    }
    return take(source,s,93);
}
// Fixed schema depth is three: no recursive parse or ignored extension values.
// Private decoded storage survives mutation/drop of the original JSON bytes.
pub fn Result<Project,Error> parse(ref u8[] source){
    var json::State s=switch(json::start(source)){case .ok(v):{v}case .err(e):{return .err(lexical(e));}};
    let usize open=take(source,ref mut s,123)?;
    // Schema is checked but not stored. Decoded semantic values total <=44816.
    var bytes::Buffer pool=switch(bytes::with_capacity(if(source.len<string_limit()){source.len}else{string_limit()})){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,0));}
    };
    var Table t=empty();var bool[5] seen=[false;5];
    while(true){
        let usize at=s.begin;let u8 field=key(source,ref mut s,0)?;let usize index=(field-1) as usize;
        if(seen[index]){return .err(error(.Duplicate,at));}seen[index]=true;
        if(field==1){let Span schema=value(source,ref mut s,ref mut pool,1)?;}
        else if(field==2){t.name=value(source,ref mut s,ref mut pool,2)?;}
        else if(field==3){
            let Source entry=pair(source,ref mut s,ref mut pool,true)?;t.scope=entry.scope;t.function=entry.path;
        }else if(field==4){let usize count=read_sources(source,ref mut s,ref mut pool,ref mut t)?;}
        else{let usize count=read_requires(source,ref mut s,ref mut pool,ref mut t)?;}
        if(s.kind==125){break;}let usize comma=take(source,ref mut s,44)?;
    }
    var usize i=0;while(i<5){if(!seen[i]){return .err(error(.Missing,s.begin));}i+=1;}
    let usize close=take(source,ref mut s,125)?;
    if(s.kind!=0){return .err(error(.Json,s.begin));}
    var bool found=false;i=0;
    while(i<t.count){if(same(ref pool,t.scope,t.sources[i].scope)){found=true;}i+=1;}
    if(!found){return .err(error(.Value,0));}
    return .ok(Project{.strings=pool,.table=t});
}
pub fn usize count(ref Project p){return p.table.count;}
pub fn usize requirements(ref Project p){return p.table.requirements;}
pub fn usize decoded_bytes(ref Project p){return bytes::len(ref p.strings);}
pub fn ref u8[] name(ref Project p){return view(ref p.strings,p.table.name);}
pub fn ref u8[] entry_module(ref Project p){return view(ref p.strings,p.table.scope);}
pub fn ref u8[] entry_function(ref Project p){return view(ref p.strings,p.table.function);}
pub fn Result<ref u8[],Error> module_name(ref Project p,usize index){
    if(index>=p.table.count){return .err(error(.Bounds,0));}return .ok(view(ref p.strings,p.table.sources[index].scope));
}
pub fn Result<ref u8[],Error> path(ref Project p,usize index){
    if(index>=p.table.count){return .err(error(.Bounds,0));}return .ok(view(ref p.strings,p.table.sources[index].path));
}
pub fn Result<ref u8[],Error> requirement(ref Project p,usize index){
    if(index>=p.table.requirements){return .err(error(.Bounds,0));}return .ok(view(ref p.strings,p.table.requires[index]));
}
