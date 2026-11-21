module worker_project_broker;

import anchored_source_loader as anchored;
import cli_local_file as files;
import cli_project as cli;
import cli_run_configuration as configuration;
import errors as errors;
import fuel as meter;
import host_wire as le;
import project_manifest as manifest;
import project_source_loader as loader;
import json_tokens as json;
import render as render;
import runtime_policy as policy;
import runtime_policy_limits as limits;
import runtime_run_config as runs;
import source_snapshot as sources;
import worker_project_wire as wire;
import std::bytes as bytes;
import std::process as process;

unsafe extern C fn u32 bc_project_broker_invoke(ptr u8 request,usize request_length,u32 run,
    ptr u8 lengths,usize lengths_count,ptr u8 configuration,usize config_size,
    ptr mut u8 reply,ptr mut usize reply_length);

struct Selection { bool run; usize fuel; usize source_bytes; usize modules; }

fn u32 validate_result(ptr u8 data,usize length,u32 run,ptr u8 bounds,usize count){
    if(data==null || length==0 || length>wire::result_limit() || run>1 ||
       bounds==null || count==0 || count>32 || count%2!=0){return 0;}
    let ref u8[] payload=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    let ref u8[] lengths=unsafe{byte_slice::from_raw_parts(ref count,bounds,count)};
    return if(wire::parse_result(payload,run==1,lengths).is_ok){1}else{0};
}

@effects(console,filesystem)
pub fn i32 execute(bool configured){
    var u8[8] operation=[0;8];
    let usize size=switch(process::arg(2,ref mut operation)){
        case .ok(v):{v}case .err(_):{return failure(false,errors::absent(10,0));}
    };
    let ref u8[] op=ref operation[..size];
    let bool run=bytes::equal(op,b"run");
    if(!run && !bytes::equal(op,b"check")){return failure(false,errors::absent(10,0));}
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(10,0));}
    };
    if(configured){return configured_project(ref path[..length],run);}
    return acquire(ref path[..length],Selection{.run=run,.fuel=if(run){meter::cli_default()}else{0},
        .source_bytes=sources::source_limit(),.modules=sources::file_limit()},b"",b"",b"",b"",b"");
}

@effects(console,filesystem)
fn i32 configured_project(ref u8[] path,bool run){
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
    if(runs::requires_count(ref request)!=0 || runs::grants_count(ref request)!=0){
        return failure(run,errors::absent(11,0));
    }
    let limits::CompileLimits compile=policy::compile_limits(ref ceiling);
    let limits::RunLimits runtime=runs::run_limits(ref request);
    let usize fuel=if(runtime.fuel<meter::cli_limit()){runtime.fuel}else{meter::cli_limit()};
    let usize source=if(compile.source_bytes<sources::source_limit()){compile.source_bytes}else{sources::source_limit()};
    let usize count=if(compile.modules<sources::file_limit()){compile.modules}else{sources::file_limit()};
    let u8[28] worker=worker_configuration(policy::worker_limits(ref ceiling));
    return acquire(path,Selection{.run=run,.fuel=if(run){fuel}else{0},.source_bytes=source,.modules=count},
        runs::module_name(ref request),runs::function_name(ref request),ref worker,policy_bytes,run_bytes);
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

@effects(console)
fn i32 acquire(ref u8[] path,Selection selected,ref u8[] module_name,ref u8[] function_name,ref u8[] worker,
    ref u8[] policy_bytes,ref u8[] run_bytes){
    let bool run=selected.run;
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=switch(cli::open_manifest(path,ref mut data)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let ref u8[] raw=bytes::view(ref data);
    let manifest::Project project=switch(cli::parse_manifest(ref root,raw)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    if(manifest::requirements(ref project)!=0 || (worker.len!=0 &&
       (!bytes::equal(manifest::entry_module(ref project),module_name) ||
        !bytes::equal(manifest::entry_function(ref project),function_name)))){
        return failure(run,errors::absent(11,0));
    }
    if(manifest::count(ref project)>selected.modules){return failure(run,errors::absent(4,0));}
    let sources::Snapshot snapshot=switch(loader::load_from(ref project,ref mut root,selected.source_bytes)){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(cli::acquisition_kind(e),0));}
    };
    return invoke(raw[..anchored::manifest_bytes(ref root)],ref project,ref snapshot,selected,worker,policy_bytes,run_bytes);
}

@effects(console)
fn i32 invoke(ref u8[] manifest_bytes,ref manifest::Project project,ref sources::Snapshot snapshot,
    Selection selected,ref u8[] worker,ref u8[] policy_bytes,ref u8[] run_bytes){
    let bool run=selected.run;
    var u8[32] limits=[0;32];
    let usize limit_bytes=2*sources::count(snapshot);
    let bytes::Buffer request=switch(wire::pack(manifest_bytes,project,snapshot,run,
        selected.fuel,policy_bytes,run_bytes,ref mut limits[..limit_bytes])){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(switch(e){case .Shape:{11}case .Limit:{4}case .Allocation:{15}},0));}
    };
    let ref u8[] input=bytes::view(ref request);
    let ref u8[] bounds=ref limits[..limit_bytes];
    var u8[260] reply=[0;260];
    var usize length=0;
    let u32 status=unsafe{bc_project_broker_invoke(input as ptr u8,input.len,if(run){1}else{0},
        bounds as ptr u8,bounds.len,worker as ptr u8,worker.len,
        ref mut reply[..] as ptr mut u8,ref mut length as ptr mut usize)};
    if(status!=1 || length==0 || length>wire::result_limit()){
        let u8 kind=if(status==2){errors::deadline_kind()}else if(status==3){errors::cancelled_kind()}else{11};
        return failure(run,errors::absent(kind,0));
    }
    let wire::Outcome outcome=switch(wire::parse_result(ref reply[..length],run,bounds)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(11,0));}
    };
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
