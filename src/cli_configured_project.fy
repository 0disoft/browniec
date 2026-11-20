module cli_configured_project;

import anchored_source_loader as anchored;
import cli_project_input as binary;
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

pub struct Selection { usize policy_file; usize run_file; }

@effects(console,filesystem)
pub fn i32 execute(render::Format format,Selection selected,binary::Selection selection,
    ref manifest::Project project,ref mut anchored::Root root){
    let policies::Policy ceiling=switch(configuration::read_policy(selected.policy_file)){
        case .ok(v):{v}case .err(e):{return failure(format,e,0);}
    };
    let runs::RunConfig run=switch(configuration::read_run(selected.run_file,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,e,0);}
    };
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,engine_error(e,false,0),0);}
    };
    let usize program=switch(engine::compile_anchored_project_output(
        ref mut owner,project,root,ref run,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}
        case .err(e):{return project_failure(format,project,root,engine_error(e,true,0),e.diagnostic.at,0);}
    };
    let limits::RunLimits bounds=runs::run_limits(ref run);
    let usize limit=if(bounds.input_bytes<bounds.memory_bytes){bounds.input_bytes}else{bounds.memory_bytes};
    let input::Snapshot payload=switch(binary::read_with_limit(selection,limit)){
        case .ok(v):{v}case .err(e):{return failure(format,e,8);}
    };
    let usize instance=switch(engine::prepare_granted_instance(ref mut owner,program,ref run,payload)){
        case .ok(v):{v}
        case .err(e):{return project_failure(format,project,root,engine_error(e,false,8),e.diagnostic.at,8);}
    };
    return complete(format,ref mut owner,program,instance,project,root);
}

@effects(console)
fn i32 complete(render::Format format,ref mut engine::Engine owner,usize program,usize instance,
    ref manifest::Project project,ref anchored::Root root){
    var i64 value=0;
    while(true){
        let engine::Event event=switch(engine::step_instance(owner,instance,4096)){
            case .ok(v):{v}
            case .err(e):{return project_failure(format,project,root,engine_error(e,false,8),e.diagnostic.at,8);}
        };
        if(event.kind==4){continue;}
        if(event.kind!=1){
            let diagnostics::Error diagnostic=event.diagnostic;
            let errors::Error problem=if(diagnostic.code.kind==0){errors::absent(5,0)}else{diagnostic.code};
            return project_failure(format,project,root,problem,diagnostic.at,8);
        }
        value=event.value;
        break;
    }
    let engine::Output output=switch(engine::take_output(owner,instance)){
        case .ok(v):{v}case .err(e):{return failure(format,engine_error(e,false,8),8);}
    };
    if(!engine::destroy_instance(owner,instance).is_ok || !engine::release_program(owner,program).is_ok ||
       !engine::destroy(owner).is_ok){return failure(format,errors::absent(5,0),8);}
    if(engine::output_available(ref output)){
        return render::published_output(format,value,engine::output_view(ref output));
    }
    return render::selected_outcome(format,true,false,value,errors::absent(0,0),8);
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
fn i32 failure(render::Format format,errors::Error error,u8 profile){
    return render::selected_outcome(format,true,true,0,error,profile);
}

@effects(console)
fn i32 project_failure(render::Format format,ref manifest::Project project,ref anchored::Root root,
    errors::Error error,sources::Span span,u8 profile){
    if(span.source>=manifest::count(project) || error.location!=0){return failure(format,error,profile);}
    let sources::Snapshot snapshot=switch(anchored::copy_collected(
        root,manifest::count(project),sources::source_limit(),sources::name_limit())){
        case .ok(v):{v}case .err(_):{return failure(format,error,profile);}
    };
    return render::project_failure(format,true,error,ref snapshot,span,profile);
}
