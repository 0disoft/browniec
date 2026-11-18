module tests::m2::host_program;

import host_catalog as catalog;
import host_exchange as host;
import std::bytes as bytes;
import host_program as programs;
import ir as ir;
import runtime_policy as policy;
import runtime_run_config as runs;
import verifier as verifier;

fn ref u8[] json(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";}
fn ref u8[] policy_json_yes(){return b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[\"host.example.check\"]}";}
fn ref u8[] policy_json_no(){return b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[]}";}
fn ref u8[] config_json_yes(){return b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[\"host.example.check\"],\"grants\":[\"host.example.check\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}";}
fn ref u8[] config_json_no(){return b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[],\"grants\":[\"host.example.check\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}";}

fn Result<ir::Program,u8> candidate(){
    var ir::Program code=ir::empty();
    let usize arg=switch(ir::literal(ref mut code,41,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize reply=switch(ir::emit(ref mut code,programs::request_opcode(),arg,0,1)){
        case .ok(v):{v}case .err(_):{return .err(2);}
    };
    let usize returned=switch(ir::emit(ref mut code,8,reply,0,2)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    code.function_count=1;
    let usize count=code.count;
    code.ends[0]=count;
    let usize registers=code.registers;
    code.register_ends[0]=registers;
    code.return_types[0]=1;
    return .ok(code);
}
fn Result<catalog::Catalog,u8> catalog_from(ref u8[] input){
    return switch(catalog::parse(input)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<policy::Policy,u8> parsed_policy(bool allow){
    return switch(policy::parse(if(allow){policy_json_yes()}else{policy_json_no()})){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn Result<runs::RunConfig,u8> config(ref policy::Policy ceiling,bool declared){
    return switch(runs::parse(if(declared){config_json_yes()}else{config_json_no()},ceiling)){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
}
fn Result<u32[8],u8> digest(ref catalog::Catalog imports){
    return switch(catalog::digest(imports)){case .ok(v):{.ok(v)}case .err(_):{.err(7)}};
}
fn usize rejected(Result<programs::Program,programs::Error> result){
    return switch(result){case .ok(_):{0}case .err(e):{switch(e){
        case .Code:{1}case .Catalog:{2}case .Binding:{3}case .Authority:{4}case .Allocation:{5}
    }}};
}

fn Result<usize,u8> binding_cases(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let policy::Policy denied=parsed_policy(false)?;
    let runs::RunConfig allowed=config(ref ceiling,true)?;
    let runs::RunConfig missing=config(ref ceiling,false)?;
    let catalog::Catalog original=catalog_from(json())?;
    let u32[8] expected=digest(ref original)?;
    let ir::Program source=candidate()?;
    assert(!verifier::verify(ref source).is_ok);
    let programs::Program p=switch(programs::retain(ref source,original,ref expected,ref ceiling,ref allowed)){
        case .ok(v):{v}case .err(_):{return .err(8);}
    };
    let u32[8] actual=programs::binding(ref p);
    assert(programs::same_digest(ref expected,ref actual));
    assert(programs::requirements(ref p)==1 && programs::allows(ref p,ref ceiling,ref allowed));
    assert(!programs::allows(ref p,ref ceiling,ref missing));
    assert(!programs::allows(ref p,ref denied,ref allowed));
    assert(rejected(programs::retain(ref source,catalog_from(json())?,ref expected,ref ceiling,ref missing))==4);
    let catalog::Catalog changed=catalog_from(b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v2\"}]}")?;
    assert(rejected(programs::retain(ref source,changed,ref expected,ref ceiling,ref allowed))==3);
    let catalog::Catalog wrong=catalog_from(b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"bool\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}")?;
    let u32[8] wrong_digest=digest(ref wrong)?;
    assert(rejected(programs::retain(ref source,wrong,ref wrong_digest,ref ceiling,ref allowed))==2);
    return .ok(1);
}

fn Result<usize,u8> operand_cases(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig allowed=config(ref ceiling,true)?;
    let catalog::Catalog expected_catalog=catalog_from(json())?;
    let u32[8] expected=digest(ref expected_catalog)?;
    var ir::Program source=candidate()?;
    source.code[10]=1; // Destination was not defined before this request.
    assert(rejected(programs::retain(ref source,catalog_from(json())?,ref expected,ref ceiling,ref allowed))==1);
    source.code[10]=0;
    source.code[11]=64;
    assert(rejected(programs::retain(ref source,catalog_from(json())?,ref expected,ref ceiling,ref allowed))==2);
    return .ok(1);
}

@test fn void catalog_and_policy_bind_exact_verified_request(){assert(binding_cases().is_ok);}
@test fn void malformed_request_operand_is_rejected_before_publication(){assert(operand_cases().is_ok);}

fn Result<programs::Program,u8> retained(ref policy::Policy ceiling,ref runs::RunConfig run){
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program source=candidate()?;
    return switch(programs::retain(ref source,imports,ref expected,ceiling,run)){
        case .ok(v):{.ok(v)}case .err(_):{.err(9)}
    };
}
fn Result<host::Exchange,u8> instance(ref programs::Program p,ref policy::Policy ceiling,
    ref runs::RunConfig run,usize id,usize deadline){
    return switch(host::create_scalar(p,ceiling,run,id,deadline)){
        case .ok(v):{.ok(v)}case .err(_):{.err(10)}
    };
}
fn host::ScalarEvent step(ref mut host::Exchange e,usize now,bool cancel){
    return switch(host::step_scalar(e,now,cancel)){
        case .ok(v):{v}case .err(_):{assert(false);return host::ScalarEvent{.phase=255,.host=host::observe(e),.value=0,.failure=0,.host_error=0};}
    };
}
fn host::ScalarEvent reply(ref mut host::Exchange e,usize run,u8 kind,ref u8[] payload,usize now){
    return switch(host::reply_scalar(e,run,1,kind,payload,now,false)){
        case .ok(v):{v}case .err(_):{assert(false);return host::ScalarEvent{.phase=255,.host=host::observe(e),.value=0,.failure=0,.host_error=0};}
    };
}
fn bool request_is(ref host::Exchange e,ref u8[] expected){
    return switch(host::request_bytes(e)){
        case .ok(v):{bytes::equal(v,expected)}case .err(_):{false}
    };
}
fn Result<usize,u8> scalar_round_trip(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig allowed=config(ref ceiling,true)?;
    let runs::RunConfig missing=config(ref ceiling,false)?;
    let programs::Program p=retained(ref ceiling,ref allowed)?;
    assert(!host::create_scalar(ref p,ref ceiling,ref missing,31,0).is_ok);
    var host::Exchange first=instance(ref p,ref ceiling,ref allowed,31,0)?;
    var host::Exchange second=instance(ref p,ref ceiling,ref allowed,32,0)?;
    let host::ScalarEvent ready=step(ref mut first,1,false);
    assert(ready.phase==0 && ready.host.fuel==9999999);
    assert(step(ref mut second,1,false).phase==0);
    let host::ScalarEvent pending=step(ref mut first,2,false);
    assert(pending.phase==1 && pending.host.run==31 && pending.host.request==1 && pending.host.import_id==0);
    assert(pending.host.calls==1 && pending.host.requests==14 && pending.host.fuel==9999984);
    let ref u8[] request=b"\x01\x00\x03\x00\x00\x00\x04\x00\x00\x00\x29\x00\x00\x00";
    let ref u8[] answer=b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00";
    assert(request_is(ref first,request));
    let host::ScalarEvent other=step(ref mut second,2,false);
    assert(other.phase==1 && other.host.run==32 && other.host.request==1);
    assert(!host::reply_scalar(ref mut first,32,1,0,answer,3,false).is_ok);
    assert(!host::reply_scalar(ref mut first,31,2,0,answer,3,false).is_ok);
    assert(!host::reply_scalar(ref mut first,31,1,0,b"\x03",3,false).is_ok);
    assert(!host::reply(ref mut first,31,1,0,answer,0,3,false).is_ok);
    let host::ScalarEvent still=step(ref mut first,4,false);
    assert(still.phase==1 && still.host.request==1 && still.host.fuel==9999984 && still.host.calls==1);
    assert(request_is(ref first,request));
    let host::ScalarEvent accepted=reply(ref mut first,31,0,answer,5);
    assert(accepted.phase==2 && accepted.host.replies==12 && accepted.host.fuel==9999972);
    assert(!host::reply_scalar(ref mut first,31,1,0,answer,5,false).is_ok);
    assert(!host::take_reply(ref mut first,5,false).is_ok);
    let host::ScalarEvent installed=step(ref mut first,6,false);
    assert(installed.phase==0 && installed.host.fuel==9999972);
    let host::ScalarEvent done=step(ref mut first,7,false);
    assert(done.phase==3 && done.value==42 && done.host.fuel==9999971);
    assert(step(ref mut first,8,true).value==42);
    let host::ScalarEvent waiting=step(ref mut second,8,false);
    assert(waiting.phase==1 && waiting.host.fuel==9999984 && request_is(ref second,request));
    return .ok(1);
}
fn Result<usize,u8> scalar_stop_cases(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig allowed=config(ref ceiling,true)?;
    let programs::Program p=retained(ref ceiling,ref allowed)?;
    var host::Exchange failed=instance(ref p,ref ceiling,ref allowed,51,0)?;
    var host::Exchange expired=instance(ref p,ref ceiling,ref allowed,52,4)?;
    assert(step(ref mut failed,1,false).phase==0 && step(ref mut failed,2,false).phase==1);
    let ref u8[] error=b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff";
    assert(reply(ref mut failed,51,1,error,3).phase==2);
    let host::ScalarEvent terminal=step(ref mut failed,4,false);
    assert(terminal.phase==4 && terminal.failure==3 && terminal.host_error==4294967295);
    assert(terminal.host.fuel==9999972 && step(ref mut failed,5,true).host_error==4294967295);
    assert(step(ref mut expired,1,false).phase==0 && step(ref mut expired,2,false).phase==1);
    let host::ScalarEvent deadline=step(ref mut expired,4,false);
    assert(deadline.phase==4 && deadline.failure==1 && deadline.host.cause==2);
    assert(deadline.host.fuel==9999984 && deadline.host.calls==1 && deadline.host.external_effects_unknown);
    assert(!host::request_bytes(ref expired).is_ok && step(ref mut expired,5,true).host.cause==2);
    return .ok(1);
}

@test fn void scalar_host_waits_and_installs_one_reply_per_instance(){assert(scalar_round_trip().is_ok);}
@test fn void scalar_host_error_and_waiting_deadline_stay_terminal(){assert(scalar_stop_cases().is_ok);}
