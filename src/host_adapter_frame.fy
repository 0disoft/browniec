module host_adapter_frame;

import runtime_engine as engine;
import host_wire as wire;

pub enum Error { Frame; Payload; }
pub fn usize header_size(){return 64;}

// The channel belongs to one Engine session. IDs are scoped to that session.
// Tags: request=0, success=1, guest error=2, adapter failure=3.
pub fn u8[64] header(ref engine::HostRequestInfo info,u8 tag,usize length){
    var u8[64] out=[0;64];
    out[0]=66;out[1]=67;out[2]=65;out[3]=49;
    out[4]=tag;
    wire::write_le(info.run,ref mut out[8..16]);
    wire::write_le(info.request,ref mut out[16..24]);
    wire::write_le(info.import_id,ref mut out[24..28]);
    wire::write_le(length,ref mut out[28..32]);
    var usize i=0;
    while(i<8){
        let usize start=32+i*4;
        wire::write_le(info.catalog.words[i] as usize,ref mut out[start..start+4]);
        i+=1;
    }
    return out;
}

// A transport can reject an untrusted header before reading the body.
pub fn Result<usize,Error> reply_size(ref engine::HostRequestInfo info,
    ref u8[] prefix,usize limit){
    if(prefix.len!=header_size()){return .err(.Frame);}
    let u8 tag=prefix[4];
    if(tag<1 || tag>3){return .err(.Frame);}
    let usize length=wire::read_u32(prefix[28..32]);
    if(length>limit){return .err(.Frame);}
    if(tag==3){
        if(length!=0){return .err(.Frame);}
    }else if(length<8){return .err(.Frame);}
    if(!matches_request(info,prefix)){return .err(.Frame);}
    return .ok(length);
}

fn bool matches_request(ref engine::HostRequestInfo info,ref u8[] prefix){
    if(wire::read_u32(prefix[..4])!=826360642 || prefix[5]!=0 || prefix[6]!=0 || prefix[7]!=0){
        return false;
    }
    if(!matches_id(info.run,prefix[8..16]) || !matches_id(info.request,prefix[16..24]) ||
        wire::read_u32(prefix[24..28])!=info.import_id){return false;}
    var usize i=0;
    while(i<8){
        let usize at=32+i*4;
        if(wire::read_u32(prefix[at..at+4])!=info.catalog.words[i] as usize){return false;}
        i+=1;
    }
    return true;
}

fn bool matches_id(usize id,ref u8[] encoded){
    return wire::read_u32(encoded[..4])==id%4294967296 &&
        wire::read_u32(encoded[4..])==id/4294967296;
}

// A complete frame must have exactly the declared body and a valid TLV.
pub fn Result<u8,Error> reply_kind(ref engine::HostRequestInfo info,u8 result,
    ref u8[] frame,usize limit){
    let usize prefix=header_size();
    if(frame.len<prefix){return .err(.Frame);}
    let usize declared=reply_size(info,frame[..prefix],limit)?;
    let ref u8[] payload=frame[prefix..];
    if(payload.len!=declared){return .err(.Frame);}
    let u8 kind=frame[4]-1;
    if(!wire::decode_reply(kind,result,payload,limit).is_ok){return .err(.Payload);}
    return .ok(kind);
}
