module worker_project_wire;

import errors as errors;
import fuel as meter;
import host_wire as le;
import json_tokens as json;
import project_manifest as manifest;
import source_snapshot as sources;
import worker_scalar_result as scalar;
import std::bytes as bytes;

pub enum Error { Shape; Limit; Allocation; }
pub struct Header { bool run; usize fuel; usize manifest_end; }
pub struct Outcome { scalar::Outcome value; u8 profile; sources::Span span; }

pub fn usize request_limit(){return 9+65536+2*16+4096;}
pub fn usize result_limit(){return 4+scalar::byte_limit();}

fn usize u16_at(ref u8[] data,usize at){return data[at] as usize+256*(data[at+1] as usize);}

pub fn Result<Header,Error> header(ref u8[] wire){
    if(wire.len<9 || wire.len>request_limit() || (wire[0]!=2 && wire[0]!=3)){return .err(.Shape);}
    let bool run=wire[0]==3;
    let usize fuel=le::read_u32(wire[1..5]);
    let usize length=le::read_u32(wire[5..9]);
    if(length==0 || length>json::byte_limit() || length>wire.len-9 ||
       fuel>meter::cli_limit() || (!run && fuel!=0)){return .err(.Shape);}
    return .ok(Header{.run=run,.fuel=fuel,.manifest_end=9+length});
}

// The parent fixes the file order to the decoded manifest rows before copying.
pub fn Result<bytes::Buffer,Error> pack(ref u8[] raw,ref manifest::Project project,
    ref sources::Snapshot snapshot,bool run,usize fuel,ref mut u8[] lengths){
    let usize count=manifest::count(project);
    if(count==0 || count>sources::file_limit() || count!=sources::count(snapshot) ||
       lengths.len!=2*count || raw.len==0 || raw.len>json::byte_limit() ||
       fuel>meter::cli_limit() || (!run && fuel!=0) || manifest::requirements(project)!=0){
        return .err(.Shape);
    }
    var u8[9] prefix=[0;9];
    prefix[0]=if(run){3}else{2};
    le::write_le(fuel,ref mut prefix[1..5]);
    le::write_le(raw.len,ref mut prefix[5..9]);
    var bytes::Buffer wire=switch(bytes::with_capacity(9+raw.len+2*count+sources::snapshot_bytes(snapshot))){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    if(!bytes::append(ref mut wire,ref prefix).is_ok || !bytes::append(ref mut wire,raw).is_ok){
        return .err(.Allocation);
    }
    var usize i=0;
    while(i<count){
        let ref u8[] path=switch(manifest::path(project,i)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        let ref u8[] name=switch(sources::name(snapshot,i)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        if(!bytes::equal(name,path)){return .err(.Shape);}
        let sources::Span span=switch(sources::whole(snapshot,i)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        le::write_le(span.end,lengths[2*i..2*i+2]);
        i+=1;
    }
    if(!bytes::append(ref mut wire,lengths).is_ok){return .err(.Allocation);}
    i=0;
    while(i<count){
        let sources::Span span=switch(sources::whole(snapshot,i)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        let ref u8[] file=switch(sources::view(snapshot,span)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        if(!bytes::append(ref mut wire,file).is_ok){return .err(.Allocation);}
        i+=1;
    }
    return .ok(wire);
}

pub fn Result<sources::Snapshot,Error> unpack(ref u8[] files,ref manifest::Project project){
    let usize count=manifest::count(project);
    let usize directory=2*count;
    if(count==0 || count>sources::file_limit() || directory>files.len ||
       files.len-directory>sources::source_limit() || manifest::requirements(project)!=0){return .err(.Shape);}
    var usize end=directory;
    var usize row=0;
    while(row<count){
        let usize length=u16_at(files,2*row);
        if(length>files.len-end){return .err(.Shape);}
        end+=length;
        row+=1;
    }
    if(end!=files.len){return .err(.Shape);}
    var sources::Builder builder=switch(sources::builder(end-directory,sources::name_limit())){
        case .ok(v):{v}case .err(_):{return .err(.Limit);}
    };
    var usize at=directory;
    row=0;
    while(row<count){
        let usize length=u16_at(files,2*row);
        let ref u8[] path=switch(manifest::path(project,row)){case .ok(v):{v}case .err(_):{return .err(.Shape);}};
        if(!sources::add(ref mut builder,path,files[at..at+length]).is_ok){return .err(.Shape);}
        at+=length;
        row+=1;
    }
    return switch(sources::freeze(ref builder)){case .ok(v):{.ok(v)}case .err(_):{.err(.Shape)}};
}

// Prefix: public profile, source index (16 means absent), little-endian span end.
pub fn Result<Outcome,Error> parse_result(ref u8[] wire,bool run,ref u8[] lengths){
    if(wire.len<=4 || wire.len>result_limit() || wire[0]>8 || wire[1]>16 ||
       lengths.len==0 || lengths.len>32 || lengths.len%2!=0){return .err(.Shape);}
    let usize source=wire[1] as usize;
    let bool located=source!=16;
    if(located && 2*source+2>lengths.len){return .err(.Shape);}
    let usize limit=if(located){u16_at(lengths,2*source)}else{0};
    let usize end=u16_at(wire,2);
    let scalar::Expected expected=scalar::Expected{.run=run,.source_bytes=limit,.instructions=256};
    let scalar::Outcome value=switch(scalar::parse(wire[4..wire.len],expected)){
        case .ok(v):{v}case .err(_):{return .err(.Shape);}
    };
    let bool source_error=switch(value.status){
        case .Failed:{value.error.location==0}case .Checked:{false}case .Completed:{false}
    };
    if(source_error!=located || end>limit || (located && end<value.error.offset)){return .err(.Shape);}
    return .ok(Outcome{.value=value,.profile=wire[0],.span=sources::Span{.source=source,
        .start=if(located){value.error.offset}else{0},.end=end}});
}

pub fn Result<bytes::Buffer,Error> encode_result(Outcome outcome,bool run){
    let sources::Span span=outcome.span;
    let scalar::Expected expected=scalar::Expected{.run=run,.source_bytes=span.end,.instructions=256};
    let bytes::Buffer payload=switch(scalar::encode(outcome.value,expected)){
        case .ok(v):{v}case .err(_):{return .err(.Shape);}
    };
    var u8[4] prefix=[0;4];
    prefix[0]=outcome.profile;
    le::write_le(span.source,ref mut prefix[1..2]);
    le::write_le(span.end,ref mut prefix[2..4]);
    var bytes::Buffer wire=switch(bytes::with_capacity(4+bytes::len(ref payload))){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    if(!bytes::append(ref mut wire,ref prefix).is_ok ||
       !bytes::append(ref mut wire,bytes::view(ref payload)).is_ok){return .err(.Allocation);}
    return .ok(wire);
}
