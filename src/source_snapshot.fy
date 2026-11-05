module source_snapshot;
import std::text as text;
import std::bytes as bytes;

// Native host snapshots only. Names are opaque source identities, not paths;
// this API never opens files, resolves imports or grants guest capabilities.
pub enum Error { State; Limit; Name; Duplicate; Utf8; Bounds; }
pub struct Span { usize source; usize start; usize end; }
pub struct Position { usize line; usize byte_column; }
pub struct Builder {
    u8[4096] data; u8[4096] names;
    usize[16] starts; usize[16] ends; usize[16] name_starts; usize[16] name_ends;
    usize used; usize names_used; usize count; usize source_limit; usize name_limit;
}
pub resource Snapshot { Builder sources; cleanup { } }
pub fn usize source_limit(){return 4096;}
pub fn usize name_limit(){return 4096;}
pub fn usize file_limit(){return 16;}
pub fn usize identity_limit(){return 256;}
pub fn Span no_source(){return Span{.source=16,.start=0,.end=0};}
pub fn Result<Builder,Error> builder(usize source_bytes,usize name_bytes){
    if(source_bytes>source_limit() || name_bytes>name_limit()){return .err(.Limit);}
    return .ok(Builder{.data=[0;4096],.names=[0;4096],.starts=[0;16],.ends=[0;16],
        .name_starts=[0;16],.name_ends=[0;16],.used=0,.names_used=0,.count=0,
        .source_limit=source_bytes,.name_limit=name_bytes});
}
fn bool identity(ref u8[] name){
    if(name.len==0 || name.len>identity_limit() || !text::validate_utf8(name).is_ok){return false;}
    var usize i=0;while(i<name.len){if(name[i]<32 || name[i]==127){return false;}i+=1;}
    return true;
}
// Copyable compiler scratch is never admitted authority. Authenticate packed
// ranges before indexing/subtracting even when a native caller forged fields.
fn Result<usize,Error> shape(ref Builder b){
    if(b.source_limit>source_limit() || b.name_limit>name_limit() || b.count>file_limit() ||
        b.used>b.source_limit || b.names_used>b.name_limit){return .err(.State);}
    var usize end=0;var usize name_end=0;var usize i=0;
    while(i<16){
        if(i<b.count){
            if(b.starts[i]!=end || b.ends[i]<end || b.ends[i]>b.used ||
                b.name_starts[i]!=name_end || b.name_ends[i]<=name_end ||
                b.name_ends[i]>b.names_used || b.name_ends[i]-name_end>identity_limit()){return .err(.State);}
            end=b.ends[i];name_end=b.name_ends[i];
        }else if(b.starts[i]!=0 || b.ends[i]!=0 || b.name_starts[i]!=0 || b.name_ends[i]!=0){return .err(.State);}
        i+=1;
    }
    if(end!=b.used || name_end!=b.names_used){return .err(.State);}
    return .ok(b.count);
}
pub fn usize pending(ref Builder b){return b.count;}
pub fn usize source_bytes(ref Builder b){return b.used;}
pub fn usize name_bytes(ref Builder b){return b.names_used;}
// Validate all bounds/encoding/identity before the first write. Both pools have
// a checked subtraction before addition; a rejected append leaves them intact.
pub fn Result<usize,Error> add(ref mut Builder b,ref u8[] name,ref u8[] source){
    let usize valid=shape(b)?;
    if(b.count==file_limit() || source.len>b.source_limit-b.used ||
        name.len>b.name_limit-b.names_used){return .err(.Limit);}
    if(!identity(name)){return .err(.Name);}
    if(!text::validate_utf8(source).is_ok){return .err(.Utf8);}
    let ref u8[] names=ref b.names;
    var usize i=0;
    while(i<b.count){
        if(bytes::equal(names[b.name_starts[i]..b.name_ends[i]],name)){return .err(.Duplicate);}
        i+=1;
    }
    let usize id=b.count;let usize start=b.used;let usize begin=b.names_used;
    i=0;while(i<source.len){b.data[start+i]=source[i];i+=1;}
    i=0;while(i<name.len){b.names[begin+i]=name[i];i+=1;}
    b.starts[id]=start;b.ends[id]=start+source.len;
    b.name_starts[id]=begin;b.name_ends[id]=begin+name.len;
    b.used=start+source.len;b.names_used=begin+name.len;b.count=id+1;
    return .ok(id);
}
// Independently authenticate all caller-mutable scratch before taking a private
// value snapshot. No mutable view or reference into the original builder escapes.
pub fn Result<Snapshot,Error> freeze(ref Builder b){
    let usize count=shape(b)?;var usize i=0;
    let ref u8[] names=ref b.names;let ref u8[] data=ref b.data;
    while(i<count){
        let ref u8[] name=names[b.name_starts[i]..b.name_ends[i]];
        if(!identity(name)){return .err(.Name);}
        if(!text::validate_utf8(data[b.starts[i]..b.ends[i]]).is_ok){return .err(.Utf8);}
        var usize j=0;while(j<i){
            if(bytes::equal(name,names[b.name_starts[j]..b.name_ends[j]])){return .err(.Duplicate);}
            j+=1;
        }i+=1;
    }
    return .ok(Snapshot{.sources=*b});
}
fn ref Builder sources(ref Snapshot p){return ref p.sources;}
pub fn usize count(ref Snapshot p){return sources(p).count;}
// Initialized payload/name bytes only, excluding fixed native storage/metadata.
pub fn usize initialized_bytes(ref Snapshot p){
    let ref Builder b=sources(p);return b.used+b.names_used;
}
pub fn Result<ref u8[],Error> name(ref Snapshot p,usize id){
    let ref Builder b=sources(p);if(id>=b.count){return .err(.Bounds);}
    let ref u8[] names=ref b.names;
    return .ok(names[b.name_starts[id]..b.name_ends[id]]);
}
pub fn Result<Span,Error> whole(ref Snapshot p,usize id){
    let ref Builder b=sources(p);if(id>=b.count){return .err(.Bounds);}
    return .ok(Span{.source=id,.start=0,.end=b.ends[id]-b.starts[id]});
}
fn Result<usize,Error> selected(ref Snapshot p,Span span){
    let ref Builder b=sources(p);
    if(span.source>=b.count || span.start>span.end){return .err(.Bounds);}
    let usize length=b.ends[span.source]-b.starts[span.source];
    if(span.end>length){return .err(.Bounds);}
    return .ok(b.starts[span.source]+span.start);
}
pub fn Result<ref u8[],Error> view(ref Snapshot p,Span span){
    let usize begin=selected(p,span)?;let ref Builder b=sources(p);
    let ref u8[] data=ref b.data;
    return .ok(data[begin..begin+span.end-span.start]);
}
pub fn Result<Span,Error> subspan(ref Snapshot p,Span parent,usize start,usize end){
    let usize begin=selected(p,parent)?;
    if(start>end || end>parent.end-parent.start){return .err(.Bounds);}
    return .ok(Span{.source=parent.source,.start=parent.start+start,.end=parent.start+end});
}
// Positions count original UTF-8 bytes, not Unicode scalars. LF completes a
// line break; CR in CRLF remains part of the previous line until that LF.
pub fn Result<Position,Error> position(ref Snapshot p,Span span){
    let usize begin=selected(p,span)?;let ref Builder b=sources(p);
    let ref u8[] data=ref b.data;
    var usize line=1;var usize column=1;var usize at=b.starts[span.source];
    while(at<begin){if(data[at]==10){line+=1;column=1;}else{column+=1;}at+=1;}
    return .ok(Position{.line=line,.byte_column=column});
}
