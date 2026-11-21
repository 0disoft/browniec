module cli_host_replies;

import cli_local_file as files;
import errors as errors;
import host_catalog as catalog;
import host_memory_adapter as adapter;
import runtime_engine as engine;
import runtime_policy_json as json;
import std::bytes as bytes;
import std::vec as vec;

resource Row {
    usize import_id; u8 kind; adapter::Route route;
    json::Span request; json::Span reply;
    cleanup { }
}
pub resource Replies { bytes::Buffer wire; vec::Vec<Row> rows; cleanup { } }

fn errors::Error usage(usize at){return errors::make(10,at);}
fn errors::Error allocation(){return errors::absent(15,0);}
fn errors::Error problem(json::Error e){
    if(switch(e.kind){case .Allocation:{true}
        case .Json:{false}case .Limit:{false}case .Unknown:{false}case .Duplicate:{false}
        case .Missing:{false}case .Value:{false}case .Relation:{false}case .Authority:{false}case .Bounds:{false}}){return allocation();}
    return usage(e.offset);
}

fn Result<u8,json::Error> digit(u8 value,usize at){
    if(value>=48 && value<=57){return .ok(value-48);}
    if(value>=97 && value<=102){return .ok(value-87);}
    return .err(json::error(.Value,at));
}
fn Result<json::Span,json::Error> hex_span(ref u8[] source,ref mut json::Cursor c,usize limit){
    let usize at=c.token.begin;
    if(c.token.kind!=34){return .err(json::error(.Value,at));}
    let usize n=c.token.end-at-2;
    if(n%2!=0 || n/2>limit){return .err(json::error(.Limit,at));}
    discard json::next(source,c)?;
    return .ok(json::Span{.begin=at+1,.end=at+1+n});
}
fn Result<json::Span,json::Error> wire_bytes(ref u8[] source,ref mut json::Cursor c,ref mut bytes::Buffer wire){
    let json::Span text=hex_span(source,c,adapter::byte_limit())?;
    let usize start=bytes::len(wire);
    let usize end=start+(text.end-text.begin)/2;
    if(!bytes::resize_zeroed(wire,end).is_ok){return .err(json::error(.Allocation,text.begin));}
    let ref mut u8[] pool=bytes::view_mut(wire);
    var usize i=text.begin;
    var usize target=start;
    while(i<text.end){
        pool[target]=digit(source[i],i)?*16+digit(source[i+1],i+1)?;
        i+=2;
        target+=1;
    }
    return .ok(json::Span{.begin=start,.end=end});
}
fn Result<usize,json::Error> binding(ref u8[] source,ref mut json::Cursor c,ref u32[] expected){
    let json::Span text=hex_span(source,c,32)?;
    if(text.end-text.begin!=64){return .err(json::error(.Value,text.begin));}
    var usize word=0;
    while(word<8){
        var u32 actual=0;
        var usize at=text.begin+word*8;
        let usize end=at+8;
        while(at<end){actual=(actual<<4)|(digit(source[at],at)? as u32);at+=1;}
        if(actual!=expected[word]){return .err(json::error(.Value,text.begin));}
        word+=1;
    }
    return .ok(word);
}
fn Result<Row,json::Error> row(ref u8[] source,ref mut json::Cursor c,ref mut bytes::Buffer wire,
    ref catalog::Catalog imports,u32[8] digest){
    let usize begin=c.token.begin;
    discard json::take(source,c,123)?;
    var bool[4] seen=[false;4];
    var usize import_id=0;
    var u8 kind=0;
    let json::Span empty=json::Span{.begin=0,.end=0};
    var json::Span request=empty;
    var json::Span reply=empty;
    while(true){
        let usize at=c.token.begin;
        let usize field=json::field(source,c,b"import_id|request_hex|kind|reply_hex")?;
        discard json::mark(ref mut seen,field,at)?;
        if(field==0){import_id=json::integer(source,c,0,catalog::import_limit()-1)?;}
        else if(field==1){request=wire_bytes(source,c,wire)?;}
        else if(field==2){
            let usize value=json::integer(source,c,0,2)?;
            kind=if(value==0){0}else if(value==1){1}else{2};
        }else{reply=wire_bytes(source,c,wire)?;}
        if(c.token.kind==125){break;}
        discard json::take(source,c,44)?;
    }
    discard json::complete(ref seen,begin)?;
    discard json::take(source,c,125)?;
    let adapter::Route route=switch(adapter::register_bound(imports,import_id,digest)){
        case .ok(v):{v}case .err(_):{return .err(json::error(.Value,begin));}
    };
    if(!adapter::valid_pair(ref route,json::view(wire,request),kind,json::view(wire,reply))){
        return .err(json::error(.Value,begin));
    }
    return .ok(Row{.import_id=import_id,.kind=kind,.route=route,.request=request,.reply=reply});
}
fn Result<usize,json::Error> rows(ref u8[] source,ref mut json::Cursor c,ref mut bytes::Buffer wire,
    ref mut vec::Vec<Row> entries,ref catalog::Catalog imports,u32[8] digest){
    discard json::take(source,c,91)?;
    if(c.token.kind!=93){while(true){
        let usize at=c.token.begin;
        let usize count=vec::len<Row>(entries);
        if(count>=64){return .err(json::error(.Limit,at));}
        let Row next=row(source,c,wire,imports,digest)?;
        var usize i=0;
        while(i<count){
            let ref Row other=vec::at<Row>(entries,i);
            if(next.import_id==other.import_id && bytes::equal(json::view(wire,next.request),json::view(wire,other.request))){
                return .err(json::error(.Duplicate,at));
            }
            i+=1;
        }
        if(!vec::push<Row>(entries,next).is_ok){return .err(json::error(.Allocation,at));}
        if(c.token.kind==93){break;}
        discard json::take(source,c,44)?;
    }}
    return json::take(source,c,93);
}
fn Result<Replies,json::Error> parse(ref u8[] source,ref catalog::Catalog imports,u32[8] digest){
    var json::Cursor c=json::start(source)?;
    discard json::take(source,ref mut c,123)?;
    var bool[3] seen=[false;3];
    var bytes::Buffer wire=switch(bytes::with_capacity(source.len/2)){
        case .ok(v):{v}case .err(_):{return .err(json::error(.Allocation,0));}
    };
    var vec::Vec<Row> entries=vec::empty<Row>();
    while(true){
        let usize at=c.token.begin;
        let usize field=json::field(source,ref mut c,b"schema|catalog_sha256|replies")?;
        discard json::mark(ref mut seen,field,at)?;
        if(field==0){discard json::constant(source,ref mut c,b"brownie.host-replies/1")?;}
        else if(field==1){discard binding(source,ref mut c,ref digest)?;}
        else{discard rows(source,ref mut c,ref mut wire,ref mut entries,imports,digest)?;}
        if(c.token.kind==125){break;}
        discard json::take(source,ref mut c,44)?;
    }
    discard json::complete(ref seen,c.token.begin)?;
    discard json::take(source,ref mut c,125)?;
    if(c.token.kind!=0){return .err(json::error(.Json,c.token.begin));}
    return .ok(Replies{.wire=wire,.rows=entries});
}
@effects(filesystem)
pub fn Result<Replies,errors::Error> read(usize argument,ref catalog::Catalog imports,u32[8] digest){
    let files::File file=files::open(argument,json::byte_limit(),10)?;
    return switch(parse(files::view(ref file),imports,digest)){
        case .ok(v):{.ok(v)}case .err(e):{.err(problem(e))}
    };
}
// The broker has already checked the import authority against its own run.
pub fn usize copy_reply(ref Replies replies,usize import_id,ref u8[] request,ref mut u8[] response){
    let usize i=switch(find(replies,request,import_id)){
        case .some(v):{v}case .none:{64}
    };
    if(i==64){return 0;}
    let ref Row entry=vec::at<Row>(ref replies.rows,i);
    let ref u8[] data=json::view(ref replies.wire,entry.reply);
    if(response.len==0 || data.len>response.len-1){return 0;}
    response[0]=entry.kind;
    var usize at=0;
    while(at<data.len){response[1+at]=data[at];at+=1;}
    return 1+data.len;
}

fn Option<usize> find(ref Replies replies,ref u8[] request,usize import_id){
    var usize i=0;
    while(i<vec::len<Row>(ref replies.rows)){
        let ref Row entry=vec::at<Row>(ref replies.rows,i);
        if(import_id==entry.import_id && bytes::equal(request,json::view(ref replies.wire,entry.request))){
            return .some(i);
        }
        i+=1;
    }
    return .none;
}
pub fn Result<engine::Event,adapter::Error> dispatch(ref Replies replies,ref mut engine::Engine owner,usize instance){
    let engine::HostRequestInfo info=switch(engine::host_request_info(owner,instance)){
        case .ok(v):{v}case .err(e):{return .err(adapter::engine_failure(e));}
    };
    let Option<usize> match={
        let ref u8[] request=switch(engine::host_request_payload(owner,instance)){
            case .ok(v):{v}case .err(e):{return .err(adapter::engine_failure(e));}
        };
        find(replies,request,info.import_id)
    };
    let usize i=switch(match){
        case .some(v):{v}case .none:{64}
    };
    if(i==64){return .err(adapter::unavailable());}
    let ref Row entry=vec::at<Row>(ref replies.rows,i);
    return adapter::dispatch(owner,instance,ref entry.route,json::view(ref replies.wire,entry.request),
        entry.kind,json::view(ref replies.wire,entry.reply));
}
