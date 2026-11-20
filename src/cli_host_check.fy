module cli_host_check;

import cli_input as source_input;
import cli_run_configuration as configuration;
import errors as errors;
import host_catalog as catalog;
import render as render;
import runtime_engine as engine;
import runtime_policy as policies;
import runtime_run_config as runs;

@effects(console,filesystem)
pub fn i32 execute(render::Format format,usize policy_file,usize run_file,usize catalog_file){
    let policies::Policy ceiling=switch(configuration::read_policy(policy_file)){
        case .ok(v):{v}case .err(e):{return failure(format,e);}
    };
    let runs::RunConfig run=switch(configuration::read_run(run_file,ref ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,e);}
    };
    let catalog::Catalog imports=switch(configuration::read_catalog(catalog_file)){
        case .ok(v):{v}case .err(e):{return failure(format,e);}
    };
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(e):{return failure(format,configuration::catalog_failure(e));}
    };
    let source_input::Source source=switch(source_input::read_source(2)){
        case .ok(v):{v}case .err(e):{return failure(format,e);}
    };
    var engine::Engine owner=switch(engine::create_with_policy(ceiling)){
        case .ok(v):{v}case .err(e):{return failure(format,engine_error(e));}
    };
    let usize program=switch(engine::compile_scalar_host(ref mut owner,ref source.data[..source.length],
        imports,ref digest,ref run)){
        case .ok(v):{v}case .err(e):{return failure(format,engine_error(e));}
    };
    if(!engine::release_program(ref mut owner,program).is_ok || !engine::destroy(ref mut owner).is_ok){
        return failure(format,errors::absent(5,0));
    }
    return render::selected_outcome(format,false,false,0,errors::absent(0,0),0);
}

fn errors::Error engine_error(engine::Error problem){
    if(problem.diagnostic.code.kind!=0){return problem.diagnostic.code;}
    if(problem.status==5){return errors::absent(11,0);}
    if(problem.status==6){return errors::absent(15,0);}
    if(problem.status==8){return errors::absent(4,0);}
    return errors::absent(5,0);
}

@effects(console)
fn i32 failure(render::Format format,errors::Error error){
    return render::selected_outcome(format,false,true,0,error,0);
}
