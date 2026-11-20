module cli_host_command;

import cli_input as source_input;
import cli_host_replies as replies;
import cli_run_configuration as configuration;
import errors as errors;
import host_catalog as catalog;
import render as render;
import runtime_engine as engine;
import runtime_policy as policies;
import runtime_run_config as runs;

struct Outcome { i64 value; errors::Error error; }

unsafe extern C fn u32 bc_cli_enable_cancel();
unsafe extern C fn u32 bc_cli_cancel_requested();

@effects(console,filesystem)
pub fn i32 execute(render::Format format,usize policy_file,usize run_file,usize catalog_file,usize reply_file){
    let bool running=reply_file!=0;
    let policies::Policy ceiling=switch(configuration::read_policy(policy_file)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let runs::RunConfig run=switch(configuration::read_run(run_file,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let catalog::Catalog imports=switch(configuration::read_catalog(catalog_file)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(e):{return failure(format,running,configuration::catalog_failure(e));}
    };
    let Option<replies::Replies> responses=if(running){
        switch(replies::read(reply_file,ref imports,digest)){
            case .ok(v):{.some(v)}case .err(e):{return failure(format,true,e);}
        }
    }else{.none};
    let source_input::Source source=switch(source_input::read_source(2)){
        case .ok(v):{v}case .err(e):{return failure(format,running,e);}
    };
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,running,engine_error(e,true));}
    };
    let usize program=switch(engine::compile_scalar_host(ref mut owner,ref source.data[..source.length],
        imports,ref digest,ref run)){
        case .ok(v):{v}case .err(e):{return failure(format,running,engine_error(e,true));}
    };
    let Outcome result=switch(responses){
        case .none:{success(0)}
        case .some(table):{execute_guest(ref mut owner,program,ref run,ref table)}
    };
    if(!engine::release_program(ref mut owner,program).is_ok || !engine::destroy(ref mut owner).is_ok){
        return failure(format,running,errors::absent(5,0));
    }
    return render::selected_outcome(format,running,result.error.kind!=0,result.value,result.error,0);
}

fn Outcome success(i64 value){return Outcome{.value=value,.error=errors::absent(0,0)};}
fn Outcome failed(errors::Error error){return Outcome{.value=0,.error=error};}

fn Outcome execute_guest(ref mut engine::Engine owner,usize program,ref runs::RunConfig run,
    ref replies::Replies responses){
    if(unsafe{bc_cli_enable_cancel()}==0){return failed(errors::absent(5,0));}
    let usize instance=switch(engine::prepare_scalar_host(owner,program,run)){
        case .ok(v):{v}case .err(e):{return failed(engine_error(e,false));}
    };
    let Outcome result=switch(complete(owner,instance,responses)){
        case .ok(v):{success(v)}case .err(e):{failed(e)}
    };
    if(!engine::destroy_instance(owner,instance).is_ok){return failed(errors::absent(5,0));}
    return result;
}

fn Result<i64,errors::Error> complete(ref mut engine::Engine owner,usize instance,ref replies::Replies responses){
    while(true){
        let engine::Event event=switch(next(owner,instance,responses)){
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

fn Result<engine::Event,errors::Error> next(ref mut engine::Engine owner,usize instance,ref replies::Replies responses){
    let engine::Event state=step(owner,instance)?;
    if(state.kind!=4){return .ok(state);}
    if(unsafe{bc_cli_cancel_requested()}!=0){return step(owner,instance);}
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
