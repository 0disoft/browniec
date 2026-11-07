module tests::m2::runtime_admission_exchange;
import runtime_policy as policies;
import runtime_run_config as runs;
import host_catalog as catalogs;
import host_exchange as exchanges;
import host_wire as wire;

fn ref u8[] policy_json(){return b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[\"host.example.check\"]}";}
fn ref u8[] granted_json(){return b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"main\",\"function\":\"main\"},\"requires\":[\"host.example.check\"],\"grants\":[\"host.example.check\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}";}
fn ref u8[] denied_json(){return b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"main\",\"function\":\"main\"},\"requires\":[],\"grants\":[],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}";}
fn ref u8[] catalog_json(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"write\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";}
fn policies::Policy policy(){return switch(policies::parse(policy_json())){
    case .ok(v):{v}case .err(_):{assert(false);policy()}
};}
fn runs::RunConfig config(ref policies::Policy p,bool granted){return switch(runs::parse(if(granted){granted_json()}else{denied_json()},p)){
    case .ok(v):{v}case .err(_):{assert(false);config(p,true)}
};}
fn catalogs::Catalog catalog(){return switch(catalogs::parse(catalog_json())){
    case .ok(v):{v}case .err(_):{assert(false);catalog()}
};}
// Trusted native composition only: it is not a Program requirement binding or
// public runtime integration. Engine-ceiling membership alone never grants.
fn exchanges::Exchange exchange(ref policies::Policy p,ref runs::RunConfig run){
    assert(runs::narrowed_to(run,p));let catalogs::Catalog c=catalog();
    let bool grant=switch(catalogs::capability(ref c,0)){case .ok(v):{runs::grants(run,v)}case .err(_):{assert(false);false}};
    let bool[1] allowed=[grant];let limits=runs::run_limits(run);
    let exchanges::Limits budget=exchanges::Limits{.request_bytes=limits.host_request_bytes,.reply_bytes=limits.host_response_bytes,
        .requests_total=1048576,.replies_total=1048576,.calls=limits.host_calls,.adapter_per_call=10,.adapter_total=100};
    return switch(exchanges::create(c,ref allowed,budget,23,limits.fuel,limits.deadline_ms)){
        case .ok(v):{v}case .err(_):{assert(false);exchange(p,run)}
    };
}
@test fn void typed_run_grants_drive_real_catalog_exchange_and_reply_handoff(){
    let policies::Policy p=policy();let runs::RunConfig r=config(ref p,true);
    var exchanges::Exchange e=exchange(ref p,ref r);
    let usize id=switch(exchanges::begin(ref mut e,0,b"\x01\x00\x03\x00\x00\x00\x04\x00\x00\x00\x29\x00\x00\x00",3,5,1,false)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };assert(id==1);
    let wire::Request request=switch(exchanges::request_fields(ref e)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };assert(request.count==1 && request.fields[0].scalar==41);
    var u8[12] reply=[0;12];assert(wire::encode_reply(0,3,
        wire::Field{.tag=3,.scalar=request.fields[0].scalar+1,.start=0,.length=0},b"",ref mut reply,12).is_ok);
    assert(exchanges::reply(ref mut e,23,id,0,ref reply,2,2,false).is_ok);
    let exchanges::Output result=switch(exchanges::take_reply(ref mut e,3,false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };assert(exchanges::output_field(ref result).scalar==42);
    assert(exchanges::observe(ref e).phase==0 && exchanges::observe(ref e).fuel==runs::run_limits(ref r).fuel-5);
}
@test fn void policy_capability_without_explicit_run_grant_never_starts_exchange(){
    let policies::Policy p=policy();let runs::RunConfig r=config(ref p,false);
    assert(policies::contains_capability(ref p,b"host.example.check"));
    assert(!runs::grants(ref r,b"host.example.check"));
    var exchanges::Exchange e=exchange(ref p,ref r);let exchanges::Observation before=exchanges::observe(ref e);
    switch(exchanges::begin(ref mut e,0,b"\x01\x00\x03\x00\x00\x00\x04\x00\x00\x00\x29\x00\x00\x00",3,5,1,false)){
        case .ok(_):{assert(false);}case .err(error):{switch(error){case .Denied:{}case .State:{assert(false);}case .Identity:{assert(false);}case .Catalog:{assert(false);}
            case .Malformed:{assert(false);}case .Allocation:{assert(false);}case .Terminated:{assert(false);}};}
    };
    let exchanges::Observation after=exchanges::observe(ref e);
    assert(before.phase==after.phase && before.request==after.request && before.fuel==after.fuel);
    assert(after.calls==0 && after.requests==0 && after.adapter==0);
}
