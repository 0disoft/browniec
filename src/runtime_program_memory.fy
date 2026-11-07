module runtime_program_memory;
import retention_plan as plans;
pub enum Error { Invalid; Quota; State; }
pub struct Limits { usize engine; usize program; usize programs; }
// Fixed control + retained Program backing only; other Engine costs are pending.
pub struct Budget { usize engine; usize program; usize programs; usize control; usize control_peak; usize retained; usize peak; bool closed; }
pub struct Observation { usize engine_limit; usize program_limit; usize programs_limit; usize control_bytes; usize program_bytes; usize program_peak; usize tracked_bytes; usize tracked_peak; bool closed; }
@link_name("bc_runtime_engine_program_layout") unsafe extern C fn usize layout_raw(u32 kind);
pub fn Limits defaults(){return Limits{.engine=1073741824,.program=67108864,.programs=536870912};}
pub fn Result<Budget,Error> create(Limits limits,usize control){
    if(limits.engine==0 || limits.engine>1073741824 || limits.program==0 || limits.program>67108864 ||
        limits.programs==0 || limits.programs>536870912 || limits.program>limits.programs || limits.programs>limits.engine){return .err(.Invalid);}
    if(control>limits.engine){return .err(.Quota);}
    return .ok(Budget{.engine=limits.engine,.program=limits.program,.programs=limits.programs,.control=control,.control_peak=control,.retained=0,.peak=0,.closed=false});
}
pub fn Observation observe(ref Budget b){
    return Observation{.engine_limit=b.engine,.program_limit=b.program,.programs_limit=b.programs,
        .control_bytes=b.control,.program_bytes=b.retained,.program_peak=b.peak,
        .tracked_bytes=b.control+b.retained,.tracked_peak=b.control_peak+b.peak,.closed=b.closed};
}
fn usize available(ref Budget b){
    let usize aggregate=b.programs-b.retained;let usize combined=b.engine-b.control-b.retained;
    return if(b.program<aggregate){if(b.program<combined){b.program}else{combined}}else{if(aggregate<combined){aggregate}else{combined}};
}
pub fn Result<usize,Error> fixed(u32 kind){
    if(kind>2){return .err(.Invalid);}
    let usize stored=unsafe{layout_raw(2*kind)};let usize handle=unsafe{layout_raw(2*kind+1)};
    let usize maximum=18446744073709551615;
    if(stored==0 || handle==0){return .err(.State);}
    if(stored>maximum/8 || handle>maximum/8 || 8*handle>maximum-8*stored){return .err(.Quota);}
    return .ok(8*stored+8*handle);
}
pub fn Result<plans::Plan,Error> prepare(ref Budget b,u32 kind){
    if(b.closed){return .err(.State);}if(kind>2){return .err(.Invalid);}
    let usize bytes=fixed(kind)?;
    return switch(plans::create(bytes,available(b))){case .ok(v):{.ok(v)}case .err(_):{.err(.Quota)}};
}
pub fn Result<usize,Error> record(ref mut Budget b,ref plans::Plan plan){
    if(b.closed){return .err(.State);}if(!plan.admitted){return .ok(0);}
    if(plan.bytes>available(b)){return .err(.State);}
    let usize planned=b.retained+plan.bytes;if(planned>b.peak){b.peak=planned;}return .ok(plan.bytes);
}
pub fn Result<usize,Error> publish(ref mut Budget b,usize bytes){
    if(b.closed || bytes>available(b)){return .err(.State);}
    b.retained+=bytes;if(b.retained>b.peak){b.peak=b.retained;}return .ok(b.retained);
}
pub fn Result<usize,Error> release(ref mut Budget b,usize bytes){
    if(b.closed || bytes>b.retained){return .err(.State);}b.retained-=bytes;return .ok(b.retained);
}
pub fn Result<usize,Error> close(ref mut Budget b){
    if(b.closed || b.retained!=0){return .err(.State);}b.control=0;b.closed=true;return .ok(0);
}
