module cli_configured_project;

import anchored_source_loader as anchored;
import cli_project_input as binary;
import cli_local_file as files;
import cli_run_configuration as configuration;
import errors as errors;
import project_manifest as manifest;
import render as render;
import runtime_engine as engine;
import runtime_input as input;
import runtime_policy as policies;
import runtime_policy_limits as limits;
import runtime_run_config as runs;
import source_error as diagnostics;
import source_snapshot as sources;
import static_image as images;
import std::text as text;

pub struct Selection { usize policy_file; usize run_file; usize output_file; bool output_text; }
unsafe extern C fn u32 bc_cli_enable_cancel();
unsafe extern C fn u32 bc_cli_cancel_requested();

@effects(console,filesystem)
pub fn i32 execute(render::Format format,bool execute_guest,Selection selected,binary::Selection selection,
    ref manifest::Project project,ref mut anchored::Root root){
    let policies::Policy ceiling=switch(configuration::read_policy(selected.policy_file)){
        case .ok(v):{v}case .err(e):{return failure(format,execute_guest,e,0);}
    };
    let runs::RunConfig run=switch(configuration::read_run(selected.run_file,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,execute_guest,e,0);}
    };
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,execute_guest,engine_error(e,false,0),0);}
    };
    let usize program=switch(engine::compile_anchored_project_output(
        ref mut owner,project,root,ref run,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}
        case .err(e):{return project_failure(format,execute_guest,project,root,engine_error(e,true,0),e.diagnostic.at,0);}
    };
    if(!execute_guest){
        if(!engine::release_program(ref mut owner,program).is_ok || !engine::destroy(ref mut owner).is_ok){
            return failure(format,false,errors::absent(5,0),8);
        }
        return render::selected_outcome(format,false,false,0,errors::absent(0,0),8);
    }
    if(selected.output_file!=0 && !runs::grants(ref run,b"brownie.output.emit")){
        return failure(format,true,errors::absent(19,0),8);
    }
    let limits::RunLimits bounds=runs::run_limits(ref run);
    let usize limit=if(bounds.input_bytes<bounds.memory_bytes){bounds.input_bytes}else{bounds.memory_bytes};
    if(unsafe{bc_cli_enable_cancel()}==0){return failure(format,true,errors::absent(5,0),8);}
    let input::Snapshot payload=switch(binary::read_with_limit(selection,limit,bounds.deadline_ms)){
        case .ok(v):{v}case .err(e):{return failure(format,true,e,8);}
    };
    let usize instance=switch(engine::prepare_granted_instance(ref mut owner,program,ref run,payload)){
        case .ok(v):{v}
        case .err(e):{return project_failure(format,true,project,root,engine_error(e,false,8),e.diagnostic.at,8);}
    };
    return complete(format,ref mut owner,program,instance,selected,project,root);
}

@effects(console,filesystem)
fn i32 complete(render::Format format,ref mut engine::Engine owner,usize program,usize instance,Selection selected,
    ref manifest::Project project,ref anchored::Root root){
    var i64 value=0;
    while(true){
        let Result<engine::Event,engine::Error> action=if(unsafe{bc_cli_cancel_requested()}!=0){
            engine::cancel_ready(owner,instance)
        }else{
            engine::step_instance(owner,instance,4096)
        };
        let engine::Event event=switch(action){
            case .ok(v):{v}
            case .err(e):{return project_failure(format,true,project,root,engine_error(e,false,8),e.diagnostic.at,8);}
        };
        if(event.kind==4){continue;}
        if(event.kind==3){
            if(!dispose(owner,program,instance)){return failure(format,true,errors::absent(5,0),8);}
            return failure(format,true,errors::absent(errors::cancelled_kind(),0),8);
        }
        if(event.kind!=1){
            let diagnostics::Error diagnostic=event.diagnostic;
            let errors::Error problem=if(diagnostic.code.kind==0){errors::absent(5,0)}else{diagnostic.code};
            return project_failure(format,true,project,root,problem,diagnostic.at,8);
        }
        value=event.value;
        break;
    }
    let engine::Output output=switch(engine::take_output(owner,instance)){
        case .ok(v):{v}case .err(e):{return failure(format,true,engine_error(e,false,8),8);}
    };
    if(!dispose(owner,program,instance)){return failure(format,true,errors::absent(5,0),8);}
    return publish(format,value,ref output,selected,8);
}

@effects(console,filesystem)
pub fn i32 publish(render::Format format,i64 value,ref engine::Output output,Selection selected,u8 profile){
    if(selected.output_file!=0){
        let ref u8[] payload=if(engine::output_available(output)){engine::output_view(output)}else{b""};
        if(selected.output_text && !text::validate_utf8(payload).is_ok){
            return failure(format,true,errors::absent(errors::output_encoding_kind(),0),profile);
        }
        if(!files::write_output(selected.output_file,payload)){
            return failure(format,true,errors::absent(errors::output_io_kind(),0),profile);
        }
    }else if(engine::output_available(output)){
        return render::published_output_profile(format,value,engine::output_view(output),profile);
    }
    return render::selected_outcome(format,true,false,value,errors::absent(0,0),profile);
}

fn bool dispose(ref mut engine::Engine owner,usize program,usize instance){
    return engine::destroy_instance(owner,instance).is_ok && engine::release_program(owner,program).is_ok &&
        engine::destroy(owner).is_ok;
}

fn errors::Error engine_error(engine::Error error,bool compiling,u8 profile){
    if(error.diagnostic.code.kind!=0){return error.diagnostic.code;}
    if(error.status==5){return errors::absent(11,0);}
    if(error.status==6){return errors::absent(15,0);}
    if(compiling && error.status==1){return errors::absent(9,0);}
    if(error.status==8){return errors::absent(if(compiling){4}else{errors::memory_limit_kind()},0);}
    if(profile==0 && error.status==1){return errors::absent(10,0);}
    return errors::absent(5,0);
}

@effects(console)
fn i32 failure(render::Format format,bool run,errors::Error error,u8 profile){
    return render::selected_outcome(format,run,true,0,error,profile);
}

@effects(console)
fn i32 project_failure(render::Format format,bool run,ref manifest::Project project,ref anchored::Root root,
    errors::Error error,sources::Span span,u8 profile){
    if(span.source>=manifest::count(project) || error.location!=0){return failure(format,run,error,profile);}
    let sources::Snapshot snapshot=switch(anchored::copy_collected(
        root,manifest::count(project),sources::source_limit(),sources::name_limit())){
        case .ok(v):{v}case .err(_):{return failure(format,run,error,profile);}
    };
    return render::project_failure(format,run,error,ref snapshot,span,profile);
}
