module runtime_program_memory;
import retention_plan as plans;
import compile_memory as compile_memory;
import module_budgeted_compile as budgeted;
pub enum Error { Invalid; Quota; State; }
pub struct Limits { usize engine; usize program; usize programs; }
// Compile source ownership shares the combined limit with the other ledgers.
// Large lowering scratch uses an operation-local plan and records its peak.
pub struct Budget { usize engine; usize program; usize programs; usize control; usize control_peak; usize retained; usize peak; bool closed; usize working_limit; usize working_peak; usize tracked_peak; usize external; usize compile_source; }
pub struct Observation { usize engine_limit; usize program_limit; usize programs_limit; usize control_bytes; usize program_bytes; usize program_peak; usize tracked_bytes; usize tracked_peak; bool closed; usize working_limit; usize working_peak; usize external_bytes; usize compile_source_bytes; }
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
    return .ok(Budget{.engine=limits.engine,.program=limits.program,.programs=limits.programs,.control=control,.control_peak=control,.retained=0,.peak=0,.closed=false,.working_limit=working_limit,.working_peak=0,.tracked_peak=control,.external=0,.compile_source=0});
}
pub fn Observation observe(ref Budget b){
    return Observation{.engine_limit=b.engine,.program_limit=b.program,.programs_limit=b.programs,
        .control_bytes=b.control,.program_bytes=b.retained,.program_peak=b.peak,
        .tracked_bytes=b.control+b.retained+b.external+b.compile_source,.tracked_peak=b.tracked_peak,.closed=b.closed,
        .working_limit=b.working_limit,.working_peak=b.working_peak,.external_bytes=b.external,.compile_source_bytes=b.compile_source};
}
pub fn Result<usize,Error> hold_compile_source(ref mut Budget b,usize bytes){
    if(b.closed || b.compile_source!=0 || bytes==0){return .err(.State);}
    if(bytes>b.working_limit || bytes>b.engine-b.control-b.retained-b.external){return .err(.Quota);}
    b.compile_source=bytes;
    let usize total=b.control+b.retained+b.external+bytes;
    if(total>b.tracked_peak){b.tracked_peak=total;}
    if(bytes>b.working_peak){b.working_peak=bytes;}
    return .ok(bytes);
}
pub fn Result<usize,Error> release_compile_source(ref mut Budget b,usize bytes){
    if(b.closed || bytes==0 || bytes!=b.compile_source){return .err(.State);}
    b.compile_source=0;
    return .ok(0);
}
// Lowering admits its full peak before allocating the candidate. The backing
// stays charged after its scratch unwinds and until terminal cleanup.
pub fn Result<usize,Error> hold_compile_candidate(ref mut Budget b,usize bytes){
    if(b.closed || b.compile_source==0 || bytes==0){return .err(.State);}
    if(bytes>b.working_limit-b.compile_source ||
        bytes>b.engine-b.control-b.retained-b.external-b.compile_source){return .err(.Quota);}
    b.compile_source+=bytes;
    let usize total=b.control+b.retained+b.external+b.compile_source;
    if(total>b.tracked_peak){b.tracked_peak=total;}
    if(b.compile_source>b.working_peak){b.working_peak=b.compile_source;}
    return .ok(b.compile_source);
}
// overhead is the still-live adopted Index + incoming Entry vector heap.
// Prove admission on a copy: the real wrapper must reserve the phase-0 plan.
pub fn Result<compile_memory::Plan,Error> prepare_compile(ref mut Budget b,usize overhead){
    if(b.closed){return .err(.State);}
    if(b.compile_source>b.working_limit || overhead>b.working_limit-b.compile_source){return .err(.Quota);}
    let usize source=b.compile_source+overhead;
    if(budgeted::working_bound()>b.working_limit-source){return .err(.Quota);}
    if(b.control>b.engine || b.retained>b.engine-b.control ||
        b.external>b.engine-b.control-b.retained ||
        b.compile_source>b.engine-b.control-b.retained-b.external ||
        overhead>b.engine-b.control-b.retained-b.external-b.compile_source){return .err(.Quota);}
    let usize baseline=b.control+b.retained+b.external+b.compile_source+overhead;
    let compile_memory::Plan plan=switch(compile_memory::create(
        compile_memory::Limits{.working=b.working_limit-source,.combined=b.engine},baseline)){
        case .ok(p):{p}case .err(e):{return .err(switch(e){case .Invalid:{.Invalid}case .Quota:{.Quota}case .State:{.State}});}
    };
    var compile_memory::Plan proof=plan;
    switch(compile_memory::reserve_work(ref mut proof,budgeted::working_bound())){
        case .ok(_):{}case .err(e):{return .err(switch(e){case .Invalid:{.Invalid}case .Quota:{.Quota}case .State:{.State}});}
    };
    let usize work=source+budgeted::working_bound();
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
// Other owning Engine classes share this ceiling, but keep separate lifetime
// ledgers. Preparation records a peak without changing current ownership.
pub fn Result<usize,Error> prepare_external(ref mut Budget b,usize peak){
    if(b.closed || peak<b.external){return .err(.State);}
    if(peak>b.engine-b.control-b.retained-b.compile_source){return .err(.Quota);}
    let usize total=b.control+b.retained+b.compile_source+peak;
    if(total>b.tracked_peak){b.tracked_peak=total;}return .ok(total);
}
pub fn Result<usize,Error> commit_external(ref mut Budget b,usize bytes){
    if(b.closed || bytes>b.engine-b.control-b.retained-b.compile_source){return .err(.State);}
    b.external=bytes;let usize total=b.control+b.retained+b.compile_source+bytes;
    if(total>b.tracked_peak){b.tracked_peak=total;}return .ok(bytes);
}
fn usize available_after_transfer(ref Budget b,usize transfer){
    let usize aggregate=b.programs-b.retained;let usize combined=b.engine-b.control-b.retained-b.external-(b.compile_source-transfer);
    return if(b.program<aggregate){if(b.program<combined){b.program}else{combined}}else{if(aggregate<combined){aggregate}else{combined}};
}
fn usize available(ref Budget b){return available_after_transfer(b,0);}
pub fn Result<usize,Error> fixed(u32 kind){
    if(kind>2){return .err(.Invalid);}
    let usize stored=unsafe{layout_raw(2*kind)};let usize handle=unsafe{layout_raw(2*kind+1)};
    let usize maximum=18446744073709551615;
    if(stored==0 || handle==0){return .err(.State);}
    if(stored>maximum/8 || handle>maximum/8 || 8*handle>maximum-8*stored){return .err(.Quota);}
    return .ok(8*stored+8*handle);
}
pub fn Result<plans::Plan,Error> prepare(ref Budget b,u32 kind){
    return prepare_transfer(b,kind,0);
}
pub fn Result<plans::Plan,Error> prepare_transfer(ref Budget b,u32 kind,usize transfer){
    if(b.closed || transfer>b.compile_source){return .err(.State);}if(kind>2){return .err(.Invalid);}
    let usize bytes=fixed(kind)?;
    return switch(plans::create(bytes,available_after_transfer(b,transfer))){case .ok(v):{.ok(v)}case .err(_):{.err(.Quota)}};
}
pub fn Result<usize,Error> record(ref mut Budget b,ref plans::Plan plan){
    return record_transfer(b,plan,0);
}
pub fn Result<usize,Error> record_transfer(ref mut Budget b,ref plans::Plan plan,usize transfer){
    if(b.closed || transfer>b.compile_source){return .err(.State);}if(!plan.admitted){return .ok(0);}
    if(plan.bytes>available_after_transfer(b,transfer)){return .err(.State);}
    let usize planned=b.retained+plan.bytes;if(planned>b.peak){b.peak=planned;}
    let usize tracked=b.control+planned+b.external+(b.compile_source-transfer);if(tracked>b.tracked_peak){b.tracked_peak=tracked;}return .ok(plan.bytes);
}
pub fn Result<usize,Error> publish(ref mut Budget b,usize bytes){
    if(b.closed || bytes>available(b)){return .err(.State);}
    b.retained+=bytes;if(b.retained>b.peak){b.peak=b.retained;}
    let usize tracked=b.control+b.retained+b.external+b.compile_source;if(tracked>b.tracked_peak){b.tracked_peak=tracked;}return .ok(b.retained);
}
pub fn Result<usize,Error> release(ref mut Budget b,usize bytes){
    if(b.closed || bytes>b.retained){return .err(.State);}b.retained-=bytes;return .ok(b.retained);
}
pub fn Result<usize,Error> close(ref mut Budget b){
    if(b.closed || b.retained!=0 || b.external!=0 || b.compile_source!=0){return .err(.State);}b.control=0;b.closed=true;return .ok(0);
}
