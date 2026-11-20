module host_adapter_frame;

import runtime_engine as engine;
import host_wire as wire;
import std::bytes as bytes;

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

// Check the complete frame, including reserved bytes and correlation, before
// allowing the payload to enter the Engine's reply receipt state.
pub fn Result<u8,Error> reply_kind(ref engine::HostRequestInfo info,u8 result,
    ref u8[] frame,usize limit){
    let usize prefix=header_size();
    if(frame.len<prefix || frame.len-prefix>limit){return .err(.Frame);}
    let u8 tag=frame[4];
    if(tag<1 || tag>3){return .err(.Frame);}
    let ref u8[] payload=frame[prefix..];
    let u8[64] expected=header(info,tag,payload.len);
    if(!bytes::equal(frame[..prefix],ref expected[..])){return .err(.Frame);}
    let u8 kind=tag-1;
    if(!wire::decode_reply(kind,result,payload,limit).is_ok){return .err(.Payload);}
    return .ok(kind);
}
