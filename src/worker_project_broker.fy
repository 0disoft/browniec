module worker_project_broker;

import anchored_source_loader as anchored;
import cli_local_file as files;
import cli_host_process as child;
import host_process_adapter as procs;
import cli_project as cli;
import cli_run_configuration as configuration;
import errors as errors;
import fuel as meter;
import host_wire as le;
import host_catalog as catalog;
import cli_host_replies as replies;
import host_memory_adapter as adapters;
import runtime_engine as engine;
import project_manifest as manifest;
import project_source_loader as loader;
import json_tokens as json;
import render as render;
import runtime_input as input;
import runtime_policy as policy;
import runtime_policy_limits as limits;
import runtime_run_config as runs;
import source_snapshot as sources;
import worker_project_wire as wire;
import std::bytes as bytes;
import std::process as process;

unsafe extern C fn u32 bc_project_broker_invoke(ptr u8 request,usize request_length,u32 run,
    ptr u8 lengths,usize lengths_count,ptr u8 configuration,usize config_size,
    u32 output,usize output_limit,ptr u8 host_limits,ptr void context,ptr u8 path,usize path_length,
    ptr mut u8 reply,usize capacity,ptr mut usize reply_length);

resource Replay {
    catalog::Catalog imports; runs::RunConfig run; replies::Replies responses;
    cleanup { }
}

fn usize respond_host(ref Replay replay,ptr u8 request,usize length,ptr mut u8 reply,usize size){
    var usize capacity=size;
    if(request==null || reply==null || length<4 || length-4>adapters::byte_limit() ||
        capacity==0 || capacity-1>adapters::byte_limit()){return 0;}
    let ref u8[] raw=unsafe{byte_slice::from_raw_parts(ref length,request,length)};
    let usize import_id=le::read_u32(raw[..4]);
    let ref u8[] capability=switch(catalog::capability(ref replay.imports,import_id)){
        case .ok(v):{v}case .err(_):{return 0;}
    };
    if(!runs::declares(ref replay.run,capability) || !runs::grants(ref replay.run,capability)){return 0;}
    let ref mut u8[] response=unsafe{byte_slice::from_raw_parts_mut(ref mut capacity,reply,size)};
    return replies::copy_reply(ref replay.responses,import_id,raw[4..],response);
}

fn bool authorized_import(ref catalog::Catalog imports,ref runs::RunConfig run,usize id){
    return switch(catalog::capability(imports,id)){
        case .ok(name):{runs::declares(run,name) && runs::grants(run,name)}case .err(_):{false}
    };
}
fn u32 process_header(ref procs::Route route,usize run,usize request,ptr u8 data,usize length,ptr mut u8 out){
    if(data==null || out==null || length<4 || length-4>adapters::byte_limit()){return 0;}
    let ref u8[] raw=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    let usize id=le::read_u32(raw[..4]);
    let ref adapters::Route selected=procs::signature(route);
    if(adapters::route_id(selected)!=id){return 0;}
    let u8[64] header=switch(adapters::broker_header(selected,run,request,raw[4..])){
        case .ok(v):{v}case .err(_):{return 0;}
    };
    var usize capacity=64;
    let ref mut u8[] result=unsafe{byte_slice::from_raw_parts_mut(ref mut capacity,out,64)};
    var usize i=0;
    while(i<64){result[i]=header[i];i+=1;}
    return 1;
}

fn usize process_reply_size(ref procs::Route route,usize run,usize request,ptr u8 data,usize length,usize limit){
    if(data==null || length!=64){return 0;}
    let ref u8[] raw=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    return switch(adapters::broker_reply_size(procs::signature(route),run,request,raw,limit)){
        case .ok(n):{n+1}case .err(_):{0}
    };
}

fn usize process_reply(ref procs::Route route,usize run,usize request,ptr u8 data,usize length,
    ptr mut u8 out,usize size){
    if(out==null){return process_reply_size(route,run,request,data,length,size);}
    if(data==null || length<64 || length-64>adapters::byte_limit() ||
        size==0 || length-64>=size){return 0;}
    let ref u8[] raw=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    let u8 kind=switch(adapters::broker_reply_kind(procs::signature(route),run,request,raw,size-1)){
        case .ok(v):{v}case .err(_):{return 0;}
    };
    var usize capacity=size;
    let ref mut u8[] result=unsafe{byte_slice::from_raw_parts_mut(ref mut capacity,out,size)};
    result[0]=kind;
    var usize i=64;
    while(i<length){result[i-63]=raw[i];i+=1;}
    return length-63;
}

struct Selection { bool run; usize fuel; usize source_bytes; usize modules; bool input_file; usize input_limit; bool output; usize output_limit; }

fn u32 validate_result(ptr u8 data,usize length,u32 run,ptr u8 bounds,usize count,u32 output,usize output_limit){
    if(data==null || length==0 || length>wire::reply_capacity(output==1,output_limit) || run>1 || output>1 ||
       bounds==null || count==0 || count>32 || count%2!=0){return 0;}
    let ref u8[] payload=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    let ref u8[] lengths=unsafe{byte_slice::from_raw_parts(ref count,bounds,count)};
    return if(wire::parse_frame(payload,run==1,lengths,output==1,output_limit).is_ok){1}else{0};
}

@effects(console,filesystem)
pub fn i32 execute(bool configured,bool input_file,bool host,bool external){
    var u8[8] operation=[0;8];
    let usize size=switch(process::arg(2,ref mut operation)){
        case .ok(v):{v}case .err(_):{return failure(false,errors::absent(10,0));}
    };
    let ref u8[] op=ref operation[..size];
    let bool run=bytes::equal(op,b"run");
    if(!run && (input_file || !bytes::equal(op,b"check"))){return failure(false,errors::absent(10,0));}
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(10,0));}
    };
    let usize host_args=if(external){if(input_file){11}else{10}}
        else if(run){if(input_file){9}else{8}}else{7};
    if((external && !run) || (host && process::arg_count()!=host_args)){
        return failure(run,errors::absent(10,0));
    }
    if(configured){return configured_project(ref path[..length],run,input_file,host,external);}
    return acquire(ref path[..length],Selection{.run=run,.fuel=if(run){meter::cli_default()}else{0},
        .source_bytes=sources::source_limit(),.modules=sources::file_limit(),.input_file=false,.input_limit=0,.output=false,.output_limit=0},b"",b"",b"",b"",b"",b"",.none,null,b"");
}

@effects(console,filesystem)
fn i32 configured_project(ref u8[] path,bool run,bool input_file,bool host,bool external){
    let files::File policy_file=switch(files::open(4,json::byte_limit(),10)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let ref u8[] policy_bytes=files::view(ref policy_file);
    let policy::Policy ceiling=switch(configuration::parse_policy(policy_bytes)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let files::File run_file=switch(files::open(5,json::byte_limit(),10)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let ref u8[] run_bytes=files::view(ref run_file);
    let runs::RunConfig request=switch(configuration::parse_run(run_bytes,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let bool output=if(host){runs::declares(ref request,b"brownie.output.emit") && runs::grants(ref request,b"brownie.output.emit")}
        else{wire::output_granted(ref request)};
    if(!host && !output && (runs::requires_count(ref request)!=0 || runs::grants_count(ref request)!=0)){
        return failure(run,errors::absent(11,0));
    }
    let limits::CompileLimits compile=policy::compile_limits(ref ceiling);
    let limits::RunLimits runtime=runs::run_limits(ref request);
    let usize fuel=if(runtime.fuel<meter::cli_limit()){runtime.fuel}else{meter::cli_limit()};
    let usize source=if(compile.source_bytes<sources::source_limit()){compile.source_bytes}else{sources::source_limit()};
    let usize count=if(compile.modules<sources::file_limit()){compile.modules}else{sources::file_limit()};
    let u8[28] worker=worker_configuration(policy::worker_limits(ref ceiling));
    let usize input_limit=if(runtime.input_bytes<runtime.memory_bytes){runtime.input_bytes}else{runtime.memory_bytes};
    let Selection selected=Selection{.run=run,.fuel=if(run){fuel}else{0},.source_bytes=source,.modules=count,
        .input_file=input_file,.input_limit=input_limit,.output=output,.output_limit=if(run && output){runtime.output_bytes}else{0}};
    if(host){
        if(run && runtime.fuel!=fuel){return failure(run,errors::absent(11,0));}
        return catalog_project(path,selected,ref worker,policy_bytes,run_bytes,request,external);
    }
    return acquire(path,selected,runs::module_name(ref request),runs::function_name(ref request),
        ref worker,policy_bytes,run_bytes,b"",.none,null,b"");
}

@effects(console,filesystem)
fn i32 catalog_project(ref u8[] path,Selection selected,ref u8[] worker,ref u8[] policy_bytes,
    ref u8[] run_bytes,runs::RunConfig run,bool external){
    let files::File file=switch(files::open(6,catalog::byte_limit(),10)){
        case .ok(v):{v}case .err(e):{return failure(selected.run,e);}
    };
    let ref u8[] raw=files::view(ref file);
    let catalog::Catalog imports=switch(catalog::parse(raw)){
        case .ok(v):{v}case .err(e):{return failure(selected.run,configuration::catalog_failure(e));}
    };
    if(!selected.run){
        return acquire(path,selected,runs::module_name(ref run),runs::function_name(ref run),
            worker,policy_bytes,run_bytes,raw,.none,null,b"");
    }
    if(external){
        let procs::Route adapter=switch(child::read(7,ref imports)){
            case .ok(v):{v}case .err(e):{return failure(true,e);}
        };
        if(!authorized_import(ref imports,ref run,adapters::route_id(procs::signature(ref adapter)))){
            return failure(true,errors::absent(11,0));
        }
        return acquire(path,selected,runs::module_name(ref run),runs::function_name(ref run),worker,
            policy_bytes,run_bytes,raw,.some(ref run),unsafe{ref adapter as ptr void},procs::executable(ref adapter));
    }
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(e):{return failure(true,configuration::catalog_failure(e));}
    };
    let replies::Replies responses=switch(replies::read(7,ref imports,digest)){
        case .ok(v):{v}case .err(e):{return failure(true,e);}
    };
    let Replay replay=Replay{.imports=imports,.run=run,.responses=responses};
    return acquire(path,selected,runs::module_name(ref replay.run),runs::function_name(ref replay.run),
        worker,policy_bytes,run_bytes,raw,.some(ref replay.run),unsafe{ref replay as ptr void},b"");
}

fn u8[28] worker_configuration(limits::WorkerLimits worker){
    var u8[28] packed=[0;28];
    le::write_le(worker.memory_bytes,ref mut packed[0..4]);
    le::write_le(worker.user_cpu_time_ms,ref mut packed[4..8]);
    le::write_le(worker.startup_ms,ref mut packed[8..12]);
    le::write_le(worker.io_idle_ms,ref mut packed[12..16]);
    le::write_le(worker.shutdown_grace_ms,ref mut packed[16..20]);
    le::write_le(worker.session_ms,ref mut packed[20..24]);
    le::write_le(worker.transport_bytes,ref mut packed[24..28]);
    return packed;
}

@effects(console,filesystem)
fn i32 acquire(ref u8[] path,Selection selected,ref u8[] module_name,ref u8[] function_name,ref u8[] worker,
    ref u8[] policy_bytes,ref u8[] run_bytes,ref u8[] imports,Option<ref runs::RunConfig> host,ptr void context,ref u8[] executable){
    let bool run=selected.run;
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=switch(cli::open_manifest(path,ref mut data)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let ref u8[] raw=bytes::view(ref data);
    let manifest::Project project=switch(cli::parse_manifest(ref root,raw)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let bool authorized=switch(host){
        case .some(route):{engine::project_host_authority(ref project,route)}
        case .none:{imports.len!=0 || wire::project_authorized(ref project,selected.output)}
    };
    if(!authorized || (worker.len!=0 &&
       (!bytes::equal(manifest::entry_module(ref project),module_name) ||
        !bytes::equal(manifest::entry_function(ref project),function_name)))){
        return failure(run,errors::absent(11,0));
    }
    if(manifest::count(ref project)>selected.modules){return failure(run,errors::absent(4,0));}
    let sources::Snapshot snapshot=switch(loader::load_from(ref project,ref mut root,selected.source_bytes)){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(cli::acquisition_kind(e),0));}
    };
    let ref u8[] project_bytes=raw[..anchored::manifest_bytes(ref root)];
    if(!selected.input_file){
        return invoke(project_bytes,ref project,ref snapshot,selected,worker,policy_bytes,run_bytes,imports,host,context,executable,b"");
    }
    let usize limit=if(selected.input_limit<input::hard_limit()){selected.input_limit}else{input::hard_limit()};
    let files::File file=switch(files::open(if(imports.len==0){6}else if(executable.len==0){8}else{10},limit,render::input_limit_kind())){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    return invoke(project_bytes,ref project,ref snapshot,selected,worker,policy_bytes,run_bytes,imports,host,context,executable,files::view(ref file));
}

@effects(console)
fn i32 invoke(ref u8[] manifest_bytes,ref manifest::Project project,ref sources::Snapshot snapshot,
    Selection selected,ref u8[] worker,ref u8[] policy_bytes,ref u8[] run_bytes,
    ref u8[] imports,Option<ref runs::RunConfig> host_run,ptr void context,ref u8[] executable,ref u8[] payload){
    let bool run=selected.run;
    var u8[32] limits=[0;32];
    let usize limit_bytes=2*sources::count(snapshot);
    let bytes::Buffer request=switch(wire::pack(manifest_bytes,project,snapshot,run,
        selected.fuel,policy_bytes,run_bytes,imports,selected.input_file,payload,ref mut limits[..limit_bytes])){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(switch(e){case .Shape:{11}case .Limit:{4}case .Allocation:{15}},0));}
    };
    let ref u8[] input=bytes::view(ref request);
    let ref u8[] bounds=ref limits[..limit_bytes];
    let bool output=run && selected.output;
    let usize capacity=wire::reply_capacity(output,selected.output_limit);
    var bytes::Buffer reply=switch(bytes::with_capacity(capacity)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(15,0));}
    };
    if(!bytes::resize_zeroed(ref mut reply,capacity).is_ok){return failure(run,errors::absent(15,0));}
    var usize length=0;
    var u8[12] host=[0;12];
    switch(host_run){
        case .some(route):{
            let limits::RunLimits limits=runs::run_limits(route);
            let usize cap=adapters::byte_limit();
            le::write_le(limits.host_calls,ref mut host[..4]);
            le::write_le(4+if(limits.host_request_bytes<cap){limits.host_request_bytes}else{cap},ref mut host[4..8]);
            le::write_le(1+if(limits.host_response_bytes<cap){limits.host_response_bytes}else{cap},ref mut host[8..]);
        }
        case .none:{}
    };
    let u32 status=unsafe{bc_project_broker_invoke(input as ptr u8,input.len,if(run){1}else{0},
        bounds as ptr u8,bounds.len,worker as ptr u8,worker.len,
        if(output){1}else{0},selected.output_limit,ref host[..] as ptr u8,context,executable as ptr u8,executable.len,bytes::view_mut(ref mut reply) as ptr mut u8,capacity,ref mut length as ptr mut usize)};
    if(status!=1 || length==0 || length>capacity){
        let u8 kind=if(status==2){errors::deadline_kind()}else if(status==3){errors::cancelled_kind()}else{11};
        return failure(run,errors::absent(kind,0));
    }
    let ref u8[] result=bytes::view(ref reply)[..length];
    let wire::ResultFrame frame=switch(wire::parse_frame(result,run,bounds,output,selected.output_limit)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(11,0));}
    };
    let wire::Outcome outcome=frame.outcome;
    if(frame.has_output){
        return render::published_output_profile(.JsonV2,outcome.value.value,result[frame.output_start..],outcome.profile);
    }
    return switch(outcome.value.status){
        case .Checked:{render::selected_outcome(.JsonV2,false,false,0,errors::absent(0,0),outcome.profile)}
        case .Completed:{render::selected_outcome(.JsonV2,true,false,outcome.value.value,errors::absent(0,0),outcome.profile)}
        case .Failed:{render::project_failure(.JsonV2,run,outcome.value.error,snapshot,outcome.span,outcome.profile)}
    };
}

@effects(console)
fn i32 failure(bool run,errors::Error error){
    return render::selected_outcome(.JsonV2,run,true,0,error,0);
}
