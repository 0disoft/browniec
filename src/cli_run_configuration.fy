module cli_run_configuration;

import cli_local_file as files;
import errors as errors;
import runtime_policy as policies;
import runtime_policy_json as json;
import runtime_run_config as runs;

fn errors::Error failure(json::Error error){
    return switch(error.kind){
        case .Allocation:{errors::absent(15,0)}
        case .Authority:{errors::absent(11,0)}
        case .Relation:{errors::absent(10,0)}
        case .Json:{errors::make(10,error.offset)}
        case .Limit:{errors::make(10,error.offset)}
        case .Unknown:{errors::make(10,error.offset)}
        case .Duplicate:{errors::make(10,error.offset)}
        case .Missing:{errors::make(10,error.offset)}
        case .Value:{errors::make(10,error.offset)}
        case .Bounds:{errors::make(10,error.offset)}
    };
}

@effects(filesystem)
pub fn Result<policies::Policy,errors::Error> read_policy(usize argument){
    let files::File file=files::open(argument,json::byte_limit(),10)?;
    return switch(policies::parse(files::view(ref file))){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}

@effects(filesystem)
pub fn Result<runs::RunConfig,errors::Error> read_run(usize argument,ref policies::Policy policy){
    let files::File file=files::open(argument,json::byte_limit(),10)?;
    return switch(runs::parse(files::view(ref file),policy)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}
