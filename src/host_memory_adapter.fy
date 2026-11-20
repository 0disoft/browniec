module host_memory_adapter;

import host_catalog as catalog;
import host_program as programs;
import host_wire as wire;
import runtime_engine as engine;
import std::bytes as bytes;

// An explicit registration from the adapter owner's trusted catalog.
struct Signature {
    u32[8] digest;
    usize import_id;
    usize count;
    u8[32] arguments;
    u8 result;
}
pub resource Route { Signature signature; cleanup { } }
pub enum Error { Routing; Request; Reply; Engine; }

pub fn Result<Route,catalog::Error> register(ref catalog::Catalog imports,usize import_id){
    let usize count=catalog::parameter_count(imports,import_id)?;
    let u8 result=catalog::result_tag(imports,import_id)?;
    let u32[8] digest=catalog::digest(imports)?;
    var u8[32] arguments=[0;32];
    var usize i=0;
    while(i<count){
        arguments[i]=catalog::parameter_tag(imports,import_id,i)?;
        i+=1;
    }
    return .ok(Route{.signature=Signature{.digest=digest,.import_id=import_id,.count=count,.arguments=arguments,.result=result}});
}

// One synchronous, in-memory match. Only caller-owned bytes survive the
// Engine borrow. Neither a miss nor an invalid response claims the request.
pub fn Result<engine::Event,Error> dispatch(ref mut engine::Engine owner,usize instance,
    ref Route route,ref u8[] expected,u8 kind,ref u8[] response){
    let engine::HostRequestInfo info=switch(engine::host_request_info(owner,instance)){
        case .ok(v):{v}case .err(_):{return .err(.Engine);}
    };
    let Signature signature=route.signature;
    if(info.import_id!=signature.import_id || !programs::same_digest(ref info.catalog.words,ref signature.digest)){
        return .err(.Routing);
    }
    if(info.payload_bytes!=expected.len || expected.len>4096 ||
       !wire::decode_request(expected,ref signature.arguments[..signature.count],4096).is_ok){
        return .err(.Request);
    }
    {
        let ref u8[] actual=switch(engine::host_request_payload(owner,instance)){
            case .ok(v):{v}case .err(_):{return .err(.Engine);}
        };
        if(!bytes::equal(actual,expected)){return .err(.Request);}
    }
    if(!wire::decode_reply(kind,signature.result,response,4096).is_ok){return .err(.Reply);}
    if(!engine::claim_host_request(owner,instance,ref info).is_ok){return .err(.Engine);}
    return switch(engine::reply_scalar_host(owner,instance,info.run,info.request,kind,response)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Engine)}
    };
}
