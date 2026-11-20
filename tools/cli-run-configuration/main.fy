module main;

import cli_run_configuration as configuration;
import errors as errors;
import runtime_policy as policies;
import runtime_run_config as runs;
import std::bytes as bytes;

fn void expect(errors::Error error,u8 kind,u8 location){
    assert(error.kind==kind && error.location==location);
}

@effects(filesystem)
fn i32 main(){
    // The first two files are valid JSON padded to the exact acquisition limit.
    let policies::Policy policy=switch(configuration::read_policy(1)){
        case .ok(v):{v}case .err(_):{return 1;}
    };
    let runs::RunConfig run=switch(configuration::read_run(2,ref policy)){
        case .ok(v):{v}case .err(_):{return 2;}
    };
    assert(bytes::equal(runs::module_name(ref run),b"main"));
    assert(bytes::equal(runs::function_name(ref run),b"main"));
    assert(runs::run_limits(ref run).fuel==10000000);
    switch(configuration::read_policy(3)){
        case .ok(_):{assert(false);}case .err(e):{expect(e,10,errors::absent_location());}
    };
    switch(configuration::read_run(4,ref policy)){
        case .ok(_):{assert(false);}case .err(e):{expect(e,11,errors::absent_location());}
    };
    switch(configuration::read_run(5,ref policy)){
        case .ok(_):{assert(false);}case .err(e):{expect(e,10,0);}
    };
    switch(configuration::read_policy(6)){
        case .ok(_):{assert(false);}case .err(e):{expect(e,9,errors::absent_location());}
    };
    return 0;
}
