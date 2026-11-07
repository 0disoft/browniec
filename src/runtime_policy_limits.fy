module runtime_policy_limits;
import runtime_policy_json as j;

// Typed accepted design ceilings; these do not change VM storage capacities.
pub struct CompileLimits { usize source_bytes; usize modules; usize depth; usize tokens; usize functions; usize types; usize instructions; usize registers_per_function; usize working_bytes; usize fuel; usize deadline_ms; usize diagnostics; }
pub struct EngineLimits { usize memory_bytes; usize control_bytes; usize program_bytes; usize total_program_bytes; usize instances_bytes; usize max_programs; usize max_instances; usize max_compiles; }
pub struct RunLimits { usize memory_bytes; usize object_bytes; usize call_frames; usize input_bytes; usize output_bytes; usize host_request_bytes; usize host_response_bytes; usize host_calls; usize owner_entries; usize descriptor_entries; usize fuel; usize deadline_ms; }
pub struct WorkerLimits { usize memory_bytes; usize user_cpu_time_ms; usize max_processes; usize transport_bytes; usize startup_ms; usize io_idle_ms; usize shutdown_grace_ms; usize session_ms; }

pub fn Result<CompileLimits,j::Error> compile(ref u8[] source,ref mut j::Cursor c){
    var usize[12] values=[0;12];var bool[12] seen=[false;12];let usize open=j::take(source,c,123)?;
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,c,b"source_bytes|modules|depth|tokens|functions|types|instructions|registers_per_function|working_bytes|fuel|deadline_ms|diagnostics")?;
        let usize unique=j::mark(ref mut seen,field,at)?;var usize minimum=1;var usize maximum=1;
        if(field==0){minimum=1;maximum=262144;}
        else if(field==1){minimum=1;maximum=32;}
        else if(field==2){minimum=1;maximum=128;}
        else if(field==3){minimum=1;maximum=131072;}
        else if(field==4){minimum=1;maximum=4096;}
        else if(field==5){minimum=1;maximum=4096;}
        else if(field==6){minimum=1;maximum=262144;}
        else if(field==7){minimum=1;maximum=1024;}
        else if(field==8){minimum=1;maximum=268435456;}
        else if(field==9){minimum=1;maximum=1000000000;}
        else if(field==10){minimum=1;maximum=60000;}
        else if(field==11){minimum=1;maximum=32;}
        values[field]=j::integer(source,c,minimum,maximum)?;
        if(c.token.kind==125){break;}let usize comma=j::take(source,c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,c,125)?;
    return .ok(CompileLimits{.source_bytes=values[0],.modules=values[1],.depth=values[2],.tokens=values[3],.functions=values[4],.types=values[5],.instructions=values[6],.registers_per_function=values[7],.working_bytes=values[8],.fuel=values[9],.deadline_ms=values[10],.diagnostics=values[11]});
}
pub fn Result<EngineLimits,j::Error> engine(ref u8[] source,ref mut j::Cursor c){
    var usize[8] values=[0;8];var bool[8] seen=[false;8];let usize open=j::take(source,c,123)?;
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,c,b"memory_bytes|control_bytes|program_bytes|total_program_bytes|instances_bytes|max_programs|max_instances|max_compiles")?;
        let usize unique=j::mark(ref mut seen,field,at)?;var usize minimum=1;var usize maximum=1;
        if(field==0){minimum=1;maximum=1073741824;}
        else if(field==1){minimum=1;maximum=4194304;}
        else if(field==2){minimum=1;maximum=67108864;}
        else if(field==3){minimum=1;maximum=536870912;}
        else if(field==4){minimum=1;maximum=536870912;}
        else if(field==5){minimum=1;maximum=1024;}
        else if(field==6){minimum=1;maximum=1024;}
        else if(field==7){minimum=1;maximum=1;}
        values[field]=j::integer(source,c,minimum,maximum)?;
        if(c.token.kind==125){break;}let usize comma=j::take(source,c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,c,125)?;
    return .ok(EngineLimits{.memory_bytes=values[0],.control_bytes=values[1],.program_bytes=values[2],.total_program_bytes=values[3],.instances_bytes=values[4],.max_programs=values[5],.max_instances=values[6],.max_compiles=values[7]});
}
pub fn Result<RunLimits,j::Error> run(ref u8[] source,ref mut j::Cursor c){
    var usize[12] values=[0;12];var bool[12] seen=[false;12];let usize open=j::take(source,c,123)?;
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,c,b"memory_bytes|object_bytes|call_frames|input_bytes|output_bytes|host_request_bytes|host_response_bytes|host_calls|owner_entries|descriptor_entries|fuel|deadline_ms")?;
        let usize unique=j::mark(ref mut seen,field,at)?;var usize minimum=1;var usize maximum=1;
        if(field==0){minimum=1;maximum=268435456;}
        else if(field==1){minimum=1;maximum=16777216;}
        else if(field==2){minimum=1;maximum=4096;}
        else if(field==3){minimum=0;maximum=1048576;}
        else if(field==4){minimum=0;maximum=1048576;}
        else if(field==5){minimum=1;maximum=1048576;}
        else if(field==6){minimum=1;maximum=1048576;}
        else if(field==7){minimum=0;maximum=65535;}
        else if(field==8){minimum=1;maximum=16384;}
        else if(field==9){minimum=1;maximum=16384;}
        else if(field==10){minimum=1;maximum=1000000000000;}
        else if(field==11){minimum=1;maximum=60000;}
        values[field]=j::integer(source,c,minimum,maximum)?;
        if(c.token.kind==125){break;}let usize comma=j::take(source,c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,c,125)?;
    return .ok(RunLimits{.memory_bytes=values[0],.object_bytes=values[1],.call_frames=values[2],.input_bytes=values[3],.output_bytes=values[4],.host_request_bytes=values[5],.host_response_bytes=values[6],.host_calls=values[7],.owner_entries=values[8],.descriptor_entries=values[9],.fuel=values[10],.deadline_ms=values[11]});
}
pub fn Result<WorkerLimits,j::Error> worker(ref u8[] source,ref mut j::Cursor c){
    var usize[8] values=[0;8];var bool[8] seen=[false;8];let usize open=j::take(source,c,123)?;
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,c,b"memory_bytes|user_cpu_time_ms|max_processes|transport_bytes|startup_ms|io_idle_ms|shutdown_grace_ms|session_ms")?;
        let usize unique=j::mark(ref mut seen,field,at)?;var usize minimum=1;var usize maximum=1;
        if(field==0){minimum=1;maximum=2147483648;}
        else if(field==1){minimum=1;maximum=120000;}
        else if(field==2){minimum=1;maximum=1;}
        else if(field==3){minimum=4194304;maximum=4194304;}
        else if(field==4){minimum=1;maximum=60000;}
        else if(field==5){minimum=1;maximum=60000;}
        else if(field==6){minimum=1;maximum=5000;}
        else if(field==7){minimum=1;maximum=120000;}
        values[field]=j::integer(source,c,minimum,maximum)?;
        if(c.token.kind==125){break;}let usize comma=j::take(source,c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,c,125)?;
    return .ok(WorkerLimits{.memory_bytes=values[0],.user_cpu_time_ms=values[1],.max_processes=values[2],.transport_bytes=values[3],.startup_ms=values[4],.io_idle_ms=values[5],.shutdown_grace_ms=values[6],.session_ms=values[7]});
}

pub fn bool run_relations(RunLimits r){
    return r.object_bytes<=r.memory_bytes && r.input_bytes<=r.memory_bytes && r.output_bytes<=r.memory_bytes &&
        r.host_request_bytes<=r.memory_bytes && r.host_response_bytes<=r.memory_bytes;
}
pub fn bool relations(CompileLimits c,EngineLimits e,RunLimits r,WorkerLimits w){
    // Subtraction preflights the worker headroom relation without overflowing.
    return run_relations(r) && r.memory_bytes<=e.instances_bytes && e.program_bytes<=e.total_program_bytes &&
        c.working_bytes<=e.memory_bytes && e.control_bytes<=e.memory_bytes && e.total_program_bytes<=e.memory_bytes &&
        e.instances_bytes<=e.memory_bytes && w.memory_bytes>=37748736 && w.transport_bytes<=w.memory_bytes-37748736 &&
        e.memory_bytes<=w.memory_bytes-37748736-w.transport_bytes &&
        c.source_bytes<=c.working_bytes && w.startup_ms<=w.session_ms && c.deadline_ms<=w.session_ms && r.deadline_ms<=w.session_ms;
}
pub fn bool narrowed(RunLimits requested,RunLimits ceiling){
    return requested.memory_bytes<=ceiling.memory_bytes &&
        requested.object_bytes<=ceiling.object_bytes &&
        requested.call_frames<=ceiling.call_frames &&
        requested.input_bytes<=ceiling.input_bytes &&
        requested.output_bytes<=ceiling.output_bytes &&
        requested.host_request_bytes<=ceiling.host_request_bytes &&
        requested.host_response_bytes<=ceiling.host_response_bytes &&
        requested.host_calls<=ceiling.host_calls &&
        requested.owner_entries<=ceiling.owner_entries &&
        requested.descriptor_entries<=ceiling.descriptor_entries &&
        requested.fuel<=ceiling.fuel &&
        requested.deadline_ms<=ceiling.deadline_ms;
}

pub fn bool valid_run(RunLimits r){
    return r.memory_bytes>=1 && r.memory_bytes<=268435456 &&
        r.object_bytes>=1 && r.object_bytes<=16777216 &&
        r.call_frames>=1 && r.call_frames<=4096 &&
        r.input_bytes>=0 && r.input_bytes<=1048576 &&
        r.output_bytes>=0 && r.output_bytes<=1048576 &&
        r.host_request_bytes>=1 && r.host_request_bytes<=1048576 &&
        r.host_response_bytes>=1 && r.host_response_bytes<=1048576 &&
        r.host_calls>=0 && r.host_calls<=65535 &&
        r.owner_entries>=1 && r.owner_entries<=16384 &&
        r.descriptor_entries>=1 && r.descriptor_entries<=16384 &&
        r.fuel>=1 && r.fuel<=1000000000000 &&
        r.deadline_ms>=1 && r.deadline_ms<=60000;
}
