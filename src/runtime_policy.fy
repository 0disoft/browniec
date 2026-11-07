module runtime_policy;
import runtime_policy_json as j;
import runtime_policy_limits as limits;

pub resource Policy {
    limits::CompileLimits compile; limits::EngineLimits engine; limits::RunLimits run; limits::WorkerLimits worker;
    j::Capabilities capabilities; cleanup { }
}
pub fn Result<Policy,j::Error> parse(ref u8[] source){
    var j::Cursor c=j::start(source)?;let usize open=j::take(source,ref mut c,123)?;
    var bool[6] seen=[false;6];
    var limits::CompileLimits compile=limits::CompileLimits{.source_bytes=0,.modules=0,.depth=0,.tokens=0,.functions=0,.types=0,.instructions=0,.registers_per_function=0,.working_bytes=0,.fuel=0,.deadline_ms=0,.diagnostics=0};
    var limits::EngineLimits engine=limits::EngineLimits{.memory_bytes=0,.control_bytes=0,.program_bytes=0,.total_program_bytes=0,.instances_bytes=0,.max_programs=0,.max_instances=0,.max_compiles=0};
    var limits::RunLimits run=limits::RunLimits{.memory_bytes=0,.object_bytes=0,.call_frames=0,.input_bytes=0,.output_bytes=0,.host_request_bytes=0,.host_response_bytes=0,.host_calls=0,.owner_entries=0,.descriptor_entries=0,.fuel=0,.deadline_ms=0};
    var limits::WorkerLimits worker=limits::WorkerLimits{.memory_bytes=0,.user_cpu_time_ms=0,.max_processes=0,.transport_bytes=0,.startup_ms=0,.io_idle_ms=0,.shutdown_grace_ms=0,.session_ms=0};
    var j::Capabilities capabilities=j::empty_capabilities();
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,ref mut c,b"schema|compile|engine|run|worker|capabilities")?;
        let usize unique=j::mark(ref mut seen,field,at)?;
        if(field==0){let usize schema=j::constant(source,ref mut c,b"brownie.policy/0.3")?;}
        else if(field==1){compile=limits::compile(source,ref mut c)?;}
        else if(field==2){engine=limits::engine(source,ref mut c)?;}
        else if(field==3){run=limits::run(source,ref mut c)?;}
        else if(field==4){worker=limits::worker(source,ref mut c)?;}
        else{capabilities=j::capabilities(source,ref mut c)?;}
        if(c.token.kind==125){break;}let usize comma=j::take(source,ref mut c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,ref mut c,125)?;
    if(c.token.kind!=0){return .err(j::error(.Json,c.token.begin));}
    if(!limits::relations(compile,engine,run,worker)){return .err(j::error(.Relation,0));}
    return .ok(Policy{.compile=compile,.engine=engine,.run=run,.worker=worker,.capabilities=capabilities});
}
pub fn limits::CompileLimits compile_limits(ref Policy p){return p.compile;}
pub fn limits::EngineLimits engine_limits(ref Policy p){return p.engine;}
pub fn limits::RunLimits run_limits(ref Policy p){return p.run;}
pub fn limits::WorkerLimits worker_limits(ref Policy p){return p.worker;}
pub fn usize capability_count(ref Policy p){return j::count(ref p.capabilities);}
pub fn Result<ref u8[],j::Error> capability(ref Policy p,usize i){return j::capability(ref p.capabilities,i);}
pub fn bool contains_capability(ref Policy p,ref u8[] name){return j::contains(ref p.capabilities,name);}
pub fn bool allows(ref Policy p,ref j::Capabilities caps){return j::subset(caps,ref p.capabilities);}
// Pure metadata comparison; no Engine allocation or host authorization occurs.
pub fn bool allows_run(ref Policy p,limits::RunLimits requested){
    return limits::valid_run(requested) && limits::narrowed(requested,p.run) && limits::relations(p.compile,p.engine,requested,p.worker);
}
