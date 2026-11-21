module cli_run_configuration;

import cli_local_file as files;
import errors as errors;
import host_catalog as catalog;
import runtime_policy as policies;
import runtime_policy_json as json;
import runtime_run_config as runs;

pub fn errors::Error catalog_failure(catalog::Error error){
    return switch(error.kind){
        case .Allocation:{errors::absent(15,0)}
        case .Json:{errors::make(10,error.offset)}
        case .Limit:{errors::make(10,error.offset)}
        case .Unknown:{errors::make(10,error.offset)}
        case .Duplicate:{errors::make(10,error.offset)}
        case .Missing:{errors::make(10,error.offset)}
        case .Value:{errors::make(10,error.offset)}
        case .Order:{errors::make(10,error.offset)}
        case .Bounds:{errors::make(10,error.offset)}
    };
}

@effects(filesystem)
pub fn Result<catalog::Catalog,errors::Error> read_catalog(usize argument){
    let files::File file=files::open(argument,catalog::byte_limit(),10)?;
    return switch(catalog::parse(files::view(ref file))){
        case .ok(v):{.ok(v)}case .err(e):{.err(catalog_failure(e))}
    };
}

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
    return parse_policy(files::view(ref file));
}

pub fn Result<policies::Policy,errors::Error> parse_policy(ref u8[] data){
    return switch(policies::parse(data)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}

@effects(filesystem)
pub fn Result<runs::RunConfig,errors::Error> read_run(usize argument,ref policies::Policy policy){
    let files::File file=files::open(argument,json::byte_limit(),10)?;
    return parse_run(files::view(ref file),policy);
}

pub fn Result<runs::RunConfig,errors::Error> parse_run(ref u8[] data,ref policies::Policy policy){
    return switch(runs::parse(data,policy)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}
