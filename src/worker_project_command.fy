module worker_project_command;

import errors as errors;
import module_program as programs;
import project_manifest as manifest;
import project_sources as binding;
import runtime_engine as engine;
import runtime_policy as policies;
import runtime_run_config as runs;
import fuel as meter;
import host_catalog as catalog;
import host_memory_adapter as adapters;
import host_wire as le;
import source_error as diagnostics;
import source_snapshot as sources;
import static_image as images;
import worker_project_wire as wire;
import worker_scalar_result as scalar;
import std::bytes as bytes;

unsafe extern C fn usize bc_project_worker_begin();
unsafe extern C fn u32 bc_project_worker_read(ptr mut u8 buffer,usize length);
unsafe extern C fn void bc_project_worker_compile_begin();
unsafe extern C fn void bc_project_worker_compile_end();
unsafe extern C fn u32 bc_project_worker_host(ptr u8 request,usize request_length,
    ptr mut u8 reply,usize capacity,ptr mut usize reply_length);
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
    let sources::Snapshot snapshot=switch(wire::unpack(request[header.catalog_end..header.input_start],ref project)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let Result<bytes::Buffer,wire::Error> encoded=if(header.policy_end==header.manifest_end){
        if(!wire::project_authorized(ref project,false)){return 4;}
        wire::encode_result(compute(ref project,snapshot,header),header.run,false)
    }else{
        configured(ref project,snapshot,header,request[header.manifest_end..header.policy_end],
            request[header.policy_end..header.run_end],request[header.run_end..header.catalog_end],
            request[header.input_start..request.len])
    };
    let bytes::Buffer payload=switch(encoded){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let ref u8[] data=bytes::view(ref payload);
    return if(unsafe{bc_scalar_worker_finish(data as ptr u8,data.len)}!=0){0}else{4};
}

fn Result<bytes::Buffer,wire::Error> configured(ref manifest::Project project,sources::Snapshot snapshot,wire::Header header,
    ref u8[] policy,ref u8[] request,ref u8[] imports,ref u8[] input){
    let policies::Policy ceiling=switch(policies::parse(policy)){
        case .ok(v):{v}case .err(_):{return wire::encode_result(denied(),header.run,false);}
    };
    let runs::RunConfig run=switch(runs::parse(request,ref ceiling)){
        case .ok(v):{v}case .err(_):{return wire::encode_result(denied(),header.run,false);}
    };
    let bool host=imports.len!=0;
    let bool output=if(host){runs::declares(ref run,b"brownie.output.emit") && runs::grants(ref run,b"brownie.output.emit")}
        else{wire::output_granted(ref run)};
    if(!host && (!wire::project_authorized(project,output) || !bytes::equal(manifest::entry_module(project),runs::module_name(ref run)) ||
       !bytes::equal(manifest::entry_function(project),runs::function_name(ref run)) ||
       (!output && (runs::requires_count(ref run)!=0 || runs::grants_count(ref run)!=0)))){
        return wire::encode_result(denied(),header.run,false);
    }
    let usize fuel=runs::run_limits(ref run).fuel;
    if(header.run && ((host && fuel>meter::cli_limit()) || header.fuel!=(if(fuel<meter::cli_limit()){fuel}else{meter::cli_limit()}))){
        return wire::encode_result(denied(),header.run,false);
    }
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return wire::encode_result(engine_failure(e,true),header.run,output);}
    };
    if(host){return execute_host(ref mut owner,project,snapshot,header,ref run,imports,input,output);}
    return execute_configured(ref mut owner,project,snapshot,header,ref run,input,output);
}

fn Result<bytes::Buffer,wire::Error> execute_host(ref mut engine::Engine owner,ref manifest::Project project,
    sources::Snapshot snapshot,wire::Header header,ref runs::RunConfig run,ref u8[] imports,ref u8[] input,bool output){
    let catalog::Catalog selected=switch(catalog::parse(imports)){
        case .ok(v):{v}case .err(_):{return wire::encode_result(denied(),header.run,output);}
    };
    let u32[8] digest=switch(catalog::digest(ref selected)){
        case .ok(v):{v}case .err(_):{return wire::encode_result(denied(),header.run,output);}
    };
    unsafe{bc_project_worker_compile_begin();}
    let Result<usize,engine::Error> compiled=engine::compile_project_snapshot_host(owner,project,snapshot,selected,ref digest,run);
    unsafe{bc_project_worker_compile_end();}
    let usize program=switch(compiled){
        case .ok(v):{v}case .err(e):{return wire::encode_result(engine_failure(e,true),header.run,output);}
    };
    let Result<bytes::Buffer,wire::Error> encoded=switch(engine::preview_host_entry(owner,program)){
        case .ok(profile):{
            if(profile.emits!=output){wire::encode_result(denied(),header.run,output)}
            else if(header.run){
                let Result<usize,engine::Error> prepared=engine::prepare_project_snapshot_host(owner,program,run,header.has_input,input);
                finish_instance(owner,prepared,output,true)
            }else{wire::encode_result(success(scalar::checked(),8),false,output)}
        }
        case .err(e):{wire::encode_result(engine_failure(e,true),header.run,output)}
    };
    let bytes::Buffer result=encoded?;
    if(!engine::release_program(owner,program).is_ok || !engine::destroy(owner).is_ok){
        return wire::encode_result(denied(),header.run,output);
    }
    return .ok(result);
}

fn Result<bytes::Buffer,wire::Error> execute_configured(ref mut engine::Engine owner,ref manifest::Project project,
    sources::Snapshot snapshot,wire::Header header,ref runs::RunConfig run,ref u8[] input,bool output){
    unsafe{bc_project_worker_compile_begin();}
    let Result<usize,engine::Error> compiled=engine::compile_project_snapshot_output(owner,project,snapshot,run,
        images::metadata_charge()+images::byte_limit());
    unsafe{bc_project_worker_compile_end();}
    let usize program=switch(compiled){
        case .ok(v):{v}case .err(e):{return wire::encode_result(engine_failure(e,true),header.run,output);}
    };
    let engine::PreviewEntry profile=switch(engine::preview_entry(owner,program)){
        case .ok(v):{v}case .err(e):{return wire::encode_result(engine_failure(e,true),header.run,output);}
    };
    let Result<bytes::Buffer,wire::Error> encoded=if(profile.emits!=output){
        wire::encode_result(denied(),header.run,false)
    }else if(header.run){run_instance(owner,program,run,header,input,output)}
    else{wire::encode_result(success(scalar::checked(),8),false,output)};
    let bytes::Buffer result=encoded?;
    if(!engine::release_program(owner,program).is_ok || !engine::destroy(owner).is_ok){
        return wire::encode_result(denied(),header.run,false);
    }
    return .ok(result);
}

fn Result<bytes::Buffer,wire::Error> run_instance(ref mut engine::Engine owner,usize program,ref runs::RunConfig run,
    wire::Header header,ref u8[] input,bool output){
    let Result<usize,engine::Error> prepared=engine::prepare_project_snapshot_instance(owner,program,run,header.fuel,header.has_input,input);
    return finish_instance(owner,prepared,output,false);
}

fn Result<bytes::Buffer,wire::Error> finish_instance(ref mut engine::Engine owner,
    Result<usize,engine::Error> prepared,bool output,bool host){
    let usize instance=switch(prepared){
        case .ok(v):{v}case .err(e):{return wire::encode_result(engine_failure(e,false),true,output);}
    };
    let wire::Outcome outcome=step_instance(owner,instance,host);
    let Result<bytes::Buffer,wire::Error> encoded=if(output && scalar::is_completed(outcome.value)){
        switch(engine::preview_output(owner,instance)){
            case .ok(payload):{wire::encode_output(outcome,payload)}
            case .err(e):{wire::encode_result(engine_failure(e,false),true,output)}
        }
    }else{wire::encode_result(outcome,true,output)};
    let bytes::Buffer result=encoded?;
    if(!engine::destroy_instance(owner,instance).is_ok){return wire::encode_result(denied(),true,false);}
    return .ok(result);
}

fn wire::Outcome step_instance(ref mut engine::Engine owner,usize instance,bool host){
    while(true){
        let engine::Event event=switch(engine::step_instance(owner,instance,4096)){
            case .ok(v):{v}case .err(e):{return engine_failure(e,false);}
        };
        if(event.kind==0 || (!host && event.kind==4)){continue;}
        if(host && event.kind==4){
            let Result<engine::Event,engine::Error> resumed=exchange(owner,instance);
            switch(resumed){
                case .ok(reply):{if(reply.kind==0){continue;}return terminal(reply);}
                case .err(e):{return engine_failure(e,false);}
            };
        }
        return terminal(event);
    }
    return denied();
}

fn wire::Outcome terminal(engine::Event event){
        if(event.kind==3){return success(scalar::failed(errors::absent(errors::cancelled_kind(),0)),8);}
        if(event.kind==1){return success(scalar::completed(event.value),8);}
        if(event.diagnostic.code.kind!=0){return failed(event.diagnostic,8);}
        return denied();
}

fn Result<engine::Event,engine::Error> exchange(ref mut engine::Engine owner,usize instance){
    let engine::HostRequestInfo info=engine::host_request_info(owner,instance)?;
    let usize max=adapters::byte_limit();
    if(info.payload_bytes>max){return .err(transport_error());}
    let usize request_size=4+info.payload_bytes;
    let usize cap=1+if(info.reply_limit<max){info.reply_limit}else{max};
    var bytes::Buffer request=bytes::empty();
    var bytes::Buffer response=bytes::empty();
    if(!bytes::resize_zeroed(ref mut request,request_size).is_ok || !bytes::resize_zeroed(ref mut response,cap).is_ok){
        return .err(engine::Error{.status=6,.diagnostic=diagnostics::absent(errors::absent(0,0))});
    }
    {
        let ref mut u8[] packed=bytes::view_mut(ref mut request);
        le::write_le(info.import_id,packed[..4]);
        let ref u8[] payload=engine::host_request_payload(owner,instance)?;
        var usize i=0;
        while(i<payload.len){packed[4+i]=payload[i];i+=1;}
    }
    discard engine::claim_host_request(owner,instance,ref info)?;
    let ref u8[] packed=bytes::view(ref request);
    var usize length=0;
    let u32 status=unsafe{bc_project_worker_host(packed as ptr u8,packed.len,
        bytes::view_mut(ref mut response) as ptr mut u8,cap,ref mut length as ptr mut usize)};
    if(status==2){return engine::cancel_ready(owner,instance);}
    if(status!=1 || length==0 || length>cap){return .err(transport_error());}
    let ref u8[] reply=bytes::view(ref response);
    return engine::receive_host_reply(owner,instance,info.run,info.request,reply[0],length-1,0,reply[1..length]);
}

fn engine::Error transport_error(){
    return engine::Error{.status=5,.diagnostic=diagnostics::absent(errors::absent(errors::host_failure_kind(),0))};
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
    unsafe{bc_project_worker_compile_begin();}
    let Result<programs::Program,diagnostics::Error> compiled=switch(binding::select(project,snapshot)){
        case .ok(entry):{programs::compile(entry,images::metadata_charge()+images::byte_limit())}
        case .err(e):{.err(diagnostics::Error{.code=diagnostics::binding(e),.at=e.at})}
    };
    unsafe{bc_project_worker_compile_end();}
    let programs::Program program=switch(compiled){
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
