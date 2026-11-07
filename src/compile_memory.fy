module compile_memory;

// Trusted scalar reservations, not allocator instrumentation or RSS accounting.
// Baseline belongs to external owners and is never released by this plan.
pub enum Error { Invalid; Quota; State; }
pub struct Limits { usize working; usize combined; }
// Keep state flat for pinned compiler composition. Only this API mutates it.
pub struct Plan {
    usize working_limit; usize combined_limit; usize baseline;
    usize working_bytes; usize persistent_bytes; usize current; usize peak;
    u8 phase;
}
pub struct Observation {
    usize working_limit; usize combined_limit; usize baseline;
    usize working_bytes; usize persistent_bytes; usize current; usize peak;
    u8 phase;
}

// Legacy callers may opt into the same phases without additional quota denial.
pub fn Plan unlimited() {
    return Plan{.working_limit=18446744073709551615,
        .combined_limit=18446744073709551615,.baseline=0,
        .working_bytes=0,.persistent_bytes=0,.current=0,.peak=0,.phase=0};
}

pub fn Result<Plan,Error> create(Limits limits,usize baseline) {
    if(limits.working==0 || limits.combined==0){return .err(.Invalid);}
    if(baseline>limits.combined){return .err(.Quota);}
    return .ok(Plan{.working_limit=limits.working,.combined_limit=limits.combined,
        .baseline=baseline,.working_bytes=0,.persistent_bytes=0,
        .current=baseline,.peak=baseline,.phase=0});
}

pub fn Observation observe(ref Plan plan) {
    return Observation{.working_limit=plan.working_limit,
        .combined_limit=plan.combined_limit,.baseline=plan.baseline,
        .working_bytes=plan.working_bytes,.persistent_bytes=plan.persistent_bytes,
        .current=plan.current,.peak=plan.peak,.phase=plan.phase};
}

// Every rejection preserves all fields. Subtract before adding, even at MAX.
pub fn Result<usize,Error> reserve_work(ref mut Plan plan,usize bytes) {
    if(plan.phase!=0){return .err(.State);}
    if(bytes>plan.working_limit || bytes>plan.combined_limit-plan.baseline){
        return .err(.Quota);
    }
    let usize next=plan.baseline+bytes;
    plan.working_bytes=bytes;
    plan.current=next;
    if(next>plan.peak){plan.peak=next;}
    plan.phase=1;
    return .ok(next);
}

// Caller destroys compiler arrays before freeze. Work and retention are exclusive.
// Check retention first so denial retains phase 1 and its reservation for retry.
pub fn Result<usize,Error> begin_retention(ref mut Plan plan,usize persistent) {
    if(plan.phase!=1){return .err(.State);}
    if(persistent>plan.combined_limit-plan.baseline){return .err(.Quota);}
    let usize next=plan.baseline+persistent;
    plan.working_bytes=0;
    plan.persistent_bytes=persistent;
    plan.current=next;
    if(next>plan.peak){plan.peak=next;}
    plan.phase=2;
    return .ok(next);
}

// Published persistent storage remains observed after successful compilation.
pub fn Result<usize,Error> finish(ref mut Plan plan) {
    if(plan.phase!=2){return .err(.State);}
    plan.phase=3;
    return .ok(plan.current);
}

// Caller destroys failed compilation/retention storage before releasing charges.
pub fn Result<usize,Error> abort(ref mut Plan plan) {
    if(plan.phase!=1 && plan.phase!=2){return .err(.State);}
    plan.working_bytes=0;
    plan.persistent_bytes=0;
    plan.current=plan.baseline;
    plan.phase=3;
    return .ok(plan.current);
}
