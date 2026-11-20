module cli_host_command;

import cli_input as source_input;
import cli_configured_project as configured;
import cli_project_input as binary;
import runtime_input as input;
import runtime_policy_limits as limits;
import cli_project as projects;
import anchored_source_loader as anchored;
import project_manifest as manifest;
import source_snapshot as sources;
import std::bytes as bytes;
import std::process as process;
import cli_host_replies as replies;
import cli_host_process as child;
import host_process_adapter as adapters;
import cli_run_configuration as configuration;
import errors as errors;
import host_catalog as catalog;
import render as render;
import runtime_engine as engine;
import runtime_policy as policies;
import runtime_run_config as runs;

unsafe extern C fn u32 bc_cli_enable_cancel();
unsafe extern C fn u32 bc_cli_cancel_requested();

@effects(console,filesystem)
pub fn i32 execute(render::Format format,configured::Selection settings,usize catalog_file,usize reply_file,usize adapter_arg,bool project,
    binary::Selection selection){
    let bool running=reply_file!=0 || adapter_arg!=0;
    let policies::Policy ceiling=switch(configuration::read_policy(settings.policy_file)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let runs::RunConfig run=switch(configuration::read_run(settings.run_file,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let catalog::Catalog imports=switch(configuration::read_catalog(catalog_file)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(e):{return failure(format,running,configuration::catalog_failure(e));}
    };
    let Option<replies::Replies> responses=if(reply_file!=0){
        switch(replies::read(reply_file,ref imports,digest)){
            case .ok(v):{.some(v)}case .err(e):{return failure(format,true,e);}
        }
    }else{.none};
    let Option<adapters::Route> executable=if(adapter_arg!=0){
        switch(child::read(adapter_arg,ref imports)){
            case .ok(v):{.some(v)}case .err(e):{return failure(format,true,e);}
        }
    }else{.none};
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,running,engine_error(e,true));}
    };
    if(project){
        return execute_project(format,running,ref mut owner,ref run,imports,ref digest,responses,executable,selection,settings);
    }
    let source_input::Source source=switch(source_input::read_source(2)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let usize program=switch(engine::compile_scalar_host(ref mut owner,ref source.data[..source.length],
        imports,ref digest,ref run)){
        case .ok(v):{v}case .err(e):{return failure(format,running,engine_error(e,true));}
    };
    return complete_command(format,running,ref mut owner,program,ref run,responses,executable,selection,settings);
}

@effects(console,filesystem)
fn i32 execute_project(render::Format format,bool running,ref mut engine::Engine owner,ref runs::RunConfig run,
    catalog::Catalog imports,ref u32[] digest,Option<replies::Replies> responses,
    Option<adapters::Route> executable,binary::Selection selection,configured::Selection settings){
    var u8[3072] path=[0;3072];
    let usize size=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(format,running,errors::absent(10,0));}
    };
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=switch(projects::open_manifest(ref path[..size],ref mut data)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let manifest::Project project=switch(projects::parse_manifest(ref root,bytes::view(ref data))){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let usize program=switch(engine::compile_anchored_project_host(owner,ref project,ref mut root,imports,digest,run)){
        case .ok(v):{v}
        case .err(e):{return project_failure(format,running,ref project,ref root,e);}
    };
    return complete_command(format,running,owner,program,run,responses,executable,selection,settings);
}

@effects(console)
fn i32 project_failure(render::Format format,bool running,ref manifest::Project project,ref anchored::Root root,
    engine::Error failure_info){
    let errors::Error problem=if(failure_info.status==1){errors::absent(9,0)}else{engine_error(failure_info,true)};
    let sources::Span at=failure_info.diagnostic.at;
    if(at.source>=manifest::count(project) || problem.location!=0){return failure(format,running,problem);}
    let sources::Snapshot snapshot=switch(anchored::copy_collected(
        root,manifest::count(project),sources::source_limit(),sources::name_limit())){
        case .ok(v):{v}case .err(_):{return failure(format,running,problem);}
    };
    return render::project_failure(format,running,problem,ref snapshot,at,0);
}

@effects(console,filesystem)
fn i32 complete_command(render::Format format,bool running,ref mut engine::Engine owner,usize program,
    ref runs::RunConfig run,Option<replies::Replies> responses,Option<adapters::Route> executable,
    binary::Selection selection,configured::Selection settings){
    var i64 value=0;
    var errors::Error problem=errors::absent(0,0);
    let Result<Option<engine::Output>,errors::Error> execution=switch(responses){
        case .some(table):{switch(executable){
            case .none:{run_selected(owner,program,run,.some(ref table),.none,selection,settings,format,ref mut value)}
            case .some(_):{.err(errors::absent(10,0))}
        }}
        case .none:{switch(executable){
            case .some(route):{run_selected(owner,program,run,.none,.some(ref route),selection,settings,format,ref mut value)}
            case .none:{.ok(.none)}
        }}
    };
    let Option<engine::Output> publish=switch(execution){
        case .ok(v):{v}case .err(e):{problem=e;.none}
    };
    if(!engine::release_program(owner,program).is_ok || !engine::destroy(owner).is_ok){
        return failure(format,running,errors::absent(5,0));
    }
    if(problem.kind!=0){return failure(format,running,problem);}
    return switch(publish){
        case .some(output):{configured::publish(format,value,ref output,settings,0)}
        case .none:{render::selected_outcome(format,running,false,value,errors::absent(0,0),0)}
    };
}

@effects(filesystem)
fn Result<Option<engine::Output>,errors::Error> run_selected(ref mut engine::Engine owner,usize program,
    ref runs::RunConfig run,Option<ref replies::Replies> responses,Option<ref adapters::Route> executable,
    binary::Selection selection,
    configured::Selection settings,render::Format format,ref mut i64 value){
    let bool emits=switch(engine::host_program_emits(owner,program)){
        case .ok(v):{v}case .err(e):{return .err(engine_error(e,false));}
    };
    if(emits && render::text_mode(format)){return .err(errors::absent(10,0));}
    if(settings.output_file!=0 && !emits){return .err(errors::absent(19,0));}
    if(unsafe{bc_cli_enable_cancel()}==0){return .err(errors::absent(5,0));}
    let usize instance=prepare_guest(owner,program,run,selection)?;
    var errors::Error problem=errors::absent(0,0);
    let Option<engine::Output> publish=switch(complete(owner,instance,responses,executable)){
        case .ok(v):{*value=v;switch(detach_output(owner,instance,emits)){
            case .ok(output):{output}case .err(e):{problem=e;.none}
        }}
        case .err(e):{problem=e;.none}
    };
    if(!engine::destroy_instance(owner,instance).is_ok){return .err(errors::absent(5,0));}
    if(problem.kind!=0){return .err(problem);}
    return .ok(publish);
}

fn Result<Option<engine::Output>,errors::Error> detach_output(ref mut engine::Engine owner,usize instance,bool emits){
    if(!emits){return .ok(.none);}
    return switch(engine::take_output(owner,instance)){
        case .ok(output):{.ok(.some(output))}
        case .err(e):{.err(engine_error(e,false))}
    };
}

@effects(filesystem)
fn Result<usize,errors::Error> prepare_guest(ref mut engine::Engine owner,usize program,ref runs::RunConfig run,
    binary::Selection selection){
    if(selection.argument==0 && !selection.stdin){
        return switch(engine::prepare_scalar_host(owner,program,run)){
            case .ok(v):{.ok(v)}case .err(e):{.err(engine_error(e,false))}
        };
    }
    let limits::RunLimits bounds=runs::run_limits(run);
    let usize limit=if(bounds.input_bytes<bounds.memory_bytes){bounds.input_bytes}else{bounds.memory_bytes};
    let input::Snapshot payload=binary::read_with_limit(selection,limit)?;
    return switch(engine::prepare_input_host(owner,program,run,ref payload)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(if(e.status==1){errors::absent(10,0)}else{engine_error(e,false)})}
    };
}

fn Result<i64,errors::Error> complete(ref mut engine::Engine owner,usize instance,
    Option<ref replies::Replies> responses,Option<ref adapters::Route> executable){
    while(true){
        let engine::Event event=switch(next(owner,instance,responses,executable)){
            case .ok(v):{v}case .err(e):{return .err(e);}
        };
        if(event.kind==0){continue;}
        if(event.kind==1){return .ok(event.value);}
        if(event.kind==3){return .err(errors::absent(errors::cancelled_kind(),0));}
        if(event.diagnostic.code.kind!=0){return .err(event.diagnostic.code);}
        return .err(errors::absent(11,0));
    }
    return .err(errors::absent(5,0));
}

fn Result<engine::Event,errors::Error> next(ref mut engine::Engine owner,usize instance,
    Option<ref replies::Replies> responses,Option<ref adapters::Route> executable){
    let engine::Event state=step(owner,instance)?;
    if(state.kind!=4){return .ok(state);}
    if(unsafe{bc_cli_cancel_requested()}!=0){return step(owner,instance);}
    return switch(executable){
        case .some(route):{child::dispatch(owner,instance,route)}
        case .none:{switch(responses){
            case .some(table):{replay(owner,instance,table)}
            case .none:{.err(errors::absent(11,0))}
        }}
    };
}

fn Result<engine::Event,errors::Error> replay(ref mut engine::Engine owner,usize instance,ref replies::Replies responses){
    let u32 status=switch(replies::dispatch(responses,owner,instance)){
        case .ok(v):{return .ok(v);}case .err(e):{e.status}
    };
    // The read or claim can observe expiry before the next step records it.
    if(status==11 || status==5){
        let engine::Event checked=step(owner,instance)?;
        if(checked.kind!=4){return .ok(checked);}
    }
    return .err(status_error(status,false));
}

fn Result<engine::Event,errors::Error> step(ref mut engine::Engine owner,usize instance){
    let Result<engine::Event,engine::Error> action=if(unsafe{bc_cli_cancel_requested()}!=0){
        engine::cancel_ready(owner,instance)
    }else{
        engine::step_instance(owner,instance,4096)
    };
    return switch(action){case .ok(v):{.ok(v)}case .err(e):{.err(engine_error(e,false))}};
}

fn errors::Error engine_error(engine::Error problem,bool compiling){
    if(problem.diagnostic.code.kind!=0){return problem.diagnostic.code;}
    return status_error(problem.status,compiling);
}
fn errors::Error status_error(u32 status,bool compiling){
    if(status==5 || status==11){return errors::absent(11,0);}
    if(status==6){return errors::absent(15,0);}
    if(status==8){return errors::absent(if(compiling){4}else{errors::memory_limit_kind()},0);}
    return errors::absent(5,0);
}

@effects(console)
fn i32 failure(render::Format format,bool running,errors::Error error){
    return render::selected_outcome(format,running,true,0,error,0);
}
