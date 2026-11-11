module value_type_source;

import lexer as lexer;
import errors as errors;
import value_properties as properties;
import struct_source as structs;
import std::num as num;
import value_type_work as staged;
import metadata_budget as budget;

// Private source-to-canonical-DAG helper. No legacy type encoding or compiler
// integration here. The caller supplies the current token, as with types::parse.
fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}
    };
    return switch(num::u8_from_i64(wide)){
        case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}
    };
}
fn Result<usize,errors::Error> inspect(ref properties::Catalog catalog,usize at){
    return switch(properties::inspect(catalog)){
        case .ok(p):{.ok(p.count)}case .err(e):{
            let u8 kind=switch(e){case .Metadata:{5}case .Type:{3}case .Depth:{4}case .Size:{4}};
            .err(errors::make(kind,at))
        }
    };
}
fn Result<usize,errors::Error> intern(ref mut properties::Catalog catalog,
    u8 kind,u8 first,u8 second,usize extent,usize at){
    var usize i=0;while(i<catalog.count){let properties::Node n=catalog.nodes[i];
        if(n.kind==kind && n.first==first && n.second==second && n.extent==extent){return .ok(i);}i+=1;
    }
    if(catalog.count>=64){return .err(errors::make(4,at));}
    let usize id=catalog.count;
    catalog.nodes[id]=properties::Node{.kind=kind,.first=first,.second=second,.extent=extent};
    catalog.count+=1;let usize valid=inspect(catalog,at)?;return .ok(id);
}
fn u8 scalar(ref u8[] name){
    return if(lexer::equal(name,b"i32")){1}else if(lexer::equal(name,b"bool")){2}
        else if(lexer::equal(name,b"i64")){9}else if(lexer::equal(name,b"u8")){10}
        else if(lexer::equal(name,b"u32")){11}else if(lexer::equal(name,b"usize")){12}else{0};
}
// A lexer >> has already advanced cursor/end past both bytes. Consume just its
// first byte, leaving a genuine '>' token at the second original byte. Neither
// cursor/end, token budget nor scoped context is rewound or fabricated.
fn Result<usize,errors::Error> close(ref u8[] source,ref mut lexer::State s){
    if(s.kind==135){s.begin+=1;s.kind=62;return .ok(0);}
    return lexer::punctuation(source,s,62);
}
fn Result<bool,errors::Error> buffer_name(ref u8[] source,ref mut lexer::State s){
    if(s.kind!=2){return .ok(false);}
    if(lexer::equal(source[s.begin..s.end],b"Buffer")){
        let usize next=lexer::next(source,s)?;return .ok(true);
    }
    let bool full=lexer::equal(source[s.begin..s.end],b"brownie");
    if(!full && !lexer::equal(source[s.begin..s.end],b"bytes")){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize name=lexer::next(source,ref mut look)?;
    if(look.kind!=58){return .ok(false);}
    let usize colon=lexer::punctuation(source,ref mut look,58)?;
    let usize colon2=lexer::punctuation(source,ref mut look,58)?;
    if(full){
        let usize bytes=lexer::word(source,ref mut look,b"bytes")?;
        let usize colon3=lexer::punctuation(source,ref mut look,58)?;
        let usize colon4=lexer::punctuation(source,ref mut look,58)?;
    }
    let usize buffer=lexer::word(source,ref mut look,b"Buffer")?;
    *s=look;return .ok(true);
}
// Scoped lexers can present an entire qualified name as kind5. Relex only its
// original span, with ordinary tokens; publish only the original lexer's next.
fn Result<bool,errors::Error> qualified_buffer(ref u8[] source,ref mut lexer::State s){
    if(s.kind!=5){return buffer_name(source,s);}
    var lexer::State look=lexer::empty();look.cursor=s.begin;
    let usize first=lexer::next(source[..s.end],ref mut look)?;
    let bool found=buffer_name(source[..s.end],ref mut look)?;
    if(!found || look.kind!=0){return .ok(false);}
    let usize next=lexer::next(source,s)?;return .ok(true);
}
fn Result<usize,errors::Error> type_node(ref u8[] source,ref mut lexer::State s,
    ref mut properties::Catalog catalog,usize depth){
    let usize at=s.begin;
    if(s.kind!=2 && s.kind!=5){return .err(errors::make(2,at));}
    let bool option=s.kind==2 && lexer::equal(source[s.begin..s.end],b"Option");
    let bool result=s.kind==2 && lexer::equal(source[s.begin..s.end],b"Result");
    var usize id=0;
    if(option || result){
        if(depth>=4){return .err(errors::make(4,at));}
        let usize name=lexer::next(source,s)?;
        let usize open=lexer::punctuation(source,s,60)?;
        let usize first=type_node(source,s,catalog,depth+1)?;
        var usize second=0;
        if(result){let usize comma=lexer::punctuation(source,s,44)?;
            second=type_node(source,s,catalog,depth+1)?;}
        let usize closed=close(source,s)?;
        let u8 a=byte(first,at)?;let u8 b=byte(second,at)?;
        id=intern(catalog,if(option){5}else{6},a,b,0,at)?;
    }else{
        let u8 tag=if(s.kind==2){scalar(source[s.begin..s.end])}else{0};
        if(tag!=0){
            let usize next=lexer::next(source,s)?;
            if(s.kind==91){
                let usize open=lexer::next(source,s)?;let usize length_at=s.begin;
                if(s.kind!=1 || s.value<1 || s.value>4096){return .err(errors::make(3,length_at));}
                let usize length=switch(num::usize_from_i64(s.value)){
                    case .ok(v):{v}case .err(_):{return .err(errors::make(3,length_at));}
                };
                let usize count=lexer::next(source,s)?;
                let usize closed=lexer::punctuation(source,s,93)?;
                id=intern(catalog,2,tag,0,length,at)?;
            }else{id=intern(catalog,1,tag,0,0,at)?;}
        }else{
            let usize begin=s.begin;let usize end=s.end;
            if(qualified_buffer(source,s)?){id=intern(catalog,4,0,0,0,at)?;}
            else{
                if(s.kind!=2 || catalog.records.count==0){return .err(errors::make(3,at));}
                let structs::Location found=structs::locate(source,begin,end,32)?;
                if(found.record>=catalog.records.count){return .err(errors::make(3,at));}
                let u8 nominal=byte(found.record,at)?;
                let usize next=lexer::next(source,s)?;
                id=intern(catalog,3,nominal,0,0,at)?;
            }
        }
    }
    // Only scalar arrays are in the target grammar; reject a second dimension
    // or an array suffix on a wrapper, record or Buffer at its original '['.
    if(s.kind==91){return .err(errors::make(3,s.begin));}return .ok(id);
}
// For nominal names, the caller first installs structs::scan(source).layouts
// into catalog.records. locate preserves the existing whole-module ID convention.
pub fn Result<usize,errors::Error> parse_raw(ref u8[] source,ref mut lexer::State cursor,
    ref mut properties::Catalog catalog){
    let usize at=cursor.begin;let usize valid=inspect(catalog,at)?;
    var lexer::State look=lexer::snapshot(cursor);var properties::Catalog working=*catalog;
    let usize id=type_node(source,ref mut look,ref mut working,0)?;
    *catalog=working;*cursor=look;return .ok(id);
}

// Synchronous compatibility adapter; originals publish only after all children.
pub fn Result<usize,errors::Error> parse(ref u8[] source,ref mut lexer::State cursor,ref mut properties::Catalog catalog){
    if(source.len>4096){return parse_raw(source,cursor,catalog);}
    var properties::Catalog candidate=properties::empty();var staged::State w=staged::begin(*cursor);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,cursor.begin)?;
        let bool done=staged::advance(source,catalog,ref mut candidate,ref mut w,ref mut meter)?;}
    let usize id=staged::prepared(ref w)?;*cursor=staged::observed(ref w);*catalog=candidate;return .ok(id);
}
