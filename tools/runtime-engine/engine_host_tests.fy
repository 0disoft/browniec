module engine_host_tests;
import host_catalog as catalog;
import host_program as programs;
import host_exchange as host;
import host_wire as wire;
import verifier as verifier;
import errors as errors;
import std::bytes as bytes;
import std::num as num;
import ir as ir;
import runtime_engine as engine;
import runtime_policy as policy;
import runtime_run_config as runs;
import runtime_live_memory as live_memory;
import runtime_program_memory as program_memory;

unsafe extern C fn usize bc_runtime_engine_monotonic_ticks();
unsafe extern C fn void bc_runtime_engine_test_set_clock(usize ticks);
unsafe extern C fn void bc_runtime_engine_test_use_os_clock();
unsafe extern C fn void bc_runtime_engine_test_wait_for_clock(usize start,usize elapsed);
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_peak_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);

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
fn usize id(Result<usize,engine::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void rejected(Result<usize,engine::Error> result,u32 status){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
}
fn Result<engine::Engine,u8> configured(policy::Policy ceiling){
    return switch(engine::create_with_policy(ceiling)){case .ok(v):{.ok(v)}case .err(_):{.err(8)}};
}
fn engine::Snapshot counts(ref mut engine::Engine e){
    return switch(engine::inspect(e)){
        case .ok(v):{v}case .err(_):{assert(false);engine::Snapshot{.programs=0,.instances=0,.pins=0,.closed=true}}
    };
}
fn Result<usize,u8> admission(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    let runs::RunConfig missing=config(ref ceiling,false)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    rejected(engine::retain_scalar_host(ref mut owner,ref code,catalog_from(json())?,ref expected,ref missing),5);
    let u32[8] wrong=[0;8];
    rejected(engine::retain_scalar_host(ref mut owner,ref code,catalog_from(json())?,ref wrong,ref run),1);
    assert(counts(ref mut owner).programs==0);
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    assert(p==1 && counts(ref mut owner).programs==1);
    assert(id(engine::release_program(ref mut owner,p))==p && counts(ref mut owner).programs==0);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn engine::Event event(Result<engine::Event,engine::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);event(result)}};
}
fn engine::HostRequest request(ref engine::Engine owner,usize instance){
    return switch(engine::scalar_host_request(owner,instance)){
        case .ok(value):{value}case .err(_):{assert(false);request(owner,instance)}
    };
}
fn Result<usize,u8> interleaved(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    let runs::RunConfig missing=config(ref ceiling,false)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    rejected(engine::prepare_scalar_host(ref mut owner,p,ref missing),5);
    let usize a=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize b=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    assert(p==1 && a==2 && b==3);
    let engine::Snapshot live=counts(ref mut owner);
    assert(live.programs==1 && live.instances==2 && live.pins==2);
    assert(id(engine::release_program(ref mut owner,p))==p);
    rejected(engine::prepare_scalar_host(ref mut owner,p,ref run),2);
    let engine::Event waiting_a=event(engine::step_instance(ref mut owner,a,8));
    let engine::Event waiting_b=event(engine::step_instance(ref mut owner,b,8));
    assert(waiting_a.kind==4 && waiting_b.kind==4 && waiting_a.remaining==9999984 && waiting_b.remaining==9999984);
    let engine::HostRequest ra=request(ref owner,a);
    let engine::HostRequest rb=request(ref owner,b);
    let ref u8[] expected_request=b"\x01\x00\x03\x00\x00\x00\x04\x00\x00\x00\x29\x00\x00\x00";
    assert(ra.run==a && rb.run==b && ra.request==1 && rb.request==1 && ra.import_id==0 && rb.import_id==0);
    assert(bytes::equal(ref ra.payload,expected_request) && bytes::equal(ref rb.payload,expected_request));
    let ref u8[] answer_a=b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00";
    let ref u8[] answer_b=b"\x03\x00\x00\x00\x04\x00\x00\x00\xf9\xff\xff\xff";
    assert(!engine::reply_scalar_host(ref mut owner,a,rb.run,rb.request,0,answer_b).is_ok);
    assert(!engine::reply_scalar_host(ref mut owner,b,ra.run,ra.request,0,answer_a).is_ok);
    assert(!engine::reply_scalar_host(ref mut owner,a,ra.run,2,0,answer_a).is_ok);
    assert(!engine::reply_scalar_host(ref mut owner,a,ra.run,ra.request,0,b"\x03").is_ok);
    assert(event(engine::observe(ref mut owner,a)).remaining==waiting_a.remaining);
    assert(event(engine::observe(ref mut owner,b)).remaining==waiting_b.remaining);
    assert(event(engine::reply_scalar_host(ref mut owner,b,rb.run,rb.request,0,answer_b)).kind==0);
    assert(!engine::reply_scalar_host(ref mut owner,b,rb.run,rb.request,0,answer_a).is_ok);
    let engine::Event done_b=event(engine::step_instance(ref mut owner,b,8));
    assert(done_b.kind==1 && done_b.value==-7 && done_b.remaining==9999971);
    let engine::Event still_a=event(engine::step_instance(ref mut owner,a,8));
    assert(still_a.kind==4 && still_a.remaining==waiting_a.remaining);
    assert(request(ref owner,a).run==a);
    assert(event(engine::reply_scalar_host(ref mut owner,a,ra.run,ra.request,0,answer_a)).kind==0);
    let engine::Event done_a=event(engine::step_instance(ref mut owner,a,8));
    assert(done_a.kind==1 && done_a.value==42 && done_a.remaining==9999971);
    assert(!engine::take_output(ref mut owner,a).is_ok);
    assert(id(engine::destroy_instance(ref mut owner,b))==b && counts(ref mut owner).pins==1);
    assert(id(engine::destroy_instance(ref mut owner,a))==a && counts(ref mut owner).programs==0);
    assert(!engine::reply_scalar_host(ref mut owner,a,ra.run,ra.request,0,answer_a).is_ok);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn Result<runs::RunConfig,u8> memory_config(ref policy::Policy ceiling,usize limit){
    var bytes::Buffer source=bytes::empty();
    assert(bytes::append(ref mut source,b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[\"host.example.check\"],\"grants\":[\"host.example.check\"],\"limits\":{\"memory_bytes\":").is_ok);
    let i64 value=switch(num::i64_from_usize(limit)){case .ok(v):{v}case .err(_):{return .err(9);}};
    assert(bytes::append_i64(ref mut source,value).is_ok);
    assert(bytes::append(ref mut source,b",\"object_bytes\":1,\"call_frames\":1,\"input_bytes\":0,\"output_bytes\":0,\"host_request_bytes\":14,\"host_response_bytes\":12,\"host_calls\":1,\"owner_entries\":1,\"descriptor_entries\":1,\"fuel\":10000000,\"deadline_ms\":1000}}").is_ok);
    return switch(runs::parse(bytes::view(ref source),ceiling)){case .ok(v):{.ok(v)}case .err(_):{.err(9)}};
}
fn void ledger(ref engine::Engine owner,usize current,usize peak){
    switch(engine::instance_memory(owner)){
        case .ok(v):{assert(v.current==current && v.peak==peak);}
        case .err(_):{assert(false);}
    };
    switch(engine::program_memory(owner)){
        case .ok(v):{assert(v.external_bytes==current && v.tracked_bytes==v.control_bytes+v.program_bytes+current);}
        case .err(_):{assert(false);}
    };
}
fn Result<usize,u8> pending_memory(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(parsed_policy(true)?)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize base=unsafe{probe_live_bytes()};
    unsafe{probe_rebase()};
    let usize sample=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize backing=unsafe{probe_live_bytes()}-base;
    assert(unsafe{probe_attempts()}==3 && unsafe{probe_peak_bytes()}==base+backing);
    let usize reservation=backing+26;
    ledger(ref owner,reservation,reservation);
    assert(id(engine::destroy_instance(ref mut owner,sample))==sample);
    assert(unsafe{probe_live_bytes()}==base);
    ledger(ref owner,0,reservation);

    let runs::RunConfig exact=memory_config(ref ceiling,reservation)?;
    let runs::RunConfig short=memory_config(ref ceiling,reservation-1)?;
    let usize baseline=unsafe{probe_live_bytes()};
    unsafe{probe_rebase()};
    rejected(engine::prepare_scalar_host(ref mut owner,p,ref short),8);
    assert(unsafe{probe_attempts()}==0 && unsafe{probe_live_bytes()}==baseline);
    assert(counts(ref mut owner).instances==0 && counts(ref mut owner).pins==0);
    ledger(ref owner,0,reservation);
    var i64 failure=0;
    while(failure<3){
        unsafe{bc_runtime_engine_test_fail(failure)};
        rejected(engine::prepare_scalar_host(ref mut owner,p,ref exact),6);
        unsafe{bc_runtime_engine_test_fail(-1)};
        assert(unsafe{probe_live_bytes()}==baseline);
        assert(counts(ref mut owner).instances==0 && counts(ref mut owner).pins==0);
        ledger(ref owner,0,reservation);
        failure+=1;
    }

    let usize a=id(engine::prepare_scalar_host(ref mut owner,p,ref exact));
    let usize b=id(engine::prepare_scalar_host(ref mut owner,p,ref exact));
    assert(a==sample+1 && b==a+1);
    assert(event(engine::step_instance(ref mut owner,a,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,b,8)).kind==4);
    ledger(ref owner,2*reservation,2*reservation);
    assert(unsafe{probe_live_bytes()}==baseline+2*(backing+14));

    assert(event(engine::cancel_ready(ref mut owner,a)).kind==3);
    assert(event(engine::cancel_ready(ref mut owner,a)).kind==3);
    switch(engine::observe_scalar_host(ref owner,a)){
        case .ok(v):{assert(v.phase==4 && v.host.cause==1 && v.host.run==a && v.host.request==1);}
        case .err(_):{assert(false);}
    };
    ledger(ref owner,reservation,2*reservation);
    assert(unsafe{probe_live_bytes()}==baseline+backing+14);
    assert(id(engine::destroy_instance(ref mut owner,a))==a);
    ledger(ref owner,reservation,2*reservation);
    assert(request(ref owner,b).run==b);

    let usize c=id(engine::prepare_scalar_host(ref mut owner,p,ref exact));
    assert(event(engine::step_instance(ref mut owner,c,8)).kind==4);
    assert(id(engine::destroy_instance(ref mut owner,c))==c);
    ledger(ref owner,reservation,2*reservation);
    let engine::HostRequest asked=request(ref owner,b);
    unsafe{probe_rebase()};
    assert(event(engine::reply_scalar_host(ref mut owner,b,asked.run,asked.request,0,
        b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00")).kind==0);
    assert(unsafe{probe_peak_bytes()}==baseline+reservation && unsafe{probe_live_bytes()}==baseline+backing+12);
    let engine::Event done=event(engine::step_instance(ref mut owner,b,8));
    assert(done.kind==1 && done.value==42);
    ledger(ref owner,0,2*reservation);
    assert(unsafe{probe_live_bytes()}==baseline);
    assert(id(engine::destroy_instance(ref mut owner,b))==b);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(reservation);
}
fn host::ScalarEvent scalar(ref engine::Engine owner,usize instance){
    return switch(engine::observe_scalar_host(owner,instance)){
        case .ok(v):{v}case .err(_):{assert(false);host::empty_scalar_event()}
    };
}
fn engine::HostRequest waiting(ref mut engine::Engine owner,usize program,ref runs::RunConfig run){
    let usize instance=id(engine::prepare_scalar_host(owner,program,run));
    assert(event(engine::step_instance(owner,instance,8)).kind==4);
    return request(owner,instance);
}
fn ref u8[] answer(){return b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00";}
fn void stopped(ref mut engine::Engine owner,engine::HostRequest asked,u8 cause,usize at,usize fuel,usize replies){
    let usize instance=asked.run;
    assert(!engine::reply_scalar_host(owner,instance,instance,asked.request,0,answer()).is_ok);
    let engine::Event terminal=event(engine::cancel_ready(owner,instance));
    let u8 expected_kind=if(cause==1){3}else{2};
    assert(terminal.kind==expected_kind);
    if(cause==2){assert(terminal.diagnostic.code.kind==errors::deadline_kind());}
    assert(terminal.remaining==fuel);
    let host::ScalarEvent after=scalar(owner,instance);
    assert(after.phase==4 && after.host.cause==cause && after.host.terminal_at==at &&
        after.host.fuel==fuel && after.host.replies==replies && after.host.external_effects_unknown);
    assert(id(engine::destroy_instance(owner,instance))==instance);
}
fn Result<usize,u8> deadline_order(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize start=1000;let usize deadline=start+10000000;
    unsafe{bc_runtime_engine_test_set_clock(start)};
    let engine::HostRequest success=waiting(ref mut owner,p,ref run);
    let engine::HostRequest cancelled=waiting(ref mut owner,p,ref run);
    let engine::HostRequest fatal=waiting(ref mut owner,p,ref run);
    let engine::HostRequest expired=waiting(ref mut owner,p,ref run);
    let engine::HostRequest late=waiting(ref mut owner,p,ref run);
    let engine::HostRequest tie=waiting(ref mut owner,p,ref run);
    let engine::HostRequest staged=waiting(ref mut owner,p,ref run);
    let usize unstarted=id(engine::prepare_scalar_host(ref mut owner,p,ref run));

    let usize before=deadline-1;
    unsafe{bc_runtime_engine_test_set_clock(before)};
    assert(event(engine::step_instance(ref mut owner,expired.run,8)).kind==4);
    assert(event(engine::reply_scalar_host(ref mut owner,success.run,success.run,success.request,0,answer())).kind==0);
    let engine::Event done=event(engine::step_instance(ref mut owner,success.run,8));
    assert(done.kind==1 && done.value==42 && done.remaining==9999971);
    assert(event(engine::cancel_ready(ref mut owner,cancelled.run)).kind==3);
    assert(event(engine::reply_scalar_host(ref mut owner,fatal.run,fatal.run,fatal.request,2,b"")).kind==2);
    assert(event(engine::reply_scalar_host(ref mut owner,staged.run,staged.run,staged.request,0,answer())).kind==0);

    unsafe{bc_runtime_engine_test_set_clock(deadline)};
    assert(!engine::scalar_host_request(ref owner,expired.run).is_ok);
    assert(event(engine::step_instance(ref mut owner,expired.run,8)).kind==2);
    assert(event(engine::reply_scalar_host(ref mut owner,late.run,late.run,late.request,0,answer())).kind==2);
    assert(event(engine::cancel_ready(ref mut owner,tie.run)).kind==3);
    assert(event(engine::step_instance(ref mut owner,staged.run,8)).kind==2);
    assert(event(engine::step_instance(ref mut owner,unstarted,8)).kind==2);
    let host::ScalarEvent idle=scalar(ref owner,unstarted);
    assert(idle.host.cause==2 && idle.host.terminal_at==deadline && idle.host.calls==0 && idle.host.fuel==10000000);

    unsafe{bc_runtime_engine_test_set_clock(deadline+1)};
    assert(event(engine::cancel_ready(ref mut owner,success.run)).value==42);
    assert(scalar(ref owner,success.run).phase==3);
    assert(id(engine::destroy_instance(ref mut owner,success.run))==success.run);
    assert(id(engine::destroy_instance(ref mut owner,unstarted))==unstarted);
    stopped(ref mut owner,cancelled,1,before,9999984,0);
    stopped(ref mut owner,fatal,3,before,9999984,0);
    stopped(ref mut owner,expired,2,deadline,9999984,0);
    stopped(ref mut owner,late,2,deadline,9999984,0);
    stopped(ref mut owner,tie,1,deadline,9999984,0);
    stopped(ref mut owner,staged,2,deadline,9999972,12);
    ledger(ref owner,0,8*63776);

    unsafe{bc_runtime_engine_test_set_clock(18446744073709551615)};
    unsafe{probe_rebase()};
    rejected(engine::prepare_scalar_host(ref mut owner,p,ref run),8);
    assert(unsafe{probe_attempts()}==0);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn Result<usize,u8> real_deadline(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let engine::HostRequest asked=waiting(ref mut owner,p,ref run);
    let usize now=unsafe{bc_runtime_engine_monotonic_ticks()};
    unsafe{bc_runtime_engine_test_wait_for_clock(now,10000000)};
    assert(event(engine::step_instance(ref mut owner,asked.run,8)).kind==2);
    let host::ScalarEvent expired=scalar(ref owner,asked.run);
    assert(expired.host.terminal_at>=now+10000000);
    stopped(ref mut owner,asked,2,expired.host.terminal_at,9999984,0);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn ref u8[] mixed_catalog(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"bool\",\"i64\",\"u32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";}
fn Result<ir::Program,u8> mixed_code(){
    var ir::Program code=ir::empty();
    let usize yes=switch(ir::boolean(ref mut code,true,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize signed=switch(ir::integer(ref mut code,-4294967297,9,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize unsigned=switch(ir::integer(ref mut code,4000000000,11,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize at=code.count*8;
    let usize received=switch(ir::emit(ref mut code,programs::typed_request_opcode(),yes,0,0)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    code.code[at+4]=3;code.types[received]=1;
    let usize returned=switch(ir::emit(ref mut code,8,received,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    code.function_count=1;let usize end=code.count;let usize registers=code.registers;
    code.ends[0]=end;code.register_ends[0]=registers;code.return_types[0]=1;
    return .ok(code);
}
fn void check_mixed(ref engine::Engine owner,usize instance){
    let ref u8[] payload=switch(engine::host_request_payload(owner,instance)){
        case .ok(v):{v}case .err(_):{assert(false);b""}
    };
    let u8[3] tags=[1,4,5];
    let wire::Request decoded=switch(wire::decode_request(payload,ref tags,64)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };
    assert(payload.len==39 && decoded.count==3);
    assert(decoded.fields[0].scalar==1 && decoded.fields[1].scalar==-4294967297 && decoded.fields[2].scalar==4000000000);
}
fn Result<usize,u8> multi_arguments(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(mixed_catalog())?;
    let u32[8] expected=digest(ref imports)?;
    var ir::Program invalid=mixed_code()?;
    invalid.code[28]=2;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(mixed_catalog())?,ref expected,ref run),1);
    invalid.code[28]=3;invalid.types[2]=1;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(mixed_catalog())?,ref expected,ref run),1);
    invalid.types[2]=11;
    // The third argument exists with the right tag but is not defined at PC 3.
    invalid.code[17]=4;invalid.types[4]=11;
    invalid.registers=5;invalid.register_ends[0]=5;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(mixed_catalog())?,ref expected,ref run),4);
    let ir::Program code=mixed_code()?;
    assert(!verifier::verify(ref code).is_ok);
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize instance=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let engine::Event suspended=event(engine::step_instance(ref mut owner,instance,8));
    assert(suspended.kind==4 && suspended.remaining==9999957);
    check_mixed(ref owner,instance);
    let host::ScalarEvent requested=scalar(ref owner,instance);
    assert(requested.host.run==instance && requested.host.request==1);
    assert(event(engine::reply_scalar_host(ref mut owner,instance,instance,1,0,answer())).kind==0);
    let engine::Event done=event(engine::step_instance(ref mut owner,instance,8));
    assert(done.kind==1 && done.value==42 && done.remaining==9999944);
    assert(id(engine::destroy_instance(ref mut owner,instance))==instance);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn ref u8[] byte_catalog(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"},{\"id\":1,\"module\":\"host::example\",\"symbol\":\"next\",\"parameters\":[\"ref u8[]\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";}
fn Result<ir::Program,u8> byte_code(){
    var ir::Program code=ir::empty();
    let usize input=switch(ir::emit(ref mut code,119,0,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    code.types[input]=14;code.code[4]=3;code.list_used=3;
    code.list_operands[0]=97;code.list_operands[1]=0;code.list_operands[2]=255;
    let usize value=switch(ir::emit(ref mut code,programs::typed_request_opcode(),input,0,0)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    code.types[value]=14;code.code[12]=1;
    let usize size=switch(ir::emit(ref mut code,120,value,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    code.types[size]=1;
    let usize acknowledged=switch(ir::emit(ref mut code,programs::typed_request_opcode(),value,1,0)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    code.types[acknowledged]=1;code.code[28]=1;
    let usize total=switch(ir::emit(ref mut code,2,size,acknowledged,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize returned=switch(ir::emit(ref mut code,8,total,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    code.function_count=1;let usize end=code.count;let usize registers=code.registers;
    code.ends[0]=end;code.register_ends[0]=registers;code.return_types[0]=1;
    return .ok(code);
}
fn void check_bytes(ref engine::Engine owner,usize instance,ref u8[] expected){
    let ref u8[] payload=switch(engine::host_request_payload(owner,instance)){
        case .ok(v):{v}case .err(_):{assert(false);b""}
    };
    let u8[1] tags=[7];
    let wire::Request decoded=switch(wire::decode_request(payload,ref tags,wire::payload_limit())){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };
    let wire::Field field=decoded.fields[0];
    assert(field.length==expected.len && bytes::equal(payload[field.start..field.start+field.length],expected));
}
fn Result<usize,u8> variable_bytes(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(byte_catalog())?;
    let u32[8] expected=digest(ref imports)?;
    var ir::Program invalid=byte_code()?;
    invalid.code[4]=4;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(byte_catalog())?,ref expected,ref run),4);
    let ir::Program code=byte_code()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize a=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize b=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    assert(event(engine::step_instance(ref mut owner,a,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,b,8)).kind==4);
    check_bytes(ref owner,a,b"a\x00\xff");
    check_bytes(ref owner,b,b"a\x00\xff");
    assert(!engine::reply_scalar_host(ref mut owner,a,b,1,0,b"\x07\x00\x00\x00\x02\x00\x00\x00x").is_ok);
    assert(!engine::reply_scalar_host(ref mut owner,a,a,1,0,b"\x07\x00\x00\x00\x02\x00\x00\x00x").is_ok);
    assert(event(engine::reply_scalar_host(ref mut owner,a,a,1,0,b"\x07\x00\x00\x00\x06\x00\x00\x00hello\xff")).kind==0);
    assert(event(engine::receive_host_reply(ref mut owner,b,b,1,0,8,0,b"\x07\x00\x00\x00\x00\x00\x00\x00")).kind==0);
    assert(event(engine::step_instance(ref mut owner,a,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,b,8)).kind==4);
    check_bytes(ref owner,a,b"hello\xff");check_bytes(ref owner,b,b"");
    assert(event(engine::reply_scalar_host(ref mut owner,a,a,2,0,answer())).kind==0);
    assert(event(engine::reply_scalar_host(ref mut owner,b,b,2,0,answer())).kind==0);
    assert(event(engine::step_instance(ref mut owner,a,8)).value==48);
    assert(event(engine::step_instance(ref mut owner,b,8)).value==42);
    assert(id(engine::destroy_instance(ref mut owner,a))==a);
    assert(id(engine::destroy_instance(ref mut owner,b))==b);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn ref u8[] result_catalog(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"},{\"id\":1,\"module\":\"host::example\",\"symbol\":\"next\",\"parameters\":[\"u32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";}
fn Result<ir::Program,u8> result_code(){
    var ir::Program code=ir::empty();
    let usize argument=switch(ir::literal(ref mut code,41,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize ok=switch(ir::emit(ref mut code,programs::result_request_opcode(),argument,0,0)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    code.types[ok]=1;code.code[12]=1;code.code[13]=2;code.code[14]=3;
    code.types[2]=11;code.registers=3;
    let usize done=switch(ir::emit(ref mut code,8,ok,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    let usize recovered=switch(ir::emit(ref mut code,programs::typed_request_opcode(),2,1,0)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    code.types[recovered]=1;code.code[28]=1;
    let usize returned=switch(ir::emit(ref mut code,8,recovered,0,0)){case .ok(v):{v}case .err(_):{return .err(1);}};
    code.function_count=1;let usize end=code.count;let usize registers=code.registers;
    code.ends[0]=end;code.register_ends[0]=registers;code.return_types[0]=1;
    return .ok(code);
}
fn void check_u32_error(ref engine::Engine owner,usize instance){
    let ref u8[] payload=switch(engine::host_request_payload(owner,instance)){
        case .ok(v):{v}case .err(_):{assert(false);b""}
    };
    assert(bytes::equal(payload,b"\x01\x00\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff"));
}
fn Result<usize,u8> result_branch(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(result_catalog())?;
    let u32[8] expected=digest(ref imports)?;
    var ir::Program invalid=result_code()?;
    invalid.code[28]=0;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(result_catalog())?,ref expected,ref run),1);
    invalid.code[28]=1;invalid.code[18]=2;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(result_catalog())?,ref expected,ref run),4);
    invalid.code[18]=1;invalid.code[14]=2;
    rejected(engine::retain_scalar_host(ref mut owner,ref invalid,catalog_from(result_catalog())?,ref expected,ref run),4);
    let ir::Program code=result_code()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize a=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize b=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize c=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    assert(event(engine::step_instance(ref mut owner,a,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,b,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,c,8)).kind==4);
    assert(event(engine::reply_scalar_host(ref mut owner,a,a,1,0,answer())).kind==0);
    let ref u8[] host_error=b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff";
    let usize fuel=scalar(ref owner,b).host.fuel;
    assert(event(engine::receive_host_reply(ref mut owner,b,b,1,1,12,0,host_error[..9])).remaining==fuel);
    receiving_invisible(ref owner,b,fuel);
    assert(!engine::receive_host_reply(ref mut owner,b,b,1,0,12,9,host_error[9..]).is_ok);
    assert(event(engine::receive_host_reply(ref mut owner,b,b,1,1,12,9,host_error[9..])).remaining==fuel-12);
    assert(event(engine::receive_host_reply(ref mut owner,c,c,1,2,0,0,b"")).kind==2);
    assert(scalar(ref owner,c).host.cause==3);
    assert(event(engine::step_instance(ref mut owner,a,8)).value==42);
    assert(event(engine::step_instance(ref mut owner,b,8)).kind==4);
    check_u32_error(ref owner,b);
    assert(event(engine::reply_scalar_host(ref mut owner,b,b,2,0,b"\x03\x00\x00\x00\x04\x00\x00\x00\xf9\xff\xff\xff")).kind==0);
    assert(event(engine::step_instance(ref mut owner,b,8)).value==-7);
    assert(id(engine::destroy_instance(ref mut owner,a))==a);
    assert(id(engine::destroy_instance(ref mut owner,b))==b);
    assert(id(engine::destroy_instance(ref mut owner,c))==c);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn Result<bytes::Buffer,u8> large_reply(){
    var bytes::Buffer message=switch(bytes::with_capacity(8203)){case .ok(v):{v}case .err(_):{return .err(1);}};
    assert(bytes::resize_zeroed(ref mut message,8203).is_ok);
    {
        let ref mut u8[] data=bytes::view_mut(ref mut message);
        data[0]=7;data[4]=3;data[5]=32;
        var usize i=8;
        while(i<data.len){
            data[i]=if(i%2==0){165}else{90};i+=1;
        }
        data[8202]=255;
    }
    return .ok(message);
}
fn void invisible_reply(ref engine::Engine owner,usize instance,usize fuel){
    let host::ScalarEvent pending=scalar(owner,instance);
    assert(pending.phase==2 && pending.host.phase==2 && pending.value==0);
    assert(pending.host.calls==1 && pending.host.request==1 && pending.host.replies==8203 && pending.host.fuel==fuel);
    assert(!engine::host_request_payload(owner,instance).is_ok);
}
fn usize instance_bytes(ref engine::Engine owner){
    return switch(engine::instance_memory(owner)){case .ok(v):{v.current}case .err(_):{assert(false);0}};
}
fn Result<usize,u8> chunked_reply(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(byte_catalog())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=byte_code()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize complete=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize charge=instance_bytes(ref owner);
    let usize cancelled=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize expired=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize peak=3*charge;
    let bytes::Buffer message=large_reply()?;
    let ref u8[] wire_reply=bytes::view(ref message);
    let usize fuel=10000000-1-14-wire_reply.len;
    stage_large_reply(ref mut owner,complete,wire_reply,fuel);
    stage_large_reply(ref mut owner,cancelled,wire_reply,fuel);
    stage_large_reply(ref mut owner,expired,wire_reply,fuel);
    ledger(ref owner,peak,peak);

    unsafe{probe_rebase()};
    copy_pending(ref mut owner,complete,1,fuel);
    copy_pending(ref mut owner,complete,4096,fuel);
    copy_pending(ref mut owner,complete,4096,fuel);
    copy_pending(ref mut owner,complete,1,fuel);
    assert(!engine::reply_scalar_host(ref mut owner,complete,complete,1,0,wire_reply).is_ok);
    invisible_reply(ref owner,complete,fuel);
    let engine::Event installed=event(engine::step_instance(ref mut owner,complete,1));
    assert(installed.kind==0 && installed.remaining==fuel);
    assert(scalar(ref owner,complete).phase==0 && !engine::host_request_payload(ref owner,complete).is_ok);

    copy_pending(ref mut owner,cancelled,4096,fuel);
    copy_pending(ref mut owner,expired,4096,fuel);
    assert(unsafe{probe_attempts()}==0);
    assert(event(engine::cancel_ready(ref mut owner,cancelled)).kind==3);
    terminal_without_bytes(ref owner,cancelled,1,fuel);
    ledger(ref owner,2*charge,peak);
    assert(event(engine::step_instance(ref mut owner,complete,2)).kind==4);
    check_bytes(ref owner,complete,wire_reply[8..]);
    assert(event(engine::reply_scalar_host(ref mut owner,complete,complete,2,0,answer())).kind==0);
    let engine::Event done=event(engine::step_instance(ref mut owner,complete,8));
    assert(done.kind==1 && done.value==8237);
    ledger(ref owner,charge,peak);

    unsafe{bc_runtime_engine_test_set_clock(10001000)};
    let engine::Event elapsed=event(engine::step_instance(ref mut owner,expired,4096));
    assert(elapsed.kind==2 && elapsed.diagnostic.code.kind==errors::deadline_kind());
    terminal_without_bytes(ref owner,expired,2,fuel);
    assert(event(engine::cancel_ready(ref mut owner,expired)).kind==2);
    terminal_without_bytes(ref owner,expired,2,fuel);
    ledger(ref owner,0,peak);

    assert(id(engine::destroy_instance(ref mut owner,complete))==complete);
    assert(id(engine::destroy_instance(ref mut owner,cancelled))==cancelled);
    assert(id(engine::destroy_instance(ref mut owner,expired))==expired);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn void stage_large_reply(ref mut engine::Engine owner,usize instance,ref u8[] reply,usize fuel){
    assert(event(engine::step_instance(owner,instance,8)).kind==4);
    receive_piece(owner,instance,reply,0,4096);
    receive_piece(owner,instance,reply,4096,8192);
    let engine::Event accepted=receive_piece(owner,instance,reply,8192,reply.len);
    assert(accepted.kind==0 && accepted.remaining==fuel);
}
fn engine::Event receive_piece(ref mut engine::Engine owner,usize instance,ref u8[] reply,usize from,usize to){
    return event(engine::receive_host_reply(owner,instance,instance,1,0,reply.len,from,reply[from..to]));
}
fn void receiving_invisible(ref engine::Engine owner,usize instance,usize fuel){
    let host::ScalarEvent waiting=scalar(owner,instance);
    assert(waiting.phase==5 && waiting.host.phase==4 && waiting.value==0);
    assert(waiting.host.calls==1 && waiting.host.request==1 && waiting.host.replies==0 && waiting.host.fuel==fuel);
    assert(!engine::host_request_payload(owner,instance).is_ok);
}
fn Result<usize,u8> chunked_receive(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(byte_catalog())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=byte_code()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize complete=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize charge=instance_bytes(ref owner);
    let usize cancelled=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize expired=id(engine::prepare_scalar_host(ref mut owner,p,ref run));
    let usize peak=3*charge;
    let bytes::Buffer message=large_reply()?;
    let ref u8[] wire_reply=bytes::view(ref message);
    let usize total=wire_reply.len;
    let usize fuel=10000000-1-14;
    assert(event(engine::step_instance(ref mut owner,complete,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,cancelled,8)).kind==4);
    assert(event(engine::step_instance(ref mut owner,expired,8)).kind==4);

    unsafe{probe_rebase()};
    assert(!engine::reply_scalar_host(ref mut owner,complete,complete,1,0,wire_reply).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total,0,wire_reply[..4097]).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total-1,0,wire_reply[..4096]).is_ok);
    assert(unsafe{probe_attempts()}==0);
    unsafe{bc_runtime_engine_test_fail(0)};
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total,0,wire_reply[..4096]).is_ok);
    unsafe{bc_runtime_engine_test_fail(-1)};
    check_bytes(ref owner,complete,b"a\x00\xff");
    assert(scalar(ref owner,complete).host.fuel==fuel && scalar(ref owner,complete).host.replies==0);
    unsafe{probe_rebase()};

    assert(receive_piece(ref mut owner,complete,wire_reply,0,4096).remaining==fuel);
    assert(receive_piece(ref mut owner,cancelled,wire_reply,0,4096).remaining==fuel);
    assert(receive_piece(ref mut owner,expired,wire_reply,0,4096).remaining==fuel);
    assert(unsafe{probe_attempts()}==3);
    receiving_invisible(ref owner,complete,fuel);
    receiving_invisible(ref owner,cancelled,fuel);
    receiving_invisible(ref owner,expired,fuel);

    unsafe{probe_rebase()};
    assert(!engine::receive_host_reply(ref mut owner,complete,cancelled,1,0,total,4096,wire_reply[4096..8192]).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total,0,wire_reply[..4096]).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total,4097,wire_reply[4097..8192]).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,complete,complete,1,0,total+1,4096,wire_reply[4096..8192]).is_ok);
    assert(event(engine::step_instance(ref mut owner,complete,4096)).kind==0);
    receiving_invisible(ref owner,complete,fuel);
    assert(receive_piece(ref mut owner,complete,wire_reply,4096,8192).remaining==fuel);
    receiving_invisible(ref owner,complete,fuel);
    assert(receive_piece(ref mut owner,complete,wire_reply,8192,total-1).remaining==fuel);
    receiving_invisible(ref owner,complete,fuel);
    assert(receive_piece(ref mut owner,complete,wire_reply,total-1,total).remaining==fuel-total);
    invisible_reply(ref owner,complete,fuel-total);
    assert(unsafe{probe_attempts()}==0);

    assert(event(engine::cancel_ready(ref mut owner,cancelled)).kind==3);
    assert(!engine::receive_host_reply(ref mut owner,cancelled,cancelled,1,0,total,4096,wire_reply[4096..8192]).is_ok);
    terminated_receive(ref owner,cancelled,1,fuel);
    ledger(ref owner,2*charge,peak);

    assert(event(engine::step_instance(ref mut owner,complete,4096)).kind==0);
    assert(event(engine::step_instance(ref mut owner,complete,4096)).kind==0);
    assert(event(engine::step_instance(ref mut owner,complete,5)).kind==4);
    check_bytes(ref owner,complete,wire_reply[8..]);
    assert(event(engine::reply_scalar_host(ref mut owner,complete,complete,2,0,answer())).kind==0);
    assert(event(engine::step_instance(ref mut owner,complete,8)).value==8237);
    ledger(ref owner,charge,peak);

    unsafe{bc_runtime_engine_test_set_clock(10001000)};
    let engine::Event elapsed=receive_piece(ref mut owner,expired,wire_reply,4096,8192);
    assert(elapsed.kind==2 && elapsed.diagnostic.code.kind==errors::deadline_kind());
    assert(event(engine::cancel_ready(ref mut owner,expired)).kind==2);
    terminated_receive(ref owner,expired,2,fuel);
    ledger(ref owner,0,peak);
    assert(id(engine::destroy_instance(ref mut owner,complete))==complete);
    assert(id(engine::destroy_instance(ref mut owner,cancelled))==cancelled);
    assert(id(engine::destroy_instance(ref mut owner,expired))==expired);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn Result<usize,u8> compact_receive(){
    let policy::Policy ceiling=parsed_policy(true)?;
    let runs::RunConfig run=config(ref ceiling,true)?;
    var engine::Engine owner=configured(ceiling)?;
    let catalog::Catalog imports=catalog_from(json())?;
    let u32[8] expected=digest(ref imports)?;
    let ir::Program code=candidate()?;
    let usize p=id(engine::retain_scalar_host(ref mut owner,ref code,imports,ref expected,ref run));
    let usize done=waiting(ref mut owner,p,ref run).run;
    let usize charge=instance_bytes(ref owner);
    let usize cancelled=waiting(ref mut owner,p,ref run).run;
    let usize expired=waiting(ref mut owner,p,ref run).run;
    let usize empty_cancelled=waiting(ref mut owner,p,ref run).run;
    let usize empty_expired=waiting(ref mut owner,p,ref run).run;
    let usize fuel=9999984;
    let ref u8[] message=answer();
    assert(!engine::receive_host_reply(ref mut owner,done,done,1,0,0,0,b"").is_ok);
    assert(!engine::receive_host_reply(ref mut owner,done,done,1,2,12,0,message[..8]).is_ok);
    assert(!engine::receive_host_reply(ref mut owner,done,done,1,0,13,0,message[..8]).is_ok);
    assert(event(engine::receive_host_reply(ref mut owner,done,done,1,0,12,0,message[..8])).remaining==fuel);
    assert(event(engine::receive_host_reply(ref mut owner,cancelled,cancelled,1,0,12,0,message[..9])).remaining==fuel);
    assert(event(engine::receive_host_reply(ref mut owner,expired,expired,1,0,12,0,message[..11])).remaining==fuel);
    receiving_invisible(ref owner,done,fuel);
    receiving_invisible(ref owner,cancelled,fuel);
    receiving_invisible(ref owner,expired,fuel);
    assert(event(engine::step_instance(ref mut owner,expired,8)).kind==0);
    assert(!engine::receive_host_reply(ref mut owner,done,done,1,2,0,0,b"").is_ok);

    unsafe{probe_rebase()};
    assert(event(engine::receive_host_reply(ref mut owner,done,done,1,0,12,8,message[8..])).remaining==fuel-12);
    assert(unsafe{probe_attempts()}==0);
    assert(scalar(ref owner,done).host.replies==12);
    let engine::Event finished=event(engine::step_instance(ref mut owner,done,8));
    assert(finished.kind==1 && finished.value==42 && finished.remaining==fuel-13);
    assert(event(engine::cancel_ready(ref mut owner,cancelled)).kind==3);
    assert(!engine::receive_host_reply(ref mut owner,cancelled,cancelled,1,0,12,9,message[9..]).is_ok);
    terminated_receive(ref owner,cancelled,1,fuel);
    assert(event(engine::cancel_ready(ref mut owner,empty_cancelled)).kind==3);
    assert(!engine::receive_host_reply(ref mut owner,empty_cancelled,empty_cancelled,1,2,0,0,b"").is_ok);
    terminated_receive(ref owner,empty_cancelled,1,fuel);
    ledger(ref owner,2*charge,5*charge);

    unsafe{bc_runtime_engine_test_set_clock(10001000)};
    let engine::Event elapsed=event(engine::receive_host_reply(ref mut owner,expired,expired,1,0,12,11,message[11..]));
    assert(elapsed.kind==2 && elapsed.diagnostic.code.kind==errors::deadline_kind());
    terminated_receive(ref owner,expired,2,fuel);
    let engine::Event late_empty=event(engine::receive_host_reply(ref mut owner,empty_expired,empty_expired,1,2,0,0,b""));
    assert(late_empty.kind==2 && late_empty.diagnostic.code.kind==errors::deadline_kind());
    terminated_receive(ref owner,empty_expired,2,fuel);
    ledger(ref owner,0,5*charge);

    assert(id(engine::destroy_instance(ref mut owner,done))==done);
    assert(id(engine::destroy_instance(ref mut owner,cancelled))==cancelled);
    assert(id(engine::destroy_instance(ref mut owner,expired))==expired);
    assert(id(engine::destroy_instance(ref mut owner,empty_cancelled))==empty_cancelled);
    assert(id(engine::destroy_instance(ref mut owner,empty_expired))==empty_expired);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
    return .ok(1);
}
fn void terminated_receive(ref engine::Engine owner,usize instance,u8 cause,usize fuel){
    let host::ScalarEvent stopped=scalar(owner,instance);
    assert(stopped.phase==4 && stopped.host.cause==cause && stopped.value==0);
    assert(stopped.host.replies==0 && stopped.host.fuel==fuel && stopped.host.calls==1);
    assert(!engine::host_request_payload(owner,instance).is_ok);
}
fn void copy_pending(ref mut engine::Engine owner,usize instance,usize work,usize fuel){
    let engine::Event partial=event(engine::step_instance(owner,instance,work));
    assert(partial.kind==0 && partial.value==0 && partial.remaining==fuel);
    invisible_reply(owner,instance,fuel);
}
fn void terminal_without_bytes(ref engine::Engine owner,usize instance,u8 cause,usize fuel){
    let host::ScalarEvent final_state=scalar(owner,instance);
    assert(final_state.phase==4 && final_state.value==0 && final_state.host.cause==cause);
    assert(final_state.host.calls==1 && final_state.host.replies==8203 && final_state.host.fuel==fuel);
    assert(!engine::host_request_payload(owner,instance).is_ok);
}
pub fn void run(){
    unsafe{bc_runtime_engine_test_set_clock(1000)};
    assert(admission().is_ok);
    assert(interleaved().is_ok);
    assert(pending_memory().is_ok);
    assert(multi_arguments().is_ok);
    assert(variable_bytes().is_ok);
    assert(result_branch().is_ok);
    assert(chunked_reply().is_ok);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    unsafe{bc_runtime_engine_test_set_clock(1000)};
    assert(chunked_receive().is_ok);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    unsafe{bc_runtime_engine_test_set_clock(1000)};
    assert(compact_receive().is_ok);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    assert(deadline_order().is_ok);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    assert(real_deadline().is_ok);
    assert(unsafe{probe_live()}==0);
}
