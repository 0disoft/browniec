module worker_project_command;

import errors as errors;
import module_entry as entries;
import module_program as programs;
import project_manifest as manifest;
import project_sources as binding;
import runtime_engine as engine;
import runtime_policy as policies;
import runtime_run_config as runs;
import fuel as meter;
import source_error as diagnostics;
import source_snapshot as sources;
import static_image as images;
import worker_project_wire as wire;
import worker_scalar_result as scalar;
import std::bytes as bytes;

unsafe extern C fn usize bc_project_worker_begin();
unsafe extern C fn u32 bc_project_worker_read(ptr mut u8 buffer,usize length);
unsafe extern C fn u32 bc_scalar_worker_finish(ptr u8 result,usize length);

pub fn i32 execute(){
    let usize length=unsafe{bc_project_worker_begin()};
    if(length==0 || length>wire::request_limit()){return 4;}
    var bytes::Buffer request=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    if(!bytes::resize_zeroed(ref mut request,length).is_ok ||
       unsafe{bc_project_worker_read(bytes::view_mut(ref mut request) as ptr mut u8,length)}==0){return 4;}
    return respond(bytes::view(ref request));
}

fn i32 respond(ref u8[] request){
    let wire::Header header=switch(wire::header(request)){case .ok(v):{v}case .err(_):{return 4;}};
    let manifest::Project project=switch(manifest::parse(request[header.manifest_start..header.manifest_end])){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let sources::Snapshot snapshot=switch(wire::unpack(request[header.run_end..header.input_start],ref project)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let wire::Outcome outcome=if(header.policy_end==header.manifest_end){
        compute(ref project,snapshot,header)
    }else{
        configured(ref project,snapshot,header,request[header.manifest_end..header.policy_end],
            request[header.policy_end..header.run_end],request[header.input_start..request.len])
    };
    let bytes::Buffer payload=switch(wire::encode_result(outcome,header.run)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let ref u8[] data=bytes::view(ref payload);
    return if(unsafe{bc_scalar_worker_finish(data as ptr u8,data.len)}!=0){0}else{4};
}

fn wire::Outcome configured(ref manifest::Project project,sources::Snapshot snapshot,wire::Header header,
    ref u8[] policy,ref u8[] request,ref u8[] input){
    let policies::Policy ceiling=switch(policies::parse(policy)){
        case .ok(v):{v}case .err(_):{return denied();}
    };
    let runs::RunConfig run=switch(runs::parse(request,ref ceiling)){
        case .ok(v):{v}case .err(_):{return denied();}
    };
    if(!bytes::equal(manifest::entry_module(project),runs::module_name(ref run)) ||
       !bytes::equal(manifest::entry_function(project),runs::function_name(ref run)) ||
       runs::requires_count(ref run)!=0 || runs::grants_count(ref run)!=0){return denied();}
    let usize fuel=runs::run_limits(ref run).fuel;
    if(header.run && header.fuel!=(if(fuel<meter::cli_limit()){fuel}else{meter::cli_limit()})){return denied();}
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return engine_failure(e,true);}
    };
    return execute_configured(ref mut owner,project,snapshot,header,ref run,input);
}

fn wire::Outcome execute_configured(ref mut engine::Engine owner,ref manifest::Project project,
    sources::Snapshot snapshot,wire::Header header,ref runs::RunConfig run,ref u8[] input){
    let usize program=switch(engine::compile_project_snapshot_output(owner,project,snapshot,
        images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return engine_failure(e,true);}
    };
    let engine::PreviewEntry profile=switch(engine::preview_entry(owner,program)){
        case .ok(v):{v}case .err(e):{return engine_failure(e,true);}
    };
    if(profile.emits){return denied();}
    let wire::Outcome outcome=if(header.run){run_instance(owner,program,run,header,input)}
        else{success(scalar::checked(),8)};
    if(!engine::release_program(owner,program).is_ok || !engine::destroy(owner).is_ok){return denied();}
    return outcome;
}

fn wire::Outcome run_instance(ref mut engine::Engine owner,usize program,ref runs::RunConfig run,
    wire::Header header,ref u8[] input){
    let usize instance=switch(engine::prepare_project_snapshot_instance(owner,program,run,header.fuel,header.has_input,input)){
        case .ok(v):{v}case .err(e):{return engine_failure(e,false);}
    };
    let wire::Outcome outcome=step_instance(owner,instance);
    if(!engine::destroy_instance(owner,instance).is_ok){return denied();}
    return outcome;
}

fn wire::Outcome step_instance(ref mut engine::Engine owner,usize instance){
    while(true){
        let engine::Event event=switch(engine::step_instance(owner,instance,4096)){
            case .ok(v):{v}case .err(e):{return engine_failure(e,false);}
        };
        if(event.kind==4){continue;}
        if(event.kind==1){return success(scalar::completed(event.value),8);}
        if(event.diagnostic.code.kind!=0){return failed(event.diagnostic,8);}
        return denied();
    }
    return denied();
}

fn wire::Outcome denied(){return success(scalar::failed(errors::absent(11,0)),0);}
fn wire::Outcome engine_failure(engine::Error error,bool compiling){
    if(error.diagnostic.code.kind!=0){return failed(error.diagnostic,8);}
    let u8 kind=if(error.status==5){11}else if(error.status==6){15}else if(error.status==8){
        if(compiling){4}else{errors::memory_limit_kind()}
    }else{5};
    return success(scalar::failed(errors::absent(kind,0)),8);
}

fn wire::Outcome compute(ref manifest::Project project,sources::Snapshot snapshot,wire::Header header){
    let entries::Entry entry=switch(binding::select(project,snapshot)){
        case .ok(v):{v}
        case .err(e):{return failed(diagnostics::Error{.code=diagnostics::binding(e),.at=e.at},0);}
    };
    let programs::Program program=switch(programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return failed(e,0);}
    };
    let u8 profile=programs::profile(ref program);
    if(!header.run){return success(scalar::checked(),profile);}
    return switch(programs::run(ref program,header.fuel)){
        case .ok(v):{success(scalar::completed(v),profile)}case .err(e):{failed(e,profile)}
    };
}

fn wire::Outcome success(scalar::Outcome value,u8 profile){
    return wire::Outcome{.value=value,.profile=profile,.span=sources::no_source()};
}

fn wire::Outcome failed(diagnostics::Error error,u8 profile){
    if(error.code.location==errors::instruction_location()){return success(scalar::failed(error.code),profile);}
    if(error.at.source==sources::no_source().source){
        return success(scalar::failed(errors::absent(error.code.kind,0)),profile);
    }
    return wire::Outcome{.value=scalar::failed(errors::make(error.code.kind,error.at.start)),
        .profile=profile,.span=error.at};
}
