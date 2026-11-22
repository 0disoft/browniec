module host_process_adapter;

import host_catalog as catalog;
import host_memory_adapter as adapter;
import runtime_engine as engine;
import std::bytes as bytes;

unsafe extern C fn u32 bc_adapter_slot_admits(ptr mut void slot,usize request_length,usize reply_limit);
unsafe extern C fn ptr mut void bc_adapter_slot_process(ptr mut void slot,ptr void owner,usize generation);
unsafe extern C fn usize bc_adapter_slot_start(ptr mut void slot,ptr void owner,ptr u8 path,
    usize path_length,ptr u8 header,ptr u8 body,usize body_length,usize reply_limit,usize deadline);
unsafe extern C fn u32 bc_adapter_process_step(ptr mut void process);
unsafe extern C fn ptr u8 bc_adapter_process_frame(ptr mut void process,ptr mut usize length);
unsafe extern C fn i32 bc_adapter_process_accept_body(ptr mut void process,usize length);
unsafe extern C fn void bc_adapter_process_cancel(ptr mut void process);

pub enum Progress { Pending; Submitted; Stopped; }
pub resource Route { adapter::Route signature; bytes::Buffer executable; cleanup { } }
// The host's slot owns the OS lease and must outlive this dispatch.
pub resource Session { adapter::Dispatch request; ptr mut void slot; usize generation; cleanup { } }

pub fn ref adapter::Route signature(ref Route route){return ref route.signature;}
pub fn ref u8[] executable(ref Route route){return bytes::view(ref route.executable);}
pub fn usize executable_capacity(ref Route route){return bytes::capacity(ref route.executable);}

pub fn Result<Route,adapter::Error> register(ref catalog::Catalog imports,usize import_id,
    ref u8[] revision,ref u8[] executable){
    let ref u8[] required=switch(catalog::adapter_revision(imports,import_id)){
        case .ok(v):{v}case .err(_):{return .err(adapter::unavailable());}
    };
    if(!bytes::equal(required,revision) || executable.len==0 || executable.len>4096){
        return .err(adapter::unavailable());
    }
    let adapter::Route signature=switch(adapter::register(imports,import_id)){
        case .ok(v):{v}case .err(_):{return .err(adapter::unavailable());}
    };
    let bytes::Buffer path=switch(bytes::copy(executable)){
        case .ok(v):{v}case .err(_):{return .err(adapter::Error{.status=6});}
    };
    return .ok(Route{.signature=signature,.executable=path});
}

// The trusted host keeps its Engine and native slot at stable addresses
// throughout this call and subsequent polls. A claimed request is one-shot.
pub fn Result<Session,adapter::Error> start(ref mut engine::Engine owner,usize instance,
    ref Route route,ptr mut void slot,usize request_limit){
    let engine::HostRequestInfo before=switch(engine::host_request_info(owner,instance)){
        case .ok(v):{v}case .err(e):{return .err(adapter::engine_failure(e));}
    };
    let usize cap=adapter::byte_limit();
    let usize reply_limit=if(before.reply_limit<cap){before.reply_limit}else{cap};
    if(unsafe{bc_adapter_slot_admits(slot,before.payload_bytes,reply_limit)}==0){
        return .err(adapter::unavailable());
    }
    let adapter::Dispatch request=adapter::claim_detached(owner,instance,ref route.signature,request_limit)?;
    let engine::HostRequestInfo info=adapter::dispatch_info(ref request);
    let u8[64] header=adapter::dispatch_header(ref request);
    let ref u8[] prefix=ref header[..];
    let ref u8[] body=adapter::dispatch_bytes(ref request);
    let ref u8[] path=bytes::view(ref route.executable);
    let usize generation=unsafe{bc_adapter_slot_start(slot,owner as ptr void,path as ptr u8,
        path.len,prefix as ptr u8,body as ptr u8,body.len,reply_limit,info.deadline)};
    if(generation==0){
        return switch(fatal(owner,ref info)){
            case .ok(_):{.err(adapter::unavailable())}case .err(e):{.err(e)}
        };
    }
    return .ok(Session{.request=request,.slot=slot,.generation=generation});
}

fn Result<Progress,adapter::Error> fatal(ref mut engine::Engine owner,ref engine::HostRequestInfo info){
    return switch(engine::reply_scalar_host(owner,info.run,info.run,info.request,2,b"")){
        case .ok(_):{.ok(.Submitted)}case .err(e):{.err(adapter::engine_failure(e))}
    };
}

fn bool live(ref engine::Engine owner,ref engine::HostRequestInfo info){
    return switch(engine::host_request_info(owner,info.run)){
        case .ok(v):{engine::same_host_request(info,ref v)}case .err(_):{false}
    };
}

pub fn Result<Progress,adapter::Error> poll(ref mut engine::Engine owner,ref Session session,
    usize reply_limit){
    let ptr mut void process=unsafe{bc_adapter_slot_process(session.slot,owner as ptr void,session.generation)};
    if(process==null){return .err(adapter::unavailable());}
    let engine::HostRequestInfo info=adapter::dispatch_info(ref session.request);
    if(!live(owner,ref info)){
        unsafe{bc_adapter_process_cancel(process)};
        return .ok(.Stopped);
    }
    let u32 state=unsafe{bc_adapter_process_step(process)};
    if(state==0){return .ok(.Pending);}
    if(state==3 || state==4){return .ok(.Stopped);}
    if(state!=1 && state!=2){return fatal(owner,ref info);}
    let usize limit=if(reply_limit<info.reply_limit){reply_limit}else{info.reply_limit};
    return frame(owner,session,process,state,limit);
}

fn Result<Progress,adapter::Error> frame(ref mut engine::Engine owner,ref Session session,
    ptr mut void process,u32 state,usize limit){
    let engine::HostRequestInfo info=adapter::dispatch_info(ref session.request);
    var usize length=0;
    let ptr u8 data=unsafe{bc_adapter_process_frame(process,ref mut length as ptr mut usize)};
    if(data==null || length>64+adapter::byte_limit()){return fatal(owner,ref info);}
    let ref u8[] wire=unsafe{byte_slice::from_raw_parts(session,data,length)};
    if(state==1){
        switch(adapter::frame_reply_size(ref session.request,wire,limit)){
            case .ok(n):{
                return .ok(if(unsafe{bc_adapter_process_accept_body(process,n)}!=0){.Pending}else{.Stopped});
            }
            case .err(_):{
                unsafe{bc_adapter_process_cancel(process)};
                return fatal(owner,ref info);
            }
        };
    }
    return switch(adapter::deliver_frame(owner,ref session.request,wire,limit)){
        case .ok(_):{.ok(.Submitted)}
        case .err(e):{if(e.status==1){fatal(owner,ref info)}else{.err(e)}}
    };
}
