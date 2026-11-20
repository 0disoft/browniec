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
pub struct Error { u32 status; }

pub fn Error engine_failure(engine::Error failure){
    return Error{.status=failure.status};
}
pub fn Error unavailable(){return Error{.status=5};}
fn Error invalid(){return Error{.status=1};}
pub fn usize byte_limit(){return 4096;}

pub fn Result<Route,catalog::Error> register(ref catalog::Catalog imports,usize import_id){
    let u32[8] digest=catalog::digest(imports)?;
    return register_bound(imports,import_id,digest);
}

// The owner computes this digest once from the same immutable Catalog.
pub fn Result<Route,catalog::Error> register_bound(ref catalog::Catalog imports,usize import_id,u32[8] digest){
    let usize count=catalog::parameter_count(imports,import_id)?;
    let u8 result=catalog::result_tag(imports,import_id)?;
    var u8[32] arguments=[0;32];
    var usize i=0;
    while(i<count){
        arguments[i]=catalog::parameter_tag(imports,import_id,i)?;
        i+=1;
    }
    return .ok(Route{.signature=Signature{.digest=digest,.import_id=import_id,.count=count,.arguments=arguments,.result=result}});
}

fn bool valid_request(ref Signature signature,ref u8[] expected){
    let Signature facts=*signature;
    return wire::decode_request(expected,ref facts.arguments[..facts.count],byte_limit()).is_ok;
}
pub fn bool valid_pair(ref Route route,ref u8[] expected,u8 kind,ref u8[] response){
    let Signature signature=route.signature;
    return valid_request(ref signature,expected) && wire::decode_reply(kind,signature.result,response,byte_limit()).is_ok;
}

// Detached request for an adapter that completes outside the Engine borrow.
pub resource Dispatch { engine::HostRequestInfo info; bytes::Buffer wire; cleanup { } }
pub fn engine::HostRequestInfo dispatch_info(ref Dispatch request){return request.info;}
pub fn ref u8[] dispatch_bytes(ref Dispatch request){return bytes::view(ref request.wire);}

fn Result<engine::HostRequestInfo,Error> routed(ref engine::Engine owner,usize instance,ref Route route){
    let engine::HostRequestInfo info=switch(engine::host_request_info(owner,instance)){
        case .ok(v):{v}case .err(e):{return .err(engine_failure(e));}
    };
    let ref Signature signature=ref route.signature;
    if(info.import_id!=signature.import_id || !programs::same_digest(ref info.catalog.words,ref signature.digest)){
        return .err(unavailable());
    }
    return .ok(info);
}

pub fn Result<Dispatch,Error> claim_detached(ref mut engine::Engine owner,usize instance,ref Route route,usize limit){
    let engine::HostRequestInfo info=routed(owner,instance,route)?;
    if(info.payload_bytes>limit || info.payload_bytes>byte_limit()){return .err(invalid());}
    let bytes::Buffer owned=snapshot_request(owner,instance,route)?;
    switch(engine::claim_host_request(owner,instance,ref info)){
        case .ok(_):{}case .err(e):{return .err(engine_failure(e));}
    };
    return .ok(Dispatch{.info=info,.wire=owned});
}
fn Result<bytes::Buffer,Error> snapshot_request(ref engine::Engine owner,usize instance,ref Route route){
    let ref u8[] actual=switch(engine::host_request_payload(owner,instance)){
        case .ok(v):{v}case .err(e):{return .err(engine_failure(e));}
    };
    if(!valid_request(ref route.signature,actual)){return .err(invalid());}
    return switch(bytes::copy(actual)){
        case .ok(v):{.ok(v)}case .err(_):{.err(Error{.status=6})}
    };
}

// One synchronous, in-memory match. Only caller-owned bytes survive the
// Engine borrow. Neither a miss nor an invalid response claims the request.
pub fn Result<engine::Event,Error> dispatch(ref mut engine::Engine owner,usize instance,
    ref Route route,ref u8[] expected,u8 kind,ref u8[] response){
    let engine::HostRequestInfo info=routed(owner,instance,route)?;
    if(info.payload_bytes!=expected.len || !valid_pair(route,expected,kind,response)){return .err(invalid());}
    {
        let ref u8[] actual=switch(engine::host_request_payload(owner,instance)){
            case .ok(v):{v}case .err(e):{return .err(engine_failure(e));}
        };
        if(!bytes::equal(actual,expected)){return .err(invalid());}
    }
    switch(engine::claim_host_request(owner,instance,ref info)){
        case .ok(_):{}case .err(e):{return .err(engine_failure(e));}
    };
    return switch(engine::reply_scalar_host(owner,instance,info.run,info.request,kind,response)){
        case .ok(v):{.ok(v)}case .err(e):{.err(engine_failure(e))}
    };
}
