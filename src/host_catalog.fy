module host_catalog;
import json_tokens as json;
import host_catalog_names as names;
import catalog_digest as hash;
import std::bytes as bytes;
import std::num as num;

// Host-owned metadata only. Admission never grants or dispatches anything.
pub enum Failure { Json; Limit; Unknown; Duplicate; Missing; Value; Order; Allocation; Bounds; }
pub struct Error { Failure kind; usize offset; }
struct Span { usize begin; usize end; }
struct Entry { Span scope; Span symbol; Span capability; Span revision;
    usize argc; u8 result; bool write; }
struct Table { Entry[64] entries; u8[2048] parameters; usize count; }
pub resource Catalog { bytes::Buffer strings; Table table; cleanup { } }
pub fn usize byte_limit(){return 16384;}
pub fn usize import_limit(){return 64;}
pub fn usize argument_limit(){return 32;}
// Schema maxima imply <58KiB even without the tighter JSON input ceiling.
pub fn usize canonical_limit(){return 65536;}
fn Error error(Failure kind,usize at){return Error{.kind=kind,.offset=at};}
fn Error lexical(json::Error e){return error(if(e.kind==2){.Limit}else{.Json},e.offset);}
fn Entry empty_entry(){
    let Span no=Span{.begin=0,.end=0};
    return Entry{.scope=no,.symbol=no,.capability=no,.revision=no,.argc=0,.result=0,.write=false};
}
fn ref u8[] view(ref bytes::Buffer pool,Span span){let ref u8[] all=bytes::view(pool);return all[span.begin..span.end];}
fn Result<usize,Error> next(ref u8[] source,ref mut json::State s){
    return switch(json::next(source,s)){case .ok(n):{.ok(n)}case .err(e):{.err(lexical(e))}};
}
fn Result<usize,Error> take(ref u8[] source,ref mut json::State s,u8 kind){
    if(s.kind!=kind){return .err(error(.Json,s.begin));}return next(source,s);
}
fn Result<usize,Error> decoded(ref u8[] source,json::State s,ref mut u8[] out){
    if(s.kind!=34){return .err(error(.Value,s.begin));}
    return switch(json::decode(source,s,out)){case .ok(n):{.ok(n)}case .err(e):{.err(lexical(e))}};
}
fn Result<usize,Error> append(ref mut bytes::Buffer out,ref u8[] value){
    let usize used=bytes::len(out);
    if(used>canonical_limit() || value.len>canonical_limit()-used){return .err(error(.Limit,0));}
    return switch(bytes::append(out,value)){case .ok(n):{.ok(n)}case .err(_):{.err(error(.Allocation,0))}};
}
fn Result<u8,Error> key(ref u8[] source,ref mut json::State s,bool root){
    if(s.kind!=34){return .err(error(.Json,s.begin));}
    var u8[32] data=[0;32];let usize n=decoded(source,*s,ref mut data)?;
    let ref u8[] all=ref data;let ref u8[] text=all[..n];var u8 field=0;
    if(root){
        if(bytes::equal(text,b"schema")){field=1;}else if(bytes::equal(text,b"imports")){field=2;}
    }else{
        if(bytes::equal(text,b"id")){field=1;}else if(bytes::equal(text,b"module")){field=2;}
        else if(bytes::equal(text,b"symbol")){field=3;}else if(bytes::equal(text,b"parameters")){field=4;}
        else if(bytes::equal(text,b"result")){field=5;}else if(bytes::equal(text,b"effect")){field=6;}
        else if(bytes::equal(text,b"capability")){field=7;}else if(bytes::equal(text,b"adapter_revision")){field=8;}
    }
    if(field==0){return .err(error(.Unknown,s.begin));}
    let usize advanced=next(source,s)?;let usize colon=take(source,s,58)?;return .ok(field);
}
fn Result<Span,Error> name(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,u8 field){
    var u8[128] data=[0;128];let usize n=decoded(source,*s,ref mut data)?;
    let ref u8[] all=ref data;let ref u8[] text=all[..n];
    let bool valid=if(field==2){names::module_name(text)}else if(field==3){names::symbol(text)}
        else if(field==7){names::capability(text)}else{names::revision(text)};
    if(!valid){return .err(error(.Value,s.begin));}
    let usize begin=bytes::len(pool);if(begin>byte_limit() || n>byte_limit()-begin){return .err(error(.Limit,s.begin));}
    let usize added=append(pool,text)?;let usize advanced=next(source,s)?;return .ok(Span{.begin=begin,.end=begin+n});
}
fn Result<u8,Error> type_value(ref u8[] source,ref mut json::State s,bool returns){
    var u8[34] data=[0;34];let usize n=decoded(source,*s,ref mut data)?;let ref u8[] all=ref data;
    let u8 tag=names::type_tag(all[..n],returns);if(tag==0){return .err(error(.Value,s.begin));}
    let usize advanced=next(source,s)?;return .ok(tag);
}
fn Result<usize,Error> parameters(ref u8[] source,ref mut json::State s,ref mut Entry item,ref mut u8[] tags){
    let usize open=take(source,s,91)?;
    if(s.kind==93){return take(source,s,93);}
    while(true){
        if(item.argc==argument_limit()){return .err(error(.Limit,s.begin));}
        let u8 tag=type_value(source,s,false)?;let usize slot=item.argc;tags[slot]=tag;item.argc=slot+1;
        if(s.kind==93){break;}let usize comma=take(source,s,44)?;
    }return take(source,s,93);
}
fn Result<usize,Error> id(ref u8[] source,ref mut json::State s,usize expected){
    if(s.kind!=2){return .err(error(.Value,s.begin));}
    var usize at=s.begin;var usize value=0;
    while(at<s.end){
        let u8 c=source[at];if(c<48 || c>57){return .err(error(.Value,s.begin));}
        let usize d=(c-48) as usize;
        if(value>6 || (value==6 && d>3)){return .err(error(.Value,s.begin));}
        value=value*10+d;at+=1;
    }
    if(value!=expected){return .err(error(.Order,s.begin));}return next(source,s);
}
fn Result<Entry,Error> entry(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,usize expected,ref mut u8[] tags){
    let usize open=take(source,s,123)?;var Entry item=empty_entry();var bool[8] seen=[false;8];
    if(s.kind!=125){while(true){
        let usize at=s.begin;let u8 field=key(source,s,false)?;let usize index=(field-1) as usize;
        if(seen[index]){return .err(error(.Duplicate,at));}seen[index]=true;
        if(field==1){let usize advanced=id(source,s,expected)?;}
        else if(field==2){item.scope=name(source,s,pool,field)?;}
        else if(field==3){item.symbol=name(source,s,pool,field)?;}
        else if(field==4){let usize argc=parameters(source,s,ref mut item,tags)?;}
        else if(field==5){item.result=type_value(source,s,true)?;}
        else if(field==6){
            var u8[5] data=[0;5];let usize n=decoded(source,*s,ref mut data)?;let ref u8[] all=ref data;
            if(bytes::equal(all[..n],b"write")){item.write=true;}
            else if(!bytes::equal(all[..n],b"read")){return .err(error(.Value,s.begin));}
            let usize advanced=next(source,s)?;
        }else if(field==7){item.capability=name(source,s,pool,field)?;}
        else{item.revision=name(source,s,pool,field)?;}
        if(s.kind==125){break;}let usize comma=take(source,s,44)?;
    }}
    var usize i=0;while(i<8){if(!seen[i]){return .err(error(.Missing,s.begin));}i+=1;}
    let usize close=take(source,s,125)?;return .ok(item);
}
fn Result<usize,Error> imports(ref u8[] source,ref mut json::State s,ref mut bytes::Buffer pool,ref mut Table table){
    let usize open=take(source,s,91)?;
    if(s.kind==93){return take(source,s,93);}
    while(true){
        let usize at=s.begin;if(table.count==import_limit()){return .err(error(.Limit,at));}
        let usize expected=table.count;
        let Entry item=entry(source,s,pool,expected,ref mut table.parameters[expected*32..expected*32+32])?;
        if(table.count>0){
            let usize previous=table.count-1;
            if(!names::before(view(pool,table.entries[previous].scope),view(pool,table.entries[previous].symbol),
                view(pool,item.scope),view(pool,item.symbol))){
                // The accepted prefix is strictly increasing. A later item
                // cannot duplicate it; scan only to classify an ordering failure.
                var usize i=0;while(i<table.count){
                    if(bytes::equal(view(pool,table.entries[i].scope),view(pool,item.scope)) &&
                        bytes::equal(view(pool,table.entries[i].symbol),view(pool,item.symbol))){return .err(error(.Duplicate,at));}i+=1;
                }
                return .err(error(.Order,at));
            }
        }
        let usize slot=table.count;table.entries[slot]=item;table.count=slot+1;
        if(s.kind==93){break;}let usize comma=take(source,s,44)?;
    }return take(source,s,93);
}
// Fixed grammar depth, no recursive descent through unrecognized values.
// Only a fully validated, privately owned table is published to the caller.
pub fn Result<Catalog,Error> parse(ref u8[] source){
    if(source.len>byte_limit()){return .err(error(.Limit,byte_limit()));}
    var json::State s=switch(json::start(source)){case .ok(v):{v}case .err(e):{return .err(lexical(e));}};
    let usize open=take(source,ref mut s,123)?;
    var bytes::Buffer pool=switch(bytes::with_capacity(source.len)){case .ok(v):{v}case .err(_):{return .err(error(.Allocation,0));}};
    var Table table=Table{.entries=[empty_entry();64],.parameters=[0;2048],.count=0};var bool[2] seen=[false;2];
    if(s.kind!=125){while(true){
        let usize at=s.begin;let u8 field=key(source,ref mut s,true)?;let usize index=(field-1) as usize;
        if(seen[index]){return .err(error(.Duplicate,at));}seen[index]=true;
        if(field==1){
            var u8[17] data=[0;17];let usize n=decoded(source,s,ref mut data)?;let ref u8[] all=ref data;
            if(!bytes::equal(all[..n],b"brownie.catalog/1")){return .err(error(.Value,s.begin));}
            let usize advanced=next(source,ref mut s)?;
        }else{let usize count=imports(source,ref mut s,ref mut pool,ref mut table)?;}
        if(s.kind==125){break;}let usize comma=take(source,ref mut s,44)?;
    }}
    if(!seen[0] || !seen[1]){return .err(error(.Missing,s.begin));}
    let usize close=take(source,ref mut s,125)?;if(s.kind!=0){return .err(error(.Json,s.begin));}
    return .ok(Catalog{.strings=pool,.table=table});
}
pub fn Result<Catalog,Error> duplicate(ref Catalog c){
    let bytes::Buffer strings=switch(bytes::copy(bytes::view(ref c.strings))){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,0));}
    };
    return .ok(Catalog{.strings=strings,.table=c.table});
}
pub fn usize count(ref Catalog c){return c.table.count;}
fn Result<usize,Error> index(ref Catalog c,usize i){if(i>=c.table.count){return .err(error(.Bounds,0));}return .ok(i);}
pub fn Result<ref u8[],Error> module_name(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(view(ref c.strings,c.table.entries[j].scope));}
pub fn Result<ref u8[],Error> symbol(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(view(ref c.strings,c.table.entries[j].symbol));}
pub fn Result<ref u8[],Error> capability(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(view(ref c.strings,c.table.entries[j].capability));}
pub fn Result<ref u8[],Error> adapter_revision(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(view(ref c.strings,c.table.entries[j].revision));}
pub fn Result<ref u8[],Error> effect(ref Catalog c,usize i){let usize j=index(c,i)?;let ref u8[] all=b"readwrite";let usize begin=if(c.table.entries[j].write){4}else{0};let usize end=if(c.table.entries[j].write){9}else{4};return .ok(all[begin..end]);}
pub fn Result<u8,Error> result_tag(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(c.table.entries[j].result);}
pub fn Result<usize,Error> parameter_count(ref Catalog c,usize i){let usize j=index(c,i)?;return .ok(c.table.entries[j].argc);}
pub fn Result<u8,Error> parameter_tag(ref Catalog c,usize i,usize arg){
    let usize j=index(c,i)?;if(arg>=c.table.entries[j].argc){return .err(error(.Bounds,0));}return .ok(c.table.parameters[j*32+arg]);
}
pub fn Result<ref u8[],Error> result_type(ref Catalog c,usize i){return .ok(names::result(result_tag(c,i)?));}
pub fn Result<ref u8[],Error> parameter_type(ref Catalog c,usize i,usize arg){return .ok(names::parameter(parameter_tag(c,i,arg)?));}
fn Result<usize,Error> u32le(ref mut bytes::Buffer out,usize n){
    var usize value=n;var u8[4] data=[0;4];var usize i=0;
    while(i<4){
        let i64 small=switch(num::i64_from_usize(value%256)){case .ok(v):{v}case .err(_):{return .err(error(.Limit,0));}};
        data[i]=switch(num::u8_from_i64(small)){case .ok(v):{v}case .err(_):{return .err(error(.Limit,0));}};
        value/=256;i+=1;
    }
    if(value!=0){return .err(error(.Limit,0));}return append(out,ref data);
}
fn Result<usize,Error> string(ref mut bytes::Buffer out,ref u8[] text){let usize prefix=u32le(out,text.len)?;return append(out,text);}
pub fn Result<bytes::Buffer,Error> canonical_bytes(ref Catalog c){
    var bytes::Buffer out=bytes::empty();let usize magic=append(ref mut out,b"BRC-CATALOG-1\n")?;
    let usize total=u32le(ref mut out,c.table.count)?;var usize i=0;
    while(i<c.table.count){
        let usize id=u32le(ref mut out,i)?;
        let usize scope=string(ref mut out,module_name(c,i)?)?;let usize name=string(ref mut out,symbol(c,i)?)?;
        let usize result=string(ref mut out,result_type(c,i)?)?;let usize mode=string(ref mut out,effect(c,i)?)?;
        let usize cap=string(ref mut out,capability(c,i)?)?;let usize rev=string(ref mut out,adapter_revision(c,i)?)?;
        let usize argc=parameter_count(c,i)?;let usize count=u32le(ref mut out,argc)?;var usize j=0;
        while(j<argc){let usize arg=string(ref mut out,parameter_type(c,i,j)?)?;j+=1;}i+=1;
    }return .ok(out);
}
// SHA words are in standard SHA-256 order; each word serializes big endian.
pub fn Result<u32[8],Error> digest(ref Catalog c){
    let bytes::Buffer canonical=canonical_bytes(c)?;
    return switch(hash::digest(bytes::view(ref canonical))){case .ok(v):{.ok(v)}case .err(_):{.err(error(.Limit,0))}};
}
