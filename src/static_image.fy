module static_image;
import std::bytes as bytes;
import std::text as utf8;

// Compiler scratch and a move-only, immutable native literal image. No guest
// pointer, Instance owner, mutable slice, unchecked text cast or runtime GC.
pub enum Error { State; Limit; Quota; Literals; Utf8; Kind; Bounds; Allocation; Provider; }
pub struct Catalog { usize[16] starts; usize[16] ends; bool[16] text; usize count; usize used; }
pub struct Builder { u8[4096] data; Catalog catalog; usize limit; }
pub resource Image { bytes::Buffer data; Catalog catalog; cleanup { } }
// Image-local offsets, not authenticated Engine/Program handles or owned roots.
pub struct Span { usize literal; usize start; usize end; }
pub fn usize byte_limit(){return 4096;}
pub fn usize literal_limit(){return 16;}
// Logical header plus 16 index rows. Not sizeof(Image) or process RAM.
pub fn usize metadata_charge(){return 576;}
fn Catalog empty_catalog(){return Catalog{.starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0};}
pub fn Result<Builder,Error> builder(usize limit){
    if(limit>byte_limit()){return .err(.Limit);}
    return .ok(Builder{.data=[0;4096],.catalog=empty_catalog(),.limit=limit});
}
// Packed ranges cover exactly the initialized prefix. Check subtraction bounds
// before every addition/index; unused metadata cannot smuggle another entry.
fn Result<usize,Error> shape(ref Catalog c,usize length){
    if(c.count>literal_limit() || c.used>byte_limit() || c.used!=length){return .err(.State);}
    var usize last=0;var usize i=0;
    while(i<16){
        if(i<c.count){if(c.starts[i]!=last || c.ends[i]<last || c.ends[i]>c.used){return .err(.State);}last=c.ends[i];}
        else if(c.starts[i]!=0 || c.ends[i]!=0 || c.text[i]){return .err(.State);}i+=1;
    }
    if(last!=c.used){return .err(.State);}return .ok(c.count);
}
fn Result<usize,Error> scratch(ref Builder b){
    if(b.limit>byte_limit() || b.catalog.used>b.limit){return .err(.State);}
    return shape(ref b.catalog,b.catalog.used);
}
fn usize find(ref Builder b,ref u8[] source,bool text){
    let ref u8[] data=ref b.data;
    var usize i=0;while(i<b.catalog.count){
        if(b.catalog.text[i]==text && bytes::equal(data[b.catalog.starts[i]..b.catalog.ends[i]],source)){return i;}i+=1;
    }return 16;
}
fn Result<usize,Error> intern(ref mut Builder b,ref u8[] source,bool text){
    let usize valid=scratch(b)?;
    if(source.len>byte_limit()){return .err(.Limit);}
    if(source.len>b.limit){return .err(.Quota);}
    if(text && !utf8::validate_utf8(source).is_ok){return .err(.Utf8);}
    let usize existing=find(b,source,text);if(existing!=16){return .ok(existing);}
    if(b.catalog.count>=literal_limit()){return .err(.Literals);}
    if(source.len>b.limit-b.catalog.used){return .err(.Quota);}
    let usize begin=b.catalog.used;let usize end=begin+source.len;let usize id=b.catalog.count;
    // Every fallible check precedes the first scratch write. No allocation here.
    var usize i=0;while(i<source.len){b.data[begin+i]=source[i];i+=1;}
    b.catalog.starts[id]=begin;b.catalog.ends[id]=end;b.catalog.text[id]=text;
    b.catalog.used=end;b.catalog.count+=1;return .ok(id);
}
pub fn Result<usize,Error> intern_bytes(ref mut Builder b,ref u8[] source){return intern(b,source,false);}
pub fn Result<usize,Error> intern_text(ref mut Builder b,ref u8[] source){return intern(b,source,true);}
fn Result<usize,Error> contents(ref Catalog c,ref u8[] data){
    let usize count=shape(c,data.len)?;var usize i=0;
    while(i<count){if(c.text[i] && !utf8::validate_utf8(data[c.starts[i]..c.ends[i]]).is_ok){return .err(.Utf8);}i+=1;}
    return .ok(count);
}
// Preflight retained capacity+metadata before the single native allocation. Only
// the used prefix is copied, so deduplication reduces actual retained payload.
// Scratch remains independently usable; later mutation cannot affect this image.
pub fn Result<usize,Error> planned_payload(ref Builder b){let usize valid=scratch(b)?;return .ok(b.catalog.used);}
pub fn Result<Image,Error> freeze(ref Builder b,usize program_limit){
    let usize valid=scratch(b)?;let ref u8[] data=ref b.data;
    let usize count=contents(ref b.catalog,data[..b.catalog.used])?;
    if(program_limit<metadata_charge() || b.catalog.used>program_limit-metadata_charge()){return .err(.Quota);}
    let bytes::Buffer payload=switch(bytes::copy(data[..b.catalog.used])){
        case .ok(value):{value}case .err(_):{return .err(.Allocation);}
    };
    if(bytes::len(ref payload)!=b.catalog.used || bytes::capacity(ref payload)!=b.catalog.used){return .err(.Provider);}
    return .ok(Image{.data=payload,.catalog=b.catalog});
}
// Independent whole-image admission, including actual UTF-8 bytes. The later
// Program verifier must call this before accepting static literal definitions.
pub fn Result<usize,Error> inspect(ref Image image){
    return inspect_catalog(ref image.catalog,bytes::view(ref image.data),bytes::capacity(ref image.data));
}
// Analysis of candidate metadata/bytes grants no immutable Image authority.
pub fn Result<usize,Error> inspect_catalog(ref Catalog catalog,ref u8[] data,usize capacity){
    if(capacity!=data.len){return .err(.State);}return contents(catalog,data);
}
// Read-only access tied to this exact immutable owning Image.
pub fn ref Catalog catalog(ref Image image){return ref image.catalog;}
// Shared payload only; the caller must keep this exact immutable Image alive.
pub fn ref u8[] payload(ref Image image){return bytes::view(ref image.data);}
pub fn Result<usize,Error> absolute(ref Image image,Span span){return selected(image,span);}
pub fn usize payload_bytes(ref Image image){return bytes::len(ref image.data);}
pub fn usize payload_capacity(ref Image image){return bytes::capacity(ref image.data);}
pub fn Result<u8,Error> kind(ref Image image,usize literal){
    let usize count=shape(ref image.catalog,bytes::len(ref image.data))?;
    if(literal>=count){return .err(.Bounds);}
    return .ok(if(image.catalog.text[literal]){2}else{1});
}
pub fn Result<usize,Error> charge(ref Image image){
    let usize count=shape(ref image.catalog,bytes::len(ref image.data))?;
    let usize capacity=bytes::capacity(ref image.data);if(capacity!=image.catalog.used){return .err(.State);}
    return .ok(metadata_charge()+capacity);
}
fn Result<usize,Error> selected(ref Image image,Span span){
    let usize count=shape(ref image.catalog,bytes::len(ref image.data))?;
    if(span.literal>=count){return .err(.Bounds);}
    let usize length=image.catalog.ends[span.literal]-image.catalog.starts[span.literal];
    if(span.start>span.end || span.end>length){return .err(.Bounds);}
    return .ok(image.catalog.starts[span.literal]+span.start);
}
pub fn Result<Span,Error> whole(ref Image image,usize literal){
    let usize count=shape(ref image.catalog,bytes::len(ref image.data))?;
    if(literal>=count){return .err(.Bounds);}
    return .ok(Span{.literal=literal,.start=0,.end=image.catalog.ends[literal]-image.catalog.starts[literal]});
}
pub fn Result<usize,Error> length(ref Image image,Span span){let usize begin=selected(image,span)?;return .ok(span.end-span.start);}
pub fn Result<Span,Error> subspan(ref Image image,Span span,usize start,usize end){
    let usize size=length(image,span)?;if(start>end || end>size){return .err(.Bounds);}
    return .ok(Span{.literal=span.literal,.start=span.start+start,.end=span.start+end});
}
pub fn Result<ref u8[],Error> view(ref Image image,Span span){
    let usize begin=selected(image,span)?;let usize size=span.end-span.start;
    return .ok(bytes::view(ref image.data)[begin..begin+size]);
}
pub fn Result<u8,Error> read(ref Image image,Span span,usize index){
    let usize begin=selected(image,span)?;if(index>=span.end-span.start){return .err(.Bounds);}
    return .ok(bytes::view(ref image.data)[begin+index]);
}
fn bool boundary(ref u8[] literal,usize offset){return offset==literal.len || (literal[offset]&192)!=128;}
pub fn Result<ref str,Error> text(ref Image image,Span span){
    let usize begin=selected(image,span)?;
    if(!image.catalog.text[span.literal]){return .err(.Kind);}
    let ref u8[] literal=bytes::view(ref image.data)[image.catalog.starts[span.literal]..image.catalog.ends[span.literal]];
    if(!boundary(literal,span.start) || !boundary(literal,span.end)){return .err(.Bounds);}
    // Even a forged native catalog flag cannot turn invalid bytes into ref str.
    return switch(utf8::validate_utf8(literal[span.start..span.end])){case .ok(value):{.ok(value)}case .err(_):{.err(.Utf8)}};
}
pub fn Result<bool,Error> equal(ref Image left,Span a,ref Image right,Span b){
    let ref u8[] x=view(left,a)?;let ref u8[] y=view(right,b)?;return .ok(bytes::equal(x,y));
}
