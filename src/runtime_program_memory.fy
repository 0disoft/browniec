module runtime_program_memory;
import retention_plan as plans;
import compile_memory as compile_memory;
import module_budgeted_compile as budgeted;
pub enum Error { Invalid; Quota; State; }
pub struct Limits { usize engine; usize program; usize programs; }
// Compiler scopes are synchronous/nonreentrant; only their historical peaks live
// here. Other Engine costs are pending. Append fields to preserve existing order.
pub struct Budget { usize engine; usize program; usize programs; usize control; usize control_peak; usize retained; usize peak; bool closed; usize working_limit; usize working_peak; usize tracked_peak; }
pub struct Observation { usize engine_limit; usize program_limit; usize programs_limit; usize control_bytes; usize program_bytes; usize program_peak; usize tracked_bytes; usize tracked_peak; bool closed; usize working_limit; usize working_peak; }
@link_name("bc_runtime_engine_program_layout") unsafe extern C fn usize layout_raw(u32 kind);
pub fn Limits defaults(){return Limits{.engine=1073741824,.program=67108864,.programs=536870912};}
pub fn Result<Budget,Error> create(Limits limits,usize control){
    return create_with_working(limits,control,268435456);
}
pub fn Result<Budget,Error> create_with_working(Limits limits,usize control,usize working_limit){
    if(limits.engine==0 || limits.engine>1073741824 || limits.program==0 || limits.program>67108864 ||
        limits.programs==0 || limits.programs>536870912 || limits.program>limits.programs || limits.programs>limits.engine ||
        working_limit==0 || working_limit>268435456){return .err(.Invalid);}
    if(control>limits.engine){return .err(.Quota);}
    return .ok(Budget{.engine=limits.engine,.program=limits.program,.programs=limits.programs,.control=control,.control_peak=control,.retained=0,.peak=0,.closed=false,.working_limit=working_limit,.working_peak=0,.tracked_peak=control});
}
pub fn Observation observe(ref Budget b){
    return Observation{.engine_limit=b.engine,.program_limit=b.program,.programs_limit=b.programs,
        .control_bytes=b.control,.program_bytes=b.retained,.program_peak=b.peak,
        .tracked_bytes=b.control+b.retained,.tracked_peak=b.tracked_peak,.closed=b.closed,
        .working_limit=b.working_limit,.working_peak=b.working_peak};
}
// overhead is the still-live adopted Index + incoming Entry vector heap.
// Prove admission on a copy: the real wrapper must reserve the phase-0 plan.
pub fn Result<compile_memory::Plan,Error> prepare_compile(ref mut Budget b,usize overhead){
    if(b.closed){return .err(.State);}
    if(overhead>b.working_limit || budgeted::working_bound()>b.working_limit-overhead){return .err(.Quota);}
    if(b.control>b.engine || b.retained>b.engine-b.control ||
        overhead>b.engine-b.control-b.retained){return .err(.Quota);}
    let usize baseline=b.control+b.retained+overhead;
    let compile_memory::Plan plan=switch(compile_memory::create(
        compile_memory::Limits{.working=b.working_limit-overhead,.combined=b.engine},baseline)){
        case .ok(p):{p}case .err(e):{return .err(switch(e){case .Invalid:{.Invalid}case .Quota:{.Quota}case .State:{.State}});}
    };
    var compile_memory::Plan proof=plan;
    switch(compile_memory::reserve_work(ref mut proof,budgeted::working_bound())){
        case .ok(_):{}case .err(e):{return .err(switch(e){case .Invalid:{.Invalid}case .Quota:{.Quota}case .State:{.State}});}
    };
    let usize work=overhead+budgeted::working_bound();
    if(work>b.working_peak){b.working_peak=work;}
    if(proof.peak>b.tracked_peak){b.tracked_peak=proof.peak;}
    return .ok(plan);
}
// Trusted plan from prepare_compile, after the real wrapper (including admitted
// OOM). Persistent reservations are recorded/published separately, never here.
pub fn Result<usize,Error> record_compile(ref mut Budget b,ref compile_memory::Plan p){
    if(b.closed){return .err(.State);}
    if(p.peak>b.tracked_peak){b.tracked_peak=p.peak;}
    return .ok(p.peak);
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
    let usize planned=b.retained+plan.bytes;if(planned>b.peak){b.peak=planned;}
    let usize tracked=b.control+planned;if(tracked>b.tracked_peak){b.tracked_peak=tracked;}return .ok(plan.bytes);
}
pub fn Result<usize,Error> publish(ref mut Budget b,usize bytes){
    if(b.closed || bytes>available(b)){return .err(.State);}
    b.retained+=bytes;if(b.retained>b.peak){b.peak=b.retained;}
    let usize tracked=b.control+b.retained;if(tracked>b.tracked_peak){b.tracked_peak=tracked;}return .ok(b.retained);
}
pub fn Result<usize,Error> release(ref mut Budget b,usize bytes){
    if(b.closed || bytes>b.retained){return .err(.State);}b.retained-=bytes;return .ok(b.retained);
}
pub fn Result<usize,Error> close(ref mut Budget b){
    if(b.closed || b.retained!=0){return .err(.State);}b.control=0;b.closed=true;return .ok(0);
}
