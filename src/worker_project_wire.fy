module worker_project_wire;

import errors as errors;
import fuel as meter;
import host_wire as le;
import host_catalog as catalog;
import json_tokens as json;
import project_manifest as manifest;
import runtime_input as input;
import runtime_output as output;
import runtime_run_config as runs;
import source_snapshot as sources;
import worker_scalar_result as scalar;
import std::bytes as bytes;

pub enum Error { Shape; Limit; Allocation; }
pub struct Header { bool run; bool has_input; usize input_start; usize fuel; usize manifest_start; usize manifest_end; usize policy_end; usize run_end; usize catalog_end; }
pub struct Outcome { scalar::Outcome value; u8 profile; sources::Span span; }
pub struct ResultFrame { Outcome outcome; bool has_output; usize output_start; }

pub fn usize request_limit(){return 25+3*65536+catalog::byte_limit()+2*16+4096+input::hard_limit();}
pub fn usize result_limit(){return 4+scalar::byte_limit();}
pub fn usize reply_capacity(bool allow_output,usize output_limit){
    return result_limit()+if(allow_output){3+output_limit}else{0};
}

pub fn bool output_granted(ref runs::RunConfig run){
    return runs::requires_count(run)==1 && runs::grants_count(run)==1 &&
        runs::declares(run,b"brownie.output.emit") && runs::grants(run,b"brownie.output.emit");
}

pub fn bool project_authorized(ref manifest::Project project,bool allow_output){
    if(!allow_output){return manifest::requirements(project)==0;}
    if(manifest::requirements(project)!=1){return false;}
    return switch(manifest::requirement(project,0)){
        case .ok(name):{bytes::equal(name,b"brownie.output.emit")}
        case .err(_):{false}
    };
}

fn usize u16_at(ref u8[] data,usize at){return data[at] as usize+256*(data[at+1] as usize);}

pub fn Result<Header,Error> header(ref u8[] wire){
    if(wire.len<9 || wire.len>request_limit() || wire[0]<2 || wire[0]>9){return .err(.Shape);}
    let bool configured=wire[0]>=4;
    let bool host=wire[0]>=7;
    let bool has_input=wire[0]==6 || wire[0]==9;
    let bool run=wire[0]==3 || wire[0]==5 || wire[0]==6 || wire[0]>=8;
    let usize start=if(host){25}else if(has_input){21}else if(configured){17}else{9};
    if(wire.len<start){return .err(.Shape);}
    let usize fuel=le::read_u32(wire[1..5]);
    let usize length=le::read_u32(wire[5..9]);
    if(length==0 || length>json::byte_limit() || length>wire.len-start ||
       fuel>meter::cli_limit() || (!run && fuel!=0)){return .err(.Shape);}
    let usize manifest_end=start+length;
    let usize policy=if(configured){le::read_u32(wire[9..13])}else{0};
    let usize request=if(configured){le::read_u32(wire[13..17])}else{0};
    if(configured && (policy==0 || policy>json::byte_limit() || request==0 || request>json::byte_limit() ||
       policy+request>wire.len-manifest_end)){return .err(.Shape);}
    let usize run_end=manifest_end+policy+request;
    let usize catalog_size=if(host){le::read_u32(wire[21..25])}else{0};
    let usize input_size=if(host || has_input){le::read_u32(wire[17..21])}else{0};
    if((host && (catalog_size==0 || catalog_size>catalog::byte_limit())) ||
        (!has_input && input_size!=0) || input_size>input::hard_limit() ||
        catalog_size+input_size>wire.len-run_end){return .err(.Shape);}
    return .ok(Header{.run=run,.has_input=has_input,.input_start=wire.len-input_size,
        .fuel=fuel,.manifest_start=start,.manifest_end=manifest_end,
        .policy_end=manifest_end+policy,.run_end=run_end,.catalog_end=run_end+catalog_size});
}

// The parent fixes the file order to the decoded manifest rows before copying.
pub fn Result<bytes::Buffer,Error> pack(ref u8[] raw,ref manifest::Project project,
    ref sources::Snapshot snapshot,bool run,usize fuel,ref u8[] policy,ref u8[] request,ref u8[] imports,bool has_input,ref u8[] payload,ref mut u8[] lengths){
    let usize count=manifest::count(project);
    if(count==0 || count>sources::file_limit() || count!=sources::count(snapshot) ||
       lengths.len!=2*count || raw.len==0 || raw.len>json::byte_limit() ||
       fuel>meter::cli_limit() || (!run && fuel!=0) || (policy.len==0 && manifest::requirements(project)!=0) ||
       (policy.len==0)!=(request.len==0) || policy.len>json::byte_limit() || request.len>json::byte_limit() ||
       (has_input && (!run || policy.len==0)) || (!has_input && payload.len!=0) ||
       (imports.len!=0 && policy.len==0) || imports.len>catalog::byte_limit() || payload.len>input::hard_limit()){
        return .err(.Shape);
    }
    var u8[25] prefix=[0;25];
    let bool host=imports.len!=0;
    let usize start=if(host){25}else if(has_input){21}else if(policy.len!=0){17}else{9};
    prefix[0]=if(host){if(has_input){9}else if(run){8}else{7}}
        else if(has_input){6}else if(policy.len==0){if(run){3}else{2}}else{if(run){5}else{4}};
    le::write_le(fuel,ref mut prefix[1..5]);
    le::write_le(raw.len,ref mut prefix[5..9]);
    le::write_le(policy.len,ref mut prefix[9..13]);
    le::write_le(request.len,ref mut prefix[13..17]);
    le::write_le(payload.len,ref mut prefix[17..21]);
    le::write_le(imports.len,ref mut prefix[21..25]);
    let usize size=start+raw.len+policy.len+request.len+imports.len+2*count+sources::snapshot_bytes(snapshot)+payload.len;
    var bytes::Buffer wire=switch(bytes::with_capacity(size)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    if(!bytes::append(ref mut wire,ref prefix[..start]).is_ok || !bytes::append(ref mut wire,raw).is_ok ||
       !bytes::append(ref mut wire,policy).is_ok || !bytes::append(ref mut wire,request).is_ok ||
       !bytes::append(ref mut wire,imports).is_ok){
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
    if(!bytes::append(ref mut wire,payload).is_ok){return .err(.Allocation);}
    return .ok(wire);
}

pub fn Result<sources::Snapshot,Error> unpack(ref u8[] files,ref manifest::Project project){
    let usize count=manifest::count(project);
    let usize directory=2*count;
    if(count==0 || count>sources::file_limit() || directory>files.len ||
       files.len-directory>sources::source_limit()){return .err(.Shape);}
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
pub fn Result<Outcome,Error> parse_result(ref u8[] wire,bool run,ref u8[] lengths,bool allow_output){
    if(wire.len<=4 || wire.len>result_limit() || wire[0]>8 || wire[1]>16 ||
       lengths.len==0 || lengths.len>32 || lengths.len%2!=0){return .err(.Shape);}
    let usize source=wire[1] as usize;
    let bool located=source!=16;
    if(located && 2*source+2>lengths.len){return .err(.Shape);}
    let usize limit=if(located){u16_at(lengths,2*source)}else{0};
    let usize end=u16_at(wire,2);
    let scalar::Expected expected=scalar::Expected{.run=run,.output=allow_output,.source_bytes=limit,.instructions=256};
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

pub fn Result<bytes::Buffer,Error> encode_result(Outcome outcome,bool run,bool allow_output){
    let sources::Span span=outcome.span;
    let scalar::Expected expected=scalar::Expected{.run=run,.output=allow_output,.source_bytes=span.end,.instructions=256};
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

// Output has its own envelope. The nested scalar result retains the original
// framing and must be a successful run before a byte tail can be exposed.
pub fn Result<ResultFrame,Error> parse_frame(ref u8[] wire,bool run,ref u8[] lengths,
    bool allow_output,usize output_limit){
    if(wire.len==0 || output_limit>output::hard_limit()){return .err(.Shape);}
    if(wire[0]!=128){
        let Outcome result=parse_result(wire,run,lengths,allow_output)?;
        if(run && allow_output && scalar::is_completed(result.value)){return .err(.Shape);}
        return .ok(ResultFrame{.outcome=result,.has_output=false,.output_start=wire.len});
    }
    if(!run || !allow_output || wire.len<3){return .err(.Shape);}
    let usize meta=u16_at(wire,1);
    if(meta>result_limit() || meta>wire.len-3){return .err(.Shape);}
    let usize start=3+meta;
    if(wire.len-start>output_limit){return .err(.Limit);}
    let Outcome result=parse_result(wire[3..start],true,lengths,allow_output)?;
    if(!scalar::is_completed(result.value)){return .err(.Shape);}
    return .ok(ResultFrame{.outcome=result,.has_output=true,.output_start=start});
}

pub fn Result<bytes::Buffer,Error> encode_output(Outcome outcome,ref u8[] payload){
    if(!scalar::is_completed(outcome.value)){return .err(.Shape);}
    if(payload.len>output::hard_limit()){return .err(.Limit);}
    let bytes::Buffer result=encode_result(outcome,true,true)?;
    let ref u8[] metadata=bytes::view(ref result);
    var u8[3] prefix=[128,0,0];
    le::write_le(metadata.len,ref mut prefix[1..3]);
    var bytes::Buffer wire=switch(bytes::with_capacity(3+metadata.len+payload.len)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    if(!bytes::append(ref mut wire,ref prefix).is_ok || !bytes::append(ref mut wire,metadata).is_ok ||
       !bytes::append(ref mut wire,payload).is_ok){return .err(.Allocation);}
    return .ok(wire);
}
